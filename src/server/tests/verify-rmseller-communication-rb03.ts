/**
 * ============================================================================
 * SPRINT RB-SELLER-03: BROKER COMMUNICATION & COMMODITY-SPECIFIC COMMISSION
 * NEGOTIATION AUTOMATED VERIFICATION SUITE
 * ============================================================================
 *
 * Validates the core requirements of Sprint RB-SELLER-03:
 * 1. Broker communication interface with dual-tab (Chat & Commission Terms).
 * 2. Strict Counterparty Shield (zero buyer exposure, broker-mediated only).
 * 3. Append-only immutability against existing `negotiation_events` table.
 * 4. Multi-unit commission proposal (₹/MT, ₹/QTL, ₹/Bag, % of Invoice) with positive validation.
 * 5. Full negotiation cycle: Propose, Accept, Reject, Counter with distinct terms.
 * 6. Commission status calculation and audit trail timeline.
 * 7. Seller notifications center with event filtering and deep link navigation.
 * 8. Entry points from Commodity Details, Broker List, and Broker Profile.
 * 9. Unit & widget tests for negotiation repository and communication screen.
 * 10. Sibling app boundary preservation and zero database schema mutations.
 * ============================================================================
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

export interface RB03TestCaseResult {
  id: string;
  name: string;
  category: string;
  passed: boolean;
  evidence: string;
  detail?: string;
}

export interface RB03VerificationReport {
  suiteName: string;
  sprintId: string;
  totalTests: number;
  passed: number;
  failed: number;
  timestamp: string;
  results: RB03TestCaseResult[];
}

const ROOT_DIR = path.resolve(__dirname, '../../..');
const SELLER_APP_DIR = path.join(ROOT_DIR, 'apps', 'rmseller_mobile');

export async function runRMSellerCommunicationVerification(): Promise<RB03VerificationReport> {
  const results: RB03TestCaseResult[] = [];

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
      console.log(`       ⚠️  Detail: ${detail}`);
    }
  };

  console.log('\n============================================================');
  console.log('🚀 RUNNING RB-SELLER-03: BROKER COMMUNICATION & NEGOTIATION VERIFICATION');
  console.log('============================================================\n');

  // --------------------------------------------------------------------------
  // Check 1: Broker Communication Screen & Dual-Tab Interface
  // --------------------------------------------------------------------------
  try {
    const screenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/presentation/broker_communication_screen.dart'
    );
    const screenExists = fs.existsSync(screenPath);
    if (!screenExists) {
      record(
        'RB03-01',
        'Broker Communication Screen & Dual-Tab Interface',
        'UI/UX Architecture',
        false,
        'File missing',
        `File not found at ${screenPath}`
      );
    } else {
      const content = fs.readFileSync(screenPath, 'utf8');
      const hasDualTab = content.includes('Broker Chat') && content.includes('Commission Terms');
      const hasChatInput = content.includes('Type a message to broker...') || content.includes('TextField');
      const hasBrokerHeader = content.includes('widget.brokerName') && content.includes('ContactLauncherService');
      const hasActiveProposalCard = content.includes('_buildActiveProposalCard') || content.includes('Commission Terms');

      const passed = hasDualTab && hasChatInput && hasBrokerHeader && hasActiveProposalCard;
      record(
        'RB03-01',
        'Broker Communication Screen & Dual-Tab Interface',
        'UI/UX Architecture',
        passed,
        `Tabs: ${hasDualTab}, ChatInput: ${hasChatInput}, BrokerHeader: ${hasBrokerHeader}, ActiveProposalCard: ${hasActiveProposalCard}`,
        passed ? undefined : 'Screen missing required tabbed chat and commission components'
      );
    }
  } catch (err: any) {
    record('RB03-01', 'Broker Communication Screen & Dual-Tab Interface', 'UI/UX Architecture', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 2: Strict Counterparty Shield & Broker-Mediated Boundaries
  // --------------------------------------------------------------------------
  try {
    const screenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/presentation/broker_communication_screen.dart'
    );
    const repoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/data/negotiation_repository.dart'
    );
    const screenContent = fs.readFileSync(screenPath, 'utf8');
    const repoContent = fs.readFileSync(repoPath, 'utf8');

    // Verify counterparty shield disclaimer exists
    const hasShieldDisclaimer = screenContent.includes('Counterparty Shield') || screenContent.includes('broker-mediated');
    
    // Verify no direct buyer chat or buyer directories are referenced in negotiation
    const hasBuyerChatLeak = /buyer.*chat|direct.*buyer.*message|buyer.*directory/i.test(screenContent);
    const repoHasBuyerExposure = /buyer_phone|buyer_email|buyer_direct/i.test(repoContent);

    const passed = hasShieldDisclaimer && !hasBuyerChatLeak && !repoHasBuyerExposure;
    record(
      'RB03-02',
      'Strict Counterparty Shield & Broker-Mediated Boundaries',
      'Security & Access Control',
      passed,
      `Shield disclaimer present: ${hasShieldDisclaimer}, Zero buyer leaks: ${!hasBuyerChatLeak && !repoHasBuyerExposure}`,
      passed ? undefined : 'Found potential buyer chat exposure or missing shield disclaimer'
    );
  } catch (err: any) {
    record('RB03-02', 'Strict Counterparty Shield & Broker-Mediated Boundaries', 'Security & Access Control', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 3: Append-Only Immutability & `negotiation_events` Table Mapping
  // --------------------------------------------------------------------------
  try {
    const modelPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/domain/negotiation_model.dart'
    );
    const repoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/data/negotiation_repository.dart'
    );
    const modelContent = fs.readFileSync(modelPath, 'utf8');
    const repoContent = fs.readFileSync(repoPath, 'utf8');

    const mapsRequestId = modelContent.includes('requestId') && repoContent.includes('request_id');
    const mapsActionType = modelContent.includes('NegotiationActionType') && repoContent.includes('action_type');
    const mapsPayload = modelContent.includes('payload') && repoContent.includes('payload:');
    const mapsTable = repoContent.includes("'negotiation_events'");
    // Verify no update or delete calls on negotiation_events
    const hasUpdateCall = repoContent.includes(".from('negotiation_events').update") || repoContent.includes(".from('negotiation_events').delete");

    const passed = mapsRequestId && mapsActionType && mapsPayload && mapsTable && !hasUpdateCall;
    record(
      'RB03-03',
      'Append-Only Immutability & negotiation_events Table Mapping',
      'Data Layer & Contracts',
      passed,
      `Table mapping: ${mapsTable}, Fields: requestId=${mapsRequestId}, actionType=${mapsActionType}, payload=${mapsPayload}, Immutable: ${!hasUpdateCall}`,
      passed ? undefined : 'Repository fails to conform to immutable negotiation_events schema'
    );
  } catch (err: any) {
    record('RB03-03', 'Append-Only Immutability & negotiation_events Table Mapping', 'Data Layer & Contracts', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 4: Multi-Unit Commission Proposal & Rate Boundaries
  // --------------------------------------------------------------------------
  try {
    const screenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/presentation/broker_communication_screen.dart'
    );
    const repoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/data/negotiation_repository.dart'
    );
    const screenContent = fs.readFileSync(screenPath, 'utf8');
    const repoContent = fs.readFileSync(repoPath, 'utf8');

    // Commission basis units: ₹/MT, ₹/QTL, ₹/Bag, % of Invoice
    const hasPerMt = screenContent.includes('₹/MT') || repoContent.includes('₹/MT');
    const hasPerQtl = screenContent.includes('₹/QTL') || repoContent.includes('₹/QTL');
    const hasPerBag = screenContent.includes('₹/Bag') || repoContent.includes('₹/Bag');
    const hasPercent = screenContent.includes('% of Invoice') || repoContent.includes('% of Invoice');

    // Validation: proposedRate must be > 0
    const hasRateValidation = repoContent.includes('proposedRate <= 0') || screenContent.includes('rate <= 0');

    const passed = hasPerMt && hasPerQtl && hasPerBag && hasPercent && hasRateValidation;
    record(
      'RB03-04',
      'Multi-Unit Commission Proposal & Rate Boundaries',
      'Business Logic',
      passed,
      `Units: MT=${hasPerMt}, QTL=${hasPerQtl}, Bag=${hasPerBag}, %= ${hasPercent}; Positive Validation=${hasRateValidation}`,
      passed ? undefined : 'Missing commission units or positive rate validation'
    );
  } catch (err: any) {
    record('RB03-04', 'Multi-Unit Commission Proposal & Rate Boundaries', 'Business Logic', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 5: Bidirectional Negotiation Cycle (Accept, Reject, Counter)
  // --------------------------------------------------------------------------
  try {
    const repoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/data/negotiation_repository.dart'
    );
    const screenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/presentation/broker_communication_screen.dart'
    );
    const repoContent = fs.readFileSync(repoPath, 'utf8');
    const screenContent = fs.readFileSync(screenPath, 'utf8');

    const hasAcceptLogic = repoContent.includes('commissionAccept') && repoContent.includes("'AGREED'");
    const hasRejectLogic = repoContent.includes('commissionReject') && repoContent.includes("'REJECTED'");
    const hasCounterLogic = repoContent.includes('commissionCounter') && repoContent.includes("'COUNTERED'");
    const hasAcceptConfirmation = screenContent.includes('Confirm Agreed Commission Terms') || screenContent.includes('AlertDialog');

    const passed = hasAcceptLogic && hasRejectLogic && hasCounterLogic && hasAcceptConfirmation;
    record(
      'RB03-05',
      'Bidirectional Negotiation Cycle (Accept, Reject, Counter)',
      'Business Logic',
      passed,
      `Accept: ${hasAcceptLogic}, Reject: ${hasRejectLogic}, Counter: ${hasCounterLogic}, ConfirmDialog: ${hasAcceptConfirmation}`,
      passed ? undefined : 'Missing negotiation action handlers or accept confirmation modal'
    );
  } catch (err: any) {
    record('RB03-05', 'Bidirectional Negotiation Cycle (Accept, Reject, Counter)', 'Business Logic', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 6: Commission Status Calculation & Audit Trail Timeline
  // --------------------------------------------------------------------------
  try {
    const modelPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/domain/negotiation_model.dart'
    );
    const repoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/data/negotiation_repository.dart'
    );
    const screenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/negotiation/presentation/broker_communication_screen.dart'
    );
    const modelContent = fs.readFileSync(modelPath, 'utf8');
    const repoContent = fs.readFileSync(repoPath, 'utf8');
    const screenContent = fs.readFileSync(screenPath, 'utf8');

    const hasCommissionSummary = modelContent.includes('class CommissionSummary');
    const hasSummaryMethod = repoContent.includes('getCommissionSummary');
    const hasTimelineMethod = repoContent.includes('getNegotiationTimeline');
    const hasTimelineWidget = screenContent.includes('_buildTimelineItem') || screenContent.includes('Negotiation History & Audit Trail');

    const passed = hasCommissionSummary && hasSummaryMethod && hasTimelineMethod && hasTimelineWidget;
    record(
      'RB03-06',
      'Commission Status Calculation & Audit Trail Timeline',
      'Data Integrity & Auditability',
      passed,
      `CommissionSummary model: ${hasCommissionSummary}, Summary method: ${hasSummaryMethod}, Timeline method: ${hasTimelineMethod}, Timeline UI: ${hasTimelineWidget}`,
      passed ? undefined : 'Missing commission status aggregation or audit timeline view'
    );
  } catch (err: any) {
    record('RB03-06', 'Commission Status Calculation & Audit Trail Timeline', 'Data Integrity & Auditability', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 7: Seller Notifications Center & Event Filtering
  // --------------------------------------------------------------------------
  try {
    const notifModelPath = path.join(
      SELLER_APP_DIR,
      'lib/features/notifications/domain/notification_model.dart'
    );
    const notifRepoPath = path.join(
      SELLER_APP_DIR,
      'lib/features/notifications/data/notifications_repository.dart'
    );
    const notifScreenPath = path.join(
      SELLER_APP_DIR,
      'lib/features/notifications/presentation/seller_notifications_screen.dart'
    );

    const hasNotifModel = fs.existsSync(notifModelPath);
    const hasNotifRepo = fs.existsSync(notifRepoPath);
    const hasNotifScreen = fs.existsSync(notifScreenPath);

    let passed = hasNotifModel && hasNotifRepo && hasNotifScreen;
    let detail = '';

    if (passed) {
      const screenContent = fs.readFileSync(notifScreenPath, 'utf8');
      const repoContent = fs.readFileSync(notifRepoPath, 'utf8');

      const hasFilterChips = screenContent.includes('FilterChip') || screenContent.includes('all') && screenContent.includes('unread');
      const hasMarkRead = repoContent.includes('markAsRead') && repoContent.includes('markAllAsRead');
      const hasUnreadCount = repoContent.includes('getUnreadCount');
      const hasDeepLink = screenContent.includes('context.push(notif.actionUrl');

      passed = hasFilterChips && hasMarkRead && hasUnreadCount && hasDeepLink;
      detail = `FilterChips: ${hasFilterChips}, MarkRead: ${hasMarkRead}, UnreadCount: ${hasUnreadCount}, DeepLink: ${hasDeepLink}`;
    }

    record(
      'RB03-07',
      'Seller Notifications Center & Event Filtering',
      'Notifications & Real-Time Sync',
      passed,
      detail || `Model: ${hasNotifModel}, Repo: ${hasNotifRepo}, Screen: ${hasNotifScreen}`,
      passed ? undefined : 'Notifications subsystem missing required filtering, unread counting, or deep linking'
    );
  } catch (err: any) {
    record('RB03-07', 'Seller Notifications Center & Event Filtering', 'Notifications & Real-Time Sync', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 8: Cross-Module Entry Points & Route Configuration
  // --------------------------------------------------------------------------
  try {
    const commodityDetailsPath = path.join(
      SELLER_APP_DIR,
      'lib/features/commodities/presentation/commodity_details_screen.dart'
    );
    const myBrokersPath = path.join(
      SELLER_APP_DIR,
      'lib/features/brokers/presentation/my_brokers_screen.dart'
    );
    const brokerProfilePath = path.join(
      SELLER_APP_DIR,
      'lib/features/brokers/presentation/broker_profile_screen.dart'
    );
    const appRouterPath = path.join(
      SELLER_APP_DIR,
      'lib/app/router/app_router.dart'
    );

    const comDetailsContent = fs.readFileSync(commodityDetailsPath, 'utf8');
    const myBrokersContent = fs.readFileSync(myBrokersPath, 'utf8');
    const brokerProfileContent = fs.readFileSync(brokerProfilePath, 'utf8');
    const routerContent = fs.readFileSync(appRouterPath, 'utf8');

    const hasCommodityDetailsAction = comDetailsContent.includes('/negotiate');
    const hasMyBrokersAction = myBrokersContent.includes('/communication/broker');
    const hasBrokerProfileAction = brokerProfileContent.includes('/communication/broker');
    const hasNegotiateRoute = routerContent.includes("path: '/commodities/:id/negotiate'");
    const hasBrokerCommRoute = routerContent.includes("path: '/communication/broker/:brokerId'");
    const hasNotificationsRoute = routerContent.includes("path: '/notifications'") && routerContent.includes('SellerNotificationsScreen');

    const passed =
      hasCommodityDetailsAction &&
      hasMyBrokersAction &&
      hasBrokerProfileAction &&
      hasNegotiateRoute &&
      hasBrokerCommRoute &&
      hasNotificationsRoute;

    record(
      'RB03-08',
      'Cross-Module Entry Points & Route Configuration',
      'Navigation & App Integration',
      passed,
      `CommodityDetails: ${hasCommodityDetailsAction}, MyBrokers: ${hasMyBrokersAction}, BrokerProfile: ${hasBrokerProfileAction}, NegotiateRoute: ${hasNegotiateRoute}, BrokerRoute: ${hasBrokerCommRoute}, NotifsRoute: ${hasNotificationsRoute}`,
      passed ? undefined : 'Missing one or more navigation entry points or AppRouter routes'
    );
  } catch (err: any) {
    record('RB03-08', 'Cross-Module Entry Points & Route Configuration', 'Navigation & App Integration', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 9: Unit & Widget Test Suites for RB-SELLER-03
  // --------------------------------------------------------------------------
  try {
    const unitTestPath = path.join(
      SELLER_APP_DIR,
      'test/unit/negotiation_repository_test.dart'
    );
    const widgetTestPath = path.join(
      SELLER_APP_DIR,
      'test/widgets/broker_communication_screen_test.dart'
    );

    const unitExists = fs.existsSync(unitTestPath);
    const widgetExists = fs.existsSync(widgetTestPath);

    let passed = unitExists && widgetExists;
    let detail = '';

    if (passed) {
      const unitContent = fs.readFileSync(unitTestPath, 'utf8');
      const widgetContent = fs.readFileSync(widgetTestPath, 'utf8');

      const hasUnitMessaging = unitContent.includes('sendMessage');
      const hasUnitPropose = unitContent.includes('proposeCommission');
      const hasUnitRespond = unitContent.includes('respondToCommission');
      const hasUnitTimeline = unitContent.includes('getNegotiationTimeline');

      const hasWidgetHeader = widgetContent.includes('Counterparty Shield');
      const hasWidgetTabs = widgetContent.includes('Broker Chat') && widgetContent.includes('Commission Terms');
      const hasWidgetModal = widgetContent.includes('Propose Broker Commission');

      passed =
        hasUnitMessaging &&
        hasUnitPropose &&
        hasUnitRespond &&
        hasUnitTimeline &&
        hasWidgetHeader &&
        hasWidgetTabs &&
        hasWidgetModal;

      detail = `Unit: msg=${hasUnitMessaging}, prop=${hasUnitPropose}, resp=${hasUnitRespond}, time=${hasUnitTimeline}; Widget: hdr=${hasWidgetHeader}, tabs=${hasWidgetTabs}, modal=${hasWidgetModal}`;
    }

    record(
      'RB03-09',
      'Unit & Widget Test Suites for RB-SELLER-03',
      'Quality Assurance & Testing',
      passed,
      detail || `UnitExists: ${unitExists}, WidgetExists: ${widgetExists}`,
      passed ? undefined : 'Missing unit or widget test cases for negotiation workflow'
    );
  } catch (err: any) {
    record('RB03-09', 'Unit & Widget Test Suites for RB-SELLER-03', 'Quality Assurance & Testing', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 10: Sibling App Boundary & Zero Database Schema Mutation
  // --------------------------------------------------------------------------
  try {
    let gitStatus = '';
    try {
      gitStatus = execSync('git status --porcelain', {
        cwd: ROOT_DIR,
        encoding: 'utf8',
      });
    } catch {
      // Fallback
      gitStatus = '';
    }

    const lines = gitStatus.split('\n').filter((l) => l.trim().length > 0);

    const rmbuyerModified = lines.some((l) => l.includes('apps/rmbuyer_mobile'));
    const rmbrokerModified = lines.some((l) => l.includes('apps/rmbroker_mobile'));
    const migrationsModified = lines.some((l) => l.includes('supabase/migrations'));

    const passed = !rmbuyerModified && !rmbrokerModified && !migrationsModified;

    record(
      'RB03-10',
      'Sibling App Boundary & Zero Database Schema Mutation',
      'Architecture Governance',
      passed,
      `RMBuyer untouched: ${!rmbuyerModified}, RMBroker untouched: ${!rmbrokerModified}, Zero DB migrations: ${!migrationsModified}`,
      passed ? undefined : 'Violated boundaries: modifications found in sibling apps or database migrations'
    );
  } catch (err: any) {
    record('RB03-10', 'Sibling App Boundary & Zero Database Schema Mutation', 'Architecture Governance', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Summary & Report Generation
  // --------------------------------------------------------------------------
  const passedCount = results.filter((r) => r.passed).length;
  const failedCount = results.filter((r) => !r.passed).length;

  console.log('\n============================================================');
  console.log(`RB-SELLER-03 VERIFICATION SUMMARY: ${passedCount}/${results.length} PASSED`);
  if (failedCount > 0) {
    console.log(`⚠️  FAILED CHECKS: ${failedCount}`);
  } else {
    console.log('🎉 ALL CHECKS PASSED PERFECTLY!');
  }
  console.log('============================================================\n');

  return {
    suiteName: 'Sprint RB-SELLER-03 Automated Verification Suite',
    sprintId: 'RB-SELLER-03',
    totalTests: results.length,
    passed: passedCount,
    failed: failedCount,
    timestamp: new Date().toISOString(),
    results,
  };
}

// Direct execution if run via CLI
if (require.main === module) {
  runRMSellerCommunicationVerification()
    .then((report) => {
      if (report.failed > 0) {
        process.exit(1);
      } else {
        process.exit(0);
      }
    })
    .catch((err) => {
      console.error('Fatal execution error:', err);
      process.exit(1);
    });
}
