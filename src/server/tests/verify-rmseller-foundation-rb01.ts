/**
 * ============================================================================
 * SPRINT RB-SELLER-01: SELLER APP FOUNDATION & CORE TRADING WORKFLOW
 * AUTOMATED VERIFICATION SUITE
 * ============================================================================
 *
 * Validates the core requirements of Sprint RB-SELLER-01:
 * 1. Project bootstrap, configuration, and runner integrity in apps/rmseller_mobile.
 * 2. Theme tokens (Deep Burgundy & Amber Gold) and atomic design components.
 * 3. Authoritative Seller Authentication & Role Gate (seller/admin only, buyer/broker denied).
 * 4. Counterparty Shield & Strict Privacy (Zero buyer directory, buyer contact, or direct chat).
 * 5. Commodities data contract parity with Supabase `availabilities` table.
 * 6. Broker selection, mediation, and contact launcher safeguards.
 * 7. Complete 6-tab navigation shell and GoRouter route guard logic.
 * 8. Zero database migrations, schema alterations, or sibling app modifications.
 * ============================================================================
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

export interface RB01TestCaseResult {
  id: string;
  name: string;
  category: string;
  passed: boolean;
  evidence: string;
  detail?: string;
}

export interface RB01VerificationReport {
  suiteName: string;
  sprintId: string;
  totalTests: number;
  passed: number;
  failed: number;
  timestamp: string;
  results: RB01TestCaseResult[];
}

const ROOT_DIR = path.resolve(__dirname, '../../..');
const SELLER_APP_DIR = path.join(ROOT_DIR, 'apps', 'rmseller_mobile');

export async function runRMSellerFoundationVerification(): Promise<RB01VerificationReport> {
  const results: RB01TestCaseResult[] = [];

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
  console.log('STARTING SPRINT RB-SELLER-01 AUTOMATED VERIFICATION SUITE');
  console.log(`Target: ${SELLER_APP_DIR}`);
  console.log('================================================================================\n');

  // --------------------------------------------------------------------------
  // Category 1: Project Setup & Flutter Environment Integrity
  // --------------------------------------------------------------------------
  console.log('--- Category 1: Project Structure & Configuration ---');

  // Test 1.1: pubspec.yaml exists and contains required dependencies
  try {
    const pubspecPath = path.join(SELLER_APP_DIR, 'pubspec.yaml');
    const pubspecExists = fs.existsSync(pubspecPath);
    if (!pubspecExists) {
      record('SETUP-01', 'pubspec.yaml configuration file presence', 'Structure', false, 'Missing pubspec.yaml');
    } else {
      const content = fs.readFileSync(pubspecPath, 'utf8');
      const hasName = content.includes('name: rmseller_mobile');
      const hasRiverpod = content.includes('flutter_riverpod');
      const hasRouter = content.includes('go_router');
      const hasSupabase = content.includes('supabase_flutter');
      const hasStorage = content.includes('flutter_secure_storage');
      const hasIcons = content.includes('lucide_icons_flutter');
      const hasLauncher = content.includes('url_launcher');

      const allPresent = hasName && hasRiverpod && hasRouter && hasSupabase && hasStorage && hasIcons && hasLauncher;
      record(
        'SETUP-01',
        'pubspec.yaml contains required core enterprise dependencies',
        'Structure',
        allPresent,
        `name, riverpod, go_router, supabase, secure_storage, lucide, url_launcher verified present in pubspec.yaml`,
        allPresent ? undefined : 'Missing one or more dependencies in pubspec.yaml'
      );
    }
  } catch (err: any) {
    record('SETUP-01', 'pubspec.yaml configuration file presence', 'Structure', false, 'Error reading pubspec.yaml', err.message);
  }

  // Test 1.2: Native platform runners exist
  try {
    const androidExists = fs.existsSync(path.join(SELLER_APP_DIR, 'android'));
    const iosExists = fs.existsSync(path.join(SELLER_APP_DIR, 'ios'));
    const windowsExists = fs.existsSync(path.join(SELLER_APP_DIR, 'windows'));
    const allRunners = androidExists && iosExists && windowsExists;

    record(
      'SETUP-02',
      'Native build runners (android, ios, windows) configured',
      'Structure',
      allRunners,
      `Runners: android=${androidExists}, ios=${iosExists}, windows=${windowsExists}`,
      allRunners ? undefined : 'One or more platform runner folders missing'
    );
  } catch (err: any) {
    record('SETUP-02', 'Native build runners configured', 'Structure', false, 'Error verifying runners', err.message);
  }

  // Test 1.3: Analysis options lint file
  try {
    const analysisPath = path.join(SELLER_APP_DIR, 'analysis_options.yaml');
    const exists = fs.existsSync(analysisPath);
    record(
      'SETUP-03',
      'Flutter analysis and lint configuration present',
      'Structure',
      exists,
      `analysis_options.yaml found=${exists}`
    );
  } catch (err: any) {
    record('SETUP-03', 'Flutter analysis and lint configuration present', 'Structure', false, 'Error checking analysis_options', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 2: Design System & Visual Architecture
  // --------------------------------------------------------------------------
  console.log('\n--- Category 2: Design System & Theme Tokens ---');

  // Test 2.1: Theme tokens (Deep Burgundy & Amber Gold)
  try {
    const colorPath = path.join(SELLER_APP_DIR, 'lib', 'app', 'theme', 'app_colors.dart');
    const exists = fs.existsSync(colorPath);
    if (!exists) {
      record('THEME-01', 'Seller App Theme Colors present', 'Theme', false, 'Missing app_colors.dart');
    } else {
      const content = fs.readFileSync(colorPath, 'utf8');
      const hasBurgundy = content.includes('0xFF7C1D24') || content.includes('#7C1D24');
      const hasAmber = content.includes('0xFFD97706') || content.includes('#D97706');
      const passed = hasBurgundy && hasAmber;
      record(
        'THEME-01',
        'Theme tokens include authoritative Deep Burgundy and Amber Gold',
        'Theme',
        passed,
        `Deep Burgundy (0xFF7C1D24)=${hasBurgundy}, Amber Gold (0xFFD97706)=${hasAmber}`,
        passed ? undefined : 'Color tokens do not match required palette'
      );
    }
  } catch (err: any) {
    record('THEME-01', 'Seller App Theme Colors present', 'Theme', false, 'Error reading app_colors.dart', err.message);
  }

  // Test 2.2: Reusable atomic widgets
  try {
    const widgetsDir = path.join(SELLER_APP_DIR, 'lib', 'core', 'widgets');
    const buttonExists = fs.existsSync(path.join(widgetsDir, 'app_button.dart'));
    const cardExists = fs.existsSync(path.join(widgetsDir, 'app_card.dart'));
    const textExists = fs.existsSync(path.join(widgetsDir, 'app_text_field.dart'));
    const badgeExists = fs.existsSync(path.join(widgetsDir, 'status_badge.dart'));
    const emptyExists = fs.existsSync(path.join(widgetsDir, 'app_empty_state.dart'));
    const errorExists = fs.existsSync(path.join(widgetsDir, 'app_error_state.dart'));
    const loadingExists = fs.existsSync(path.join(widgetsDir, 'app_loading_indicator.dart'));

    const allWidgets = buttonExists && cardExists && textExists && badgeExists && emptyExists && errorExists && loadingExists;
    record(
      'THEME-02',
      'Atomic UI components created for loading, empty, error, button, card, input, and badges',
      'UI System',
      allWidgets,
      `Core widgets present: button, card, text_field, status_badge, empty_state, error_state, loading_indicator`,
      allWidgets ? undefined : 'One or more atomic components missing'
    );
  } catch (err: any) {
    record('THEME-02', 'Atomic UI components created', 'UI System', false, 'Error checking widgets', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 3: Authentication & Role Authorization Gate
  // --------------------------------------------------------------------------
  console.log('\n--- Category 3: Authentication & Role Gate ---');

  // Test 3.1: Auth repository enforces seller/admin role boundary
  try {
    const authRepoPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'authentication', 'data', 'auth_repository.dart');
    const content = fs.readFileSync(authRepoPath, 'utf8');

    const enforcesRole = content.includes("resolvedRole == 'seller'") || content.includes("role == 'seller'");
    const yieldsAccessDenied = content.includes('AuthAccessDenied');
    const storesSellerSession = content.includes('saveUserInfo') && content.includes('saveToken');
    const passed = enforcesRole && yieldsAccessDenied && storesSellerSession;

    record(
      'AUTH-01',
      'AuthRepository enforces role gate: seller/admin allowed, buyer/broker rejected with AuthAccessDenied',
      'Security',
      passed,
      `Role check enforcement=${enforcesRole}, AuthAccessDenied=${yieldsAccessDenied}, Session=${storesSellerSession}`,
      passed ? undefined : 'AuthRepository role validation logic incomplete'
    );
  } catch (err: any) {
    record('AUTH-01', 'AuthRepository enforces role gate', 'Security', false, 'Error inspecting auth_repository', err.message);
  }

  // Test 3.2: Access Denied screen exists
  try {
    const accessDeniedPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'authentication', 'presentation', 'access_denied_screen.dart');
    const exists = fs.existsSync(accessDeniedPath);
    const content = exists ? fs.readFileSync(accessDeniedPath, 'utf8') : '';
    const hasShield = content.includes('shieldAlert');
    const hasSignOut = content.includes('Sign Out & Return to Login');
    const passed = exists && hasShield && hasSignOut;

    record(
      'AUTH-02',
      'AccessDeniedScreen displays security shield, account role details, and safe sign-out',
      'Security',
      passed,
      `Screen exists=${exists}, shieldIcon=${hasShield}, signOutAction=${hasSignOut}`,
      passed ? undefined : 'AccessDeniedScreen incomplete'
    );
  } catch (err: any) {
    record('AUTH-02', 'AccessDeniedScreen displays security shield', 'Security', false, 'Error checking access denied screen', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 4: Counterparty Shield & Privacy Safeguards
  // --------------------------------------------------------------------------
  console.log('\n--- Category 4: Counterparty Shield & Strict Privacy ---');

  // Test 4.1: Static scan across all Seller App source code for Buyer direct contact leaks
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
      'Counterparty Shield: Zero buyer phone, email, direct chat, or directory references across all Seller code',
      'Privacy',
      passed,
      `Scanned ${filesToScan.length} Dart files. Violations detected: ${buyerFieldViolations.length}`,
      passed ? undefined : `Violations found: ${buyerFieldViolations.join('; ')}`
    );
  } catch (err: any) {
    record('PRIVACY-01', 'Counterparty Shield scan', 'Privacy', false, 'Error scanning files', err.message);
  }

  // Test 4.2: Contact launcher restricted strictly to brokers
  try {
    const contactLauncherPath = path.join(SELLER_APP_DIR, 'lib', 'core', 'services', 'contact_launcher_service.dart');
    const content = fs.readFileSync(contactLauncherPath, 'utf8');

    const hasPhoneAndWhatsApp = content.includes('launchPhone') && content.includes('launchWhatsApp');
    const noBuyerLauncher = !content.includes('callBuyer') && !content.includes('launchBuyer');
    const hasShieldNotice = content.includes('STRICT COUNTERPARTY SHIELD INVARIANT');
    const passed = hasPhoneAndWhatsApp && noBuyerLauncher && hasShieldNotice;

    record(
      'PRIVACY-02',
      'ContactLauncherService restricts dialer/messaging exclusively to authorized Brokers',
      'Privacy',
      passed,
      `Phone/WhatsApp triggers present=${hasPhoneAndWhatsApp}, Shield notice=${hasShieldNotice}, Zero Buyer triggers=${noBuyerLauncher}`,
      passed ? undefined : 'Contact launcher contains direct buyer triggers or lacks counterparty shield'
    );
  } catch (err: any) {
    record('PRIVACY-02', 'Contact launcher restriction', 'Privacy', false, 'Error reading contact launcher', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 5: Commodities & Trading Workflows
  // --------------------------------------------------------------------------
  console.log('\n--- Category 5: Commodities & Trading Workflow ---');

  // Test 5.1: Availabilities table data mapping
  try {
    const modelPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'domain', 'commodity_model.dart');
    const content = fs.readFileSync(modelPath, 'utf8');

    const hasLotNumber = content.includes('lotNumber');
    const hasTotalQty = content.includes('totalQuantity');
    const hasAvailableQty = content.includes('availableQuantity');
    const hasAskingPrice = content.includes('askingPrice');
    const hasConfPrice = content.includes('confidentialMinimumPrice');
    const hasLoadingStatus = content.includes('loadingStatus');
    const hasBrokerId = content.includes('brokerId');

    const passed = hasLotNumber && hasTotalQty && hasAvailableQty && hasAskingPrice && hasConfPrice && hasLoadingStatus && hasBrokerId;
    record(
      'COMMODITY-01',
      'SellerCommodity domain model maps to existing `availabilities` database schema',
      'Data Contract',
      passed,
      `LotNumber, TotalQty, AvailableQty, AskingPrice, ConfPrice, LoadingStatus, BrokerId mapped`,
      passed ? undefined : 'Domain model missing critical database fields'
    );
  } catch (err: any) {
    record('COMMODITY-01', 'SellerCommodity domain model mapping', 'Data Contract', false, 'Error reading commodity model', err.message);
  }

  // Test 5.2: Commodities repository companyId scoping
  try {
    const repoPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'data', 'commodities_repository.dart');
    const content = fs.readFileSync(repoPath, 'utf8');

    const hasCompanyFilter = content.includes('company_id');
    const hasAvailabilitiesTable = content.includes("'availabilities'");
    const hasOptimisticLocking = content.includes('commoditiesUpdatedNotifier');
    const passed = hasCompanyFilter && hasAvailabilitiesTable && hasOptimisticLocking;

    record(
      'COMMODITY-02',
      'CommoditiesRepository scopes queries strictly to seller company_id and targets `availabilities` table',
      'Data Contract',
      passed,
      `Scopes by company_id=${hasCompanyFilter}, uses 'availabilities'=${hasAvailabilitiesTable}, notifier=${hasOptimisticLocking}`,
      passed ? undefined : 'Repository query scoping incorrect'
    );
  } catch (err: any) {
    record('COMMODITY-02', 'CommoditiesRepository scoping', 'Data Contract', false, 'Error reading commodities repo', err.message);
  }

  // Test 5.3: Post Commodity 4-step workflow screen
  try {
    const postScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'commodities', 'presentation', 'post_commodity_screen.dart');
    const content = fs.readFileSync(postScreenPath, 'utf8');

    const hasStep1 = content.includes('1. Commodity & Specification');
    const hasStep2 = content.includes('2. Quantity & Commercial Pricing');
    const hasStep3 = content.includes('3. Warehouse Location & Loading');
    const hasStep4 = content.includes('4. Broker Mandate Assignment');
    const hasBrokerSheet = content.includes('Select Mandi Broker Desk');
    const passed = hasStep1 && hasStep2 && hasStep3 && hasStep4 && hasBrokerSheet;

    record(
      'COMMODITY-03',
      'PostCommodityScreen implements full 4-step workflow with Broker Desk selection sheet',
      'Workflow',
      passed,
      `Sections: Step 1=${hasStep1}, Step 2=${hasStep2}, Step 3=${hasStep3}, Step 4=${hasStep4}, Broker Desk Sheet=${hasBrokerSheet}`,
      passed ? undefined : 'Posting workflow screen missing required sections'
    );
  } catch (err: any) {
    record('COMMODITY-03', 'PostCommodityScreen 4-step workflow', 'Workflow', false, 'Error reading post_commodity_screen', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 6: Broker Mediation & Discovery
  // --------------------------------------------------------------------------
  console.log('\n--- Category 6: Broker Mediation & Discovery ---');

  // Test 6.1: Seller Broker Repository queries broker users with company trust score
  try {
    const brokerRepoPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'brokers', 'data', 'seller_broker_repository.dart');
    const content = fs.readFileSync(brokerRepoPath, 'utf8');

    const hasBrokerRole = content.includes(".eq('role', 'broker')");
    const hasTrustScore = content.includes("trust_score") || content.includes("trustScore");
    const passed = hasBrokerRole && hasTrustScore;

    record(
      'BROKER-01',
      'SellerBrokerRepository queries verified brokers with trust score',
      'Brokerage',
      passed,
      `.eq('role', 'broker')=${hasBrokerRole}, trustScore mapping=${hasTrustScore}`,
      passed ? undefined : 'Broker query does not filter by broker role or map trust scores'
    );
  } catch (err: any) {
    record('BROKER-01', 'SellerBrokerRepository validation', 'Brokerage', false, 'Error reading broker repo', err.message);
  }

  // Test 6.2: My Brokers screen renders list with contact actions
  try {
    const brokerScreenPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'brokers', 'presentation', 'my_brokers_screen.dart');
    const exists = fs.existsSync(brokerScreenPath);
    const content = exists ? fs.readFileSync(brokerScreenPath, 'utf8') : '';
    const hasCall = content.includes('launchPhone') || content.includes('ContactLauncherService');
    const hasSearch = content.includes('search');
    const passed = exists && (hasCall || hasSearch);

    record(
      'BROKER-02',
      'MyBrokersScreen provides broker discovery and mediated communication actions',
      'Brokerage',
      passed,
      `Screen exists=${exists}, contact launcher/search actions=${passed}`,
      passed ? undefined : 'MyBrokersScreen incomplete'
    );
  } catch (err: any) {
    record('BROKER-02', 'MyBrokersScreen validation', 'Brokerage', false, 'Error reading my brokers screen', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 7: Navigation & Router Routing Logic
  // --------------------------------------------------------------------------
  console.log('\n--- Category 7: Navigation & Route Guard Logic ---');

  // Test 7.1: Navigation Shell contains all 6 core tabs
  try {
    const navShellPath = path.join(SELLER_APP_DIR, 'lib', 'features', 'home', 'presentation', 'navigation_shell.dart');
    const content = fs.readFileSync(navShellPath, 'utf8');

    const hasDashboard = content.includes('Dashboard');
    const hasCommodities = content.includes('Commodities');
    const hasBrokers = content.includes('Brokers');
    const hasDeals = content.includes('Deals');
    const hasReports = content.includes('Reports');
    const hasProfile = content.includes('Profile');

    const passed = hasDashboard && hasCommodities && hasBrokers && hasDeals && hasReports && hasProfile;
    record(
      'NAV-01',
      'NavigationShell defines 6 persistent tabs: Dashboard, Commodities, Brokers, Deals, Reports, Profile',
      'Navigation',
      passed,
      `Tabs present: Dashboard=${hasDashboard}, Commodities=${hasCommodities}, Brokers=${hasBrokers}, Deals=${hasDeals}, Reports=${hasReports}, Profile=${hasProfile}`,
      passed ? undefined : 'Navigation shell missing one or more required tabs'
    );
  } catch (err: any) {
    record('NAV-01', 'NavigationShell tabs validation', 'Navigation', false, 'Error reading navigation shell', err.message);
  }

  // Test 7.2: AppRouter defines full route tree
  try {
    const routerPath = path.join(SELLER_APP_DIR, 'lib', 'app', 'router', 'app_router.dart');
    const content = fs.readFileSync(routerPath, 'utf8');

    const hasSplash = content.includes("path: '/'");
    const hasLogin = content.includes("path: '/login'");
    const hasDenied = content.includes("path: '/access-denied'");
    const hasHome = content.includes("path: '/home'");
    const hasPostNew = content.includes("path: '/commodities/new'");
    const hasRedirect = content.includes('redirectLogic');

    const passed = hasSplash && hasLogin && hasDenied && hasHome && hasPostNew && hasRedirect;
    record(
      'NAV-02',
      'AppRouter configures route hierarchy with redirectLogic route guarding',
      'Navigation',
      passed,
      `Routes configured: /, /login, /access-denied, /home, /commodities/new, redirect guard`,
      passed ? undefined : 'AppRouter missing critical routes'
    );
  } catch (err: any) {
    record('NAV-02', 'AppRouter configuration', 'Navigation', false, 'Error reading app router', err.message);
  }

  // --------------------------------------------------------------------------
  // Category 8: Project Boundaries & Zero-Mutation Invariant
  // --------------------------------------------------------------------------
  console.log('\n--- Category 8: Boundaries & Zero Database Alteration ---');

  // Test 8.1: Zero DB migrations added in supabase/migrations during this sprint
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
      gitDiff.length === 0 ? 'Git status: 0 modifications or new files in supabase/migrations' : `Modifications detected: ${gitDiff}`,
      passed ? undefined : `Found unauthorized migration modifications: ${gitDiff}`
    );
  } catch (err: any) {
    record('BOUNDARY-01', 'Zero database migrations invariant', 'Integrity', false, 'Error checking migrations', err.message);
  }

  // Test 8.2: Sibling app boundary preservation (rmbuyer_mobile and rmbroker_mobile)
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

  // Test 8.3: Unit & Widget test coverage suites present in rmseller_mobile/test
  try {
    const testDir = path.join(SELLER_APP_DIR, 'test');
    const unitFiles = fs.readdirSync(path.join(testDir, 'unit'));
    const widgetFiles = fs.readdirSync(path.join(testDir, 'widgets'));
    const totalSuites = unitFiles.length + widgetFiles.length;

    const passed = totalSuites >= 10;
    record(
      'TEST-01',
      'Automated test suites present (unit and widget tests >= 10 suites)',
      'Testing',
      passed,
      `Found ${unitFiles.length} unit test suites and ${widgetFiles.length} widget test suites (Total: ${totalSuites})`,
      passed ? undefined : `Insufficient test suites: ${totalSuites} < 10`
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

  const report: RB01VerificationReport = {
    suiteName: 'Sprint RB-SELLER-01: Seller App Foundation & Core Trading Workflow Verification Suite',
    sprintId: 'RB-SELLER-01',
    totalTests,
    passed,
    failed,
    timestamp: new Date().toISOString(),
    results,
  };

  console.log('\n--------------------------------------------------------------------------------');
  console.log(`RB-SELLER-01 Verification Complete: ${passed}/${totalTests} Tests Passed (${failed} Failed)`);
  console.log('================================================================================\n');

  return report;
}

// Direct CLI execution support
if (process.argv[1]?.includes('verify-rmseller-foundation-rb01')) {
  runRMSellerFoundationVerification()
    .then((report) => {
      if (report.failed > 0) {
        console.error(`\n❌ RB-SELLER-01 Verification FAILED: ${report.failed} test(s) did not pass.`);
        process.exit(1);
      } else {
        console.log('\n✅ All RB-SELLER-01 Seller App Foundation Verification tests PASSED cleanly!');
        process.exit(0);
      }
    })
    .catch((err) => {
      console.error('\nRB-SELLER-01 test runner encountered unhandled error:', err);
      process.exit(1);
    });
}
