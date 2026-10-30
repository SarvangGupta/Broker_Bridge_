import { sql, type SQL } from 'drizzle-orm';
import type { PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import { ZodError } from 'zod';

// ============================================================================
// Broker directory list query: server-side filters + keyset pagination.
// Kept out of the 'use server' actions file so the pure helpers can be tested.
// ============================================================================

export const DIRECTORY_PAGE_MAX = 100;

const UUID_RE = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
const UUID_JS = new RegExp(UUID_RE, 'i');

export interface DirectoryScope {
  brokerId: string;
  isAdmin: boolean;
}

export interface DirectoryListFilter {
  role?: 'all' | 'buyer' | 'seller';
  status?: 'all' | 'active' | 'inactive';
  search?: string;
}

/** Position after the last row of a page: `crm_contacts.created_at` + `id`. */
export interface DirectoryCursor {
  createdAt: string;
  id: string;
}

/**
 * Cursor wire format: `<created_at>|<id>`, the same shape the mobile app's
 * direct Supabase path produces, so either side can continue a list.
 */
export function encodeDirectoryCursor(c: DirectoryCursor): string {
  return `${c.createdAt}|${c.id}`;
}

/** Returns null for a malformed cursor (never trusted into SQL unchecked). */
export function decodeDirectoryCursor(raw: string | null | undefined): DirectoryCursor | null {
  if (!raw) return null;
  const sep = raw.lastIndexOf('|');
  if (sep <= 0) return null;
  const createdAt = raw.slice(0, sep).trim();
  const id = raw.slice(sep + 1).trim();
  if (!UUID_JS.test(id)) return null;
  if (!/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d{1,6})?$/.test(createdAt)) return null;
  return { createdAt, id };
}

/** Clamps a requested page size; undefined means "no paging" (full list). */
export function parseDirectoryLimit(raw: string | null | undefined): number | undefined {
  if (raw == null || raw === '') return undefined;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n) || n < 1) return 1;
  return Math.min(n, DIRECTORY_PAGE_MAX);
}

/**
 * ISO string for a `timestamp` (without time zone) rendered as text. Stored
 * values are UTC, as Drizzle's own mapping assumes.
 */
export function pgTimestampToIso(text: string): string {
  const m = /^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})(\.\d+)?/.exec(text);
  if (!m) return new Date(text).toISOString();
  const ms = (m[3] ?? '.000').padEnd(4, '0').slice(0, 4);
  return new Date(`${m[1]}T${m[2]}${ms}Z`).toISOString();
}

export function escapeLikePattern(q: string): string {
  return q.replace(/[\\%_]/g, (m) => `\\${m}`);
}

/**
 * A message safe to show the broker. Validation messages pass through;
 * database/driver errors are replaced by [fallback] (details stay in logs).
 */
export function publicDirectoryError(error: unknown, fallback: string): string {
  if (error instanceof ZodError) return error.issues[0]?.message ?? fallback;
  return fallback;
}

/**
 * HTTP status for a failed directory action. Only a missing/invalid session
 * is 401: the app clears its stored session on 401, so a permission problem
 * on one contact must not log the broker out.
 */
export function directoryErrorStatus(error: string | undefined): number {
  const e = (error ?? '').toLowerCase();
  if (e.includes('valid broker session')) return 401;
  if (e.includes('forbidden') || e.includes('permission') || e.includes('unauthorized')) return 403;
  if (e.includes('not found')) return 404;
  return 400;
}

export interface DirectoryRow {
  contactId: string;
  createdAt: string; // created_at::text, full precision (used for the cursor)
  userId: string;
  userName: string;
  userMobile: string | null;
  userEmail: string | null;
  userRole: string | null;
  userStatus: boolean;
  companyId: string;
  companyName: string;
  companyStatus: boolean;
  isVerified: boolean;
  trustScore: number;
  districtId: string | null;
  stateId: string | null;
}

type Db = PostgresJsDatabase<Record<string, unknown>>;

function scopeSql(scope: DirectoryScope): SQL {
  const brokerPart = scope.isAdmin ? sql`true` : sql`c.broker_id = ${scope.brokerId}::uuid`;
  return sql`${brokerPart} and c.removed_at is null`;
}

/** Filters matching the app's `DirectoryContact.matchesFilters` exactly. */
function filterSql(filter: DirectoryListFilter): SQL[] {
  const parts: SQL[] = [];
  if (filter.role === 'seller') {
    parts.push(sql`lower(trim(coalesce(u.role, ''))) = 'seller'`);
  } else if (filter.role === 'buyer') {
    parts.push(sql`lower(trim(coalesce(u.role, ''))) <> 'seller'`);
  }
  if (filter.status === 'active') {
    parts.push(sql`(u.status and co.status)`);
  } else if (filter.status === 'inactive') {
    parts.push(sql`not (u.status and co.status)`);
  }
  const q = filter.search?.trim().toLowerCase();
  if (q) {
    const p = `%${escapeLikePattern(q)}%`;
    const digits = q.replace(/\D/g, '');
    // Location matches the displayed label: master name for a UUID value,
    // otherwise the stored text (never the raw UUID).
    parts.push(sql`(
      u.name ilike ${p}
      or co.name ilike ${p}
      or coalesce(u.email, '') ilike ${p}
      ${digits.length >= 3 ? sql`or regexp_replace(coalesce(u.mobile, ''), '\\D', '', 'g') like ${`%${digits}%`}` : sql``}
      or coalesce(md.name, case when co.district_id ~* ${UUID_RE} then null else co.district_id end, '') ilike ${p}
      or coalesce(ms.name, case when co.state_id ~* ${UUID_RE} then null else co.state_id end, '') ilike ${p}
    )`);
  }
  return parts;
}

/**
 * One page (or, with no [limit], the full list) of the broker's contacts,
 * newest first, ordered by (created_at, id) so keyset paging never repeats
 * or skips a row even while contacts are added.
 */
export async function queryDirectoryPage(
  database: Db,
  scope: DirectoryScope,
  filter: DirectoryListFilter,
  page: { limit?: number; after?: DirectoryCursor | null } = {}
): Promise<{ rows: DirectoryRow[]; hasMore: boolean; nextCursor: string | null }> {
  const where = [scopeSql(scope), ...filterSql(filter)];
  if (page.after) {
    where.push(sql`(c.created_at, c.id) < (${page.after.createdAt}::timestamp, ${page.after.id}::uuid)`);
  }
  const fetch = page.limit ? page.limit + 1 : undefined;

  const result = await database.execute(sql`
    select
      c.id as "contactId", c.created_at::text as "createdAt",
      u.id as "userId", u.name as "userName", u.mobile as "userMobile",
      u.email as "userEmail", u.role as "userRole", u.status as "userStatus",
      co.id as "companyId", co.name as "companyName", co.status as "companyStatus",
      co.is_verified as "isVerified", co.trust_score as "trustScore",
      co.district_id as "districtId", co.state_id as "stateId"
    from crm_contacts c
    join users u on u.id = c.user_id
    join companies co on co.id = c.company_id
    left join master_districts md on md.id::text = co.district_id
    left join master_states ms on ms.id::text = co.state_id
    where ${sql.join(where, sql` and `)}
    order by c.created_at desc, c.id desc
    ${fetch ? sql`limit ${fetch}` : sql``}
  `);

  const all = result as unknown as DirectoryRow[];
  const hasMore = page.limit != null && all.length > page.limit;
  const rows = hasMore ? all.slice(0, page.limit) : all;
  const last = rows[rows.length - 1];
  return {
    rows,
    hasMore,
    nextCursor: hasMore && last ? encodeDirectoryCursor({ createdAt: last.createdAt, id: last.contactId }) : null,
  };
}

/** Summary stats over ALL of the broker's contacts (unaffected by paging/filters). */
export async function queryDirectoryStats(database: Db, scope: DirectoryScope) {
  const brokerFilter = (col: SQL) => (scope.isAdmin ? sql`true` : sql`${col} = ${scope.brokerId}::uuid`);
  const result = await database.execute(sql`
    select
      count(*)::int as "totalContacts",
      count(*) filter (where u.status and co.status and lower(trim(coalesce(u.role, ''))) <> 'seller')::int as "buyersCount",
      count(*) filter (where u.status and co.status and lower(trim(coalesce(u.role, ''))) = 'seller')::int as "sellersCount",
      coalesce(sum(
        (select count(*) from requirements r
          where r.company_id = c.company_id and ${brokerFilter(sql`r.broker_id`)}
            and r.status in ('Open', 'Partially Fulfilled'))
        + (select count(*) from availabilities a
          where a.company_id = c.company_id and ${brokerFilter(sql`a.broker_id`)} and a.status = 'Open')
        + (select count(*) from deals d
          where (d.buyer_id = c.company_id or d.seller_id = c.company_id)
            and ${brokerFilter(sql`d.broker_id`)} and d.status not in ('Closed', 'Cancelled'))
      ), 0)::int as "activeMandatesCount"
    from crm_contacts c
    join users u on u.id = c.user_id
    join companies co on co.id = c.company_id
    where ${scopeSql(scope)}
  `);
  const row = (result as unknown as Array<Record<string, number>>)[0] ?? {};
  return {
    totalContacts: row.totalContacts ?? 0,
    buyersCount: row.buyersCount ?? 0,
    sellersCount: row.sellersCount ?? 0,
    activeMandatesCount: row.activeMandatesCount ?? 0,
  };
}
