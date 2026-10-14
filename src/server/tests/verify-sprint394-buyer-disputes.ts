/**
 * Comprehensive Automated Verification Suite for Micro-Sprint 39.4
 * Buyer Dispute Generation & Tracker (Sprint 39: Quality, Documents, Payments & Disputes)
 *
 * Verifies:
 * 1. Input Validation Guards:
 *    - Rejection of empty/whitespace booking IDs.
 *    - Strict rejection of unauthorized/invalid dispute categories.
 *    - Enforces 50-character minimum length on description.
 * 2. Category Strict Invariants:
 *    - Validates strictly against: 'Quality', 'Quantity', 'Delivery', 'Document', 'Payment', 'Commercial', 'Other'.
 * 3. Dispute Creation & State Engine:
 *    - createBuyerDisputeAction sets initial status to 'Open'.
 *    - Flags initiator as 'Buyer'.
 * 4. Active Dispute Ledger & Mediation Fetching:
 *    - getBuyerActiveDisputesAction returns structured dispute list and summary counts.
 * 5. Tenant Isolation & Privacy Scrubber:
 *    - Zero Seller identities exposed (no seller name, company, email, phone).
 *    - Zero internal Broker notes exposed in the read-only buyer payload.
 *    - Enforces neutral Broker mediation notice (no direct buyer-seller channel).
 * 6. Order Detail Page Component Mounting:
 *    - RaiseDisputeModal is imported and rendered in app/(buyer)/buyer/orders/[id]/page.tsx.
 *    - Positioned sequentially below BuyerPaymentCard in standard space-y-4 layout.
 * 7. Raise Dispute Modal Contract (raise-dispute-modal.tsx):
 *    - Destructive / Red outline trigger button.
 *    - useTransition submission with loading spinner.
 *    - 360px mobile-friendly layout and min-h-[48px] touch targets.
 * 8. Dedicated Dispute Tracker Contract (buyer/more/disputes/page.tsx & buyer-dispute-card.tsx):
 *    - Route exists at app/(buyer)/buyer/more/disputes/page.tsx.
 *    - STRICT UX RULE: Read-only tracker with ZERO chat box inputs.
 *    - Renders booking reference, category badge, date, description, and status.
 */

import {
  createBuyerDisputeAction,
  getBuyerActiveDisputesAction,
} from '../actions/buyer-dispute-actions';
import {
  BUYER_DISPUTE_CATEGORIES,
  BuyerDisputeCategory,
} from '@/src/types/buyer-dispute-types';
import * as fs from 'fs';
import * as path from 'path';

async function runSprint394Verification() {
  console.log('========================================================');
  console.log('  MICRO-SPRINT 39.4: BUYER DISPUTE GENERATION & TRACKER');
  console.log('========================================================\n');

  let passedTests = 0;
  let totalTests = 0;

  function assert(condition: boolean, testName: string, detail?: string) {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`✅ [PASS] ${testName}`);
      if (detail) console.log(`   └─ ${detail}`);
    } else {
      console.error(`❌ [FAIL] ${testName}`);
      if (detail) console.error(`   └─ Detail: ${detail}`);
    }
  }

  // --- 1. Validation Guards ---
  console.log('\n--- 1. Input Validation Guards ---');
  try {
    const emptyBookingRes = await createBuyerDisputeAction({
      booking_id: '',
      category: 'Quality',
      description:
        'This is a valid long description exceeding 50 characters to test booking ID validation exclusively.',
    });
    assert(
      !emptyBookingRes.success && Boolean(emptyBookingRes.error),
      'Validation: Rejects empty booking identifier',
      `Error: "${emptyBookingRes.error}"`
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects empty booking identifier', err.message);
  }

  try {
    const whitespaceBookingRes = await createBuyerDisputeAction({
      booking_id: '    ',
      category: 'Quality',
      description:
        'This is a valid long description exceeding 50 characters to test whitespace booking ID rejection.',
    });
    assert(
      !whitespaceBookingRes.success && Boolean(whitespaceBookingRes.error),
      'Validation: Rejects whitespace-only booking identifier'
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects whitespace-only booking identifier', err.message);
  }

  try {
    const invalidCategoryRes = await createBuyerDisputeAction({
      booking_id: 'BKG-2026-8812',
      category: 'ArbitraryInvalidCategory' as any,
      description:
        'This is a valid long description exceeding 50 characters to test category validation guard exclusively.',
    });
    assert(
      !invalidCategoryRes.success && Boolean(invalidCategoryRes.error?.includes('category')),
      'Validation: Rejects invalid dispute category outside strict enum',
      `Error: "${invalidCategoryRes.error}"`
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects invalid dispute category', err.message);
  }

  try {
    const shortDescRes = await createBuyerDisputeAction({
      booking_id: 'BKG-2026-8812',
      category: 'Quality',
      description: 'Too short (less than 50 chars)',
    });
    assert(
      !shortDescRes.success && Boolean(shortDescRes.error?.includes('50 characters')),
      'Validation: Rejects description under 50-character minimum length',
      `Error: "${shortDescRes.error}"`
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects short description', err.message);
  }

  // --- 2. Allowed Category Acceptance ---
  console.log('\n--- 2. Allowed Category Acceptance Invariants ---');
  assert(
    BUYER_DISPUTE_CATEGORIES.length === 7,
    'Categories: Exactly 7 strict dispute categories are defined',
    `Categories: ${BUYER_DISPUTE_CATEGORIES.join(', ')}`
  );

  const expectedCategories: BuyerDisputeCategory[] = [
    'Quality',
    'Quantity',
    'Delivery',
    'Document',
    'Payment',
    'Commercial',
    'Other',
  ];
  for (const cat of expectedCategories) {
    assert(
      BUYER_DISPUTE_CATEGORIES.includes(cat),
      `Category Supported: "${cat}" is authorized`
    );
  }

  // --- 3. Live Dispute Creation & Status Engine ---
  console.log('\n--- 3. Live Dispute Creation & Status Engine ---');
  try {
    const validPayload = {
      booking_id: 'BKG-2026-8812',
      category: 'Quality' as BuyerDisputeCategory,
      description:
        'Moisture content observed at 14.5% on destination unloading, significantly deviating from the 12.0% contractual maximum specification. Authorized lab slip attached.',
      evidence_urls: ['https://storage.brokerbridge.com/evidence/lab-moisture-analysis.pdf'],
    };

    const createRes = await createBuyerDisputeAction(validPayload);
    assert(
      createRes.success && Boolean(createRes.disputeId),
      'Dispute Creation: createBuyerDisputeAction successfully inserts dispute record',
      `Dispute ID: ${createRes.disputeId}`
    );
  } catch (err: any) {
    assert(false, 'Dispute Creation: createBuyerDisputeAction', err.message);
  }

  // --- 4. Active Dispute Ledger & Mediation Fetching ---
  console.log('\n--- 4. Active Dispute Ledger Fetching ---');
  try {
    const disputesRes = await getBuyerActiveDisputesAction();
    assert(
      disputesRes.success && Boolean(disputesRes.data),
      'Disputes Fetching: getBuyerActiveDisputesAction returns active records',
      `Total returned: ${disputesRes.data?.disputes.length}`
    );

    if (disputesRes.data) {
      const { summary, disputes: items } = disputesRes.data;

      assert(
        summary.totalDisputes > 0,
        'Summary Metrics: Calculates total logged disputes',
        `Total: ${summary.totalDisputes}`
      );

      assert(
        typeof summary.openCount === 'number' &&
          typeof summary.underReviewCount === 'number' &&
          typeof summary.resolvedCount === 'number',
        'Summary Metrics: Tracks Open, Under Broker Review, and Resolved counts',
        `Open: ${summary.openCount}, Under Review: ${summary.underReviewCount}, Resolved: ${summary.resolvedCount}`
      );

      const openItem = items.find((i) => i.status === 'Open');
      assert(
        Boolean(openItem),
        'Status Engine: Recognizes initial "Open" status for new filings',
        `Open Dispute Booking: ${openItem?.bookingId} (${openItem?.category})`
      );

      const reviewItem = items.find((i) => i.status === 'Under Broker Review');
      assert(
        Boolean(reviewItem),
        'Status Engine: Recognizes "Under Broker Review" mediation status',
        `Mediation Dispute: ${reviewItem?.bookingId} (${reviewItem?.category})`
      );

      const resolvedItem = items.find((i) => i.status === 'Resolved');
      assert(
        Boolean(resolvedItem),
        'Status Engine: Recognizes "Resolved" completed mediation status',
        `Resolved Dispute: ${resolvedItem?.bookingId} (${resolvedItem?.category})`
      );

      assert(
        items.every((i) => i.initiator === 'Buyer'),
        'Initiator Tag: Flags all buyer disputes as initiated by "Buyer"'
      );
    }
  } catch (err: any) {
    assert(false, 'Disputes Fetching: getBuyerActiveDisputesAction', err.message);
  }

  // --- 5. Tenant Boundary & Privacy Scrubber ---
  console.log('\n--- 5. Tenant Boundary & Privacy Scrubber ---');
  try {
    const disputesRes = await getBuyerActiveDisputesAction();
    const payloadStr = JSON.stringify(disputesRes.data);

    // Verify zero Seller identities exposed
    const hasSellerCompany = /seller.*company|seller_id|seller_name/i.test(payloadStr);
    const hasSellerPhone = /seller.*phone|seller.*mobile/i.test(payloadStr);
    const hasSellerEmail = /seller.*email/i.test(payloadStr);
    const hasInternalBrokerNotes = /resolution_notes|internal_notes|broker_private/i.test(
      payloadStr
    );

    assert(
      !hasSellerCompany && !hasSellerPhone && !hasSellerEmail,
      'Privacy Scrubber: Zero Seller identities or direct contact details leaked to Buyer',
      'No seller company, phone, or email in dispute payload'
    );

    assert(
      !hasInternalBrokerNotes,
      'Privacy Scrubber: Zero internal Broker notes leaked to Buyer'
    );
  } catch (err: any) {
    assert(false, 'Tenant Boundary & Privacy Scrubber', err.message);
  }

  // --- 6. Order Detail Page Component Mounting ---
  console.log('\n--- 6. Order Detail Page Component Mounting ---');
  try {
    const orderPagePath = path.resolve(
      process.cwd(),
      'app/(buyer)/buyer/orders/[id]/page.tsx'
    );
    assert(
      fs.existsSync(orderPagePath),
      'File System: Order Detail page exists at app/(buyer)/buyer/orders/[id]/page.tsx'
    );

    const pageContent = fs.readFileSync(orderPagePath, 'utf8');

    assert(
      pageContent.includes('RaiseDisputeModal') && pageContent.includes('<RaiseDisputeModal'),
      'Mounting 39.4: RaiseDisputeModal is imported and rendered',
      'Module 8 mounted'
    );

    // Verify Hierarchy: PaymentCard -> RaiseDisputeModal
    const paymentIdx = pageContent.indexOf('<BuyerPaymentCard');
    const disputeIdx = pageContent.indexOf('<RaiseDisputeModal');

    assert(
      paymentIdx !== -1 && disputeIdx !== -1 && paymentIdx < disputeIdx,
      'Layout Hierarchy: Rendered directly below BuyerPaymentCard',
      `PaymentCard (${paymentIdx}) < RaiseDisputeModal (${disputeIdx})`
    );
  } catch (err: any) {
    assert(false, 'Order Detail Component Mounting', err.message);
  }

  // --- 7. Raise Dispute Modal Contract (raise-dispute-modal.tsx) ---
  console.log('\n--- 7. Raise Dispute Modal UI Contract ---');
  try {
    const modalPath = path.resolve(
      process.cwd(),
      'src/components/buyer/orders/raise-dispute-modal.tsx'
    );
    assert(
      fs.existsSync(modalPath),
      'File System: RaiseDisputeModal exists at src/components/buyer/orders/raise-dispute-modal.tsx'
    );

    const modalContent = fs.readFileSync(modalPath, 'utf8');

    assert(
      modalContent.includes("'use client'"),
      'Client Component: Enforces "use client" directive'
    );

    assert(
      modalContent.includes('useTransition'),
      'Concurrency Defense: Employs useTransition to prevent duplicate submissions'
    );

    assert(
      modalContent.includes('border-rose-300') && modalContent.includes('text-rose-700'),
      'Visual Contract: Trigger button features Destructive / Red outline styling'
    );

    assert(
      modalContent.includes('50') && modalContent.includes('min chars'),
      'Description Guard: Enforces 50-character minimum length validation with visual counter'
    );

    assert(
      modalContent.includes('min-h-[48px]'),
      'Mobile Accessibility: Enforces min-h-[48px] touch targets on buttons and select inputs'
    );
  } catch (err: any) {
    assert(false, 'Raise Dispute Modal UI Contract', err.message);
  }

  // --- 8. Dedicated Dispute Tracker Contract (/buyer/more/disputes) ---
  console.log('\n--- 8. Dedicated Dispute Tracker UI Contract ---');
  try {
    const disputesPagePath = path.resolve(
      process.cwd(),
      'app/(buyer)/buyer/more/disputes/page.tsx'
    );
    assert(
      fs.existsSync(disputesPagePath),
      'File System: Dispute Tracker route exists at app/(buyer)/buyer/more/disputes/page.tsx'
    );

    const pageContent = fs.readFileSync(disputesPagePath, 'utf8');

    assert(
      pageContent.includes('async function BuyerDisputesPage') &&
        pageContent.includes('getBuyerActiveDisputesAction'),
      'Async Server Component: Page fetches getBuyerActiveDisputesAction()'
    );

    const cardPath = path.resolve(
      process.cwd(),
      'src/components/buyer/disputes/buyer-dispute-card.tsx'
    );
    assert(
      fs.existsSync(cardPath),
      'File System: BuyerDisputeCard exists at src/components/buyer/disputes/buyer-dispute-card.tsx'
    );

    const cardContent = fs.readFileSync(cardPath, 'utf8');

    assert(
      !cardContent.includes('<input') && !cardContent.includes('<textarea'),
      'Strict UX Rule: Strictly read-only tracker — ZERO chat box or direct messaging inputs'
    );

    assert(
      cardContent.includes('renderCategoryBadge') &&
        cardContent.includes('renderDisputeStatusBadge'),
      'Badge Styling: Distinctive category and status badges rendered'
    );

    assert(
      cardContent.includes('Fiduciary Mediation') ||
        cardContent.includes('Direct seller messaging disabled'),
      'Fiduciary Disclaimer: Enforces neutral mediation protocol seal'
    );

    assert(
      cardContent.includes('/buyer/orders/'),
      'Order Navigation: Includes deep link to relevant Order Details view'
    );
  } catch (err: any) {
    assert(false, 'Dedicated Dispute Tracker UI Contract', err.message);
  }

  // --- Summary ---
  console.log('\n========================================================');
  console.log(`  VERIFICATION RESULTS: ${passedTests} / ${totalTests} PASSED`);
  console.log('========================================================');

  if (passedTests === totalTests) {
    console.log('🎉 ALL MICRO-SPRINT 39.4 VERIFICATION SUITES PASSED!\n');
    process.exit(0);
  } else {
    console.error(`⚠️ ${totalTests - passedTests} TESTS FAILED.\n`);
    process.exit(1);
  }
}

runSprint394Verification().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
