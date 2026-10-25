import { sql } from 'drizzle-orm';
import type { PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import { encodeDirectoryCursor, pgTimestampToIso, type DirectoryCursor } from './broker-directory-query';

// ============================================================================
// Broker requirements list (GET /api/v1/broker/requirements).
// Same assignment rule as getBrokerAssignedRequirementsAction and the
// requirements RLS policy: only rows with broker_id = the signed-in broker.
// Rows use the snake_case shape the mobile app's direct path already flattens
// to, so RequirementItem.fromJson parses either source identically.
// ============================================================================

type Db = PostgresJsDatabase<Record<string, unknown>>;

export interface BrokerRequirementsPage {
  requirements: Record<string, unknown>[];
  hasMore: boolean;
  nextCursor: string | null;
}

/**
 * Newest first, keyset on (created_at, id). Without [limit] the full list is
 * returned (the app's current behaviour); with it, one page plus a cursor.
 * Joins are LEFT so a missing master row never hides an assigned requirement.
 */
export async function queryBrokerRequirements(
  db: Db,
  brokerId: string,
  opts: { limit?: number; after?: DirectoryCursor | null } = {}
): Promise<BrokerRequirementsPage> {
  const after = opts.after
    ? sql`and (r.created_at < ${opts.after.createdAt}::timestamp
          or (r.created_at = ${opts.after.createdAt}::timestamp and r.id < ${opts.after.id}::uuid))`
    : sql``;
  const limit = opts.limit ? sql`limit ${opts.limit + 1}` : sql``;

  const rows = (await db.execute(sql`
    select r.id, r.company_id, r.commodity_id, r.grade_id, r.unit_id, r.broker_id,
      r.quantity, r.fulfilled_quantity, r.target_price, r.delivery_terms_id,
      r.target_date::text as target_date, r.status, r.visibility,
      r.created_at::text as created_at,
      c.name as buyer_company_name, c.is_verified as buyer_company_verified,
      c.trust_score as buyer_trust_score,
      mc.name as commodity_name, mc.code as commodity_code, cat.name as category_name,
      g.grade_name, g.parameters as quality_parameters,
      u.name as unit_name, u.symbol as unit_symbol
    from requirements r
    left join companies c on c.id = r.company_id
    left join master_commodities mc on mc.id = r.commodity_id
    left join master_categories cat on cat.id = mc.category_id
    left join master_grades g on g.id = r.grade_id
    left join master_units u on u.id = r.unit_id
    where r.broker_id = ${brokerId}::uuid ${after}
    order by r.created_at desc, r.id desc
    ${limit}
  `)) as unknown as Record<string, any>[];

  const hasMore = opts.limit != null && rows.length > opts.limit;
  const page = hasMore ? rows.slice(0, opts.limit) : rows;
  const last = page[page.length - 1];

  return {
    requirements: page.map((r) => ({
      ...r,
      quantity: Number(r.quantity) || 0,
      fulfilled_quantity: Number(r.fulfilled_quantity) || 0,
      target_price: Number(r.target_price) || 0,
      buyer_trust_score: r.buyer_trust_score == null ? null : Number(r.buyer_trust_score),
      target_date: r.target_date ? pgTimestampToIso(r.target_date) : null,
      created_at: pgTimestampToIso(r.created_at),
    })),
    hasMore,
    // Cursor keeps the raw timestamp text (full precision) for exact keyset.
    nextCursor: hasMore && last ? encodeDirectoryCursor({ createdAt: last.created_at, id: last.id }) : null,
  };
}
