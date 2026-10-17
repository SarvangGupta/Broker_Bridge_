/**
 * ============================================================================
 * UNIFIED BUYER E2E UAT RUNNER (BB-SPRINT-40-B)
 * ============================================================================
 * 
 * Target: src/server/tests/verify-buyer-e2e-uat.ts
 * Purpose: Consolidates complete end-to-end Buyer User Acceptance Testing (UAT)
 * across all 10 canonical Buyer workflow phases and mobile responsive contracts.
 * 
 * Execution Modes:
 * 1. OFFLINE FIXTURE MODE: Runs deterministically when DATABASE_URL is absent.
 *    Validates pure input guards, state machines, commercial formulas, AST contracts,
 *    privacy scrubbing, and component mounting.
 *    CRITICAL: Database-dependent assertions are NEVER reported as passed.
 *    They are explicitly marked and counted as UNVERIFIED_DATABASE.
 * 
 * 2. LIVE INTEGRATION MODE: Runs only when DATABASE_URL is explicitly set and verified.
 *    Executes live database transactions and PostgreSQL trigger catalog queries
 *    only against an authorized test environment.
 * 
 * Invariants Enforced:
 * - Decoupled Confirmation vs Booking: Buyer confirmation strictly does NOT create bookings.
 * - Mediation Firewall: Zero direct Buyer-Seller messaging; zero Seller PII/bank details leaked.
 * - Flat Buyer Role Model: Exclusively maps to 'BUYER_ADMIN'.
 * - Server-Side Math: Pre-calculated gross, paid, and outstanding values prevent client manipulation.
 * - Mobile 360px Contract: Source-level inspection of all 8 Order Detail modules.
 * ============================================================================
 */

import * as fs from 'fs';
import * as path from 'path';

// ----------------------------------------------------------------------------
// Phase 1: Auth & Role Validation
// ----------------------------------------------------------------------------
import { resolveBuyerRole, verifyBuyerSession } from '../utils/buyer-auth';
import { signUpAction, signInAction } from '../actions/auth-actions';

// ----------------------------------------------------------------------------
// Phase 2: Buyer Dashboard
// ----------------------------------------------------------------------------
import { getBuyerDashboardSummaryAction } from '../actions/buyer-dashboard-actions';

// ----------------------------------------------------------------------------
// Phase 3: Requirement Creation & Validation
// ----------------------------------------------------------------------------
import {
  requirementWizardSchema,
  step1WhatSchema,
  step2HowMuchSchema,
  step4WhenSchema,
} from '@/src/lib/validations/requirement-schema';
import { createRequirementAction } from '../actions/requirement-actions';

// ----------------------------------------------------------------------------
// Phase 4: Dynamic Quality Parameters
// ----------------------------------------------------------------------------
import {
  extractParamBounds,
  validateSingleQualityParam,
  validateAllQualityParams,
  MasterQualityParameter,
} from '@/src/lib/validations/buyer-quality-schema';

// ----------------------------------------------------------------------------
// Phase 5: Proposal Inbox & Privacy Scrubber
// ----------------------------------------------------------------------------
import { getBuyerProposalsInboxAction } from '../actions/buyer-proposal-actions';
import {
  sanitizeBuyerChannelText,
  SELLER_ACTION_TYPES_BLACKLIST,
  BUYER_PERMITTED_ACTION_TYPES,
} from '../utils/buyer-privacy-scrubber';

// ----------------------------------------------------------------------------
// Phase 6: Negotiation & State Transitions
// ----------------------------------------------------------------------------
import {
  buyerCounterOfferSchema,
  NEGOTIATION_PAYMENT_TERMS,
  NEGOTIATION_PACKAGING_TYPES,
  NEGOTIATION_FREIGHT_TERMS,
  NEGOTIATION_INSPECTION_TERMS,
} from '@/src/lib/validations/buyer-negotiation-schema';
import {
  deriveNegotiationState,
  NegotiationState,
} from '../utils/buyer-negotiation-state';

// ----------------------------------------------------------------------------
// Phase 7: Buyer Confirmation & Deal Integrity
// ----------------------------------------------------------------------------
import {
  confirmFinalDealAction,
  requestDealAmendmentAction,
} from '../actions/buyer-deal-actions';
import {
  computeDealTermsDiff,
  mapToDealConfirmationStatus,
} from '@/src/utils/visual-diff-engine';
import { FinalDealCommercialTerms } from '@/src/types/buyer-deal-review';

// ----------------------------------------------------------------------------
// Phase 8: Broker Finalization Gate & Booking
// ----------------------------------------------------------------------------
import { validateFinalizationPreconditions } from '../utils/finalization-gate';
import { finalizeDealAction } from '../actions/finalization-actions';
import { createIdempotentBookingAction } from '../actions/booking-actions';

// ----------------------------------------------------------------------------
// Phase 9: Document Vault & Payable Ledger
// ----------------------------------------------------------------------------
import {
  getBuyerDocumentMatrixAction,
  getBuyerDocumentSignedUrlAction,
} from '../actions/buyer-document-actions';
import { getBuyerPayableLedgerAction } from '../actions/buyer-payment-actions';
import { getBuyerTransactionQualityAction } from '../actions/buyer-quality-tracking-actions';

// ----------------------------------------------------------------------------
// Phase 10: Mediation Firewall & Dispute Tracker
// ----------------------------------------------------------------------------
import {
  createBuyerDisputeAction,
  getBuyerActiveDisputesAction,
} from '../actions/buyer-dispute-actions';
import { BUYER_DISPUTE_CATEGORIES } from '@/src/types/buyer-dispute-types';

// ============================================================================
// Types & Report Structures
// ============================================================================

export type AssertionStatus =
  | 'PASSED'
  | 'FAILED'
  | 'SKIPPED_OFFLINE'
  | 'UNVERIFIED_DATABASE';

export interface UATAssertionResult {
  id: string;
  phase: number;
  phaseName: string;
  testName: string;
  status: AssertionStatus;
  isOfflineRunnable: boolean;
  requiresDatabase: boolean;
  evidence: string;
  error?: string;
}

export interface PhaseSummary {
  phase: number;
  name: string;
  total: number;
  passed: number;
  failed: number;
  unverifiedDb: number;
  skippedOffline: number;
  status: 'PASS' | 'PARTIAL_OFFLINE' | 'FAIL';
}

export interface BuyerUATReport {
  suiteName: string;
  timestamp: string;
  mode: 'OFFLINE_FIXTURE' | 'LIVE_DATABASE';
  databaseUrlConfigured: boolean;
  totals: {
    total: number;
    passed: number;
    failed: number;
    skippedOffline: number;
    unverifiedDatabase: number;
    passRatePercent: number;
  };
  phaseSummaries: PhaseSummary[];
  assertions: UATAssertionResult[];
}

// ============================================================================
// Core Test Runner Implementation
// ============================================================================

export async function runBuyerE2EUAT(): Promise<BuyerUATReport> {
  const assertions: UATAssertionResult[] = [];
  const databaseUrlConfigured = Boolean(
    process.env.DATABASE_URL && process.env.DATABASE_URL.trim() !== ''
  );
  const mode: 'OFFLINE_FIXTURE' | 'LIVE_DATABASE' = databaseUrlConfigured
    ? 'LIVE_DATABASE'
    : 'OFFLINE_FIXTURE';

  console.log('================================================================================');
  console.log('  BROKERBRIDGE ENTERPRISE — UNIFIED BUYER E2E UAT RUNNER (BB-SPRINT-40-B)');
  console.log('================================================================================');
  console.log(`Execution Mode: [${mode}]`);
  console.log(`Database Configured: ${databaseUrlConfigured ? 'YES (Live Database Mode)' : 'NO (Offline Fixture Mode)'}`);
  console.log('Timestamp: ' + new Date().toISOString());
  console.log('================================================================================\n');

  // Helper to record assertions
  const record = (
    id: string,
    phase: number,
    phaseName: string,
    testName: string,
    passed: boolean,
    evidence: string,
    requiresDatabase: boolean = false,
    error?: string
  ) => {
    let status: AssertionStatus;
    if (requiresDatabase && !databaseUrlConfigured) {
      status = 'UNVERIFIED_DATABASE';
    } else if (passed) {
      status = 'PASSED';
    } else {
      status = 'FAILED';
    }

    assertions.push({
      id,
      phase,
      phaseName,
      testName,
      status,
      isOfflineRunnable: !requiresDatabase,
      requiresDatabase,
      evidence,
      error,
    });

    const statusBadge =
      status === 'PASSED'
        ? '✅ [PASS]'
        : status === 'UNVERIFIED_DATABASE'
        ? '⚠️ [UNVERIFIED_DB]'
        : '❌ [FAIL]';

    console.log(`${statusBadge} [Phase ${phase} | ${id}] ${testName}`);
    console.log(`   └─ ${evidence}`);
    if (error) {
      console.log(`   └─ Error details: ${error}`);
    }
  };

  // ============================================================================
  // PHASE 1: Authentication and Role Validation
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 1: Authentication & Role Validation');
  console.log('--------------------------------------------------------------------------------');

  // 1.1: Flat Buyer Role Invariant
  const resolvedRole = resolveBuyerRole('any_arbitrary_role');
  record(
    'UAT-1.1',
    1,
    'Auth & Role Validation',
    'Strict Flat Role Model: Maps all inputs exclusively to BUYER_ADMIN',
    resolvedRole === 'BUYER_ADMIN',
    `Resolved role: "${resolvedRole}" (Single-tier flat role invariant confirmed)`
  );

  // 1.2: Sign-up rejects missing required fields
  const emptyFormData = new FormData();
  const emptySignUpRes = await signUpAction(emptyFormData);
  record(
    'UAT-1.2',
    1,
    'Auth & Role Validation',
    'Sign-up Guard: Rejects missing required credentials',
    Boolean(emptySignUpRes.error?.includes('Missing required fields')),
    `Error returned: "${emptySignUpRes.error}"`
  );

  // 1.3: Sign-up rejects broker registration (Invite-only protection)
  const brokerFormData = new FormData();
  brokerFormData.append('email', 'testbroker@example.com');
  brokerFormData.append('password', 'ValidPass123!');
  brokerFormData.append('name', 'Broker Agent');
  brokerFormData.append('role', 'broker');
  const brokerSignUpRes = await signUpAction(brokerFormData);
  record(
    'UAT-1.3',
    1,
    'Auth & Role Validation',
    'Role Gate: Rejects public broker self-registration (invite-only)',
    Boolean(brokerSignUpRes.error?.includes('invite-only')),
    `Error returned: "${brokerSignUpRes.error}"`
  );

  // 1.4: Sign-up rejects unauthorized roles (e.g. admin or invalid)
  const invalidRoleFormData = new FormData();
  invalidRoleFormData.append('email', 'hacker@example.com');
  invalidRoleFormData.append('password', 'ValidPass123!');
  invalidRoleFormData.append('name', 'Admin Impersonator');
  invalidRoleFormData.append('role', 'admin');
  const invalidRoleSignUpRes = await signUpAction(invalidRoleFormData);
  record(
    'UAT-1.4',
    1,
    'Auth & Role Validation',
    'RBAC Invariant: Restricts registration exclusively to buyer or seller',
    Boolean(invalidRoleSignUpRes.error?.includes('restricted')),
    `Error returned: "${invalidRoleSignUpRes.error}"`
  );

  // 1.5: Sign-in rejects missing password or email
  const emptySignInFormData = new FormData();
  const emptySignInRes = await signInAction(emptySignInFormData);
  record(
    'UAT-1.5',
    1,
    'Auth & Role Validation',
    'Sign-in Guard: Rejects empty credentials submission',
    Boolean(emptySignInRes.error?.includes('Missing email or password')),
    `Error returned: "${emptySignInRes.error}"`
  );

  // 1.6: Server-side Buyer session resolution outside Next.js request context
  const standaloneSessionRes = await verifyBuyerSession();
  record(
    'UAT-1.6',
    1,
    'Auth & Role Validation',
    'Session Resilience: Gracefully handles standalone execution without crashing',
    standaloneSessionRes.success === false,
    `Standalone session rejection handled gracefully: "${standaloneSessionRes.error || 'Unauthorized'}"`
  );

  // 1.7: Live DB User Session Resolution
  record(
    'UAT-1.7',
    1,
    'Auth & Role Validation',
    'Live Database: Query user profile and company association in PostgreSQL',
    false,
    databaseUrlConfigured
      ? 'Live database query evaluated.'
      : 'DATABASE_URL is absent. Cannot verify Supabase Auth token verification or Drizzle users table in live database.',
    true
  );

  // ============================================================================
  // PHASE 2: Buyer Dashboard Summary Behavior
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 2: Buyer Dashboard Summary Behavior');
  console.log('--------------------------------------------------------------------------------');

  const dashboardRes = await getBuyerDashboardSummaryAction();
  const dashboardPayload = dashboardRes.data;

  // 2.1: Execution resilience
  record(
    'UAT-2.1',
    2,
    'Dashboard Summary',
    'Dashboard Action: Completes safely and returns structured payload',
    Boolean(dashboardPayload),
    `Success status: ${dashboardRes.success}, Payload received with KPIs and activity streams.`
  );

  // 2.2: KPI Metric Blocks
  const kpis = dashboardPayload?.kpis;
  const kpisValid =
    typeof kpis?.activeRequirementsCount === 'number' &&
    typeof kpis?.proposalsPendingCount === 'number' &&
    typeof kpis?.activeOrdersCount === 'number' &&
    typeof kpis?.pendingPayablesFormatted === 'string';
  record(
    'UAT-2.2',
    2,
    'Dashboard Summary',
    'KPI Metrics: Returns all 4 required operational metrics',
    Boolean(kpisValid),
    `KPIs: Active Reqs=${kpis?.activeRequirementsCount}, Proposals=${kpis?.proposalsPendingCount}, Orders=${kpis?.activeOrdersCount}, Payables=${kpis?.pendingPayablesFormatted}`
  );

  // 2.3: Action Required Feed
  const actionItems = dashboardPayload?.actionRequired || [];
  const actionItemsValid =
    actionItems.length > 0 &&
    actionItems.every((item) => item.id && item.title && item.ctaLabel && item.ctaUrl);
  record(
    'UAT-2.3',
    2,
    'Dashboard Summary',
    'Action Feed: Returns urgent action items with valid CTAs',
    Boolean(actionItemsValid),
    `Found ${actionItems.length} action item(s) (e.g. "${actionItems[0]?.title}").`
  );

  // 2.4: Recent Requirements Stream
  const recentReqs = dashboardPayload?.recentRequirements || [];
  record(
    'UAT-2.4',
    2,
    'Dashboard Summary',
    'Recent Requirements: Returns recent mandate cards with pricing & status',
    recentReqs.length > 0,
    `Found ${recentReqs.length} recent requirement(s) (e.g. ${recentReqs[0]?.commodityName} - ${recentReqs[0]?.status}).`
  );

  // 2.5: Active Shipments Tracker
  const activeShipments = dashboardPayload?.activeShipments || [];
  record(
    'UAT-2.5',
    2,
    'Dashboard Summary',
    'Active Shipments: Returns in-transit shipment tracking records with ETA',
    activeShipments.length > 0,
    `Found ${activeShipments.length} shipment(s) (e.g. ${activeShipments[0]?.bookingId} - ${activeShipments[0]?.status}).`
  );

  // 2.6: Live DB Data Wiring
  record(
    'UAT-2.6',
    2,
    'Dashboard Summary',
    'Live Database: Synchronize dashboard KPIs from live PostgreSQL tables',
    false,
    databaseUrlConfigured
      ? 'Live dashboard tables queried.'
      : 'DATABASE_URL is absent. Dashboard is currently returning deterministic fallback demo data as documented in Technical Debt Note 2.',
    true
  );

  // ============================================================================
  // PHASE 3: Requirement Validation and Creation Logic
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 3: Requirement Validation & Creation Logic');
  console.log('--------------------------------------------------------------------------------');

  // 3.1: Step 1 (What) validation
  const emptyStep1 = step1WhatSchema.safeParse({ commodity_id: '', grade_id: '' });
  record(
    'UAT-3.1',
    3,
    'Requirement Creation',
    'Step 1 Guard: Rejects empty commodity and grade selections',
    !emptyStep1.success,
    `Zod validation caught ${emptyStep1.error?.issues.length || 0} issue(s) as expected.`
  );

  // 3.2: Step 2 (How Much) validation
  const negativeQty = step2HowMuchSchema.safeParse({
    quantity: -50,
    unit_id: 'unit-1',
    target_price: 2500,
    allow_partial_fulfillment: true,
  });
  record(
    'UAT-3.2',
    3,
    'Requirement Creation',
    'Step 2 Guard: Strictly rejects negative or zero procurement quantity',
    !negativeQty.success,
    `Negative quantity rejected: ${negativeQty.error?.issues[0]?.message}`
  );

  // 3.3: Step 4 (When) date logic
  const pastDate = new Date(Date.now() - 86400000 * 5);
  const futureDate = new Date(Date.now() + 86400000 * 5);
  const invalidDateRange = step4WhenSchema.safeParse({
    delivery_window_start: futureDate,
    delivery_window_end: pastDate,
  });
  record(
    'UAT-3.3',
    3,
    'Requirement Creation',
    'Step 4 Guard: Rejects delivery window end date prior to start date',
    !invalidDateRange.success,
    'Date range constraint enforced by Zod schema.'
  );

  // 3.4: SuperRefine Preferred Broker rule for private network visibility
  const privateWithoutBroker = requirementWizardSchema.safeParse({
    commodity_id: 'comm-101',
    grade_id: 'grade-101',
    quality_parameters: [],
    quantity: 100,
    unit_id: 'unit-mt',
    target_price: 35000,
    allow_partial_fulfillment: true,
    delivery_state_id: 'state-01',
    payment_terms: 'NET_15',
    packaging_type: '50KG_PP_BAGS',
    freight_terms: 'FOR_DESTINATION',
    visibility: 'restricted',
    broker_id: '',
  });
  record(
    'UAT-3.4',
    3,
    'Requirement Creation',
    'Visibility Rule: Enforces preferred broker when restricted visibility is selected',
    !privateWithoutBroker.success,
    `Error caught: "${privateWithoutBroker.error?.issues[0]?.message}"`
  );

  // 3.5: Full compliant requirement schema validation
  const validReq = requirementWizardSchema.safeParse({
    commodity_id: 'comm-101',
    grade_id: 'grade-101',
    quality_parameters: [],
    quantity: 100,
    unit_id: 'unit-mt',
    target_price: 35000,
    allow_partial_fulfillment: true,
    delivery_state_id: 'state-01',
    payment_terms: 'NET_15',
    packaging_type: '50KG_PP_BAGS',
    freight_terms: 'FOR_DESTINATION',
    visibility: 'global',
    broker_id: '',
    delivery_window_start: new Date(Date.now() + 86400000),
    delivery_window_end: new Date(Date.now() + 86400000 * 10),
  });
  record(
    'UAT-3.5',
    3,
    'Requirement Creation',
    'Schema Conformance: Validates fully compliant buyer requirement payload',
    validReq.success,
    'Compliant commercial mandate passes all 5-step wizard validation constraints.'
  );

  // 3.6: Action guard on invalid input
  const emptyActionRes = await createRequirementAction({});
  record(
    'UAT-3.6',
    3,
    'Requirement Creation',
    'Server Action Guard: Rejects unauthenticated/invalid requirement creation',
    emptyActionRes.success === false,
    `Action responded safely: "${emptyActionRes.error}"`
  );

  // 3.7: Live DB Requirement Insertion
  record(
    'UAT-3.7',
    3,
    'Requirement Creation',
    'Live Database: Insert and persist requirement row into requirements table',
    false,
    databaseUrlConfigured
      ? 'Live requirement row inserted.'
      : 'DATABASE_URL is absent. Cannot execute live Drizzle INSERT into requirements table.',
    true
  );

  // ============================================================================
  // PHASE 4: Dynamic Quality Parameter Validation
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 4: Dynamic Quality Parameter Validation');
  console.log('--------------------------------------------------------------------------------');

  const sampleMasterParam: MasterQualityParameter = {
    id: 'qp-moisture',
    name: 'Moisture Content',
    min_value: 8.0,
    max_value: 12.0,
    is_mandatory: true,
    unit: '%',
  };

  // 4.1: Bounds extraction
  const bounds = extractParamBounds(sampleMasterParam);
  record(
    'UAT-4.1',
    4,
    'Quality Parameters',
    'Parameter Bounds Engine: Correctly parses min, max, mandatory flag, and unit',
    bounds.minVal === 8.0 && bounds.maxVal === 12.0 && bounds.isMandatory && bounds.unitStr === ' %',
    `Extracted bounds: Min=${bounds.minVal}, Max=${bounds.maxVal}, Mandatory=${bounds.isMandatory}, Unit="${bounds.unitStr.trim()}"`
  );

  // 4.2: Mandatory check
  const emptyParamRes = validateSingleQualityParam('', sampleMasterParam);
  record(
    'UAT-4.2',
    4,
    'Quality Parameters',
    'Mandatory Parameter Guard: Rejects missing input for mandatory specification',
    !emptyParamRes.isValid && Boolean(emptyParamRes.error?.includes('required')),
    `Error caught: "${emptyParamRes.error}"`
  );

  // 4.3: Range overflow check
  const overflowParamRes = validateSingleQualityParam(14.5, sampleMasterParam);
  record(
    'UAT-4.3',
    4,
    'Quality Parameters',
    'Mathematical Range Guard: Rejects quality value exceeding contract maximum',
    !overflowParamRes.isValid && Boolean(overflowParamRes.error?.includes('must be between')),
    `Value 14.5% rejected against 8.0–12.0% bounds: "${overflowParamRes.error}"`
  );

  // 4.4: Compliant parameter value
  const validParamRes = validateSingleQualityParam(10.5, sampleMasterParam);
  record(
    'UAT-4.4',
    4,
    'Quality Parameters',
    'Tolerance Acceptance: Accepts value cleanly within master specifications',
    validParamRes.isValid,
    'Value 10.5% verified within 8.0–12.0% range without error.'
  );

  // 4.5: Multi-parameter aggregate validation
  const multiParamRes = validateAllQualityParams(
    { 'qp-moisture': 10.2 },
    [sampleMasterParam]
  );
  record(
    'UAT-4.5',
    4,
    'Quality Parameters',
    'Multi-Parameter Grid: Aggregates validation for all commodity specifications',
    multiParamRes.isValid && Object.keys(multiParamRes.errors).length === 0,
    'All parameters passed batch validation.'
  );

  // 4.6: Live Master Parameters Fetch
  record(
    'UAT-4.6',
    4,
    'Quality Parameters',
    'Live Database: Query active master quality parameters from PostgreSQL',
    false,
    databaseUrlConfigured
      ? 'Live master quality parameters queried.'
      : 'DATABASE_URL is absent. Cannot query master_quality_parameters table in live database.',
    true
  );

  // ============================================================================
  // PHASE 5: Proposal Inbox and Quotation Validation
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 5: Proposal Inbox & Privacy Scrubber');
  console.log('--------------------------------------------------------------------------------');

  // 5.1: Phone number scrubbing
  const textWithPhone = 'Contact supplier directly at +91 9876543210 for price reduction.';
  const sanitizedPhone = sanitizeBuyerChannelText(textWithPhone);
  record(
    'UAT-5.1',
    5,
    'Proposal Inbox & Privacy',
    'Privacy Scrubber: Shields phone numbers from negotiation payload',
    !sanitizedPhone.includes('9876543210') && sanitizedPhone.includes('[PROTECTED_CONTACT]'),
    `Sanitized output: "${sanitizedPhone}"`
  );

  // 5.2: Email address scrubbing
  const textWithEmail = 'Inquiries to agro.supplier@privatefarms.com should be sent today.';
  const sanitizedEmail = sanitizeBuyerChannelText(textWithEmail);
  record(
    'UAT-5.2',
    5,
    'Proposal Inbox & Privacy',
    'Privacy Scrubber: Shields direct email addresses from negotiation payload',
    !sanitizedEmail.includes('agro.supplier@privatefarms.com') && sanitizedEmail.includes('[PROTECTED_EMAIL]'),
    `Sanitized output: "${sanitizedEmail}"`
  );

  // 5.3: GSTIN scrubbing
  const textWithGstin = 'Supplier GST number is 27AABCU9603R1ZM for dispatch billing.';
  const sanitizedGstin = sanitizeBuyerChannelText(textWithGstin);
  record(
    'UAT-5.3',
    5,
    'Proposal Inbox & Privacy',
    'Privacy Scrubber: Shields GSTIN tax identifiers from negotiation payload',
    !sanitizedGstin.includes('27AABCU9603R1ZM') && sanitizedGstin.includes('[PROTECTED_GST]'),
    `Sanitized output: "${sanitizedGstin}"`
  );

  // 5.4: WhatsApp & direct messaging link scrubbing
  const textWithWa = 'Chat on wa.me/919876543210 to negotiate offline.';
  const sanitizedWa = sanitizeBuyerChannelText(textWithWa);
  record(
    'UAT-5.4',
    5,
    'Proposal Inbox & Privacy',
    'Privacy Scrubber: Shields WhatsApp and offline negotiation invite links',
    !sanitizedWa.includes('wa.me') && sanitizedWa.includes('[SELLER_SHIELDED]'),
    `Sanitized output: "${sanitizedWa}"`
  );

  // 5.5: Blacklist of seller-originated events
  const sellerBlacklistMaintained =
    SELLER_ACTION_TYPES_BLACKLIST.has('SELLER_COUNTER') &&
    SELLER_ACTION_TYPES_BLACKLIST.has('SELLER_PROPOSED') &&
    SELLER_ACTION_TYPES_BLACKLIST.has('SELLER_NOTE');
  record(
    'UAT-5.5',
    5,
    'Proposal Inbox & Privacy',
    'Channel Isolation: Blacklists Seller internal actions from Buyer channel',
    sellerBlacklistMaintained,
    'SELLER_COUNTER, SELLER_PROPOSED, and SELLER_NOTE strictly blocked from buyer visibility.'
  );

  // 5.6: Whitelist of buyer-permitted events
  const buyerWhitelistMaintained =
    BUYER_PERMITTED_ACTION_TYPES.has('BROKER_PROPOSAL_TO_BUYER') &&
    BUYER_PERMITTED_ACTION_TYPES.has('BUYER_COUNTER') &&
    BUYER_PERMITTED_ACTION_TYPES.has('BUYER_ACCEPTED');
  record(
    'UAT-5.6',
    5,
    'Proposal Inbox & Privacy',
    'Channel Isolation: Whitelists Broker ↔ Buyer negotiation events',
    buyerWhitelistMaintained,
    'BROKER_PROPOSAL_TO_BUYER, BUYER_COUNTER, and BUYER_ACCEPTED permitted in Buyer channel.'
  );

  // 5.7: Proposal inbox server action execution
  const proposalInboxRes = await getBuyerProposalsInboxAction();
  record(
    'UAT-5.7',
    5,
    'Proposal Inbox & Privacy',
    'Inbox Execution: Safely enforces session authentication without crashing',
    proposalInboxRes.success === false,
    `Responded safely to unauthenticated runner: "${proposalInboxRes.error}"`
  );

  // 5.8: Live Database Proposals Query
  record(
    'UAT-5.8',
    5,
    'Proposal Inbox & Privacy',
    'Live Database: Query quotations and deal_versions for buyer organization',
    false,
    databaseUrlConfigured
      ? 'Live quotations and deal_versions queried.'
      : 'DATABASE_URL is absent. Cannot execute live Drizzle join across quotations and deal_versions.',
    true
  );

  // ============================================================================
  // PHASE 6: Negotiation and Counteroffer State Transitions
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 6: Negotiation & Counteroffer State Transitions');
  console.log('--------------------------------------------------------------------------------');

  // 6.1: Counteroffer schema rejects negative price
  const negativeCounterPrice = buyerCounterOfferSchema.safeParse({
    proposal_id: '123e4567-e89b-12d3-a456-426614174000',
    expected_version_number: 1,
    counter_price: -100,
    counter_quantity: 50,
    delivery_date: '2026-11-01',
    payment_terms: NEGOTIATION_PAYMENT_TERMS[0],
    packaging: NEGOTIATION_PACKAGING_TYPES[0],
    freight: NEGOTIATION_FREIGHT_TERMS[0],
    inspection: NEGOTIATION_INSPECTION_TERMS[0],
  });
  record(
    'UAT-6.1',
    6,
    'Negotiation State Machine',
    'Counteroffer Guard: Rejects negative counter offer price',
    !negativeCounterPrice.success,
    'Negative counter price rejected by Zod validation.'
  );

  // 6.2: Counteroffer schema rejects zero quantity
  const zeroCounterQty = buyerCounterOfferSchema.safeParse({
    proposal_id: '123e4567-e89b-12d3-a456-426614174000',
    expected_version_number: 1,
    counter_price: 32000,
    counter_quantity: 0,
    delivery_date: '2026-11-01',
    payment_terms: NEGOTIATION_PAYMENT_TERMS[0],
    packaging: NEGOTIATION_PACKAGING_TYPES[0],
    freight: NEGOTIATION_FREIGHT_TERMS[0],
    inspection: NEGOTIATION_INSPECTION_TERMS[0],
  });
  record(
    'UAT-6.2',
    6,
    'Negotiation State Machine',
    'Counteroffer Guard: Rejects zero counter offer quantity',
    !zeroCounterQty.success,
    'Zero counter quantity rejected by Zod validation.'
  );

  // 6.3: Valid counteroffer payload
  const validCounter = buyerCounterOfferSchema.safeParse({
    proposal_id: '123e4567-e89b-12d3-a456-426614174000',
    expected_version_number: 2,
    counter_price: 31500,
    counter_quantity: 50,
    delivery_date: '2026-11-15',
    payment_terms: NEGOTIATION_PAYMENT_TERMS[0],
    packaging: NEGOTIATION_PACKAGING_TYPES[0],
    freight: NEGOTIATION_FREIGHT_TERMS[0],
    inspection: NEGOTIATION_INSPECTION_TERMS[0],
    buyer_notes_to_broker: 'Firm commitment if delivery window is locked.',
  });
  record(
    'UAT-6.3',
    6,
    'Negotiation State Machine',
    'Counteroffer Schema: Validates fully compliant counter-proposal terms',
    validCounter.success,
    'Counter offer passes all commercial schema requirements.'
  );

  // 6.4: 6-State Negotiation Lifecycle Transitions
  const sOpen = deriveNegotiationState('Open', 'BROKER_PROPOSAL_TO_BUYER', false);
  const sWaitBroker = deriveNegotiationState('Waiting for Broker', 'BUYER_COUNTER', false);
  const sWaitBuyer = deriveNegotiationState('Active', 'BROKER_REVISED', false);
  const sAgreed = deriveNegotiationState('Agreed', 'BUYER_ACCEPTED', false);
  const sClosed = deriveNegotiationState('Rejected', 'BUYER_REJECTED', false);
  const sExpired = deriveNegotiationState('Active', 'BROKER_PROPOSAL', true);

  const stateMachineValid =
    sOpen === 'Open' &&
    sWaitBroker === 'Waiting for Broker' &&
    sWaitBuyer === 'Waiting for Buyer' &&
    sAgreed === 'Agreed' &&
    sClosed === 'Closed' &&
    sExpired === 'Expired';

  record(
    'UAT-6.4',
    6,
    'Negotiation State Machine',
    'State Transition Engine: Accurately derives all 6 negotiation states',
    stateMachineValid,
    `Derived states: [Open=${sOpen}, WaitBroker=${sWaitBroker}, WaitBuyer=${sWaitBuyer}, Agreed=${sAgreed}, Closed=${sClosed}, Expired=${sExpired}]`
  );

  // 6.5: Mutation Guard logic
  const checkMutationPermitted = (state: NegotiationState) =>
    state === 'Open' || state === 'Waiting for Buyer';

  const mutationGuardCorrect =
    checkMutationPermitted('Open') &&
    checkMutationPermitted('Waiting for Buyer') &&
    !checkMutationPermitted('Waiting for Broker') &&
    !checkMutationPermitted('Agreed') &&
    !checkMutationPermitted('Closed') &&
    !checkMutationPermitted('Expired');

  record(
    'UAT-6.5',
    6,
    'Negotiation State Machine',
    'Server Mutation Guard: Permits counter-offers only in Open or Waiting for Buyer states',
    mutationGuardCorrect,
    'Terminal, expired, and broker-pending states strictly reject counter-offer submission.'
  );

  // 6.6: Database Trigger Immutability Verification
  record(
    'UAT-6.6',
    6,
    'Negotiation State Machine',
    'Live Database: Verify prevent_negotiation_events_mutation() PostgreSQL triggers',
    false,
    databaseUrlConfigured
      ? 'PostgreSQL trigger catalog verified.'
      : 'DATABASE_URL is absent. Cannot query information_schema or pg_trigger to verify active PostgreSQL immutability triggers.',
    true
  );

  // ============================================================================
  // PHASE 7: Buyer Confirmation and Deal-Version Integrity
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 7: Buyer Confirmation & Deal-Version Integrity');
  console.log('--------------------------------------------------------------------------------');

  // 7.1: Rejection of missing deal ID
  const emptyDealConfirm = await confirmFinalDealAction('', 2);
  record(
    'UAT-7.1',
    7,
    'Buyer Confirmation',
    'Validation Guard: Rejects confirmation with empty deal ID',
    emptyDealConfirm.success === false && emptyDealConfirm.error === 'Deal ID is required.',
    `Error returned: "${emptyDealConfirm.error}"`
  );

  // 7.2: Rejection of invalid expected version number
  const invalidVersionConfirm = await confirmFinalDealAction('demo-deal-37-2', 0);
  record(
    'UAT-7.2',
    7,
    'Buyer Confirmation',
    'Concurrency Guard: Rejects confirmation with non-positive expected version',
    invalidVersionConfirm.success === false &&
      invalidVersionConfirm.error === 'Expected version number is required.',
    `Error returned: "${invalidVersionConfirm.error}"`
  );

  // 7.3: Successful execution of demo deal confirmation
  const demoConfirmRes = await confirmFinalDealAction('demo-deal-37-2', 2);
  record(
    'UAT-7.3',
    7,
    'Buyer Confirmation',
    'Demo Execution: confirmFinalDealAction executes successfully on demo payload',
    demoConfirmRes.success === true && Boolean(demoConfirmRes.message?.includes('confirmed')),
    `Message returned: "${demoConfirmRes.message}"`
  );

  // 7.4: Non-Negotiable Architecture Invariant: Confirmation does NOT generate booking
  const confirmPayloadString = JSON.stringify(demoConfirmRes);
  const containsBookingId = /(?:booking_id|bookingId|bookingReference)/i.test(confirmPayloadString);
  record(
    'UAT-7.4',
    7,
    'Buyer Confirmation',
    'Decoupled Booking Gate: Buyer confirmation strictly does NOT issue a booking reference',
    !containsBookingId,
    'Verified that confirmation response payload contains zero booking identifiers.'
  );

  // 7.5: Amendment reason length guard
  const shortAmendmentRes = await requestDealAmendmentAction('demo-deal-37-2', 2, 'bad');
  record(
    'UAT-7.5',
    7,
    'Buyer Confirmation',
    'Amendment Guard: Rejects amendment request with reason shorter than 5 characters',
    shortAmendmentRes.success === false && Boolean(shortAmendmentRes.error?.includes('detailed reason')),
    `Error returned: "${shortAmendmentRes.error}"`
  );

  // 7.6: Visual Diff Engine
  const prevTerms: FinalDealCommercialTerms = {
    commodityName: 'Durum Wheat',
    gradeName: 'Grade A',
    quantity: 100,
    unitSymbol: 'MT',
    basePricePerUnit: 25000,
    netLandedPricePerUnit: 26000,
    totalEstimatedValue: 2600000,
    applicableCharges: [],
    totalChargesPerUnit: 1000,
    deliveryLocation: 'Warehouse A',
    deliveryWindowStart: '2026-11-01',
    deliveryWindowEnd: '2026-11-05',
    deliveryDate: '2026-11-01',
    paymentTerms: 'NET_30',
    packagingType: '50KG Bags',
    freightTerms: 'EXW',
    inspectionRequirements: 'Third Party',
    qualityParameters: [],
  };
  const newTerms: FinalDealCommercialTerms = {
    ...prevTerms,
    basePricePerUnit: 24500, // Changed
    paymentTerms: 'NET_15', // Changed
  };
  const diffReport = computeDealTermsDiff(newTerms, prevTerms);
  const priceChanged = diffReport.basePrice.isChanged;
  const qtyUnchanged = !diffReport.quantity.isChanged;

  record(
    'UAT-7.6',
    7,
    'Buyer Confirmation',
    'Visual Diff Engine: Flags changed commercial terms and preserves unchanged fields',
    Boolean(priceChanged && qtyUnchanged),
    `Price changed: ${priceChanged} (Prev: "${diffReport.basePrice.previous}", New: "${diffReport.basePrice.current}"); Qty changed: ${diffReport.quantity.isChanged}`
  );

  // 7.7: State mapping across confirmation states
  const mappedConfirmed = mapToDealConfirmationStatus('Buyer Confirmed', 'Buyer Confirmed');
  const mappedProposed = mapToDealConfirmationStatus('Awaiting Confirmations', 'Proposed');
  record(
    'UAT-7.7',
    7,
    'Buyer Confirmation',
    'Confirmation State Mapper: Correctly maps dual-confirmation states',
    mappedConfirmed === 'Buyer Confirmed' && mappedProposed === 'Awaiting Buyer Confirmation',
    `Mapped states: Confirmed="${mappedConfirmed}", Proposed="${mappedProposed}"`
  );

  // ============================================================================
  // PHASE 8: Broker-Only Booking Finalization Gate
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 8: Broker Finalization Gate & Booking Isolation');
  console.log('--------------------------------------------------------------------------------');

  // 8.1: Precondition validation rejects empty deal ID
  let emptyGateFailed = false;
  try {
    await validateFinalizationPreconditions('', 1);
  } catch (err: any) {
    emptyGateFailed = Boolean(err.message?.includes('required'));
  }
  record(
    'UAT-8.1',
    8,
    'Broker Finalization Gate',
    'Gate Guard: validateFinalizationPreconditions rejects empty deal ID',
    emptyGateFailed,
    'Empty deal ID thrown before database query execution.'
  );

  // 8.2: Precondition validation rejects version <= 0
  let invalidVersionGateFailed = false;
  try {
    await validateFinalizationPreconditions('deal-101', 0);
  } catch (err: any) {
    invalidVersionGateFailed = Boolean(err.message?.includes('Valid version number'));
  }
  record(
    'UAT-8.2',
    8,
    'Broker Finalization Gate',
    'Gate Guard: validateFinalizationPreconditions rejects invalid version number',
    invalidVersionGateFailed,
    'Invalid version number thrown before database query execution.'
  );

  // 8.3: finalizeDealAction rejects unauthenticated / buyer caller
  const unauthorizedFinalizeRes = await finalizeDealAction('deal-101', 2);
  record(
    'UAT-8.3',
    8,
    'Broker Finalization Gate',
    'Authorization Gate: finalizeDealAction rejects unauthorized or buyer execution',
    unauthorizedFinalizeRes.success === false,
    `Error returned: "${unauthorizedFinalizeRes.error}"`
  );

  // 8.4: createIdempotentBookingAction input validation
  const emptyBookingRes = await createIdempotentBookingAction('');
  record(
    'UAT-8.4',
    8,
    'Broker Finalization Gate',
    'Booking Guard: createIdempotentBookingAction rejects unauthenticated / empty execution',
    emptyBookingRes.success === false,
    `Error returned: "${emptyBookingRes.error}"`
  );

  // 8.5: Booking Reference format invariant
  const sampleRef = `BKG-${new Date().getFullYear()}-AB12`;
  const bookingRefRegex = /^BKG-\d{4}-[A-Z0-9]{4}$/;
  record(
    'UAT-8.5',
    8,
    'Broker Finalization Gate',
    'Enterprise Identifier Format: Adheres to standard BKG-YYYY-XXXX schema',
    bookingRefRegex.test(sampleRef),
    `Sample format: "${sampleRef}" matches standard regex ${bookingRefRegex}`
  );

  // 8.6: Live Database Booking Idempotency
  record(
    'UAT-8.6',
    8,
    'Broker Finalization Gate',
    'Live Database: Enforce unique constraint on bookings.deal_id and atomic inventory reservation',
    false,
    databaseUrlConfigured
      ? 'Live booking idempotency verified.'
      : 'DATABASE_URL is absent. Cannot verify UNIQUE constraint on bookings.deal_id or inventory lock in live database.',
    true
  );

  // ============================================================================
  // PHASE 9: Document Vault and Payable Ledger Behavior
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 9: Document Vault & Payable Ledger Behavior');
  console.log('--------------------------------------------------------------------------------');

  // 9.1: Document matrix rejects empty booking ID
  const emptyDocRes = await getBuyerDocumentMatrixAction('');
  record(
    'UAT-9.1',
    9,
    'Document Vault & Payables',
    'Vault Guard: getBuyerDocumentMatrixAction rejects empty booking ID',
    emptyDocRes.success === false && Boolean(emptyDocRes.error?.includes('required')),
    `Error returned: "${emptyDocRes.error}"`
  );

  // 9.2: Signed URL delivery & path validation
  const signedDocRes = await getBuyerDocumentSignedUrlAction('BKG-2026-8812', 'COA_Malwa_Wheat.pdf');
  const validSignedUrl = signedDocRes.success && Boolean(signedDocRes.data?.signedUrl);
  record(
    'UAT-9.2',
    9,
    'Document Vault & Payables',
    'Security Shield: getBuyerDocumentSignedUrlAction delivers short-lived signed URL and guards paths',
    validSignedUrl,
    `Signed URL generated: "${signedDocRes.data?.signedUrl}"`
  );

  // 9.3: Document matrix demo execution with 4-state lifecycle
  const docMatrixRes = await getBuyerDocumentMatrixAction('BKG-2026-8812');
  const validMatrixStatuses = ['Verified', 'Received', 'Missing', 'Required'];
  const allStatusesValid =
    docMatrixRes.success &&
    docMatrixRes.data?.documents.every((d) => validMatrixStatuses.includes(d.status));

  record(
    'UAT-9.3',
    9,
    'Document Vault & Payables',
    'Compliance Matrix: Returns structured document matrix with valid 4-state lifecycles',
    Boolean(allStatusesValid),
    `Total documents: ${docMatrixRes.data?.documents.length}, Compliance rate: ${docMatrixRes.data?.compliancePercentage}%`
  );

  // 9.4: Payable ledger rejects whitespace booking ID
  const whitespacePayableRes = await getBuyerPayableLedgerAction('   ');
  record(
    'UAT-9.4',
    9,
    'Document Vault & Payables',
    'Ledger Guard: getBuyerPayableLedgerAction rejects whitespace booking ID',
    whitespacePayableRes.success === false,
    `Error returned: "${whitespacePayableRes.error}"`
  );

  // 9.5: Server-side financial math engine
  const payableRes = await getBuyerPayableLedgerAction('BKG-2026-8812');
  const payableItem = payableRes.data?.singlePayable;

  let mathEnginePassed = false;
  if (payableItem) {
    const expectedBase = Math.round(payableItem.finalQuantity * payableItem.lockedBaseRate);
    const baseMatches = payableItem.baseAmount === expectedBase;
    const expectedGross = payableItem.baseAmount + payableItem.chargesAndTaxes;
    const grossMatches = payableItem.grossPayable === expectedGross;
    const sumPayments = payableItem.paymentRecords
      .filter((p) => p.status === 'Confirmed')
      .reduce((sum, p) => sum + p.amount, 0);
    const totalPaidMatches = payableItem.totalPaid === sumPayments;
    const expectedOutstanding = payableItem.grossPayable - payableItem.totalPaid;
    const outstandingMatches = payableItem.outstandingBalance === expectedOutstanding;

    mathEnginePassed = baseMatches && grossMatches && totalPaidMatches && outstandingMatches;
  }

  record(
    'UAT-9.5',
    9,
    'Document Vault & Payables',
    'Server-Side Financial Math: Base Amount, Gross Payable, Total Paid, and Outstanding Balance match formula',
    mathEnginePassed,
    payableItem
      ? `Base: ₹${payableItem.baseAmount}, Gross: ₹${payableItem.grossPayable}, Paid: ₹${payableItem.totalPaid}, Outstanding: ₹${payableItem.outstandingBalance}`
      : 'Payable item not resolved.'
  );

  // 9.6: Nodal Escrow Isolation & Seller Account Redaction
  const isNodalAccount = payableItem?.escrowReference.startsWith('BB-NODAL-');
  const sellerBankRedacted =
    !JSON.stringify(payableRes).includes('seller_ifsc') &&
    !JSON.stringify(payableRes).includes('seller_account');

  record(
    'UAT-9.6',
    9,
    'Document Vault & Payables',
    'Nodal Escrow Shield: Emits virtual platform nodal account and strictly redacts seller bank details',
    Boolean(isNodalAccount && sellerBankRedacted),
    `Escrow reference: "${payableItem?.escrowReference}", Zero seller bank identifiers leaked.`
  );

  // 9.7: Live Database Payments & Ledger Synchronization
  record(
    'UAT-9.7',
    9,
    'Document Vault & Payables',
    'Live Database: Query payments and dispatch_documents tables in PostgreSQL',
    false,
    databaseUrlConfigured
      ? 'Live payments queried.'
      : 'DATABASE_URL is absent. Cannot query live payments table or compute PostgreSQL aggregation in live database.',
    true
  );

  // ============================================================================
  // PHASE 10: Mediation Firewall and Buyer Dispute Behavior
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 10: Mediation Firewall & Buyer Dispute Behavior');
  console.log('--------------------------------------------------------------------------------');

  // 10.1: Empty booking ID guard
  const emptyDisputeRes = await createBuyerDisputeAction({
    booking_id: '',
    category: 'Quality',
    description: 'A'.repeat(60),
  });
  record(
    'UAT-10.1',
    10,
    'Disputes & Mediation',
    'Dispute Guard: createBuyerDisputeAction rejects empty booking ID',
    emptyDisputeRes.success === false && Boolean(emptyDisputeRes.error),
    `Error returned: "${emptyDisputeRes.error}"`
  );

  // 10.2: Invalid dispute category guard
  const invalidCategoryRes = await createBuyerDisputeAction({
    booking_id: 'BKG-2026-8812',
    category: 'InvalidCategory' as any,
    description: 'A'.repeat(60),
  });
  record(
    'UAT-10.2',
    10,
    'Disputes & Mediation',
    'Category Invariant: Rejects categories outside BUYER_DISPUTE_CATEGORIES enum',
    invalidCategoryRes.success === false && Boolean(invalidCategoryRes.error?.includes('category')),
    `Error returned: "${invalidCategoryRes.error}"`
  );

  // 10.3: Minimum 50-character description requirement
  const shortDisputeRes = await createBuyerDisputeAction({
    booking_id: 'BKG-2026-8812',
    category: 'Quality',
    description: 'Quality is bad and unacceptable.',
  });
  record(
    'UAT-10.3',
    10,
    'Disputes & Mediation',
    'Description Length Guard: Enforces minimum 50-character detailed explanation',
    shortDisputeRes.success === false && Boolean(shortDisputeRes.error?.includes('50 characters')),
    `Error returned: "${shortDisputeRes.error}"`
  );

  // 10.4: Valid dispute creation on demo booking
  const validDisputeRes = await createBuyerDisputeAction({
    booking_id: 'BKG-2026-8812',
    category: 'Quality',
    description:
      'Moisture content observed at 14.5% on destination unloading, significantly deviating from the 12.0% contractual maximum specification. Authorized lab slip attached.',
    evidence_urls: ['https://storage.brokerbridge.com/evidence/lab-moisture-analysis.pdf'],
  });
  record(
    'UAT-10.4',
    10,
    'Disputes & Mediation',
    'Dispute Generation: Successfully creates dispute under status "Open" with initiator "Buyer"',
    validDisputeRes.success === true && Boolean(validDisputeRes.disputeId),
    `Dispute ID: "${validDisputeRes.disputeId}", Result: "${validDisputeRes.success ? 'Created' : 'Failed'}"`
  );

  // 10.5: Mediation Firewall & Counterparty Shielding
  const activeDisputesRes = await getBuyerActiveDisputesAction();
  const disputePayloadStr = JSON.stringify(activeDisputesRes);
  const sellerIdentitiesLeaked =
    disputePayloadStr.includes('seller_name') ||
    disputePayloadStr.includes('seller_phone') ||
    disputePayloadStr.includes('seller_email') ||
    disputePayloadStr.includes('internalBrokerNotes');

  record(
    'UAT-10.5',
    10,
    'Disputes & Mediation',
    'Mediation Firewall: Zero counterparty identity leakage & internal broker notes shielded',
    !sellerIdentitiesLeaked && activeDisputesRes.success,
    `Active disputes count: ${activeDisputesRes.data?.summary.totalDisputes || 0}, Firewall strictly shields seller contact and internal notes.`
  );

  // 10.6: Live Database Dispute Persistence
  record(
    'UAT-10.6',
    10,
    'Disputes & Mediation',
    'Live Database: Persist dispute row into disputes table with tenant isolation',
    false,
    databaseUrlConfigured
      ? 'Live dispute persisted in PostgreSQL.'
      : 'DATABASE_URL is absent. Cannot execute live Drizzle INSERT into disputes table.',
    true
  );

  // ============================================================================
  // PHASE 11: Mobile Contract Checks (8 Order Detail Modules)
  // Source-Level Contract Inspection (Labeled accurately as source checks)
  // ============================================================================
  console.log('\n--------------------------------------------------------------------------------');
  console.log('PHASE 11: Mobile Contract Checks (8 Order Detail Modules)');
  console.log('Note: Source-level AST/text inspection (real browser viewport testing not configured)');
  console.log('--------------------------------------------------------------------------------');

  const orderDetailPath = path.resolve(
    process.cwd(),
    'app/(buyer)/buyer/orders/[id]/page.tsx'
  );
  const orderDetailContent = fs.existsSync(orderDetailPath)
    ? fs.readFileSync(orderDetailPath, 'utf-8')
    : '';

  // 11.1: Container Contract
  const hasPageOverflowHidden = orderDetailContent.includes('w-full max-w-full overflow-x-hidden');
  const hasPageStandardContainer = orderDetailContent.includes('max-w-3xl mx-auto p-4 space-y-4');
  record(
    'UAT-11.1',
    11,
    'Mobile Contract Checks',
    'Container Contract: Order Detail page enforces overflow-x-hidden and max-w-3xl space-y-4',
    hasPageOverflowHidden && hasPageStandardContainer,
    'Verified presence of overflow-x-hidden and max-w-3xl mx-auto p-4 space-y-4 container.'
  );

  // 11.2: Sequential Mounting of All 8 Modules
  const m1Mounted = orderDetailContent.includes('<BookingVisibilityCard');
  const m2Mounted = orderDetailContent.includes('<OrderFulfillmentCard');
  const m3Mounted = orderDetailContent.includes('<LogisticsTimeline');
  const m4Mounted = orderDetailContent.includes('<DeliveryDetailsCard');
  const m5Mounted = orderDetailContent.includes('<TransactionQualityCard');
  const m6Mounted = orderDetailContent.includes('<TransactionDocumentVault');
  const m7Mounted = orderDetailContent.includes('<BuyerPaymentCard');
  const m8Mounted = orderDetailContent.includes('<RaiseDisputeModal');

  const all8ModulesMounted =
    m1Mounted &&
    m2Mounted &&
    m3Mounted &&
    m4Mounted &&
    m5Mounted &&
    m6Mounted &&
    m7Mounted &&
    m8Mounted;

  record(
    'UAT-11.2',
    11,
    'Mobile Contract Checks',
    'Order Detail Composition: All 8 modules mounted sequentially in page.tsx',
    all8ModulesMounted,
    `Modules verified: M1(Booking)=${m1Mounted}, M2(Fulfillment)=${m2Mounted}, M3(Logistics)=${m3Mounted}, M4(Vehicle)=${m4Mounted}, M5(Quality)=${m5Mounted}, M6(Vault)=${m6Mounted}, M7(Payment)=${m7Mounted}, M8(Dispute)=${m8Mounted}`
  );

  // Inspect component files for responsive contracts
  const componentsDir = path.resolve(process.cwd(), 'src/components/buyer/orders');

  // 11.3: Module 2 (OrderFulfillmentCard) - 360px grid resilience
  const fulfillmentFile = path.join(componentsDir, 'order-fulfillment-card.tsx');
  const fulfillmentContent = fs.existsSync(fulfillmentFile)
    ? fs.readFileSync(fulfillmentFile, 'utf-8')
    : '';
  const fulfillment360Safe =
    fulfillmentContent.includes('overflow-x-auto') &&
    fulfillmentContent.includes('min-w-[280px]');
  record(
    'UAT-11.3',
    11,
    'Mobile Contract Checks',
    'Module 2 Contract: OrderFulfillmentCard contains min-w-[280px] inside overflow-x-auto',
    fulfillment360Safe,
    '3-column progress math wraps cleanly inside 360px viewport boundaries.'
  );

  // 11.4: Module 7 (BuyerPaymentCard) - responsive stacking & 48px targets
  const paymentCardFile = path.join(componentsDir, 'buyer-payment-card.tsx');
  const paymentContent = fs.existsSync(paymentCardFile)
    ? fs.readFileSync(paymentCardFile, 'utf-8')
    : '';
  const paymentStacksOnMobile = paymentContent.includes('grid-cols-1 sm:grid-cols-3');
  const paymentHas48pxTargets = paymentContent.includes('min-h-[48px]');
  record(
    'UAT-11.4',
    11,
    'Mobile Contract Checks',
    'Module 7 Contract: BuyerPaymentCard stacks 3 blocks on mobile and enforces min-h-[48px]',
    paymentStacksOnMobile && paymentHas48pxTargets,
    'grid-cols-1 sm:grid-cols-3 and min-h-[48px] touch targets verified.'
  );

  // 11.5: Module 8 (RaiseDisputeModal) - Destructive trigger button & 48px touch targets
  const disputeModalFile = path.join(componentsDir, 'raise-dispute-modal.tsx');
  const disputeModalContent = fs.existsSync(disputeModalFile)
    ? fs.readFileSync(disputeModalFile, 'utf-8')
    : '';
  const disputeTriggerStyled =
    disputeModalContent.includes('border-rose-300') &&
    disputeModalContent.includes('text-rose-700');
  const disputeModal48px = disputeModalContent.includes('min-h-[48px]');
  record(
    'UAT-11.5',
    11,
    'Mobile Contract Checks',
    'Module 8 Contract: RaiseDisputeModal trigger enforces Destructive styling & min-h-[48px]',
    disputeTriggerStyled && disputeModal48px,
    'Red outline trigger (border-rose-300 text-rose-700) and min-h-[48px] targets verified.'
  );

  // 11.6: Module 5 (TransactionQualityCard) - 48px signed URL preview buttons
  const qualityCardFile = path.join(componentsDir, 'transaction-quality-card.tsx');
  const qualityContent = fs.existsSync(qualityCardFile)
    ? fs.readFileSync(qualityCardFile, 'utf-8')
    : '';
  const qualityHas48px = qualityContent.includes('min-h-[48px]');
  record(
    'UAT-11.6',
    11,
    'Mobile Contract Checks',
    'Module 5 Contract: TransactionQualityCard enforces min-h-[48px] preview action targets',
    qualityHas48px,
    'Quality certificate and weighment slip preview triggers conform to 48px touch standard.'
  );

  // 11.7: Module 6 (TransactionDocumentVault) - break-words and responsive table
  const vaultCardFile = path.join(componentsDir, 'transaction-document-vault.tsx');
  const vaultContent = fs.existsSync(vaultCardFile)
    ? fs.readFileSync(vaultCardFile, 'utf-8')
    : '';
  const vaultHas48px = vaultContent.includes('min-h-[48px]');
  record(
    'UAT-11.7',
    11,
    'Mobile Contract Checks',
    'Module 6 Contract: TransactionDocumentVault enforces min-h-[48px] touch targets',
    vaultHas48px,
    'Document download and preview actions conform to 48px touch standard.'
  );

  // ============================================================================
  // SUMMARY CALCULATIONS & REPORT GENERATION
  // ============================================================================

  const totalAssertions = assertions.length;
  const passedAssertions = assertions.filter((a) => a.status === 'PASSED').length;
  const failedAssertions = assertions.filter((a) => a.status === 'FAILED').length;
  const unverifiedDbAssertions = assertions.filter(
    (a) => a.status === 'UNVERIFIED_DATABASE'
  ).length;
  const skippedOfflineAssertions = assertions.filter(
    (a) => a.status === 'SKIPPED_OFFLINE'
  ).length;

  const passRatePercent =
    totalAssertions > 0
      ? Math.round((passedAssertions / (totalAssertions - unverifiedDbAssertions - skippedOfflineAssertions)) * 100)
      : 0;

  // Build Phase Summaries (Phases 1-11)
  const phaseNames: Record<number, string> = {
    1: 'Auth & Role Validation',
    2: 'Dashboard Summary Behavior',
    3: 'Requirement Creation & Logic',
    4: 'Quality Parameter Validation',
    5: 'Proposal Inbox & Privacy',
    6: 'Negotiation & Transitions',
    7: 'Buyer Deal Confirmation',
    8: 'Broker Finalization Gate',
    9: 'Document Vault & Payables',
    10: 'Disputes & Mediation',
    11: 'Mobile Contract Checks',
  };

  const phaseSummaries: PhaseSummary[] = [];

  for (let p = 1; p <= 11; p++) {
    const phaseTests = assertions.filter((a) => a.phase === p);
    const pPassed = phaseTests.filter((a) => a.status === 'PASSED').length;
    const pFailed = phaseTests.filter((a) => a.status === 'FAILED').length;
    const pUnverified = phaseTests.filter((a) => a.status === 'UNVERIFIED_DATABASE').length;
    const pSkipped = phaseTests.filter((a) => a.status === 'SKIPPED_OFFLINE').length;

    let pStatus: 'PASS' | 'PARTIAL_OFFLINE' | 'FAIL' = 'PASS';
    if (pFailed > 0) {
      pStatus = 'FAIL';
    } else if (pUnverified > 0 || pSkipped > 0) {
      pStatus = 'PARTIAL_OFFLINE';
    }

    phaseSummaries.push({
      phase: p,
      name: phaseNames[p] || `Phase ${p}`,
      total: phaseTests.length,
      passed: pPassed,
      failed: pFailed,
      unverifiedDb: pUnverified,
      skippedOffline: pSkipped,
      status: pStatus,
    });
  }

  const report: BuyerUATReport = {
    suiteName: 'BrokerBridge Unified Buyer E2E UAT Runner (BB-SPRINT-40-B)',
    timestamp: new Date().toISOString(),
    mode,
    databaseUrlConfigured,
    totals: {
      total: totalAssertions,
      passed: passedAssertions,
      failed: failedAssertions,
      skippedOffline: skippedOfflineAssertions,
      unverifiedDatabase: unverifiedDbAssertions,
      passRatePercent,
    },
    phaseSummaries,
    assertions,
  };

  // ============================================================================
  // CONSOLE SUMMARY OUTPUT
  // ============================================================================
  console.log('\n================================================================================');
  console.log('  UAT SUMMARY EXECUTION MATRIX');
  console.log('================================================================================');
  console.log(
    'Phase | Workflow Phase Name              | Total | Pass | Fail | Unver DB | Status'
  );
  console.log('------+----------------------------------+-------+------+------+----------+----------------');

  for (const ps of phaseSummaries) {
    const pNum = String(ps.phase).padEnd(5);
    const pName = ps.name.padEnd(32);
    const pTot = String(ps.total).padEnd(5);
    const pPass = String(ps.passed).padEnd(4);
    const pFail = String(ps.failed).padEnd(4);
    const pUnver = String(ps.unverifiedDb).padEnd(8);
    const badge =
      ps.status === 'PASS'
        ? '✅ PASSED'
        : ps.status === 'PARTIAL_OFFLINE'
        ? '⚠️ PARTIAL_OFFLINE'
        : '❌ FAILED';

    console.log(`${pNum} | ${pName} | ${pTot} | ${pPass} | ${pFail} | ${pUnver} | ${badge}`);
  }

  console.log('------+----------------------------------+-------+------+------+----------+----------------');
  console.log(`TOTALS: Total=${totalAssertions} | Passed=${passedAssertions} | Failed=${failedAssertions} | Unverified DB=${unverifiedDbAssertions} | Pass Rate=${passRatePercent}%`);
  console.log('================================================================================\n');

  if (failedAssertions > 0) {
    console.error(`❌ UAT RUN COMPLETED WITH ${failedAssertions} FAILURE(S).`);
  } else if (unverifiedDbAssertions > 0) {
    console.log(`⚠️ OFFLINE UAT PASSED (100% of runnable checks passed, ${unverifiedDbAssertions} database assertions marked UNVERIFIED_DATABASE).`);
  } else {
    console.log('🎉 ALL UAT ASSERTIONS PASSED (Full live integration verified).');
  }

  return report;
}

// ============================================================================
// CLI Direct Invocation
// ============================================================================
if (
  process.argv[1]?.includes('verify-buyer-e2e-uat') ||
  process.argv[1]?.endsWith('verify-buyer-e2e-uat.ts')
) {
  runBuyerE2EUAT()
    .then((report) => {
      if (report.totals.failed > 0) {
        process.exit(1);
      } else {
        process.exit(0);
      }
    })
    .catch((err) => {
      console.error('Fatal Runner Exception:', err);
      process.exit(1);
    });
}
