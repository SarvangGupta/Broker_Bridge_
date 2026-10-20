import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
import { db } from '../src/server/db';
import { requirements } from '../src/server/db/schema';
import { eq } from 'drizzle-orm';
import {
  getBuyerNegotiationDetailsAction,
  getBuyerNegotiationTimelineAction,
  sendProposalToBuyerAction,
} from '../src/server/actions/broker-buyer-actions';

async function main() {
  console.log('=== AUTHENTICATING VARUN ===');
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
  console.log('Varun authenticated successfully!');

  // Find a requirement assigned to Varun
  const req = await db.query.requirements.findFirst({
    where: eq(requirements.brokerId, 'b354958e-779a-41f2-b7a3-5899eca32e32'),
  });

  if (!req) {
    console.error('No requirement found for Varun');
    process.exit(1);
  }

  console.log(`\nRequirement: ${req.id}, Quantity: ${req.quantity}, Target Price: ₹${req.targetPrice}`);

  // Test 1: Get Details
  console.log('\n--- Testing getBuyerNegotiationDetailsAction ---');
  const details = await getBuyerNegotiationDetailsAction(req.id, token);
  console.log('Details Result Success:', details.success);
  if (details.data) {
    console.log(`Commodity: ${details.data.commodityName}, Buyer: ${details.data.buyerCompanyName}, Active Version: v${details.data.currentVersionNumber}`);
  }

  // Test 2: Get Timeline
  console.log('\n--- Testing getBuyerNegotiationTimelineAction ---');
  const timeline = await getBuyerNegotiationTimelineAction(req.id, token);
  console.log('Timeline Result Success:', timeline.success, 'Rounds Count:', timeline.data?.length || 0);

  // Test 3: Send Proposal
  console.log('\n--- Testing sendProposalToBuyerAction ---');
  const proposalRes = await sendProposalToBuyerAction({
    requirement_id: req.id,
    offered_price: Number(req.targetPrice) + 50,
    quantity: Number(req.quantity),
    delivery_date: '2026-11-15',
    payment_terms: '100% Against Delivery & Weighbridge Verification',
    packaging: '50kg HDPE / PP Laminated Bags',
    broker_notes: 'Broker verified mandi lot proposal from RMBroker desk.',
    expected_version_number: details.data?.currentVersionNumber || 0,
  }, token);

  console.log('Proposal Result:', proposalRes);

  // Test 4: Re-verify timeline after proposal
  console.log('\n--- Re-verifying Timeline After Proposal Submission ---');
  const updatedTimeline = await getBuyerNegotiationTimelineAction(req.id, token);
  console.log('Updated Timeline Rounds Count:', updatedTimeline.data?.length || 0);
  if (updatedTimeline.data && updatedTimeline.data.length > 0) {
    const latest = updatedTimeline.data[updatedTimeline.data.length - 1];
    console.log(`Latest Round: v${latest.versionNumber}, Status: ${latest.status}, Rate: ₹${latest.rate}`);
  }

  console.log('\n=== ALL PROPOSAL BACKEND TESTS PASSED ===');
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
