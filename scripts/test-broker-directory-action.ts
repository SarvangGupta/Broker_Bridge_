import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
import { getBrokerDirectoryContactsAction } from '../src/server/actions/broker-directory-actions';

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
  const token = authData.session.access_token;
  console.log('Varun authenticated, token obtained. Calling getBrokerDirectoryContactsAction...');

  const result = await getBrokerDirectoryContactsAction({ role: 'all' }, token);
  console.log('Result success:', result.success);
  if (!result.success) {
    console.error('Error:', result.error);
  } else {
    console.log('Stats:', result.data?.stats);
    console.log(`Contacts count: ${result.data?.contacts.length}`);
    console.table(result.data?.contacts.map(c => ({
      name: c.name,
      role: c.role,
      company: c.companyName,
      openReqs: c.openRequirementsCount,
      offers: c.availableOffersCount,
      deals: c.activeDealsCount,
    })));
  }

  process.exit(0);
}

main().catch(console.error);
