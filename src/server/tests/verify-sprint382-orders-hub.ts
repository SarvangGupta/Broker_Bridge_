/**
 * Comprehensive Verification Suite for Micro-Sprint 38.2
 * Buyer "My Orders" Hub (Sprint 38)
 *
 * Verifies:
 * 1. Server action execution: getBuyerOrdersListAction returns structured array.
 * 2. Data payload structure: Booking ID, Status, Commodity, Grade, Quantity, Delivery Location.
 * 3. Status filtering: Filters orders by status correctly.
 * 4. Tenant data isolation: Code inspection confirms buyerCompanyId scoping.
 * 5. Mobile & UI guardrails: Confirms zero HTML tables, card grid layout, 48px touch targets, and overflow guards.
 * 6. Placeholder removal: Confirms SprintPlaceholder is completely removed from /buyer/orders/page.tsx.
 */

import { getBuyerOrdersListAction } from '../actions/buyer-order-actions';
import * as fs from 'fs';
import * as path from 'path';

async function runSprint382Verification() {
  console.log('========================================================');
  console.log('  MICRO-SPRINT 38.2: BUYER "MY ORDERS" HUB TEST');
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

  // --- 1. Server Action Execution ---
  console.log('\n--- 1. Orders List Server Action Execution ---');
  try {
    const res = await getBuyerOrdersListAction();
    assert(
      res.success && Array.isArray(res.data),
      'Execution: getBuyerOrdersListAction completes successfully and returns array',
      `Orders count: ${res.data?.length}`
    );

    assert(
      Boolean(res.data && res.data.length > 0),
      'Data: Returns non-empty list of active buyer orders',
      `Count: ${res.data?.length}`
    );

    if (res.data && res.data.length > 0) {
      const firstOrder = res.data[0];

      assert(
        firstOrder.bookingId.startsWith('BKG-'),
        'Data Field: Booking ID formatted properly (BKG-XXXX)',
        `Value: ${firstOrder.bookingId}`
      );

      assert(
        Boolean(firstOrder.status) && typeof firstOrder.status === 'string',
        'Data Field: Logistics status present',
        `Status: ${firstOrder.status}`
      );

      assert(
        Boolean(firstOrder.commodityName) && firstOrder.commodityName.length > 0,
        'Data Field: Human-readable Commodity name joined',
        `Commodity: ${firstOrder.commodityName}`
      );

      assert(
        typeof firstOrder.finalQuantity === 'number' && firstOrder.finalQuantity > 0,
        'Data Field: Final Quantity is numeric and positive',
        `Quantity: ${firstOrder.finalQuantity} ${firstOrder.unitSymbol}`
      );

      assert(
        Boolean(firstOrder.deliveryLocation) && firstOrder.deliveryLocation.length > 0,
        'Data Field: Delivery Location present',
        `Location: ${firstOrder.deliveryLocation}`
      );

      assert(
        Boolean(firstOrder.dealReference),
        'Data Field: Deal Reference ID present',
        `Deal Ref: ${firstOrder.dealReference}`
      );
    }
  } catch (err: any) {
    assert(false, 'Execution: getBuyerOrdersListAction', err.message);
  }

  // --- 2. Filtering Verification ---
  console.log('\n--- 2. Status Filtering ---');
  try {
    const transitRes = await getBuyerOrdersListAction({ status: 'In Transit' });
    assert(
      transitRes.success && Array.isArray(transitRes.data),
      'Filter: Filter by "In Transit" succeeds',
      `Transit count: ${transitRes.data?.length}`
    );

    const allInTransit = transitRes.data?.every((o) =>
      o.status.toLowerCase().includes('transit')
    );
    assert(
      Boolean(allInTransit),
      'Filter: All returned orders match requested status filter'
    );
  } catch (err: any) {
    assert(false, 'Status Filtering', err.message);
  }

  // --- 3. Tenant Data Isolation Guardrail ---
  console.log('\n--- 3. Strict Tenant Isolation Guardrail ---');
  const actionsFilePath = path.resolve(__dirname, '../actions/buyer-order-actions.ts');
  const actionSource = fs.readFileSync(actionsFilePath, 'utf-8');

  const enforcesTenantIsolation =
    actionSource.includes('buyerCompanyId') &&
    actionSource.includes('eq(deals.buyerId, buyerCompanyId)') &&
    actionSource.includes('getBuyerOrdersListAction');

  assert(
    enforcesTenantIsolation,
    'Tenant Isolation: getBuyerOrdersListAction strictly queries by buyerCompanyId',
    'Prevents cross-buyer order leakage'
  );

  // --- 4. Mobile & UI Guardrails (Zero Tables, Card Layout, 48px Targets) ---
  console.log('\n--- 4. Mobile Resilience & No-Table Guardrails ---');
  const pageFilePath = path.resolve(__dirname, '../../../app/(buyer)/buyer/orders/page.tsx');
  const pageSource = fs.readFileSync(pageFilePath, 'utf-8');

  const cardFilePath = path.resolve(__dirname, '../../components/buyer/orders/order-summary-card.tsx');
  const cardSource = fs.readFileSync(cardFilePath, 'utf-8');

  const feedFilePath = path.resolve(__dirname, '../../components/buyer/orders/buyer-orders-feed.tsx');
  const feedSource = fs.readFileSync(feedFilePath, 'utf-8');

  assert(
    !pageSource.includes('SprintPlaceholder') && !pageSource.includes('<SprintPlaceholder'),
    'Placeholder Removal: SprintPlaceholder completely removed from /buyer/orders/page.tsx'
  );

  assert(
    !feedSource.includes('<table') && !cardSource.includes('<table') && !pageSource.includes('<table'),
    'Zero HTML Tables: Orders feed strictly uses mobile card grid (no HTML table elements)'
  );

  assert(
    cardSource.includes('min-h-[48px]') && cardSource.includes('/buyer/orders/'),
    'Touch Target Rule: "Track Order" button enforces min-h-[48px] thumb target and routes to detail'
  );

  assert(
    pageSource.includes('w-full max-w-full overflow-x-hidden'),
    'Mobile Viewport: Page root container enforces w-full max-w-full overflow-x-hidden (360px safe)'
  );

  // --- Summary ---
  console.log('\n========================================================');
  console.log(`  VERIFICATION RESULTS: ${passedTests} / ${totalTests} TESTS PASSED (${Math.round((passedTests / totalTests) * 100)}%)`);
  console.log('========================================================\n');

  if (passedTests !== totalTests) {
    process.exit(1);
  }
}

runSprint382Verification().catch((err) => {
  console.error('Test suite failed with unexpected error:', err);
  process.exit(1);
});
