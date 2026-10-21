/**
 * ============================================================================
 * SPRINT RB-SELLER-02: COMMODITY POSTING COMPLETION & BROKER RELATIONSHIP
 * AUTOMATED VERIFICATION SUITE
 * ============================================================================
 *
 * Validates the core requirements of Sprint RB-SELLER-02:
 * 1. 5-step posting workflow with dedicated Review Mandate & Listing Summary.
 * 2. Broker discovery, commodity relevance filtering, and mandate persistence.
 * 3. In-flight duplicate submission guard and deep link to saved listing.
 * 4. Separate physical loading/dispatch facility vs registered office location.
 * 5. Quality conditions, lab test certificate reference, and commercial terms.
 * 6. Listing management: status updates (withdraw/fulfill) & asking price edits.
 * 7. Commodity details screen with volume pills, broker card, and contact launcher.
 * 8. Counterparty shield preservation (zero buyer exposure, broker-mediated only).
 * 9. Sibling app boundary preservation and zero database schema mutations.
 * ============================================================================
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

export interface RB02TestCaseResult {
  id: string;
  name: string;
  category: string;
  passed: boolean;
  evidence: string;
  detail?: string;
}

export interface RB02VerificationReport {
  suiteName: string;
  sprintId: string;
  totalTests: number;
  passed: number;
  failed: number;
  timestamp: string;
  results: RB02TestCaseResult[];
}

const ROOT_DIR = path.resolve(__dirname, '../../..');
const SELLER_APP_DIR = path.join(ROOT_DIR, 'apps', 'rmseller_mobile');

export async function runRMSellerPostingVerification(): Promise<RB02VerificationReport> {
  const results: RB02TestCaseResult[] = [];

  const record = (
    id: string,
    name: string,
    category: string,
    passed: boolean,
    evidence: string,
    detail?: string
  ) => {
    results.push({ id, name, category, passed, evidence, detail });
    const mark = passed ? '✅ PASS' : '❌ FAIL';
    console.log(`[${mark}] ${id}: ${name} (${category})`);
    if (!passed && detail) {
      console.log(`       Error: ${detail}`);
    }
  };

  console.log('\n================================================================================');
  console.log('STARTING SPRINT RB-SELLER-02 AUTOMATED VERIFICATION SUITE');
  console.log(`Target: ${SELLER_APP_DIR}`);
  console.log('================================================================================\n');

  // --------------------------------------------------------------------------
  // Category 1: Commodity Posting Workflow & Form Integrity
  // --------------------------------------------------------------------------
  console.log('--- Category 1: Commodity Posting Form & Workflow ---');

  // Test 1.1: 5-step posting structure in PostCommodityScreen
  try {
    const postScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'presentation', 'post_commodity_screen.dart');
    const content = fs.readFileSync(postScreenPath, 'utf8');

    const hasStep1 = content.includes('1. Commodity & Specification');
    const hasStep2 = content.includes('2. Quantity & Commercial Pricing');
    const hasStep3 = content.includes('3. Warehouse Location & Loading');
    const hasStep4 = content.includes('4. Broker Mandate Assignment');
    const hasStep5 = content.includes('5. Review Mandate & Listing Summary');
    const passed = hasStep1 && hasStep2 && hasStep3 && hasStep4 && hasStep5;

    record(
      'POST-01',
      'PostCommodityScreen implements complete 5-section trading workflow with Review Summary',
      'Workflow',
      passed,
      `Steps: 1=${hasStep1}, 2=${hasStep2}, 3=${hasStep3}, 4=${hasStep4}, 5(Review)=${hasStep5}`,
      passed ? undefined : 'PostCommodityScreen missing one or more required workflow sections'
    );
  } catch (err: any) {
    record('POST-01', 'PostCommodityScreen 5-section workflow', 'Workflow', false, 'Error reading post_commodity_screen', err.message);
  }

  // Test 1.2: Separate office location vs physical loading location
  try {
    const postScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'presentation', 'post_commodity_screen.dart');
    const content = fs.readFileSync(postScreenPath, 'utf8');

    const hasDispatchFacility = content.includes('_dispatchFacilityController');
    const hasOfficeLocation = content.includes('_officeLocationController');
    const hasLoadingReadiness = content.includes('_loadingStatus');
    const passed = hasDispatchFacility && hasOfficeLocation && hasLoadingReadiness;

    record(
      'POST-02',
      'Posting form captures physical dispatch facility separately from registered office HQ',
      'Data Contract',
      passed,
      `dispatchFacility=${hasDispatchFacility}, officeLocation=${hasOfficeLocation}, loadingReadiness=${hasLoadingReadiness}`,
      passed ? undefined : 'Office and loading facility separation missing'
    );
  } catch (err: any) {
    record('POST-02', 'Separate office vs loading location', 'Data Contract', false, 'Error verifying location fields', err.message);
  }

  // Test 1.3: Quality conditions, lab report certificate, and payment terms
  try {
    const postScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'presentation', 'post_commodity_screen.dart');
    const content = fs.readFileSync(postScreenPath, 'utf8');

    const hasLabReport = content.includes('_labReportType') && content.includes('_labReportNumberController');
    const hasPaymentTerms = content.includes('_paymentSchedule');
    const hasConfidentialPrice = content.includes('_confidentialPriceController');
    const passed = hasLabReport && hasPaymentTerms && hasConfidentialPrice;

    record(
      'POST-03',
      'Posting form captures lab certificate reference, payment terms, and confidential reserve price',
      'Commercials',
      passed,
      `labReport=${hasLabReport}, paymentTerms=${hasPaymentTerms}, confidentialPrice=${hasConfidentialPrice}`,
      passed ? undefined : 'Quality conditions or payment terms missing'
    );
  } catch (err: any) {
    record('POST-03', 'Quality conditions & payment terms', 'Commercials', false, 'Error checking commercial fields', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 2: Broker Selection & Relevance
  // --------------------------------------------------------------------------
  console.log('\n--- Category 2: Broker Selection & Mandate Persistence ---');

  // Test 2.1: Broker selection modal sheet with commodity relevance filter
  try {
    const postScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'presentation', 'post_commodity_screen.dart');
    const content = fs.readFileSync(postScreenPath, 'utf8');

    const hasBrokerSheet = content.includes('Select Mandi Broker Desk');
    const hasCommodityFilter = content.includes('_filterBrokersByCommodity') || content.includes('Commodity Matched');
    const hasSpecialistBadge = content.includes('Specialist');
    const passed = hasBrokerSheet && hasCommodityFilter && hasSpecialistBadge;

    record(
      'BROKER-01',
      'Broker picker supports commodity relevance filtering and displays specialist matching tags',
      'Brokerage',
      passed,
      `sheetTitle=${hasBrokerSheet}, relevanceFilter=${hasCommodityFilter}, specialistBadge=${hasSpecialistBadge}`,
      passed ? undefined : 'Broker relevance filtering missing from broker picker'
    );
  } catch (err: any) {
    record('BROKER-01', 'Broker picker relevance filtering', 'Brokerage', false, 'Error inspecting broker picker', err.message);
  }

  // Test 2.2: Mandate assignment persisted in CreateCommodityDto
  try {
    const modelPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'domain', 'commodity_model.dart');
    const content = fs.readFileSync(modelPath, 'utf8');

    const hasBrokerId = content.includes('brokerId');
    const hasBrokerPhone = content.includes('brokerPhone');
    const hasLoadingRemarks = content.includes('loadingRemarks');
    const hasInsertMapping = content.includes('toSupabaseInsert');
    const passed = hasBrokerId && hasBrokerPhone && hasLoadingRemarks && hasInsertMapping;

    record(
      'BROKER-02',
      'CreateCommodityDto maps broker assignment and loading facility into Supabase payload',
      'Persistence',
      passed,
      `brokerId=${hasBrokerId}, brokerPhone=${hasBrokerPhone}, loadingRemarks=${hasLoadingRemarks}`,
      passed ? undefined : 'Broker assignment mapping incomplete'
    );
  } catch (err: any) {
    record('BROKER-02', 'CreateCommodityDto broker persistence', 'Persistence', false, 'Error reading commodity model', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 3: Submission, Duplicate Lock & Deep Link Navigation
  // --------------------------------------------------------------------------
  console.log('\n--- Category 3: Submission & Deep Link Navigation ---');

  // Test 3.1: In-flight duplicate submission guard
  try {
    const postScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'presentation', 'post_commodity_screen.dart');
    const content = fs.readFileSync(postScreenPath, 'utf8');

    const hasDuplicateGuard = content.includes('if (_isSubmitting) return;');
    const hasSubmitButtonLock = content.includes('_isSubmitting ? null : _handleSubmit');
    const passed = hasDuplicateGuard && hasSubmitButtonLock;

    record(
      'SUBMIT-01',
      'Duplicate submission prevention: in-flight guard and disabled button state verified',
      'Reliability',
      passed,
      `In-flight guard=${hasDuplicateGuard}, Button disabled lock=${hasSubmitButtonLock}`,
      passed ? undefined : 'Duplicate submission protection missing'
    );
  } catch (err: any) {
    record('SUBMIT-01', 'Duplicate submission protection', 'Reliability', false, 'Error reading post_commodity_screen', err.message);
  }

  // Test 3.2: Deep link replacement to saved listing details
  try {
    const postScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'presentation', 'post_commodity_screen.dart');
    const content = fs.readFileSync(postScreenPath, 'utf8');

    const hasDeepLink = content.includes("context.pushReplacement('/commodities/\${created.id}'");
    const passed = hasDeepLink;

    record(
      'SUBMIT-02',
      'Submission immediately deep links to saved listing details screen with created lot payload',
      'Navigation',
      passed,
      `Deep link pushReplacement present=${hasDeepLink}`,
      passed ? undefined : 'Deep link navigation to details screen missing'
    );
  } catch (err: any) {
    record('SUBMIT-02', 'Deep link to saved listing', 'Navigation', false, 'Error reading post_commodity_screen', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 4: Listing Management & Lifecycle Actions
  // --------------------------------------------------------------------------
  console.log('\n--- Category 4: Listing Management & Lifecycle Actions ---');

  // Test 4.1: CommoditiesRepository supports status updates and price edits
  try {
    const repoPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'data', 'commodities_repository.dart');
    const content = fs.readFileSync(repoPath, 'utf8');

    const hasStatusUpdate = content.includes('updateCommodityStatus');
    const hasPriceUpdate = content.includes('updateCommodityPrice');
    const hasCompanyScoping = content.includes(".eq('company_id', companyId)");
    const hasNotifierTrigger = content.includes('commoditiesUpdatedNotifier.value++');
    const passed = hasStatusUpdate && hasPriceUpdate && hasCompanyScoping && hasNotifierTrigger;

    record(
      'MGMT-01',
      'CommoditiesRepository implements status update, price update, company scoping, and notifier broadcast',
      'Lifecycle',
      passed,
      `updateStatus=${hasStatusUpdate}, updatePrice=${hasPriceUpdate}, companyScope=${hasCompanyScoping}, notifier=${hasNotifierTrigger}`,
      passed ? undefined : 'Listing management methods missing in repository'
    );
  } catch (err: any) {
    record('MGMT-01', 'Repository listing management methods', 'Lifecycle', false, 'Error reading commodities repo', err.message);
  }

  // Test 4.2: CommodityDetailsScreen renders full breakdown and management actions
  try {
    const detailsScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'presentation', 'commodity_details_screen.dart');
    const content = fs.readFileSync(detailsScreenPath, 'utf8');

    const hasVolumePills = content.includes('_buildVolumePill');
    const hasBrokerCard = content.includes('Mandi Broker Desk');
    const hasCallBroker = content.includes('Call Broker');
    const hasWhatsApp = content.includes('WhatsApp');
    const hasPriceEditAction = content.includes('Update Asking Price');
    const hasCancelAction = content.includes('Withdraw / Cancel Lot');
    const hasFulfillAction = content.includes('Mark as Fulfilled / Dispatched');

    const passed = hasVolumePills && hasBrokerCard && hasCallBroker && hasWhatsApp && hasPriceEditAction && hasCancelAction && hasFulfillAction;

    record(
      'MGMT-02',
      'CommodityDetailsScreen displays volumes, broker card, mediated contact actions, and listing controls',
      'UI System',
      passed,
      `volumePills=${hasVolumePills}, brokerCard=${hasBrokerCard}, phone/wa=${hasCallBroker}, priceEdit=${hasPriceEditAction}, cancel=${hasCancelAction}, fulfill=${hasFulfillAction}`,
      passed ? undefined : 'CommodityDetailsScreen missing required elements'
    );
  } catch (err: any) {
    record('MGMT-02', 'CommodityDetailsScreen elements', 'UI System', false, 'Error reading commodity details screen', err.message);
  }

  // Test 4.3: MyCommoditiesScreen supports listing history and full status filter chips
  try {
    const listScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'presentation', 'my_commodities_screen.dart');
    const content = fs.readFileSync(listScreenPath, 'utf8');

    const hasOpen = content.includes("'Open'");
    const hasActive = content.includes("'Active'");
    const hasReserved = content.includes("'Reserved'");
    const hasFulfilled = content.includes("'Fulfilled'");
    const hasCancelled = content.includes("'Cancelled'");
    const hasExpired = content.includes("'Expired'");
    const hasExtraLotPush = content.includes("extra: lot");

    const passed = hasOpen && hasActive && hasReserved && hasFulfilled && hasCancelled && hasExpired && hasExtraLotPush;

    record(
      'MGMT-03',
      'MyCommoditiesScreen includes full status filters (Open, Active, Reserved, Fulfilled, Cancelled, Expired) and card deep linking',
      'Listing History',
      passed,
      `filters: Open, Active, Reserved, Fulfilled, Cancelled, Expired; card push with extra: lot=${hasExtraLotPush}`,
      passed ? undefined : 'Listing screen filters incomplete'
    );
  } catch (err: any) {
    record('MGMT-03', 'MyCommoditiesScreen filters', 'Listing History', false, 'Error reading my commodities screen', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 5: Counterparty Shield & Privacy Safeguards
  // --------------------------------------------------------------------------
  console.log('\n--- Category 5: Counterparty Shield & Strict Privacy ---');

  // Test 5.1: Zero Buyer direct contact leaks across entire codebase
  try {
    const libDir = path.join(SELLER_APP_DIR, 'lib');
    const filesToScan: string[] = [];

    const walkDir = (dir: string) => {
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          walkDir(fullPath);
        } else if (entry.isFile() && entry.name.endsWith('.dart')) {
          filesToScan.push(fullPath);
        }
      }
    };
    walkDir(libDir);

    let buyerFieldViolations: string[] = [];
    const forbiddenPatterns = [
      /buyer_phone/i,
      /buyer_mobile/i,
      /buyer_email/i,
      /buyer_contact/i,
      /buyer_directory/i,
      /chat_with_buyer/i,
      /direct_buyer_chat/i,
    ];

    for (const file of filesToScan) {
      const code = fs.readFileSync(file, 'utf8');
      for (const pattern of forbiddenPatterns) {
        if (pattern.test(code)) {
          buyerFieldViolations.push(`${path.relative(SELLER_APP_DIR, file)} matched ${pattern.source}`);
        }
      }
    }

    const passed = buyerFieldViolations.length === 0;
    record(
      'PRIVACY-01',
      'Counterparty Shield: Zero buyer contact references or directories in updated Seller codebase',
      'Privacy',
      passed,
      `Scanned ${filesToScan.length} Dart files. Violations: ${buyerFieldViolations.length}`,
      passed ? undefined : `Violations: ${buyerFieldViolations.join('; ')}`
    );
  } catch (err: any) {
    record('PRIVACY-01', 'Counterparty Shield scan', 'Privacy', false, 'Error scanning files', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 6: Boundaries & Invariants
  // --------------------------------------------------------------------------
  console.log('\n--- Category 6: Boundaries & Zero-Mutation Invariant ---');

  // Test 6.1: Zero DB migrations added in supabase/migrations
  try {
    const gitDiff = execSync('git status --porcelain supabase/migrations', {
      cwd: ROOT_DIR,
      encoding: 'utf8',
    }).trim();

    const passed = gitDiff.length === 0;
    record(
      'BOUNDARY-01',
      'Zero database migrations or schema alterations introduced in supabase/migrations',
      'Integrity',
      passed,
      gitDiff.length === 0 ? 'Git status: 0 modifications in supabase/migrations' : `Modifications detected: ${gitDiff}`,
      passed ? undefined : `Found unauthorized migration modifications: ${gitDiff}`
    );
  } catch (err: any) {
    record('BOUNDARY-01', 'Zero database migrations invariant', 'Integrity', false, 'Error checking migrations', err.message);
  }

  // Test 6.2: Sibling app boundary preservation (rmbuyer_mobile and rmbroker_mobile)
  try {
    const gitDiff = execSync('git status --porcelain apps/rmbuyer_mobile apps/rmbroker_mobile', {
      cwd: ROOT_DIR,
      encoding: 'utf8',
    }).trim();

    const passed = gitDiff.length === 0;
    record(
      'BOUNDARY-02',
      'Sibling applications (rmbuyer_mobile, rmbroker_mobile) completely untouched',
      'Integrity',
      passed,
      gitDiff.length === 0 ? 'Git status: 0 modifications in rmbuyer_mobile and rmbroker_mobile' : `Modifications found: ${gitDiff}`,
      passed ? undefined : 'Unapproved modifications found in sibling applications'
    );
  } catch (err: any) {
    record('BOUNDARY-02', 'Sibling app boundary preservation', 'Integrity', false, 'Error checking git status', err.message);
  }

  // Test 6.3: Automated test suites in rmseller_mobile/test
  try {
    const testDir = path.join(SELLER_APP_DIR, 'test');
    const unitFiles = fs.readdirSync(path.join(testDir, 'unit'));
    const widgetFiles = fs.readdirSync(path.join(testDir, 'widgets'));
    const totalSuites = unitFiles.length + widgetFiles.length;

    const passed = totalSuites >= 12;
    record(
      'TEST-01',
      'Automated test suites present (unit and widget tests >= 12 suites)',
      'Testing',
      passed,
      `Found ${unitFiles.length} unit test suites and ${widgetFiles.length} widget test suites (Total: ${totalSuites})`,
      passed ? undefined : `Insufficient test suites: ${totalSuites} < 12`
    );
  } catch (err: any) {
    record('TEST-01', 'Automated test suite presence', 'Testing', false, 'Error checking test directory', err.message);
  }

  // --------------------------------------------------------------------------
  // Summary
  // --------------------------------------------------------------------------
  const totalTests = results.length;
  const passed = results.filter((r) => r.passed).length;
  const failed = totalTests - passed;

  const report: RB02VerificationReport = {
    suiteName: 'Sprint RB-SELLER-02: Commodity Posting Completion & Broker Relationship Verification Suite',
    sprintId: 'RB-SELLER-02',
    totalTests,
    passed,
    failed,
    timestamp: new Date().toISOString(),
    results,
  };

  console.log('\n--------------------------------------------------------------------------------');
  console.log(`RB-SELLER-02 Verification Complete: ${passed}/${totalTests} Tests Passed (${failed} Failed)`);
  console.log('================================================================================\n');

  return report;
}

// Direct CLI execution support
if (process.argv[1]?.includes('verify-rmseller-posting-rb02')) {
  runRMSellerPostingVerification()
    .then((report) => {
      if (report.failed > 0) {
        console.error(`\n❌ RB-SELLER-02 Verification FAILED: ${report.failed} test(s) did not pass.`);
        process.exit(1);
      } else {
        console.log('\n✅ All RB-SELLER-02 Commodity Posting & Broker Relationship tests PASSED cleanly!');
        process.exit(0);
      }
    })
    .catch((err) => {
      console.error('\nRB-SELLER-02 test runner encountered unhandled error:', err);
      process.exit(1);
    });
}
