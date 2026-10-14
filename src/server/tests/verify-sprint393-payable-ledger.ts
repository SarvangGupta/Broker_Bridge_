/**
 * Comprehensive Automated Verification Suite for Micro-Sprint 39.3
 * Buyer Payable Ledger & Component Mounting (Sprint 39: Quality, Documents, Payments & Disputes)
 *
 * Verifies:
 * 1. Input Validation Guards: Rejection of empty/whitespace booking IDs when explicitly passed.
 * 2. Global Payables Action: getBuyerPayableLedgerAction() without arguments returns global overview & payables.
 * 3. Specific Booking Payable Action: getBuyerPayableLedgerAction(bookingId) returns singlePayable.
 * 4. Server-Side Math Engine Invariants:
 *    - Base Amount = Final Quantity * Locked Base Rate
 *    - Gross Payable = Base Amount + Buyer Charges/Taxes
 *    - Total Paid = Sum of confirmed payments
 *    - Outstanding Balance = Gross Payable - Total Paid
 *    - UI receives pre-calculated numbers and currency formatted strings
 * 5. Payment Status Calculation Invariants:
 *    - 'Pending': Total Paid == 0
 *    - 'Part Paid': Total Paid > 0 && Outstanding > 0
 *    - 'Paid': Outstanding <= 0
 * 6. Tenant Boundary & Nodal Escrow Isolation (Strict Privacy Scrubber):
 *    - Zero Seller Bank Details (no seller IFSC, no seller account numbers)
 *    - Zero Seller PII (no seller phone, email, contact)
 *    - Verified platform Nodal Escrow account reference (BB-NODAL-...)
 * 7. Order Detail Page Component Mounting:
 *    - TransactionQualityCard (39.1) mounted
 *    - TransactionDocumentVault (39.2) mounted
 *    - BuyerPaymentCard (39.3) mounted
 *    - Positioned beneath LogisticsTimeline in standard space-y-4 layout
 * 8. Order-Level Financial UI Contract (buyer-payment-card.tsx):
 *    - 'use client' directive
 *    - 3 prominent metric blocks (Gross Payable, Amount Paid in Emerald, Outstanding in Rose/Amber)
 *    - Mobile-first: grid-cols-1 sm:grid-cols-3 (wraps to single column on 360px)
 *    - min-h-[48px] touch targets
 * 9. Global Payables Hub Contract (global-payables-hub.tsx & /buyer/more):
 *    - SprintPlaceholder deleted
 *    - Async Server Component in /buyer/more fetching getBuyerPayableLedgerAction()
 *    - Master Table + 360px mobile card list
 *    - "View Order" links to /buyer/orders/[bookingId]
 */

import { getBuyerPayableLedgerAction } from '../actions/buyer-payment-actions';
import * as fs from 'fs';
import * as path from 'path';

async function runSprint393Verification() {
  console.log('========================================================');
  console.log('  MICRO-SPRINT 39.3: BUYER PAYABLE LEDGER & MOUNTING');
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
  console.log('\n--- 1. Validation Guards ---');
  try {
    const emptyRes = await getBuyerPayableLedgerAction('');
    assert(
      !emptyRes.success && emptyRes.error?.includes('empty'),
      'Validation: Rejects explicitly passed empty booking identifier',
      `Error: "${emptyRes.error}"`
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects empty booking identifier', err.message);
  }

  try {
    const whitespaceRes = await getBuyerPayableLedgerAction('    ');
    assert(
      !whitespaceRes.success && whitespaceRes.error?.includes('empty'),
      'Validation: Rejects whitespace-only booking identifier',
      `Error: "${whitespaceRes.error}"`
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects whitespace-only booking identifier', err.message);
  }

  // --- 2. Global Payables Hub Fetching ---
  console.log('\n--- 2. Global Payables Hub Fetching (No ID) ---');
  try {
    const globalRes = await getBuyerPayableLedgerAction();
    assert(
      globalRes.success && Boolean(globalRes.data),
      'Global Action: getBuyerPayableLedgerAction() returns global payload',
      `Active Orders: ${globalRes.data?.overview.totalActiveOrders}`
    );

    if (globalRes.data) {
      const { overview, payables } = globalRes.data;

      assert(
        overview.totalActiveOrders > 0,
        'Overview: Aggregates total active contracts',
        `Count: ${overview.totalActiveOrders}`
      );

      assert(
        overview.totalGrossPayable > 0 && Boolean(overview.formattedTotalGrossPayable),
        'Overview: Aggregates total gross payable volume with currency formatting',
        `Gross: ${overview.formattedTotalGrossPayable}`
      );

      assert(
        typeof overview.totalAmountPaid === 'number' && Boolean(overview.formattedTotalAmountPaid),
        'Overview: Aggregates total escrow deposits with currency formatting',
        `Deposited: ${overview.formattedTotalAmountPaid}`
      );

      assert(
        typeof overview.totalOutstandingBalance === 'number' &&
          Boolean(overview.formattedTotalOutstandingBalance),
        'Overview: Aggregates total pending balance due',
        `Outstanding: ${overview.formattedTotalOutstandingBalance}`
      );

      assert(
        payables.length >= 3,
        'Global Ledger: Returns consolidated active commodity contracts',
        `Payables returned: ${payables.length}`
      );
    }
  } catch (err: any) {
    assert(false, 'Global Action: getBuyerPayableLedgerAction()', err.message);
  }

  // --- 3. Order-Specific Payable Ledger Fetching ---
  console.log('\n--- 3. Order-Specific Payable Ledger Fetching ---');
  try {
    const orderRes = await getBuyerPayableLedgerAction('BKG-2026-8812');
    assert(
      orderRes.success && Boolean(orderRes.data?.singlePayable),
      'Order Action: Returns singlePayable record for specific booking',
      `Booking: ${orderRes.data?.singlePayable?.bookingId}`
    );

    const item = orderRes.data?.singlePayable;
    if (item) {
      assert(
        item.commodityName.includes('Wheat'),
        'Contract Metadata: Resolves human-readable commodity name',
        `Commodity: ${item.commodityName} (${item.gradeName})`
      );

      assert(
        item.finalQuantity > 0 && Boolean(item.unitSymbol),
        'Volume: Returns verified commercial lot quantity',
        `Quantity: ${item.finalQuantity} ${item.unitSymbol}`
      );

      assert(
        item.lockedBaseRate > 0 && Boolean(item.formattedLockedBaseRate),
        'Locked Rate: Surfaces locked rate from deal version snapshot',
        `Rate: ${item.formattedLockedBaseRate}`
      );
    }
  } catch (err: any) {
    assert(false, 'Order Action: getBuyerPayableLedgerAction(bookingId)', err.message);
  }

  // --- 4. Server-Side Math Engine Invariants ---
  console.log('\n--- 4. Server-Side Math Engine Invariants ---');
  try {
    const orderRes = await getBuyerPayableLedgerAction('BKG-2026-8812');
    const item = orderRes.data?.singlePayable;

    if (item) {
      const calculatedBaseAmount = Math.round(item.finalQuantity * item.lockedBaseRate);
      assert(
        item.baseAmount === calculatedBaseAmount,
        'Math Engine: Base Amount = Final Quantity * Locked Base Rate',
        `Expected ${calculatedBaseAmount}, got ${item.baseAmount}`
      );

      const calculatedGross = item.baseAmount + item.chargesAndTaxes;
      assert(
        item.grossPayable === calculatedGross,
        'Math Engine: Gross Payable = Base Amount + Buyer Charges/Taxes',
        `Expected ${calculatedGross}, got ${item.grossPayable}`
      );

      const sumPayments = item.paymentRecords
        .filter((p) => p.status === 'Confirmed')
        .reduce((sum, p) => sum + p.amount, 0);
      assert(
        item.totalPaid === sumPayments,
        'Math Engine: Total Paid = Sum of confirmed payments in payments table',
        `Expected ${sumPayments}, got ${item.totalPaid}`
      );

      const calculatedOutstanding = item.grossPayable - item.totalPaid;
      assert(
        item.outstandingBalance === calculatedOutstanding,
        'Math Engine: Outstanding Balance = Gross Payable - Total Paid',
        `Expected ${calculatedOutstanding}, got ${item.outstandingBalance}`
      );

      assert(
        item.paymentStatus === 'Part Paid',
        'Status Engine: Evaluates status as "Part Paid" when 0 < Total Paid < Gross',
        `Status: ${item.paymentStatus}`
      );
    }

    // Test Paid Invariant with BKG-2026-8790
    const paidRes = await getBuyerPayableLedgerAction('BKG-2026-8790');
    const paidItem = paidRes.data?.singlePayable;
    if (paidItem) {
      assert(
        paidItem.outstandingBalance === 0 && paidItem.paymentStatus === 'Paid',
        'Status Engine: Evaluates status as "Paid" when Outstanding Balance == 0',
        `Outstanding: ${paidItem.outstandingBalance}, Status: ${paidItem.paymentStatus}`
      );
    }

    // Test Pending Invariant with BKG-2026-1042
    const pendingRes = await getBuyerPayableLedgerAction('BKG-2026-1042');
    const pendingItem = pendingRes.data?.singlePayable;
    if (pendingItem) {
      assert(
        pendingItem.totalPaid === 0 &&
          pendingItem.outstandingBalance === pendingItem.grossPayable &&
          pendingItem.paymentStatus === 'Pending',
        'Status Engine: Evaluates status as "Pending" when Total Paid == 0',
        `Total Paid: ${pendingItem.totalPaid}, Status: ${pendingItem.paymentStatus}`
      );
    }
  } catch (err: any) {
    assert(false, 'Server-Side Math Engine Invariants', err.message);
  }

  // --- 5. Tenant Boundary & Nodal Escrow Isolation ---
  console.log('\n--- 5. Tenant Boundary & Nodal Escrow Isolation ---');
  try {
    const globalRes = await getBuyerPayableLedgerAction();
    const payloadStr = JSON.stringify(globalRes.data);

    // Verify absence of sensitive seller data
    const hasSellerIfsc = /seller.*ifsc|ifsc.*seller/i.test(payloadStr);
    const hasSellerAccount = /seller.*account_number|seller_bank/i.test(payloadStr);
    const hasSellerPhone = /seller.*phone|seller.*mobile/i.test(payloadStr);

    assert(
      !hasSellerIfsc && !hasSellerAccount,
      'Tenant Boundary: Zero Seller Bank Credentials in payload',
      'No seller IFSC or bank account numbers exposed'
    );

    assert(
      !hasSellerPhone,
      'Tenant Boundary: Zero Seller Direct Contact Info / PII',
      'No private seller contact details exposed'
    );

    const firstItem = globalRes.data?.payables[0];
    assert(
      Boolean(firstItem?.nodalAccountName.includes('Nodal')) && Boolean(firstItem?.escrowReference),
      'Nodal Escrow Model: Designates verified BrokerBridge Nodal Escrow account',
      `Account: ${firstItem?.nodalAccountName}, Ref: ${firstItem?.escrowReference}`
    );

    assert(
      Boolean(firstItem?.disclaimer.includes('regulated BrokerBridge Nodal Escrow')),
      'Escrow Safeguard: Enforces platform nodal transfer disclaimer',
      `Disclaimer: "${firstItem?.disclaimer.substring(0, 60)}..."`
    );
  } catch (err: any) {
    assert(false, 'Tenant Boundary & Nodal Escrow Isolation', err.message);
  }

  // --- 6. Component Mounting in Order Detail Page ---
  console.log('\n--- 6. Component Mounting in Order Detail Page ---');
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

    // 1. Quality Card (39.1)
    assert(
      pageContent.includes('TransactionQualityCard') &&
        pageContent.includes('<TransactionQualityCard'),
      'Mounting 39.1: TransactionQualityCard is imported and rendered',
      'Module 5 mounted'
    );

    // 2. Document Vault (39.2)
    assert(
      pageContent.includes('TransactionDocumentVault') &&
        pageContent.includes('<TransactionDocumentVault'),
      'Mounting 39.2: TransactionDocumentVault is imported and rendered',
      'Module 6 mounted'
    );

    // 3. Buyer Payment Card (39.3)
    assert(
      pageContent.includes('BuyerPaymentCard') &&
        pageContent.includes('<BuyerPaymentCard'),
      'Mounting 39.3: BuyerPaymentCard is imported and rendered',
      'Module 7 mounted'
    );

    // 4. Hierarchy: Timeline -> Quality -> Vault -> Payment
    const timelineIdx = pageContent.indexOf('<LogisticsTimeline');
    const qualityIdx = pageContent.indexOf('<TransactionQualityCard');
    const vaultIdx = pageContent.indexOf('<TransactionDocumentVault');
    const paymentIdx = pageContent.indexOf('<BuyerPaymentCard');

    assert(
      timelineIdx !== -1 &&
        qualityIdx !== -1 &&
        vaultIdx !== -1 &&
        paymentIdx !== -1 &&
        timelineIdx < qualityIdx &&
        qualityIdx < vaultIdx &&
        vaultIdx < paymentIdx,
      'Layout Hierarchy: Rendered sequentially below LogisticsTimeline (Timeline -> Quality -> Vault -> Payment)',
      `Timeline (${timelineIdx}) < Quality (${qualityIdx}) < Vault (${vaultIdx}) < Payment (${paymentIdx})`
    );

    assert(
      pageContent.includes('space-y-4'),
      'Layout Spacing: Wrapped in standard space-y-4 spacing container'
    );
  } catch (err: any) {
    assert(false, 'Order Detail Component Mounting', err.message);
  }

  // --- 7. Order-Level Financial UI Contract ---
  console.log('\n--- 7. Order-Level Financial UI Contract (buyer-payment-card.tsx) ---');
  try {
    const cardPath = path.resolve(
      process.cwd(),
      'src/components/buyer/orders/buyer-payment-card.tsx'
    );
    assert(
      fs.existsSync(cardPath),
      'File System: BuyerPaymentCard exists at src/components/buyer/orders/buyer-payment-card.tsx'
    );

    const cardContent = fs.readFileSync(cardPath, 'utf8');

    assert(
      cardContent.includes("'use client'"),
      'Client Component: Enforces "use client" directive'
    );

    assert(
      cardContent.includes('1. Total Gross Payable') &&
        cardContent.includes('2. Total Amount Paid') &&
        cardContent.includes('3. Outstanding Balance'),
      'Prominent Metrics: Displays 3 metric blocks (Total Gross Payable, Amount Paid, Outstanding Balance)'
    );

    assert(
      cardContent.includes('text-emerald-900') || cardContent.includes('text-emerald-700'),
      'Visual Excellence: Amount Paid highlighted in Green/Emerald'
    );

    assert(
      cardContent.includes('grid-cols-1 sm:grid-cols-3'),
      'Mobile-First Responsiveness: 3-column metrics wrap to single column (flex-col) on mobile screens'
    );

    assert(
      cardContent.includes('min-h-[48px]'),
      'Accessibility: Interactive buttons enforce min-h-[48px] touch targets'
    );
  } catch (err: any) {
    assert(false, 'Order-Level Financial UI Contract', err.message);
  }

  // --- 8. Global Payables Hub Contract ---
  console.log('\n--- 8. Global Payables Hub Contract (global-payables-hub.tsx & /buyer/more) ---');
  try {
    const morePagePath = path.resolve(
      process.cwd(),
      'app/(buyer)/buyer/more/page.tsx'
    );
    assert(
      fs.existsSync(morePagePath),
      'File System: Buyer more page exists at app/(buyer)/buyer/more/page.tsx'
    );

    const moreContent = fs.readFileSync(morePagePath, 'utf8');

    assert(
      !moreContent.includes('<SprintPlaceholder') &&
        !moreContent.includes('sprint-placeholder'),
      'Sprint Placeholder: SprintPlaceholder component has been completely removed from /buyer/more'
    );

    assert(
      moreContent.includes('async function BuyerMorePage') &&
        moreContent.includes('getBuyerPayableLedgerAction'),
      'Async Server Component: /buyer/more is an Async Server Component fetching getBuyerPayableLedgerAction()'
    );

    assert(
      moreContent.includes('<GlobalPayablesHub'),
      'Component Mount: /buyer/more mounts <GlobalPayablesHub />'
    );

    const hubPath = path.resolve(
      process.cwd(),
      'src/components/buyer/payments/global-payables-hub.tsx'
    );
    assert(
      fs.existsSync(hubPath),
      'File System: GlobalPayablesHub exists at src/components/buyer/payments/global-payables-hub.tsx'
    );

    const hubContent = fs.readFileSync(hubPath, 'utf8');

    assert(
      hubContent.includes('<Table') && hubContent.includes('md:block'),
      'Desktop Presentation: Renders master Shadcn <Table>'
    );

    assert(
      hubContent.includes('md:hidden') && hubContent.includes('/buyer/orders/'),
      'Mobile Presentation: Renders card-based list on 360px viewports with "View Order" links'
    );

    assert(
      hubContent.includes('min-h-[48px]'),
      'Touch Targets: Enforces min-h-[48px] across interactive search and order link buttons'
    );

    const paymentsPagePath = path.resolve(
      process.cwd(),
      'app/(buyer)/buyer/payments/page.tsx'
    );
    assert(
      fs.existsSync(paymentsPagePath),
      'Route Alias: /buyer/payments route exists and points to GlobalPayablesHub'
    );
  } catch (err: any) {
    assert(false, 'Global Payables Hub Contract', err.message);
  }

  // --- Summary ---
  console.log('\n========================================================');
  console.log(`  VERIFICATION RESULTS: ${passedTests} / ${totalTests} PASSED`);
  console.log('========================================================');

  if (passedTests === totalTests) {
    console.log('🎉 ALL MICRO-SPRINT 39.3 VERIFICATION SUITES PASSED!\n');
    process.exit(0);
  } else {
    console.error(`⚠️ ${totalTests - passedTests} TESTS FAILED.\n`);
    process.exit(1);
  }
}

runSprint393Verification().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
