import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';

async function main() {
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
  const varunId = authData.user.id;
  console.log(`Authenticated as Varun (${varunId})`);

  // Disambiguating the relation using 'users!user_id' or 'users!crm_contacts_user_id_fkey'
  const res = await supabase
    .from('crm_contacts')
    .select(
      'id, broker_id, user_id, company_id, last_activity_at, created_at, ' +
      'users!user_id(id, name, mobile, email, role, status), ' +
      'companies(id, name, status, is_verified, trust_score, district_id, state_id)'
    )
    .eq('broker_id', varunId)
    .order('created_at', { ascending: false });

  if (res.error) {
    console.error('PostgREST query FAILED with users!user_id:');
    console.error(res.error);

    // Try foreign key name
    console.log('Trying with users!crm_contacts_user_id_fkey...');
    const res2 = await supabase
      .from('crm_contacts')
      .select(
        'id, broker_id, user_id, company_id, last_activity_at, created_at, ' +
        'users!crm_contacts_user_id_fkey(id, name, mobile, email, role, status), ' +
        'companies(id, name, status, is_verified, trust_score, district_id, state_id)'
      )
      .eq('broker_id', varunId)
      .order('created_at', { ascending: false });

    if (res2.error) {
      console.error('res2 FAILED:', res2.error);
    } else {
      console.log(`res2 SUCCEEDED! Rows returned: ${res2.data?.length}`);
      console.table(res2.data?.map((d: any) => ({
        id: d.id.substring(0, 8),
        name: d.users?.name,
        role: d.users?.role,
        company: d.companies?.name
      })));
    }
  } else {
    console.log(`PostgREST query SUCCEEDED! Rows returned: ${res.data?.length}`);
    console.table(res.data?.map((d: any) => ({
      id: d.id.substring(0, 8),
      name: d.users?.name,
      role: d.users?.role,
      company: d.companies?.name
    })));
  }

  process.exit(0);
}
main().catch(console.error);
