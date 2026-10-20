import 'dotenv/config';
import { db } from '../src/server/db';
import { sql } from 'drizzle-orm';

async function main() {
  console.log('=== UPDATING NEGOTIATION RLS POLICIES ===');

  // 1. Update deal_versions SELECT policy
  await db.execute(sql`
    DROP POLICY IF EXISTS deal_versions_select_policy ON deal_versions;
    CREATE POLICY deal_versions_select_policy ON deal_versions FOR SELECT USING (
      (EXISTS (
        SELECT 1 FROM deals d
        WHERE d.id = deal_versions.request_id
        AND (d.broker_id = auth.uid() OR is_admin())
      ))
      OR (EXISTS (
        SELECT 1 FROM requirements r
        WHERE r.id = deal_versions.request_id
        AND (r.broker_id = auth.uid() OR is_admin())
      ))
      OR (EXISTS (
        SELECT 1 FROM quotations q
        WHERE q.id = deal_versions.request_id
        AND (q.broker_id = auth.uid() OR is_admin())
      ))
      OR is_admin()
    );
  `);
  console.log('Updated deal_versions_select_policy');

  // 2. Update deal_versions INSERT policy
  await db.execute(sql`
    DROP POLICY IF EXISTS deal_versions_insert_policy ON deal_versions;
    CREATE POLICY deal_versions_insert_policy ON deal_versions FOR INSERT WITH CHECK (
      (EXISTS (
        SELECT 1 FROM deals d
        WHERE d.id = deal_versions.request_id
        AND (d.broker_id = auth.uid() OR is_admin())
      ))
      OR (EXISTS (
        SELECT 1 FROM requirements r
        WHERE r.id = deal_versions.request_id
        AND (r.broker_id = auth.uid() OR is_admin())
      ))
      OR (EXISTS (
        SELECT 1 FROM quotations q
        WHERE q.id = deal_versions.request_id
        AND (q.broker_id = auth.uid() OR is_admin())
      ))
      OR is_admin()
    );
  `);
  console.log('Updated deal_versions_insert_policy');

  // 3. Create negotiation_events policies
  await db.execute(sql`
    DROP POLICY IF EXISTS negotiation_events_select_policy ON negotiation_events;
    CREATE POLICY negotiation_events_select_policy ON negotiation_events FOR SELECT USING (
      actor_id = auth.uid()
      OR is_admin()
      OR EXISTS (
        SELECT 1 FROM requirements r
        WHERE r.id = negotiation_events.request_id
        AND (r.broker_id = auth.uid() OR is_admin())
      )
    );

    DROP POLICY IF EXISTS negotiation_events_insert_policy ON negotiation_events;
    CREATE POLICY negotiation_events_insert_policy ON negotiation_events FOR INSERT WITH CHECK (
      actor_id = auth.uid()
      OR is_admin()
    );
  `);
  console.log('Updated negotiation_events policies');

  console.log('=== POLICIES UPDATED SUCCESSFULLY ===');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
