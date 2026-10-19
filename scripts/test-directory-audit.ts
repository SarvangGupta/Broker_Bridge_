import 'dotenv/config';
import { db } from '../src/server/db';
import { sql } from 'drizzle-orm';
import { createClient } from '@supabase/supabase-js';

async function main() {
  const varunId = 'b354958e-779a-41f2-b7a3-5899eca32e32';

  console.log('=== 1. DATABASE ROW COUNTS (SERVICE ROLE) ===');
  const [contactsCount]: any = await db.execute(sql`SELECT count(*)::int as count FROM public.crm_contacts;`);
  const [varunContactsCount]: any = await db.execute(sql`SELECT count(*)::int as count FROM public.crm_contacts WHERE broker_id = ${varunId};`);
  const [companiesCount]: any = await db.execute(sql`SELECT count(*)::int as count FROM public.companies;`);
  const [usersCount]: any = await db.execute(sql`SELECT count(*)::int as count FROM public.users;`);
  const [activitiesCount]: any = await db.execute(sql`SELECT count(*)::int as count FROM public.crm_activities;`);

  console.log(`public.crm_contacts total: ${contactsCount.count} | Varun Owned: ${varunContactsCount.count}`);
  console.log(`public.companies total: ${companiesCount.count}`);
  console.log(`public.users total: ${usersCount.count}`);
  console.log(`public.crm_activities total: ${activitiesCount.count}`);

  console.log('\n=== 2. VARUN CRM CONTACTS DETAILS ===');
  const varunContacts: any = await db.execute(sql`
    SELECT 
      c.id, c.broker_id, c.user_id, c.company_id, c.created_at,
      u.name as user_name, u.role as user_role, u.mobile as user_mobile, u.email as user_email,
      comp.name as company_name, comp.district_id, comp.state_id
    FROM public.crm_contacts c
    LEFT JOIN public.users u ON u.id = c.user_id
    LEFT JOIN public.companies comp ON comp.id = c.company_id
    WHERE c.broker_id = ${varunId};
  `);
  console.table(varunContacts);

  console.log('\n=== 3. TABLE GRANTS FOR AUTHENTICATED ROLE ===');
  const grants: any = await db.execute(sql`
    SELECT table_name, privilege_type
    FROM information_schema.role_table_grants
    WHERE grantee = 'authenticated'
      AND table_schema = 'public'
      AND table_name IN ('crm_contacts', 'companies', 'users', 'crm_activities')
    ORDER BY table_name, privilege_type;
  `);
  console.table(grants);

  console.log('\n=== 4. RLS POLICIES ===');
  const policies: any = await db.execute(sql`
    SELECT tablename, policyname, cmd, roles, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('crm_contacts', 'companies', 'users', 'crm_activities')
    ORDER BY tablename, policyname;
  `);
  console.table(policies);

  console.log('\n=== 5. RUN EXACT POSTGREST QUERY AS AUTHENTICATED VARUN ===');
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://imztlkvkxzeaekxvmcfe.supabase.co';
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
  const supabase = createClient(supabaseUrl, supabaseAnonKey);

  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'varun@gmail.com',
    password: process.env.DEMO_USER_PASSWORD || 'varun123',
  });

  if (authErr || !authData.session) {
    console.error('Varun auth failed:', authErr);
    process.exit(1);
  }
  console.log(`Authenticated as Varun (${authData.user.id})`);

  // Run the exact query from DirectoryRepository.getContacts() line 144
  const res = await supabase
    .from('crm_contacts')
    .select(
      'id, broker_id, user_id, company_id, last_activity_at, created_at, ' +
      'users(id, name, mobile, email, role, status), ' +
      'companies(id, name, status, is_verified, trust_score, district_id, state_id)'
    )
    .eq('broker_id', varunId)
    .order('created_at', { ascending: false });

  if (res.error) {
    console.error('DirectoryRepository PostgREST query FAILED:');
    console.error(JSON.stringify(res.error, null, 2));
  } else {
    console.log(`DirectoryRepository PostgREST query SUCCEEDED! Rows returned: ${res.data?.length}`);
    console.log('Sample row:');
    console.log(JSON.stringify(res.data?.[0], null, 2));
  }

  process.exit(0);
}
main().catch(console.error);
