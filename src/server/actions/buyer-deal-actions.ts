'use server';

import { revalidatePath } from 'next/cache';
import { db } from '@/src/server/db';
import {
  deals,
  dealVersions,
  negotiationEvents,
  quotations,
  requirements,
  masterCommodities,
  masterGrades,
  masterUnits,
  users,
} from '@/src/server/db/schema';
import { eq, desc, asc, inArray, and, or } from 'drizzle-orm';
import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';
import {
  sanitizeBuyerNegotiationPayload,
  sanitizeBuyerChannelText,
} from '@/src/server/utils/buyer-privacy-scrubber';
import {
  FinalDealCommercialTerms,
  FinalDealReviewData,
  FinalDealReviewResponse,
  DealConfirmationStatus,
  BuyerSideCharge,
  BuyerQualitySpec,
} from '@/src/types/buyer-deal-review';
import { mapToDealConfirmationStatus } from '@/src/utils/visual-diff-engine';

/**
 * Robust JSONB snapshot parser that handles both native objects and stringified JSON payloads.
 */
function parseSnapshot(raw: any): Record<string, any> {
  if (!raw) return {};
  if (typeof raw === 'object') return raw;
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch {
      return {};
    }
  }
  return {};
}

/**
 * Normalizes raw snapshot payload into structured FinalDealCommercialTerms.
 */
function extractTermsFromSnapshot(
  snapshot: any,
  fallbackRow?: any
): FinalDealCommercialTerms {
  // If broker nested the buyer snapshot under buyer_snapshot, prioritize it
  const buyerSnap = snapshot?.buyer_snapshot || snapshot;

  const commodityName =
    buyerSnap?.commodityName ||
    snapshot?.commodityName ||
    fallbackRow?.commodity?.name ||
    fallbackRow?.commodityName ||
    'Standard Commodity';

  const gradeName =
    buyerSnap?.gradeName ||
    snapshot?.gradeName ||
    fallbackRow?.grade?.gradeName ||
    fallbackRow?.gradeName ||
    'Standard Commercial Grade';

  const quantity = Number(
    buyerSnap?.quantity ??
    snapshot?.quantity ??
    fallbackRow?.deal?.agreedQuantity ??
    fallbackRow?.requirement?.quantity ??
    100
  );

  const unitSymbol =
    buyerSnap?.unitSymbol ||
    snapshot?.unitSymbol ||
    fallbackRow?.unit?.symbol ||
    'MT';

  const basePricePerUnit = Number(
    buyerSnap?.agreedRate ??
    buyerSnap?.rate ??
    snapshot?.baseRate ??
    snapshot?.rate ??
    snapshot?.price ??
    fallbackRow?.deal?.agreedPrice ??
    fallbackRow?.quotation?.offeredPrice ??
    0
  );

  // Applicable Buyer charges
  let applicableCharges: BuyerSideCharge[] = [];
  if (Array.isArray(buyerSnap?.applicableCharges) && buyerSnap.applicableCharges.length > 0) {
    applicableCharges = buyerSnap.applicableCharges;
  } else if (Array.isArray(snapshot?.applicableCharges) && snapshot.applicableCharges.length > 0) {
    applicableCharges = snapshot.applicableCharges;
  } else {
    const brokerage = buyerSnap?.brokerageRate ? Number(buyerSnap.brokerageRate) : 35;
    const handling = 15;
    const transit = 10;
    applicableCharges = [
      {
        name: 'Brokerage & Facilitation Fee',
        rate: brokerage,
        amount: Math.round(quantity * brokerage),
        type: 'per_unit',
        description: 'Regulated broker mediation and transaction settlement fee',
        includedInLandedPrice: true,
      },
      {
        name: 'Mandi Cess & Weighment Handling',
        rate: handling,
        amount: Math.round(quantity * handling),
        type: 'per_unit',
        description: 'Certified digital weighbridge slips and loading supervision',
        includedInLandedPrice: true,
      },
      {
        name: 'Transit Escrow & Quality Assurance Cover',
        rate: transit,
        amount: Math.round(quantity * transit),
        type: 'per_unit',
        description: 'Dispute protection and escrow holding until delivery acceptance',
        includedInLandedPrice: true,
      },
    ];
  }

  const totalChargesPerUnit = applicableCharges.reduce((acc, c) => acc + (c.rate || 0), 0);
  const netLandedPricePerUnit = Math.round(
    buyerSnap?.totalBuyerRate ??
    buyerSnap?.netLandedPricePerUnit ??
    (basePricePerUnit + totalChargesPerUnit)
  );

  const totalEstimatedValue = Math.round(
    buyerSnap?.totalPayable ??
    buyerSnap?.totalEstimatedValue ??
    (quantity * netLandedPricePerUnit)
  );

  const deliveryLocation =
    buyerSnap?.deliveryLocation ||
    snapshot?.deliveryLocation ||
    'Buyer Designated Warehouse / Mill Hub';

  const deliveryWindowStart =
    buyerSnap?.deliveryWindowStart ||
    snapshot?.deliveryWindowStart ||
    buyerSnap?.deliveryDate ||
    snapshot?.deliveryDate ||
    null;

  const deliveryWindowEnd =
    buyerSnap?.deliveryWindowEnd ||
    snapshot?.deliveryWindowEnd ||
    buyerSnap?.deliveryDate ||
    snapshot?.deliveryDate ||
    null;

  const deliveryDate =
    buyerSnap?.deliveryDate ||
    snapshot?.deliveryDate ||
    deliveryWindowStart ||
    null;

  const paymentTerms =
    buyerSnap?.paymentTerms ||
    snapshot?.paymentTerms ||
    '100% Against Delivery & Verified Weighbridge Slip via Broker Escrow Desk';

  const packagingType =
    buyerSnap?.packagingType ||
    snapshot?.packagingType ||
    '50kg HDPE / PP Laminated Bags';

  const freightTerms =
    buyerSnap?.freightTerms ||
    snapshot?.freightTerms ||
    buyerSnap?.deliveryTerms ||
    snapshot?.deliveryTerms ||
    'FOR Destination (Freight Paid by Seller)';

  const inspectionRequirements =
    buyerSnap?.inspectionRequirements ||
    snapshot?.inspectionRequirements ||
    'NABL Accredited Third-Party Lab Testing & Joint Sampling at Dispatch Point';

  const specialConditions =
    buyerSnap?.specialConditions ||
    snapshot?.specialConditions ||
    buyerSnap?.remarks ||
    snapshot?.remarks ||
    'Standard FSSAI commercial compliance guidelines apply.';

  // Quality specifications
  let qualityParameters: BuyerQualitySpec[] = [];
  const rawQuality = buyerSnap?.qualityParameters || snapshot?.qualityParameters || [];
  if (Array.isArray(rawQuality) && rawQuality.length > 0) {
    qualityParameters = rawQuality.map((q: any) => ({
      parameterName: q.name || q.parameterName,
      targetValue: q.value ?? q.targetValue,
      tolerance: q.tolerance || (q.unit ? `± 0.5 ${q.unit}` : 'Standard'),
      unit: q.unit || null,
      isMandatory: q.isMandatory ?? true,
    }));
  } else {
    qualityParameters = [
      { parameterName: 'Moisture Content', targetValue: '12.0', tolerance: 'Max 12.5%', unit: '%', isMandatory: true },
      { parameterName: 'Foreign Matter / Admixture', targetValue: '1.0', tolerance: 'Max 1.5%', unit: '%', isMandatory: true },
      { parameterName: 'Damaged / Discolored Grains', targetValue: '2.0', tolerance: 'Max 2.5%', unit: '%', isMandatory: false },
      { parameterName: 'Purity / Grain Count', targetValue: '98.0', tolerance: 'Min 97.0%', unit: '%', isMandatory: true },
    ];
  }

  return {
    commodityName,
    gradeName,
    quantity,
    unitSymbol,
    basePricePerUnit,
    netLandedPricePerUnit,
    totalEstimatedValue,
    applicableCharges,
    totalChargesPerUnit,
    deliveryLocation,
    deliveryState: buyerSnap?.deliveryState || snapshot?.deliveryState || null,
    deliveryDistrict: buyerSnap?.deliveryDistrict || snapshot?.deliveryDistrict || null,
    deliveryCity: buyerSnap?.deliveryCity || snapshot?.deliveryCity || null,
    deliveryWindowStart,
    deliveryWindowEnd,
    deliveryDate,
    paymentTerms,
    packagingType,
    freightTerms,
    inspectionRequirements,
    specialConditions,
    remarks: buyerSnap?.remarks || snapshot?.remarks || null,
    qualityParameters,
  };
}

/**
 * Returns development/demo fallback data demonstrating current vs previous version diff.
 */
function getDemoFinalDealReview(dealId: string): FinalDealReviewResponse {
  const currentTerms: FinalDealCommercialTerms = {
    commodityName: 'Yellow Maize / Corn',
    gradeName: 'Grade-A Poultry Feed',
    quantity: 250,
    unitSymbol: 'MT',
    basePricePerUnit: 24200,
    netLandedPricePerUnit: 24260,
    totalEstimatedValue: 6065000,
    applicableCharges: [
      {
        name: 'Brokerage & Facilitation Fee',
        rate: 35,
        amount: 8750,
        type: 'per_unit',
        description: 'Regulated broker mediation and transaction settlement fee',
        includedInLandedPrice: true,
      },
      {
        name: 'Mandi Cess & Weighment Handling',
        rate: 15,
        amount: 3750,
        type: 'per_unit',
        description: 'Certified digital weighbridge slips and loading supervision',
        includedInLandedPrice: true,
      },
      {
        name: 'Transit Escrow & Quality Assurance Cover',
        rate: 10,
        amount: 2500,
        type: 'per_unit',
        description: 'Dispute protection and escrow holding until delivery acceptance',
        includedInLandedPrice: true,
      },
    ],
    totalChargesPerUnit: 60,
    deliveryLocation: 'Khanna Industrial Area, Ludhiana, Punjab',
    deliveryState: 'Punjab',
    deliveryDistrict: 'Ludhiana',
    deliveryCity: 'Khanna',
    deliveryWindowStart: new Date(Date.now() + 4 * 24 * 3600 * 1000).toISOString(),
    deliveryWindowEnd: new Date(Date.now() + 9 * 24 * 3600 * 1000).toISOString(),
    deliveryDate: new Date(Date.now() + 5 * 24 * 3600 * 1000).toISOString(),
    paymentTerms: '100% Against Delivery & Verified Weighbridge Slip via Escrow',
    packagingType: '50kg HDPE / PP Laminated Bags',
    freightTerms: 'FOR Destination (Freight Paid by Seller)',
    inspectionRequirements: 'NABL Accredited Third-Party Lab Testing with sealed joint sampling at dispatch point.',
    specialConditions: 'Standard FSSAI moisture deductions apply for moisture between 12.0% and 12.5%.',
    qualityParameters: [
      { parameterName: 'Moisture Content', targetValue: '12.0', tolerance: 'Max 12.5%', unit: '%', isMandatory: true },
      { parameterName: 'Foreign Matter', targetValue: '1.0', tolerance: 'Max 1.5%', unit: '%', isMandatory: true },
      { parameterName: 'Aflatoxin (B1+B2+G1+G2)', targetValue: '20', tolerance: 'Max 20 ppb', unit: 'ppb', isMandatory: true },
      { parameterName: 'Broken Kernels', targetValue: '2.5', tolerance: 'Max 3.0%', unit: '%', isMandatory: false },
    ],
  };

  const previousTerms: FinalDealCommercialTerms = {
    commodityName: 'Yellow Maize / Corn',
    gradeName: 'Grade-A Poultry Feed',
    quantity: 200, // Changed from 200 to 250
    unitSymbol: 'MT',
    basePricePerUnit: 24500, // Changed from 24500 to 24200
    netLandedPricePerUnit: 24560,
    totalEstimatedValue: 4912000,
    applicableCharges: currentTerms.applicableCharges,
    totalChargesPerUnit: 60,
    deliveryLocation: 'Khanna Industrial Area, Ludhiana, Punjab',
    deliveryState: 'Punjab',
    deliveryDistrict: 'Ludhiana',
    deliveryCity: 'Khanna',
    deliveryWindowStart: new Date(Date.now() + 2 * 24 * 3600 * 1000).toISOString(),
    deliveryWindowEnd: new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString(),
    deliveryDate: new Date(Date.now() + 3 * 24 * 3600 * 1000).toISOString(),
    paymentTerms: '100% Advance Payment Against Dispatch Notice', // Changed to Escrow delivery
    packagingType: '50kg Jute Gunny Bags', // Changed to HDPE
    freightTerms: 'Ex-Mill (Freight Paid by Buyer)', // Changed to FOR Destination
    inspectionRequirements: 'Self-inspection at seller premises.',
    specialConditions: 'Standard trade rules apply.',
    qualityParameters: [
      { parameterName: 'Moisture Content', targetValue: '13.0', tolerance: 'Max 13.5%', unit: '%', isMandatory: true },
      { parameterName: 'Foreign Matter', targetValue: '1.5', tolerance: 'Max 2.0%', unit: '%', isMandatory: true },
      { parameterName: 'Aflatoxin (B1+B2+G1+G2)', targetValue: '30', tolerance: 'Max 30 ppb', unit: 'ppb', isMandatory: true },
      { parameterName: 'Broken Kernels', targetValue: '3.0', tolerance: 'Max 3.5%', unit: '%', isMandatory: false },
    ],
  };

  const data: FinalDealReviewData = {
    dealId,
    requestId: 'req-demo-001',
    requirementDisplayId: 'REQ-DEMO001',
    status: 'Awaiting Buyer Confirmation',
    rawStatus: 'Awaiting Confirmations',
    versionNumber: 2,
    hasPreviousVersion: true,
    previousVersionNumber: 1,
    currentTerms,
    previousTerms,
    brokerName: 'Rajesh Sharma',
    brokerAgency: 'BrokerBridge Verified Commodity Desk',
    brokerNotes: 'Final negotiated terms aligned with both parties. Please review the updated quantity, rate, and delivery window before confirming.',
    snapshotTimestamp: new Date().toISOString(),
    createdAt: new Date(Date.now() - 24 * 3600 * 1000).toISOString(),
    updatedAt: new Date().toISOString(),
  };

  return {
    success: true,
    data,
  };
}

/**
 * Task 1 (Micro-Sprint 37.1): Fetches the Final Deal Snapshot and immediately preceding version.
 * 
 * Strict Security Guardrails:
 * 1. Authenticates session via `@supabase/ssr` (role: BUYER_ADMIN).
 * 2. Tenant Isolation: Caller's companyId must match the deal's buyerId or requirement owner.
 * 3. Privacy Firewall: Mathematically removes all Seller identifiers, warehouse addresses,
 *    minimum floor prices, and internal broker CRM logs before returning payload to client.
 */
export async function getFinalDealReviewAction(dealId: string): Promise<FinalDealReviewResponse> {
  try {
    if (!dealId) {
      return { success: false, error: 'Deal ID is required.' };
    }

    // Check for demo/sample testing
    if (
      dealId.startsWith('demo-') ||
      dealId.startsWith('sample-') ||
      dealId.startsWith('mock-') ||
      dealId === 'demo'
    ) {
      return getDemoFinalDealReview(dealId);
    }

    // 1. Authenticate buyer session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const buyerCompanyId = sessionRes.data.companyId;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // 2. Query deal under buyer tenant isolation
    let dealRow = await db
      .select({
        deal: deals,
        requirement: requirements,
        commodity: masterCommodities,
        grade: masterGrades,
        unit: masterUnits,
        brokerUser: users,
      })
      .from(deals)
      .leftJoin(requirements, eq(deals.requirementId, requirements.id))
      .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
      .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
      .leftJoin(users, eq(deals.brokerId, users.id))
      .where(
        and(
          eq(deals.id, dealId),
          eq(deals.buyerId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);

    // If not found directly by dealId, check if dealId is a quotationId or direct requestId
    let quoteRow = null;
    if (!dealRow) {
      quoteRow = await db
        .select({
          quotation: quotations,
          requirement: requirements,
          commodity: masterCommodities,
          grade: masterGrades,
          unit: masterUnits,
          brokerUser: users,
        })
        .from(quotations)
        .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
        .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
        .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
        .leftJoin(users, eq(quotations.brokerId, users.id))
        .where(
          and(
            eq(quotations.id, dealId),
            eq(requirements.companyId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);

      if (quoteRow) {
        // Find any associated deal linked to this quotation
        dealRow = await db
          .select({
            deal: deals,
            requirement: requirements,
            commodity: masterCommodities,
            grade: masterGrades,
            unit: masterUnits,
            brokerUser: users,
          })
          .from(deals)
          .leftJoin(requirements, eq(deals.requirementId, requirements.id))
          .leftJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
          .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
          .leftJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
          .leftJoin(users, eq(deals.brokerId, users.id))
          .where(
            and(
              eq(deals.quotationId, quoteRow.quotation.id),
              eq(deals.buyerId, buyerCompanyId)
            )
          )
          .limit(1)
          .then((rows) => rows[0] || null);
      }
    }

    // 3. Resolve candidate request IDs for deal_versions lookup
    const candidateRequestIds = Array.from(
      new Set(
        [
          dealId,
          dealRow?.deal.id,
          dealRow?.deal.quotationId,
          quoteRow?.quotation.id,
        ].filter(Boolean) as string[]
      )
    );

    if (candidateRequestIds.length === 0) {
      return {
        success: false,
        error: 'Deal not found or access denied under organization isolation rules.',
      };
    }

    // 4. Fetch all linked deal_versions ordered by version_number DESC
    const versionRows = await db
      .select()
      .from(dealVersions)
      .where(inArray(dealVersions.requestId, candidateRequestIds))
      .orderBy(desc(dealVersions.versionNumber), desc(dealVersions.createdAt));

    if (versionRows.length === 0) {
      // If no version rows in DB yet, synthesize fallback review from base deal/quotation
      const fallbackSnapshot = {
        commodityName: dealRow?.commodity?.name || quoteRow?.commodity?.name || 'Commercial Commodity',
        gradeName: dealRow?.grade?.gradeName || quoteRow?.grade?.gradeName || 'Standard Grade',
        quantity: Number(dealRow?.deal.agreedQuantity || quoteRow?.requirement.quantity || 100),
        unitSymbol: dealRow?.unit?.symbol || quoteRow?.unit?.symbol || 'MT',
        rate: Number(dealRow?.deal.agreedPrice || quoteRow?.quotation.offeredPrice || 0),
        status: dealRow?.deal.status || quoteRow?.quotation.status || 'Proposed',
      };

      const currentTerms = extractTermsFromSnapshot(fallbackSnapshot, dealRow || quoteRow);
      const reqId = dealRow?.requirement?.id || quoteRow?.requirement.id || dealId;

      const reviewData: FinalDealReviewData = {
        dealId: dealRow?.deal.id || dealId,
        requestId: dealId,
        requirementDisplayId: `REQ-${reqId.substring(0, 8).toUpperCase()}`,
        status: mapToDealConfirmationStatus(dealRow?.deal.status || quoteRow?.quotation.status, 'Proposed'),
        rawStatus: dealRow?.deal.status || quoteRow?.quotation.status || 'Proposed',
        versionNumber: 1,
        hasPreviousVersion: false,
        previousVersionNumber: null,
        currentTerms,
        previousTerms: null,
        brokerName: dealRow?.brokerUser?.name || quoteRow?.brokerUser?.name || 'Assigned Broker',
        brokerAgency: 'BrokerBridge Verified Commodity Desk',
        brokerNotes: 'Final commercial terms generated by Broker desk.',
        snapshotTimestamp: new Date().toISOString(),
        createdAt: dealRow?.deal.createdAt ? new Date(dealRow.deal.createdAt).toISOString() : new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      const sanitized = sanitizeBuyerNegotiationPayload(reviewData);
      return { success: true, data: sanitized };
    }

    // 5. Identify latest version and immediately preceding version
    const latestVersion = versionRows[0];
    const previousVersion = versionRows.length > 1 ? versionRows[1] : null;

    const latestSnapshot = parseSnapshot(latestVersion.snapshotPayload);
    const previousSnapshot = previousVersion ? parseSnapshot(previousVersion.snapshotPayload) : null;

    const currentTerms = extractTermsFromSnapshot(latestSnapshot, dealRow || quoteRow);
    const previousTerms = previousSnapshot ? extractTermsFromSnapshot(previousSnapshot, dealRow || quoteRow) : null;

    const reqId = dealRow?.requirement?.id || quoteRow?.requirement?.id || dealId;
    const rawStatus = dealRow?.deal.status || latestVersion.status || 'Awaiting Buyer Confirmation';

    const reviewData: FinalDealReviewData = {
      dealId: dealRow?.deal.id || dealId,
      requestId: dealId,
      requirementDisplayId: `REQ-${reqId.substring(0, 8).toUpperCase()}`,
      status: mapToDealConfirmationStatus(rawStatus, latestVersion.status),
      rawStatus,
      versionNumber: latestVersion.versionNumber,
      hasPreviousVersion: Boolean(previousVersion),
      previousVersionNumber: previousVersion ? previousVersion.versionNumber : null,
      currentTerms,
      previousTerms,
      brokerName: dealRow?.brokerUser?.name || quoteRow?.brokerUser?.name || 'Assigned Broker',
      brokerAgency: 'BrokerBridge Verified Commodity Desk',
      brokerNotes: latestSnapshot?.brokerNotes || latestSnapshot?.remarks || 'Please review final terms before confirmation.',
      snapshotTimestamp: new Date(latestVersion.createdAt).toISOString(),
      createdAt: dealRow?.deal.createdAt ? new Date(dealRow.deal.createdAt).toISOString() : new Date(latestVersion.createdAt).toISOString(),
      updatedAt: new Date(latestVersion.createdAt).toISOString(),
    };

    // 6. Strict Privacy Sanitization Firewall
    const sanitizedData = sanitizeBuyerNegotiationPayload(reviewData);

    return {
      success: true,
      data: sanitizedData,
    };
  } catch (error: any) {
    console.error('getFinalDealReviewAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch final deal review snapshot',
    };
  }
}

export interface DealConfirmationActionResult {
  success: boolean;
  error?: string;
  message?: string;
}

/**
 * Task 1 (Micro-Sprint 37.2): Buyer Confirms Final Deal Snapshot.
 * 
 * Strict Security Guardrails:
 * 1. Authenticates session (`BUYER_ADMIN` role).
 * 2. Tenant Isolation: Caller's companyId must own the deal/requirement.
 * 3. Concurrency Guard: expectedVersion must match latest version_number in deal_versions.
 *    If stale, returns STALE_VERSION_DETECTED.
 * 4. Immutability & Booking Gate Isolation:
 *    - Updates deal_versions status to 'Buyer Confirmed'.
 *    - Updates parent deal status to 'Buyer Confirmed'.
 *    - Appends immutable event into negotiation_events (action_type: 'BUYER_FINAL_CONFIRMATION').
 *    - Non-negotiable: Does NOT generate system Booking ID (Broker executes booking).
 */
export async function confirmFinalDealAction(
  dealId: string,
  expectedVersion: number
): Promise<DealConfirmationActionResult> {
  try {
    if (!dealId) {
      return { success: false, error: 'Deal ID is required.' };
    }
    if (typeof expectedVersion !== 'number' || expectedVersion < 1) {
      return { success: false, error: 'Expected version number is required.' };
    }

    // Demo/Mock ID fallback for development harnesses
    if (
      dealId.startsWith('demo-') ||
      dealId.startsWith('sample-') ||
      dealId.startsWith('mock-') ||
      dealId === 'demo'
    ) {
      return {
        success: true,
        message: 'Final Deal Snapshot v' + expectedVersion + ' confirmed successfully (Demo Mode).',
      };
    }

    // 1. Authenticate buyer session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const { user, companyId: buyerCompanyId } = sessionRes.data;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // 2. Resolve deal / quotation under strict tenant isolation
    let dealRow = await db
      .select({
        deal: deals,
        requirement: requirements,
      })
      .from(deals)
      .leftJoin(requirements, eq(deals.requirementId, requirements.id))
      .where(
        and(
          eq(deals.id, dealId),
          eq(deals.buyerId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);

    let quoteRow = null;
    if (!dealRow) {
      quoteRow = await db
        .select({
          quotation: quotations,
          requirement: requirements,
        })
        .from(quotations)
        .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
        .where(
          and(
            eq(quotations.id, dealId),
            eq(requirements.companyId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);

      if (quoteRow) {
        dealRow = await db
          .select({
            deal: deals,
            requirement: requirements,
          })
          .from(deals)
          .leftJoin(requirements, eq(deals.requirementId, requirements.id))
          .where(
            and(
              eq(deals.quotationId, quoteRow.quotation.id),
              eq(deals.buyerId, buyerCompanyId)
            )
          )
          .limit(1)
          .then((rows) => rows[0] || null);
      }
    }

    // Candidate request IDs for deal_versions lookup
    const candidateRequestIds = Array.from(
      new Set(
        [
          dealId,
          dealRow?.deal.id,
          dealRow?.deal.quotationId,
          quoteRow?.quotation.id,
        ].filter(Boolean) as string[]
      )
    );

    if (candidateRequestIds.length === 0) {
      return {
        success: false,
        error: 'Deal not found or access denied under organization isolation rules.',
      };
    }

    const targetRequestId = dealRow?.deal.quotationId || dealRow?.deal.id || quoteRow?.quotation.id || dealId;

    // 3. Concurrency Guard within atomic transaction
    return await db.transaction(async (tx) => {
      const versionRows = await tx
        .select()
        .from(dealVersions)
        .where(inArray(dealVersions.requestId, candidateRequestIds))
        .orderBy(desc(dealVersions.versionNumber), desc(dealVersions.createdAt));

      const latestVersionRecord = versionRows[0] || null;
      const currentVersion = latestVersionRecord ? latestVersionRecord.versionNumber : 1;

      if (currentVersion > expectedVersion) {
        return {
          success: false,
          error: 'STALE_VERSION_DETECTED',
          message: `The Broker has updated this deal snapshot to Version ${currentVersion}. Please refresh the page to review the latest terms before confirming.`,
        };
      }

      // Check terminal state
      if (
        latestVersionRecord?.status === 'Buyer Confirmed' ||
        latestVersionRecord?.status === 'Confirmed' ||
        dealRow?.deal.status === 'Buyer Confirmed' ||
        dealRow?.deal.status === 'Confirmed'
      ) {
        return {
          success: false,
          error: 'This deal snapshot has already been confirmed.',
        };
      }

      // 4. Update deal_versions status to 'Buyer Confirmed'
      // STRICT IMMUTABILITY: Only status column modified to satisfy prevent_deal_version_snapshot_tampering()
      if (latestVersionRecord) {
        await tx
          .update(dealVersions)
          .set({ status: 'Buyer Confirmed' })
          .where(eq(dealVersions.id, latestVersionRecord.id));
      }

      // 5. Update parent deals record status to 'Buyer Confirmed'
      if (dealRow) {
        await tx
          .update(deals)
          .set({ status: 'Buyer Confirmed' })
          .where(eq(deals.id, dealRow.deal.id));
      }

      if (quoteRow) {
        await tx
          .update(quotations)
          .set({ status: 'Buyer Confirmed' })
          .where(eq(quotations.id, quoteRow.quotation.id));
      }

      // 6. Append immutable audit record into negotiation_events (PRD 37.2 & 37.3)
      await tx.insert(negotiationEvents).values({
        requestId: targetRequestId,
        companyId: buyerCompanyId,
        actorId: user.id,
        actionType: 'BUYER_FINAL_CONFIRMATION',
        payload: {
          actor_role: 'buyer',
          version_number: expectedVersion,
          action: 'BUYER_FINAL_CONFIRMATION',
          deal_id: dealRow?.deal.id || dealId,
          confirmed_by_id: user.id,
          confirmed_at: new Date().toISOString(),
        },
      });

      revalidatePath(`/buyer/deals/${dealId}`);
      revalidatePath('/buyer/proposals');
      revalidatePath('/buyer');

      return {
        success: true,
        message: 'Final Deal Snapshot v' + expectedVersion + ' officially confirmed. Broker finalization gate unlocked.',
      };
    });
  } catch (error: any) {
    console.error('confirmFinalDealAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to confirm deal snapshot',
    };
  }
}

/**
 * Task 1 (Micro-Sprint 37.2): Buyer Requests Deal Amendment.
 * 
 * Strict Security Guardrails:
 * 1. Authenticates session (`BUYER_ADMIN` role).
 * 2. Concurrency Guard: expectedVersion must match latest version_number.
 * 3. Updates deal_versions status to 'Amendment Required'.
 * 4. Appends immutable event into negotiation_events detailing amendment reason.
 */
export async function requestDealAmendmentAction(
  dealId: string,
  expectedVersion: number,
  reason: string
): Promise<DealConfirmationActionResult> {
  try {
    if (!dealId) {
      return { success: false, error: 'Deal ID is required.' };
    }
    if (typeof expectedVersion !== 'number' || expectedVersion < 1) {
      return { success: false, error: 'Expected version number is required.' };
    }
    if (!reason || reason.trim().length < 5) {
      return {
        success: false,
        error: 'Please provide a detailed reason for the amendment request (min 5 characters).',
      };
    }

    // Demo/Mock ID fallback for development harnesses
    if (
      dealId.startsWith('demo-') ||
      dealId.startsWith('sample-') ||
      dealId.startsWith('mock-') ||
      dealId === 'demo'
    ) {
      return {
        success: true,
        message: 'Amendment request submitted to the Broker desk (Demo Mode).',
      };
    }

    // 1. Authenticate buyer session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const { user, companyId: buyerCompanyId } = sessionRes.data;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // 2. Resolve deal / quotation under tenant isolation
    let dealRow = await db
      .select({
        deal: deals,
        requirement: requirements,
      })
      .from(deals)
      .leftJoin(requirements, eq(deals.requirementId, requirements.id))
      .where(
        and(
          eq(deals.id, dealId),
          eq(deals.buyerId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);

    let quoteRow = null;
    if (!dealRow) {
      quoteRow = await db
        .select({
          quotation: quotations,
          requirement: requirements,
        })
        .from(quotations)
        .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
        .where(
          and(
            eq(quotations.id, dealId),
            eq(requirements.companyId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);

      if (quoteRow) {
        dealRow = await db
          .select({
            deal: deals,
            requirement: requirements,
          })
          .from(deals)
          .leftJoin(requirements, eq(deals.requirementId, requirements.id))
          .where(
            and(
              eq(deals.quotationId, quoteRow.quotation.id),
              eq(deals.buyerId, buyerCompanyId)
            )
          )
          .limit(1)
          .then((rows) => rows[0] || null);
      }
    }

    const candidateRequestIds = Array.from(
      new Set(
        [
          dealId,
          dealRow?.deal.id,
          dealRow?.deal.quotationId,
          quoteRow?.quotation.id,
        ].filter(Boolean) as string[]
      )
    );

    if (candidateRequestIds.length === 0) {
      return {
        success: false,
        error: 'Deal not found or access denied under organization isolation rules.',
      };
    }

    const targetRequestId = dealRow?.deal.quotationId || dealRow?.deal.id || quoteRow?.quotation.id || dealId;

    // 3. Concurrency Guard & Atomic Mutation
    return await db.transaction(async (tx) => {
      const versionRows = await tx
        .select()
        .from(dealVersions)
        .where(inArray(dealVersions.requestId, candidateRequestIds))
        .orderBy(desc(dealVersions.versionNumber), desc(dealVersions.createdAt));

      const latestVersionRecord = versionRows[0] || null;
      const currentVersion = latestVersionRecord ? latestVersionRecord.versionNumber : 1;

      if (currentVersion > expectedVersion) {
        return {
          success: false,
          error: 'STALE_VERSION_DETECTED',
          message: `The Broker has updated this deal snapshot to Version ${currentVersion}. Please refresh the page to review the latest terms before requesting an amendment.`,
        };
      }

      // 4. Update deal_versions status to 'Amendment Required'
      if (latestVersionRecord) {
        await tx
          .update(dealVersions)
          .set({ status: 'Amendment Required' })
          .where(eq(dealVersions.id, latestVersionRecord.id));
      }

      // 5. Update parent deal status to 'Amendment Required'
      if (dealRow) {
        await tx
          .update(deals)
          .set({ status: 'Amendment Required' })
          .where(eq(deals.id, dealRow.deal.id));
      }

      if (quoteRow) {
        await tx
          .update(quotations)
          .set({ status: 'Amendment Required' })
          .where(eq(quotations.id, quoteRow.quotation.id));
      }

      // 6. Append immutable audit record into negotiation_events (PRD 37.4)
      await tx.insert(negotiationEvents).values({
        requestId: targetRequestId,
        companyId: buyerCompanyId,
        actorId: user.id,
        actionType: 'AMENDMENT_REQUESTED',
        payload: {
          actor_role: 'buyer',
          version_number: expectedVersion,
          action: 'AMENDMENT_REQUESTED',
          deal_id: dealRow?.deal.id || dealId,
          reason: sanitizeBuyerChannelText(reason.trim()),
          requested_by_id: user.id,
          requested_at: new Date().toISOString(),
        },
      });

      revalidatePath(`/buyer/deals/${dealId}`);
      revalidatePath('/buyer/proposals');
      revalidatePath('/buyer');

      return {
        success: true,
        message: 'Amendment request submitted to the Broker desk. New deal iteration required.',
      };
    });
  } catch (error: any) {
    console.error('requestDealAmendmentAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to submit amendment request',
    };
  }
}

