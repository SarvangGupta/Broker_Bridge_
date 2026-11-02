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
  categoryId?: string;
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
  gstin: string | null;
  gstVerificationStatus: string | null;
}

type Db = PostgresJsDatabase<Record<string, unknown>>;

function scopeSql(scope: DirectoryScope): SQL {
  const brokerPart = scope.isAdmin ? sql`true` : sql`c.broker_id = ${scope.brokerId}::uuid`;
  return sql`${brokerPart} and c.removed_at is null`;
}

/** No saved categories means All Categories; otherwise the category must be saved. */
function categoryMatchSql(buyerId: SQL, categoryId: string): SQL {
  return sql`(
    not exists (select 1 from buyer_category_preferences p where p.buyer_id = ${buyerId})
    or exists (
      select 1 from buyer_category_preferences p
      where p.buyer_id = ${buyerId} and p.category_id = ${categoryId}::uuid
    )
  )`;
}

/** False until migration 0064 is applied; every buyer is then All Categories. */
export async function categoryPreferencesAvailable(database: Db): Promise<boolean> {
  const rows = (await database.execute(
    sql`select to_regclass('public.buyer_category_preferences') is not null as "available"`
  )) as unknown as Array<{ available: boolean }>;
  return rows[0]?.available === true;
}

/** Saved categories per buyer user id; buyers with none are simply absent. */
export async function queryBuyerCategories(
  database: Db,
  buyerIds: string[]
): Promise<Map<string, Array<{ id: string; name: string }>>> {
  const out = new Map<string, Array<{ id: string; name: string }>>();
  if (buyerIds.length === 0 || !(await categoryPreferencesAvailable(database))) return out;
  const rows = (await database.execute(sql`
    select p.buyer_id as "buyerId", m.id::text as "id", m.name as "name"
    from buyer_category_preferences p
    join master_categories m on m.id = p.category_id
    where p.buyer_id in (${sql.join(buyerIds.map((id) => sql`${id}::uuid`), sql`, `)})
    order by m.name
  `)) as unknown as Array<{ buyerId: string; id: string; name: string }>;
  for (const r of rows) {
    out.set(r.buyerId, [...(out.get(r.buyerId) ?? []), { id: r.id, name: r.name }]);
  }
  return out;
}

/**
 * An active buyer this broker may find: one with its own sign-in, one created
 * by an admin, one no broker has linked (a backend-created record), or one
 * already linked to this broker. A contact typed in by another broker has no
 * sign-in and carries that broker's link, so it never matches.
 */
function discoverableBuyerSql(brokerId: string): SQL {
  return sql`
    lower(trim(coalesce(u.role, ''))) = 'buyer'
    and u.status and co.status
    and to_jsonb(u)->>'removed_at' is null
    and (
      exists (select 1 from auth.users au where au.id = u.id)
      or exists (
        select 1 from users creator
        where creator.id::text = to_jsonb(u)->>'created_by' and lower(creator.role) = 'admin'
      )
      or not exists (select 1 from crm_contacts l where l.user_id = u.id or l.company_id = co.id)
      or exists (
        select 1 from crm_contacts l
        where l.broker_id = ${brokerId}::uuid and (l.user_id = u.id or l.company_id = co.id)
      )
    )
  `;
}

export interface DiscoverableBuyerRow {
  userId: string;
  name: string;
  companyId: string;
  companyName: string;
  tradeName: string | null;
  gstin: string | null;
  gstVerificationStatus: string | null;
  location: string | null;
  contactId: string | null;
}

export const DISCOVERY_MIN_SEARCH = 3;
const DISCOVERY_LIMIT = 30;

/**
 * Eligible buyers matching name, company, trade/legal name, or an exact
 * GSTIN, email or full mobile.
 * Selects no mobile, email or bank data: those stay private until linked.
 * GST columns are read through to_jsonb so a database without them still works.
 */
export async function queryDiscoverableBuyers(
  database: Db,
  brokerId: string,
  filter: { search: string; categoryId?: string }
): Promise<DiscoverableBuyerRow[]> {
  const q = filter.search.trim();
  const p = `%${escapeLikePattern(q)}%`;
  // Full numbers only: partial digits would let a broker enumerate mobiles.
  const digits = q.replace(/\D/g, '');
  const mobile10 = digits.length >= 10 && !/[a-z]/i.test(q) ? digits.slice(-10) : null;
  const result = await database.execute(sql`
    select
      u.id as "userId", u.name as "name", co.id as "companyId", co.name as "companyName",
      to_jsonb(co)->>'trade_name' as "tradeName",
      to_jsonb(co)->>'gst' as "gstin",
      to_jsonb(co)->>'gst_verification_status' as "gstVerificationStatus",
      coalesce(md.name, case when co.district_id ~* ${UUID_RE} then null else co.district_id end) as "location",
      (select c.id from crm_contacts c
        where c.broker_id = ${brokerId}::uuid and c.company_id = co.id and c.removed_at is null
        limit 1) as "contactId"
    from users u
    join companies co on co.id = u.company_id
    left join master_districts md on md.id::text = co.district_id
    where ${discoverableBuyerSql(brokerId)}
      and (
        u.name ilike ${p}
        or co.name ilike ${p}
        or coalesce(to_jsonb(co)->>'trade_name', '') ilike ${p}
        or coalesce(to_jsonb(co)->>'legal_name', '') ilike ${p}
        or upper(coalesce(to_jsonb(co)->>'gst', '')) = ${q.toUpperCase()}
        or lower(coalesce(u.email, '')) = ${q.toLowerCase()}
        ${mobile10 ? sql`or right(regexp_replace(coalesce(u.mobile, ''), '\\D', '', 'g'), 10) = ${mobile10}` : sql``}
      )
      ${filter.categoryId ? sql`and ${categoryMatchSql(sql`u.id`, filter.categoryId)}` : sql``}
    order by co.name, u.id
    limit ${DISCOVERY_LIMIT}
  `);
  return result as unknown as DiscoverableBuyerRow[];
}

/**
 * Links an eligible buyer to the broker using the existing user and company.
 * Writes crm_contacts only. The advisory lock serialises concurrent adds, as
 * crm_contacts has no unique (broker, company) constraint.
 */
export async function linkExistingBuyer(
  database: Db,
  brokerId: string,
  buyerUserId: string
): Promise<{ outcome: 'not_eligible' } | { outcome: 'already' | 'reactivated' | 'created'; contactId: string }> {
  return database.transaction(async (tx) => {
    const buyers = (await tx.execute(sql`
      select u.id as "userId", co.id as "companyId"
      from users u
      join companies co on co.id = u.company_id
      where u.id = ${buyerUserId}::uuid and ${discoverableBuyerSql(brokerId)}
    `)) as unknown as Array<{ userId: string; companyId: string }>;
    const buyer = buyers[0];
    if (!buyer) return { outcome: 'not_eligible' as const };

    await tx.execute(
      sql`select pg_advisory_xact_lock(hashtextextended(${`${brokerId}:${buyer.companyId}`}, 0))`
    );
    const links = (await tx.execute(sql`
      select id, removed_at as "removedAt" from crm_contacts
      where broker_id = ${brokerId}::uuid and company_id = ${buyer.companyId}::uuid
      order by removed_at nulls first, created_at
      limit 1
    `)) as unknown as Array<{ id: string; removedAt: string | null }>;
    const link = links[0];
    if (link && link.removedAt == null) return { outcome: 'already' as const, contactId: link.id };
    if (link) {
      await tx.execute(sql`
        update crm_contacts set removed_at = null, last_activity_at = now() where id = ${link.id}::uuid
      `);
      return { outcome: 'reactivated' as const, contactId: link.id };
    }
    const created = (await tx.execute(sql`
      insert into crm_contacts (broker_id, user_id, company_id, last_activity_at)
      values (${brokerId}::uuid, ${buyer.userId}::uuid, ${buyer.companyId}::uuid, now())
      returning id
    `)) as unknown as Array<{ id: string }>;
    return { outcome: 'created' as const, contactId: created[0].id };
  });
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
  if (filter.categoryId) {
    parts.push(sql`(
      lower(trim(coalesce(u.role, ''))) = 'seller'
      or ${categoryMatchSql(sql`u.id`, filter.categoryId)}
    )`);
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
      co.district_id as "districtId", co.state_id as "stateId",
      to_jsonb(co)->>'gst' as "gstin",
      to_jsonb(co)->>'gst_verification_status' as "gstVerificationStatus"
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
