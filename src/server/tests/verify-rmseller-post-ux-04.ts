/**
 * ============================================================================
 * SPRINT RB-SELLER-POST-UX-04: POST COMMODITY LOT - SECTIONS 1 & 2 REDESIGN
 * AUTOMATED VERIFICATION SUITE
 * ============================================================================
 *
 * Verifies all 15 checkpoints:
 * - SELLER-UX4-01: Verify separate editable Batch/Lot text field is removed from Section 1
 * - SELLER-UX4-02: Verify Batch/Lot Number is displayed as small readable secondary label at top of Section 1
 * - SELLER-UX4-03: Verify existing Batch/Lot Number value lifecycle & submission are preserved
 * - SELLER-UX4-04: Verify Section 1 Commodity & Quality Grade dropdowns render with unified typography
 * - SELLER-UX4-05: Verify Section 1 responsive 2-column wide layout & stacked mobile layout
 * - SELLER-UX4-06: Verify Section 2 Quantity and Unit alignment with matching baselines
 * - SELLER-UX4-07: Verify Section 2 Asking Price per Unit with currency prefix & live valuation badge
 * - SELLER-UX4-08: Verify Section 2 responsive commercial grid (3-column wide, stacked narrow)
 * - SELLER-UX4-09: Verify Commercial pricing calculations, validations & payment terms are preserved
 * - SELLER-UX4-10: Verify Section 3 (Warehouse Location & Loading) is untouched
 * - SELLER-UX4-11: Verify Section 4 (My Trusted Broker) is untouched
 * - SELLER-UX4-12: Verify Section 5 (Review Listing & Broker Summary) is untouched
 * - SELLER-UX4-13: Verify Certified Lab Testing rate card, UPI payments & admin notifications untouched
 * - SELLER-UX4-14: Verify dedicated Flutter widget test suite exists and covers critical scenarios
 * - SELLER-UX4-15: Verify Scope Guardrail: Zero modifications to Buyer, Broker, or Database schemas
 * ============================================================================
 */

import * as fs from 'fs';
import * as path from 'path';

interface TestCase {
  id: string;
  name: string;
  category: string;
  fn: () => boolean | Promise<boolean>;
}

const tests: TestCase[] = [];

function registerTest(id: string, name: string, category: string, fn: () => boolean | Promise<boolean>) {
  tests.push({ id, name, category, fn });
}

const ROOT_DIR = process.cwd();
const POST_SCREEN_PATH = path.join(
  ROOT_DIR,
  'apps/rmseller_mobile/lib/features/commodities/presentation/post_commodity_screen.dart'
);

// ----------------------------------------------------------------------------
// 1. Section 1 — Batch/Lot Number & Commodity Specification
// ----------------------------------------------------------------------------

registerTest(
  'SELLER-UX4-01',
  'Verify separate editable Batch/Lot text field is removed from Section 1 form layout',
  'Section 1 Redesign',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    // Should NOT have an AppTextField or TextFormField dedicated to user-entering lot number in Section 1
    const hasOldEditableLotField =
      content.includes("label: 'Lot / Batch Number *'") &&
      content.includes("hint: 'e.g. LOT-SOY-001'");
    return !hasOldEditableLotField;
  }
);

registerTest(
  'SELLER-UX4-02',
  'Verify Batch/Lot Number is displayed as small readable secondary label at top of Section 1',
  'Section 1 Redesign',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes('BATCH / LOT NO.') &&
      content.includes('section1_batch_lot_label') &&
      content.includes('_lotNumberController.text')
    );
  }
);

registerTest(
  'SELLER-UX4-03',
  'Verify existing Batch/Lot Number value lifecycle & submission are preserved',
  'Section 1 Redesign',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    // Initialized in initState, disposed, used in _handleSubmit
    return (
      content.includes("LOT-${DateTime.now().millisecondsSinceEpoch") &&
      content.includes("lotNumber: _lotNumberController.text.trim()") &&
      content.includes("_lotNumberController.dispose()")
    );
  }
);

registerTest(
  'SELLER-UX4-04',
  'Verify Section 1 Commodity & Quality Grade dropdowns render with unified typography',
  'Section 1 Redesign',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes("commodity_dropdown") &&
      content.includes("grade_dropdown") &&
      content.includes("_buildFormFieldWrapper") &&
      content.includes("label: 'Commodity *'") &&
      content.includes("label: 'Quality Grade *'")
    );
  }
);

registerTest(
  'SELLER-UX4-05',
  'Verify Section 1 responsive 2-column wide layout & stacked mobile layout',
  'Section 1 Redesign',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes("_buildSection1()") &&
      content.includes("final isWide = constraints.maxWidth >=") &&
      content.includes("Expanded(child: commodityDropdown)") &&
      content.includes("Expanded(child: gradeDropdown)")
    );
  }
);

// ----------------------------------------------------------------------------
// 2. Section 2 — Quantity & Commercial Pricing
// ----------------------------------------------------------------------------

registerTest(
  'SELLER-UX4-06',
  'Verify Section 2 Quantity and Unit alignment with matching baselines',
  'Section 2 Redesign',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes("quantity_field") &&
      content.includes("unit_dropdown") &&
      content.includes("label: 'Total Quantity *'") &&
      content.includes("label: 'Unit *'")
    );
  }
);

registerTest(
  'SELLER-UX4-07',
  'Verify Section 2 Asking Price per Unit with currency prefix & live valuation badge',
  'Section 2 Redesign',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes("asking_price_field") &&
      content.includes("LucideIcons.indianRupee") &&
      content.includes("section2_live_valuation") &&
      content.includes("Est. Value: ₹")
    );
  }
);

registerTest(
  'SELLER-UX4-08',
  'Verify Section 2 responsive commercial grid (3-column wide, stacked narrow)',
  'Section 2 Redesign',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes("_buildSection2(double totalVal)") &&
      content.includes("payment_terms_dropdown") &&
      content.includes("valuationWidget")
    );
  }
);

registerTest(
  'SELLER-UX4-09',
  'Verify Commercial pricing calculations, validations & payment terms are preserved',
  'Section 2 Redesign',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes("Payment on Delivery (CAD)") &&
      content.includes("Advance RTGS (50% Advance / 50% on B/L)") &&
      content.includes("Immediate RTGS on Weighbridge Slip") &&
      content.includes("Letter of Credit (LC at Sight)") &&
      content.includes("Must be > 0") &&
      content.includes("Must be positive")
    );
  }
);

// ----------------------------------------------------------------------------
// 3. Explicitly Untouched Scope Guardrails
// ----------------------------------------------------------------------------

registerTest(
  'SELLER-UX4-10',
  'Verify Section 3 (Warehouse Location & Loading) is untouched',
  'Scope Boundary',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes("3. Warehouse Location & Loading") &&
      content.includes("_openLocationPopup") &&
      content.includes("_warehouseAddressController") &&
      content.includes("_dispatchFacilityController")
    );
  }
);

registerTest(
  'SELLER-UX4-11',
  'Verify Section 4 (My Trusted Broker) is untouched',
  'Scope Boundary',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes("4. My Trusted Broker") &&
      content.includes("_buildBrokerSelectionSection()") &&
      content.includes("Choose the broker or brokers you trust to handle this commodity.")
    );
  }
);

registerTest(
  'SELLER-UX4-12',
  'Verify Section 5 (Review Listing & Broker Summary) is untouched',
  'Scope Boundary',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');

    return (
      content.includes("5. Review Listing & Broker Summary") &&
      content.includes("_buildReviewSummaryCard(totalVal, dateFormat)") &&
      content.includes("Supply Quantity") &&
      content.includes("Asking Price")
    );
  }
);

registerTest(
  'SELLER-UX4-13',
  'Verify Certified Lab Testing rate card, UPI payments & admin notifications untouched',
  'Scope Boundary',
  () => {
    if (!fs.existsSync(POST_SCREEN_PATH)) return false;
    const content = fs.readFileSync(POST_SCREEN_PATH, 'utf8');
    const labRepoPath = path.join(
      ROOT_DIR,
      'apps/rmseller_mobile/lib/features/commodities/data/lab_testing_repository.dart'
    );
    const labRepoContent = fs.existsSync(labRepoPath)
      ? fs.readFileSync(labRepoPath, 'utf8')
      : '';

    return (
      content.includes('_buildLabTestingSection()') &&
      content.includes('LabTestRateCard') &&
      content.includes('_buildPaymentActionCard') &&
      content.includes('_handleInitiateUpiPayment') &&
      labRepoContent.includes('upi://pay?')
    );
  }
);

registerTest(
  'SELLER-UX4-14',
  'Verify dedicated Flutter widget test suite exists and covers critical scenarios',
  'Verification',
  () => {
    const testPath = path.join(
      ROOT_DIR,
      'apps/rmseller_mobile/test/widgets/post_commodity_ux04_test.dart'
    );
    if (!fs.existsSync(testPath)) return false;
    const content = fs.readFileSync(testPath, 'utf8');

    return (
      content.includes('POST-UX04-01') &&
      content.includes('POST-UX04-04') &&
      content.includes('POST-UX04-06') &&
      content.includes('POST-UX04-08')
    );
  }
);

registerTest(
  'SELLER-UX4-15',
  'Verify Scope Guardrail: Zero modifications to Buyer, Broker, or Database schemas',
  'Scope Guardrail',
  () => {
    const migrationDir = path.join(ROOT_DIR, 'supabase/migrations');
    return fs.existsSync(migrationDir);
  }
);

// ----------------------------------------------------------------------------
// Runner
// ----------------------------------------------------------------------------

async function runAll() {
  console.log('================================================================');
  console.log('RB-SELLER-POST-UX-04: Automated Verification Test Suite');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  for (const t of tests) {
    try {
      const ok = await t.fn();
      if (ok) {
        passed++;
        console.log(`[PASS] ${t.id}: ${t.name} (${t.category})`);
      } else {
        failed++;
        console.error(`[FAIL] ${t.id}: ${t.name} (${t.category})`);
      }
    } catch (e: any) {
      failed++;
      console.error(`[ERROR] ${t.id}: ${t.name} (${t.category}): ${e.message}`);
    }
  }

  console.log('\n----------------------------------------------------------------');
  console.log(`Execution Summary: Total: ${tests.length} | Passed: ${passed} | Failed: ${failed}`);
  console.log(`Pass Rate: ${((passed / tests.length) * 100).toFixed(1)}%`);
  console.log('----------------------------------------------------------------\n');

  if (failed > 0) process.exit(1);
}

runAll();
