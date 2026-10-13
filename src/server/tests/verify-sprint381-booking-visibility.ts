/**
 * Comprehensive Verification Suite for Micro-Sprint 38.1
 * Buyer Booking Visibility Engine (Sprint 38)
 *
 * Verifies:
 * 1. Validation guards: Rejection of missing/empty booking IDs.
 * 2. Successful execution: getBuyerBookingVisibilityAction returns structured payload.
 * 3. Required data fields: Booking ID, Status, Created Date, Deal Reference, Commodity, Quantity, Rate.
 * 4. Fallback / Pending state: Correctly indicates "Awaiting Broker Finalization" when not yet finalized.
 * 5. Architectural Invariant: Strictly read-only layer (no booking mutation or creation exports).
 * 6. Tenant isolation: Server action includes companyId verification logic.
 */

import { getBuyerBookingVisibilityAction } from '../actions/buyer-order-actions';
import * as buyerOrderActions from '../actions/buyer-order-actions';
import * as fs from 'fs';
import * as path from 'path';

async function runSprint381Verification() {
  console.log('========================================================');
  console.log('  MICRO-SPRINT 38.1: BUYER BOOKING VISIBILITY TEST');
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
    const emptyRes = await getBuyerBookingVisibilityAction('');
    assert(
      !emptyRes.success && emptyRes.error?.includes('required'),
      'Validation: Rejects empty booking ID',
      `Error: "${emptyRes.error}"`
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects empty booking ID', err.message);
  }

  try {
    const whitespaceRes = await getBuyerBookingVisibilityAction('   ');
    assert(
      !whitespaceRes.success,
      'Validation: Rejects whitespace booking ID'
    );
  } catch (err: any) {
    assert(false, 'Validation: Rejects whitespace booking ID', err.message);
  }

  // --- 2. Live / Demo Execution ---
  console.log('\n--- 2. Booking Visibility Execution ---');
  try {
    const res = await getBuyerBookingVisibilityAction('BKG-2026-1042');
    assert(
      res.success && Boolean(res.data),
      'Execution: getBuyerBookingVisibilityAction completes successfully',
      `Booking ID: ${res.data?.bookingId}`
    );

    if (res.data) {
      assert(
        res.data.bookingId === 'BKG-2026-1042',
        'Data Field: Prominently returns physical Booking ID',
        `Value: ${res.data.bookingId}`
      );

      assert(
        res.data.bookingStatus === 'Confirmed',
        'Data Field: Returns valid Booking Status',
        `Status: ${res.data.bookingStatus}`
      );

      assert(
        Boolean(res.data.createdAt) && !isNaN(Date.parse(res.data.createdAt)),
        'Data Field: Returns valid ISO Created Date',
        `Created At: ${res.data.createdAt}`
      );

      assert(
        Boolean(res.data.dealReference),
        'Data Field: Returns associated Deal Reference',
        `Deal Reference: ${res.data.dealReference}`
      );

      assert(
        Boolean(res.data.commodityName) && res.data.commodityName.length > 0,
        'Data Field: Joins parent Commodity information',
        `Commodity: ${res.data.commodityName} (${res.data.gradeName})`
      );

      assert(
        typeof res.data.finalQuantity === 'number' && res.data.finalQuantity > 0,
        'Data Field: Returns locked Final Quantity',
        `Quantity: ${res.data.finalQuantity} ${res.data.unitSymbol}`
      );

      assert(
        typeof res.data.finalRate === 'number' && res.data.finalRate > 0,
        'Data Field: Returns locked Final Rate',
        `Rate: ₹${res.data.finalRate}`
      );
    }
  } catch (err: any) {
    assert(false, 'Execution: getBuyerBookingVisibilityAction', err.message);
  }

  // --- 3. Pending State Fallback (Awaiting Broker Finalization) ---
  console.log('\n--- 3. Pending State Fallback Guard ---');
  try {
    const pendingRes = await getBuyerBookingVisibilityAction('demo-pending');
    assert(
      pendingRes.success && Boolean(pendingRes.data),
      'Pending State: Returns payload for unfinalized deal'
    );

    if (pendingRes.data) {
      assert(
        pendingRes.data.isBrokerFinalized === false,
        'Pending State: Flags isBrokerFinalized as false'
      );

      assert(
        pendingRes.data.bookingStatus === 'Awaiting Broker Finalization',
        'Pending State: Sets status to "Awaiting Broker Finalization"',
        `Status: ${pendingRes.data.bookingStatus}`
      );
    }
  } catch (err: any) {
    assert(false, 'Pending State Fallback', err.message);
  }

  // --- 4. Architectural Invariant: Read-Only Visibility Layer ---
  console.log('\n--- 4. Architectural Invariant & Tenant Isolation ---');
  const actionKeys = Object.keys(buyerOrderActions);
  const hasMutationOrCreation = actionKeys.some(
    (key) =>
      key.toLowerCase().includes('createbooking') ||
      key.toLowerCase().includes('finalizebooking') ||
      key.toLowerCase().includes('updatebooking')
  );

  assert(
    !hasMutationOrCreation,
    'Architecture Guardrail: Strictly read-only layer (zero booking creation/mutation actions exported)',
    `Exported actions: [${actionKeys.join(', ')}]`
  );

  // Read code file directly to verify strict tenant isolation
  const actionsFilePath = path.resolve(__dirname, '../actions/buyer-order-actions.ts');
  const fileContent = fs.readFileSync(actionsFilePath, 'utf-8');

  const hasTenantCheck =
    fileContent.includes('buyerCompanyId') &&
    (fileContent.includes('dealRecord.buyerId === buyerCompanyId') ||
      fileContent.includes('requirementRecord.companyId === buyerCompanyId'));

  assert(
    hasTenantCheck,
    'Tenant Isolation: Validates underlying deal/requirement against buyerCompanyId',
    'Guards against unauthorized URL guessing'
  );

  // --- Summary ---
  console.log('\n========================================================');
  console.log(`  VERIFICATION RESULTS: ${passedTests} / ${totalTests} TESTS PASSED (${Math.round((passedTests / totalTests) * 100)}%)`);
  console.log('========================================================\n');

  if (passedTests !== totalTests) {
    process.exit(1);
  }
}

runSprint381Verification().catch((err) => {
  console.error('Test suite failed with unexpected error:', err);
  process.exit(1);
});
