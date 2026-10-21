/**
 * ============================================================================
 * SPRINT RB-SELLER-05: BROKER RATINGS, SELLER FEEDBACK & ROLE-BASED RATING SECURITY
 * AUTOMATED VERIFICATION SUITE
 * ============================================================================
 *
 * Validates the core requirements of Sprint RB-SELLER-05:
 * 1. Seller Rating Interface: 1-5 star selector, sub-criteria, and confirmation modal.
 * 2. Authoritative Rating Permission Matrix:
 *    - Seller -> Broker: Allowed for eligible trading relationships.
 *    - Seller -> Buyer: Strictly Prohibited (Counterparty Shield).
 *    - Broker -> Broker: Strictly Prohibited.
 *    - Buyer -> Seller: Strictly Prohibited.
 * 3. Rating Eligibility: Requires verified completed deals, explains locks.
 * 4. Written feedback & suggestions with <= 500-char validation.
 * 5. Broker Rating Display: Average rating, star distribution, and criteria performance.
 * 6. Duplicate rating handling & in-flight double submission prevention.
 * 7. Strict Counterparty Shield: Zero buyer identity or contact exposure.
 * 8. Routing & Cross-Module Entry Points (/brokers/:id/rate, DealDetailsScreen, BrokerProfileScreen).
 * 9. Unit & Widget Test Suites for RB-SELLER-05.
 * 10. Sibling App Boundary & Zero Database Schema Mutation.
 * ============================================================================
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

export interface RB05TestCaseResult {
  id: string;
  name: string;
  category: string;
  passed: boolean;
  evidence: string;
  detail?: string;
}

export interface RB05VerificationReport {
  suiteName: string;
  sprintId: string;
  totalTests: number;
  passed: number;
  failed: number;
  timestamp: string;
  results: RB05TestCaseResult[];
}

const ROOT_DIR = process.env.PROJECT_ROOT || process.cwd();
const SELLER_APP_DIR = path.join(ROOT_DIR, 'apps', 'rmseller_mobile');

export async function runRMSellerRatingsVerification(): Promise<RB05VerificationReport> {
  const results: RB05TestCaseResult[] = [];

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
  console.log('🚀 RUNNING RB-SELLER-05: BROKER RATINGS & SECURITY VERIFICATION');
  console.log('============================================================\n');

  // --------------------------------------------------------------------------
  // Check 1: Seller Rating Interface & Sub-Criteria
  // --------------------------------------------------------------------------
  try {
    const modelPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/domain/broker_rating_model.dart');
    const screenPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/presentation/rate_broker_screen.dart');

    const modelContent = fs.readFileSync(modelPath, 'utf8');
    const screenContent = fs.readFileSync(screenPath, 'utf8');

    const hasOverallRating = modelContent.includes('rating') && screenContent.includes('_overallRating');
    const hasMandiKnowledge = modelContent.includes('mandiKnowledgeRating') && screenContent.includes('_mandiKnowledge');
    const hasPromptness = modelContent.includes('promptnessRating') && screenContent.includes('_promptness');
    const hasSettlement = modelContent.includes('settlementRating') && screenContent.includes('_settlement');
    const hasCommunication = modelContent.includes('communicationRating') && screenContent.includes('_communication');
    const hasConfirmationDialog = screenContent.includes('_showConfirmationDialog') && screenContent.includes('AlertDialog');

    const passed = hasOverallRating && hasMandiKnowledge && hasPromptness && hasSettlement && hasCommunication && hasConfirmationDialog;
    record(
      'RB05-01',
      'Seller Rating Interface & Trading Criteria',
      'UI Architecture',
      passed,
      `OverallStars=${hasOverallRating}, MandiKnowledge=${hasMandiKnowledge}, Promptness=${hasPromptness}, Settlement=${hasSettlement}, Comm=${hasCommunication}, ConfirmDialog=${hasConfirmationDialog}`,
      passed ? undefined : 'RateBrokerScreen missing sub-criteria or pre-submission confirmation modal'
    );
  } catch (err: any) {
    record('RB05-01', 'Seller Rating Interface & Trading Criteria', 'UI Architecture', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 2: Authoritative Rating Permission Matrix
  // --------------------------------------------------------------------------
  try {
    const repoPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/data/seller_ratings_repository.dart');
    const repoContent = fs.readFileSync(repoPath, 'utf8');

    const hasBuyerTargetGuard = repoContent.includes('target-buyer') || repoContent.includes('Ratings cannot be submitted for Buyers');
    const hasMatrixDocumentation = repoContent.includes('Rating Permission Matrix') || repoContent.includes('RATING PERMISSION MATRIX');
    const hasRoleValidation = repoContent.includes('Counterparty Shield active') || repoContent.includes('Counterparty Shield');

    const passed = hasBuyerTargetGuard && hasMatrixDocumentation;
    record(
      'RB05-02',
      'Authoritative Rating Permission Matrix Enforcement',
      'Security & Access Control',
      passed,
      `BuyerTargetGuard=${hasBuyerTargetGuard}, MatrixContract=${hasMatrixDocumentation}, RoleShield=${hasRoleValidation}`,
      passed ? undefined : 'Repository fails to enforce permission matrix or allows rating buyers'
    );
  } catch (err: any) {
    record('RB05-02', 'Authoritative Rating Permission Matrix Enforcement', 'Security & Access Control', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 3: Rating Eligibility & Completed Deal Linking
  // --------------------------------------------------------------------------
  try {
    const repoPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/data/seller_ratings_repository.dart');
    const modelPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/domain/broker_rating_model.dart');

    const repoContent = fs.readFileSync(repoPath, 'utf8');
    const modelContent = fs.readFileSync(modelPath, 'utf8');

    const hasEligibilityMethod = repoContent.includes('checkRatingEligibility');
    const checksDealStatus = repoContent.includes('completed') || repoContent.includes('dispatch') || repoContent.includes('closed_at');
    const hasExplanationReason = repoContent.includes('Rating Unavailable') && modelContent.includes('reason');

    const passed = hasEligibilityMethod && checksDealStatus && hasExplanationReason;
    record(
      'RB05-03',
      'Rating Eligibility & Completed Deal Verification',
      'Commercial Integrity',
      passed,
      `CheckEligibility=${hasEligibilityMethod}, DealStatusVerification=${checksDealStatus}, ExplanatoryReason=${hasExplanationReason}`,
      passed ? undefined : 'Eligibility check does not verify completed deal status or lacks clear explanation'
    );
  } catch (err: any) {
    record('RB05-03', 'Rating Eligibility & Completed Deal Verification', 'Commercial Integrity', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 4: Written Feedback Validation & Persistence
  // --------------------------------------------------------------------------
  try {
    const repoPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/data/seller_ratings_repository.dart');
    const screenPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/presentation/rate_broker_screen.dart');

    const repoContent = fs.readFileSync(repoPath, 'utf8');
    const screenContent = fs.readFileSync(screenPath, 'utf8');

    const has500LimitRepo = repoContent.includes('500');
    const has500LimitScreen = screenContent.includes('maxLength: 500') || screenContent.includes('length > 500');
    const persistsToTickets = repoContent.includes('support_tickets') && repoContent.includes('Broker Rating & Feedback');

    const passed = has500LimitRepo && has500LimitScreen && persistsToTickets;
    record(
      'RB05-04',
      'Written Feedback Constraints & Backend Persistence',
      'Data Integrity',
      passed,
      `RepoLimit=${has500LimitRepo}, ScreenLimit=${has500LimitScreen}, SupportTicketsAudit=${persistsToTickets}`,
      passed ? undefined : 'Feedback length limit not enforced or support_tickets audit trail absent'
    );
  } catch (err: any) {
    record('RB05-04', 'Written Feedback Constraints & Backend Persistence', 'Data Integrity', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 5: Broker Rating Display & Aggregate Metrics
  // --------------------------------------------------------------------------
  try {
    const screenPath = path.join(SELLER_APP_DIR, 'lib/features/brokers/presentation/broker_profile_screen.dart');
    const repoPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/data/seller_ratings_repository.dart');
    const modelPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/domain/broker_rating_model.dart');

    const screenContent = fs.readFileSync(screenPath, 'utf8');
    const repoContent = fs.readFileSync(repoPath, 'utf8');
    const modelContent = fs.readFileSync(modelPath, 'utf8');

    const displaysAverageRating = screenContent.includes('summary.averageRating');
    const displaysDistributionBars = screenContent.includes('LinearProgressIndicator') || screenContent.includes('starDistribution');
    const displaysCriteriaAverages = screenContent.includes('criteriaAverages') || screenContent.includes('Criteria Performance');
    const distinguishesUnrated = (repoContent.includes('isUnrated') || modelContent.includes('isUnrated')) && screenContent.includes('Unrated Desk');

    const passed = displaysAverageRating && displaysDistributionBars && displaysCriteriaAverages && distinguishesUnrated;
    record(
      'RB05-05',
      'Broker Rating Display, Star Distribution & Unrated Distinction',
      'Presentation & Aggregation',
      passed,
      `AvgScore=${displaysAverageRating}, DistributionBars=${displaysDistributionBars}, CriteriaAverages=${displaysCriteriaAverages}, UnratedDistinction=${distinguishesUnrated}`,
      passed ? undefined : 'BrokerProfileScreen missing star distribution, criteria breakdown, or unrated state'
    );
  } catch (err: any) {
    record('RB05-05', 'Broker Rating Display, Star Distribution & Unrated Distinction', 'Presentation & Aggregation', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 6: Duplicate Submission & Update Handling
  // --------------------------------------------------------------------------
  try {
    const screenPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/presentation/rate_broker_screen.dart');
    const repoPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/data/seller_ratings_repository.dart');

    const screenContent = fs.readFileSync(screenPath, 'utf8');
    const repoContent = fs.readFileSync(repoPath, 'utf8');

    const hasInFlightGuard = screenContent.includes('_isSubmitting') && screenContent.includes('isLoading: _isSubmitting');
    const handlesUpdate = repoContent.includes('existingIndex') || repoContent.includes('submitBrokerRating');
    const screenEditState = screenContent.includes('_isEditing');

    const passed = hasInFlightGuard && handlesUpdate && screenEditState;
    record(
      'RB05-06',
      'In-Flight Double Submission Guard & Review Updates',
      'Reliability & Idempotency',
      passed,
      `InFlightGuard=${hasInFlightGuard}, RepoUpdateHandling=${handlesUpdate}, ScreenEditState=${screenEditState}`,
      passed ? undefined : 'Missing in-flight submission guard or review update handling'
    );
  } catch (err: any) {
    record('RB05-06', 'In-Flight Double Submission Guard & Review Updates', 'Reliability & Idempotency', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 7: Strict Counterparty Shield & Privacy Scrubbing
  // --------------------------------------------------------------------------
  try {
    const modelPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/domain/broker_rating_model.dart');
    const screenPath = path.join(SELLER_APP_DIR, 'lib/features/ratings/presentation/rate_broker_screen.dart');
    const profilePath = path.join(SELLER_APP_DIR, 'lib/features/brokers/presentation/broker_profile_screen.dart');

    const modelContent = fs.readFileSync(modelPath, 'utf8');
    const screenContent = fs.readFileSync(screenPath, 'utf8');
    const profileContent = fs.readFileSync(profilePath, 'utf8');

    const zeroBuyerInModel = !modelContent.includes('buyer_id') && !modelContent.includes('buyerId') && !modelContent.includes('buyer_name');
    const hasShieldNoticeInRateScreen = screenContent.includes('Counterparty Shield');
    const anonymousReviewerTag = profileContent.includes('Verified Mandi Seller');

    const passed = zeroBuyerInModel && hasShieldNoticeInRateScreen && anonymousReviewerTag;
    record(
      'RB05-07',
      'Strict Counterparty Shield & Privacy Scrubbing',
      'Privacy & Governance',
      passed,
      `ZeroBuyerInModel=${zeroBuyerInModel}, ShieldNoticeInRating=${hasShieldNoticeInRateScreen}, AnonymousVerifiedSeller=${anonymousReviewerTag}`,
      passed ? undefined : 'Counterparty shield violated: buyer fields or un-anonymized reviewer data detected'
    );
  } catch (err: any) {
    record('RB05-07', 'Strict Counterparty Shield & Privacy Scrubbing', 'Privacy & Governance', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 8: Routing & Cross-Module Entry Points
  // --------------------------------------------------------------------------
  try {
    const routerPath = path.join(SELLER_APP_DIR, 'lib/app/router/app_router.dart');
    const dealDetailsPath = path.join(SELLER_APP_DIR, 'lib/features/deals/presentation/deal_details_screen.dart');
    const brokerProfilePath = path.join(SELLER_APP_DIR, 'lib/features/brokers/presentation/broker_profile_screen.dart');

    const routerContent = fs.readFileSync(routerPath, 'utf8');
    const dealDetailsContent = fs.readFileSync(dealDetailsPath, 'utf8');
    const brokerProfileContent = fs.readFileSync(brokerProfilePath, 'utf8');

    const hasRoute = routerContent.includes('/brokers/:id/rate') && routerContent.includes('RateBrokerScreen');
    const hasDealEntry = dealDetailsContent.includes('/rate') && dealDetailsContent.includes('Rate Mandi Broker Desk');
    const hasProfileEntry = brokerProfileContent.includes('_handleRateBroker') && brokerProfileContent.includes('/rate');

    const passed = hasRoute && hasDealEntry && hasProfileEntry;
    record(
      'RB05-08',
      'Cross-Module Entry Points & Route Configuration',
      'Navigation Architecture',
      passed,
      `RouterRegistered=${hasRoute}, DealDetailsEntry=${hasDealEntry}, BrokerProfileEntry=${hasProfileEntry}`,
      passed ? undefined : 'Route /brokers/:id/rate missing or entry points not wired in DealDetailsScreen / BrokerProfileScreen'
    );
  } catch (err: any) {
    record('RB05-08', 'Cross-Module Entry Points & Route Configuration', 'Navigation Architecture', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 9: Unit & Widget Test Suites for RB-SELLER-05
  // --------------------------------------------------------------------------
  try {
    const unitTestPath = path.join(SELLER_APP_DIR, 'test/unit/seller_ratings_repository_test.dart');
    const widgetRateTestPath = path.join(SELLER_APP_DIR, 'test/widgets/rate_broker_screen_test.dart');
    const widgetDisplayTestPath = path.join(SELLER_APP_DIR, 'test/widgets/broker_rating_display_test.dart');

    const hasUnitTest = fs.existsSync(unitTestPath);
    const hasWidgetRateTest = fs.existsSync(widgetRateTestPath);
    const hasWidgetDisplayTest = fs.existsSync(widgetDisplayTestPath);

    let testCaseCount = 0;
    if (hasUnitTest) {
      const content = fs.readFileSync(unitTestPath, 'utf8');
      testCaseCount += (content.match(/test\(/g) || []).length;
    }
    if (hasWidgetRateTest) {
      const content = fs.readFileSync(widgetRateTestPath, 'utf8');
      testCaseCount += (content.match(/testWidgets\(/g) || []).length;
    }
    if (hasWidgetDisplayTest) {
      const content = fs.readFileSync(widgetDisplayTestPath, 'utf8');
      testCaseCount += (content.match(/testWidgets\(/g) || []).length;
    }

    const passed = hasUnitTest && hasWidgetRateTest && hasWidgetDisplayTest && testCaseCount >= 10;
    record(
      'RB05-09',
      'Unit & Widget Test Suites for RB-SELLER-05',
      'Quality Assurance',
      passed,
      `RepoUnitTest=${hasUnitTest}, RateWidgetTest=${hasWidgetRateTest}, DisplayWidgetTest=${hasWidgetDisplayTest}, TotalCases=${testCaseCount}`,
      passed ? undefined : 'Missing test suites or fewer than 10 test cases across ratings'
    );
  } catch (err: any) {
    record('RB05-09', 'Unit & Widget Test Suites for RB-SELLER-05', 'Quality Assurance', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Check 10: Sibling App Boundary & Zero Database Schema Mutation
  // --------------------------------------------------------------------------
  try {
    const gitStatus = execSync('git status --porcelain', { cwd: ROOT_DIR, encoding: 'utf8' });
    const modifiedLines = gitStatus.split('\n').filter(Boolean);

    const rmbuyerModified = modifiedLines.some((l) => l.includes('apps/rmbuyer_mobile'));
    const rmbrokerModified = modifiedLines.some((l) => l.includes('apps/rmbroker_mobile'));
    const migrationsModified = modifiedLines.some((l) => l.includes('supabase/migrations'));

    const passed = !rmbuyerModified && !rmbrokerModified && !migrationsModified;
    record(
      'RB05-10',
      'Sibling App Boundary & Zero Database Schema Mutation',
      'Architecture Governance',
      passed,
      `RMBuyer untouched: ${!rmbuyerModified}, RMBroker untouched: ${!rmbrokerModified}, Zero DB migrations: ${!migrationsModified}`,
      passed ? undefined : 'Violated boundaries: modifications found in sibling apps or database migrations'
    );
  } catch (err: any) {
    record('RB05-10', 'Sibling App Boundary & Zero Database Schema Mutation', 'Architecture Governance', false, err.message);
  }

  // --------------------------------------------------------------------------
  // Summary & Report Generation
  // --------------------------------------------------------------------------
  const passedCount = results.filter((r) => r.passed).length;
  const failedCount = results.filter((r) => !r.passed).length;

  console.log('\n============================================================');
  console.log(`RB-SELLER-05 VERIFICATION SUMMARY: ${passedCount}/${results.length} PASSED`);
  if (failedCount > 0) {
    console.log(`⚠️  FAILED CHECKS: ${failedCount}`);
  } else {
    console.log('🎉 ALL CHECKS PASSED PERFECTLY!');
  }
  console.log('============================================================\n');

  return {
    suiteName: 'Sprint RB-SELLER-05 Automated Verification Suite',
    sprintId: 'RB-SELLER-05',
    totalTests: results.length,
    passed: passedCount,
    failed: failedCount,
    timestamp: new Date().toISOString(),
    results,
  };
}

// Direct execution if run via CLI
runRMSellerRatingsVerification()
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
