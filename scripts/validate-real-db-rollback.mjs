import postgres from 'postgres';
import fs from 'node:fs';

const env = Object.fromEntries(
  fs.readFileSync('.env.local', 'utf8').split(/\r?\n/)
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')])
);

const sql = postgres(env.DATABASE_URL, { prepare: false, max: 1 });

async function runValidation() {
  console.log('=== REAL POSTGRESQL RLS & SCHEMA VALIDATION (ROLLED BACK) ===');
  
  // We run inside a transaction and ALWAYS abort/rollback at the end
  try {
    await sql.begin(async (trx) => {
      console.log('1. Transaction started (will be rolled back).');
      
      // Load proposed 0048 migration SQL, stripping top-level BEGIN and COMMIT so our outer transaction controls rollback
      let migrationSql = fs.readFileSync('supabase/proposed/0048_reconciled_seller_listings_and_broker_check.sql', 'utf8')
        .replace(/^BEGIN;/m, '-- BEGIN;')
        .replace(/^COMMIT;/m, '-- COMMIT;');
      console.log('2. Applying proposed 0048 SQL within transaction...');
      await trx.unsafe(migrationSql);
      console.log('   -> 0048 applied successfully within transaction.');

      // Setup test UUIDs
      const indiv1 = '00000000-0000-4000-8000-000000000001';
      const indiv2 = '00000000-0000-4000-8000-000000000002';
      const activeBroker = 'b354958e-779a-41f2-b7a3-5899eca32e32'; // Real active broker from DB
      const existingCompany = 'c36a6176-b333-40a2-aa59-866632483d36'; // Real company from DB
      
      // Real foreign keys needed for availabilities insert
      const commRow = await trx`SELECT id FROM public.master_commodities LIMIT 1;`;
      const gradeRow = await trx`SELECT id FROM public.master_grades LIMIT 1;`;
      const unitRow = await trx`SELECT id FROM public.master_units LIMIT 1;`;
      const stateRow = await trx`SELECT id FROM public.master_states LIMIT 1;`;
      const distRow = await trx`SELECT id FROM public.master_districts LIMIT 1;`;
      
      const commId = commRow[0].id;
      const gradeId = gradeRow[0].id;
      const unitId = unitRow[0].id;
      const stateId = stateRow[0].id;
      const distId = distRow[0].id;

      // Provision temporary test users
      await trx`
        INSERT INTO public.users (id, name, email, role, status, company_id)
        VALUES 
          (${indiv1}, 'Indiv Seller 1', 'indiv1@test.com', 'seller', true, NULL),
          (${indiv2}, 'Indiv Seller 2', 'indiv2@test.com', 'seller', true, NULL)
        ON CONFLICT (id) DO UPDATE SET role = 'seller', company_id = NULL;
      `;
      console.log('3. Test individual sellers provisioned in users table.');

      // Test 4: Mutual exclusivity constraint (both set)
      console.log('4. Testing owner check constraint (both company_id and seller_user_id set)...');
      try {
        await trx.savepoint(async (sp) => {
          await sp`
            INSERT INTO public.availabilities (
              company_id, seller_user_id, commodity_id, grade_id, unit_id,
              quantity, total_quantity, available_quantity, asking_price, price,
              state_id, district_id, status, lot_number, valid_until
            ) VALUES (
              ${existingCompany}, ${indiv1}, ${commId}, ${gradeId}, ${unitId},
              10, 10, 10, 2000, 2000, ${stateId}, ${distId}, 'Open', 'TEST-FAIL-BOTH', '2026-11-15'
            );
          `;
        });
        throw new Error('FAILED: Mutual exclusivity constraint did not reject both set!');
      } catch (e) {
        if (e.message.includes('availabilities_owner_check') || e.code === '23514') {
          console.log('   -> Correctly rejected by availabilities_owner_check constraint (23514).');
        } else {
          throw e;
        }
      }

      // Test 5: Mutual exclusivity constraint (neither set)
      console.log('5. Testing owner check constraint (neither set)...');
      try {
        await trx.savepoint(async (sp) => {
          await sp`
            INSERT INTO public.availabilities (
              company_id, seller_user_id, commodity_id, grade_id, unit_id,
              quantity, total_quantity, available_quantity, asking_price, price,
              state_id, district_id, status, lot_number, valid_until
            ) VALUES (
              NULL, NULL, ${commId}, ${gradeId}, ${unitId},
              10, 10, 10, 2000, 2000, ${stateId}, ${distId}, 'Open', 'TEST-FAIL-NONE', '2026-11-15'
            );
          `;
        });
        throw new Error('FAILED: Mutual exclusivity constraint did not reject neither set!');
      } catch (e) {
        if (e.message.includes('availabilities_owner_check') || e.code === '23514') {
          console.log('   -> Correctly rejected by availabilities_owner_check constraint (23514).');
        } else {
          throw e;
        }
      }

      // Test 6: Authenticated RLS - Individual Seller 1 inserts own lot
      console.log('6. Testing RLS: Individual Seller 1 inserts own lot...');
      await trx`SET LOCAL ROLE authenticated;`;
      await trx.unsafe(`SET LOCAL "request.jwt.claim.sub" = '${indiv1}';`);
      await trx.unsafe(`SET LOCAL "request.jwt.claim.role" = 'authenticated';`);

      const inserted = await trx`
        INSERT INTO public.availabilities (
          seller_user_id, commodity_id, grade_id, unit_id,
          quantity, total_quantity, available_quantity, asking_price, price,
          state_id, district_id, status, lot_number, broker_id, valid_until
        ) VALUES (
          ${indiv1}, ${commId}, ${gradeId}, ${unitId},
          10, 10, 10, 2500, 2500, ${stateId}, ${distId}, 'Open', 'LOT-INDIV-001', ${activeBroker}, '2026-11-15'
        ) RETURNING id, seller_user_id, lot_number, status;
      `;
      console.log('   -> Inserted lot:', inserted[0].lot_number, 'id:', inserted[0].id);

      // Test 7: Authenticated RLS - Individual Seller 1 attempts to insert for Individual Seller 2 (impersonation)
      console.log('7. Testing RLS: Individual Seller 1 attempts to insert lot owned by Seller 2...');
      try {
        await trx.savepoint(async (sp) => {
          await sp`
            INSERT INTO public.availabilities (
              seller_user_id, commodity_id, grade_id, unit_id,
              quantity, total_quantity, available_quantity, asking_price, price,
              state_id, district_id, status, lot_number, valid_until
            ) VALUES (
              ${indiv2}, ${commId}, ${gradeId}, ${unitId},
              10, 10, 10, 2500, 2500, ${stateId}, ${distId}, 'Open', 'LOT-SPOOF', '2026-11-15'
            );
          `;
        });
        throw new Error('FAILED: RLS allowed cross-seller insert!');
      } catch (e) {
        if (e.code === '42501' || e.message.includes('row-level security')) {
          console.log('   -> Correctly rejected by RLS insert policy (42501).');
        } else {
          throw e;
        }
      }

      // Test 8: Authenticated RLS - Individual Seller 1 reads lots (Isolation check)
      console.log('8. Testing RLS Isolation: Individual Seller 1 reads availabilities...');
      const readLots = await trx`SELECT id, lot_number, seller_user_id, company_id FROM public.availabilities;`;
      console.log('   -> Lots visible to Individual Seller 1:', readLots.map((r) => r.lot_number));
      if (readLots.some((r) => r.seller_user_id === indiv2)) {
        throw new Error('FAILED: Seller 1 saw Seller 2 lots!');
      }

      // Test 9: Authenticated RLS - Update asking price
      console.log('9. Testing RLS: Individual Seller 1 updates asking price of own lot...');
      const updated = await trx`
        UPDATE public.availabilities
        SET asking_price = 2700, price = 2700
        WHERE id = ${inserted[0].id}
        RETURNING id, asking_price;
      `;
      console.log('   -> Price updated to:', updated[0].asking_price);

      // Test 10: Duplicate lot number protection for individual seller
      console.log('10. Testing duplicate lot number protection for individual seller...');
      try {
        await trx.savepoint(async (sp) => {
          await sp`
            INSERT INTO public.availabilities (
              seller_user_id, commodity_id, grade_id, unit_id,
              quantity, total_quantity, available_quantity, asking_price, price,
              state_id, district_id, status, lot_number, valid_until
            ) VALUES (
              ${indiv1}, ${commId}, ${gradeId}, ${unitId},
              15, 15, 15, 2600, 2600, ${stateId}, ${distId}, 'Open', 'LOT-INDIV-001', '2026-11-15'
            );
          `;
        });
        throw new Error('FAILED: Duplicate lot number was allowed for individual seller!');
      } catch (e) {
        if (e.code === '23505' || e.message.includes('unique constraint') || e.message.includes('duplicate key')) {
          console.log('   -> Correctly rejected by unique index (23505).');
        } else {
          throw e;
        }
      }

      // Switch back to postgres superuser role to test rollback
      await trx`RESET ROLE;`;
      
      console.log('11. Forcing transaction rollback now to ensure ZERO production writes...');
      throw new Error('INTENTIONAL_ROLLBACK');
    });
  } catch (err) {
    if (err.message === 'INTENTIONAL_ROLLBACK') {
      console.log('=== TRANSACTION SAFELY ROLLED BACK (NO CHANGES COMMITTED) ===');
    } else {
      console.error('Validation error:', err);
      process.exit(1);
    }
  }

  // Verify post-rollback state
  const postCheck = await sql`
    SELECT count(*) as count FROM public.availabilities WHERE lot_number = 'LOT-INDIV-001';
  `;
  console.log('Post-check: LOT-INDIV-001 exists in database?', postCheck[0].count > 0 ? 'YES (UNEXPECTED)' : 'NO (VERIFIED ZERO WRITES)');
  
  await sql.end();
}

runValidation();
