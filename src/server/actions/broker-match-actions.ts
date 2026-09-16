'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  requirements,
  availabilities,
  companies,
  masterCommodities,
  masterCategories,
  masterIndustries,
  masterGrades,
  masterUnits,
  masterStates,
  masterDistricts,
  users,
} from '@/src/server/db/schema';
import { eq, and, or, gt, inArray, desc, sql } from 'drizzle-orm';
import { format, differenceInHours, isPast } from 'date-fns';
import {
  calculateMatchScore,
  type MatchResult,
  type RequirementData,
  type AvailabilityData,
} from '@/src/server/utils/match-engine';
import { logDecisionGateAuditEventAction } from '@/src/server/actions/audit-actions';

export interface MatchedRequirementDetail {
  id: string;
  requirementRef: string;
  buyerCompanyName: string;
  buyerCompanyVerified: boolean;
  buyerTrustScore: number;
  commodityId: string;
  commodityName: string;
  categoryName: string | null;
  industryName: string | null;
  gradeId: string;
  gradeName: string;
  quantity: number;
  fulfilledQuantity: number;
  remainingQuantity: number;
  unitName: string;
  unitSymbol: string | null;
  targetPrice: number;
  deliveryTerms: string;
  targetDateFormatted: string;
  targetDateRaw: string;
  isUrgent: boolean;
  status: string;
  operationalStatus: string;
}

export interface RankedBrokerSupplyMatch {
  id: string;
  lotNumber: string | null;
  sellerCompanyName: string;
  sellerCompanyVerified: boolean;
  sellerTrustScore: number;
  commodityId: string;
  commodityName: string;
  gradeId: string;
  gradeName: string;
  availableQuantity: number;
  totalQuantity: number;
  unitName: string;
  unitSymbol: string | null;
  askingPrice: number;
  confidentialMinimumPrice: number | null; // Authorized for Broker
  stateName: string | null;
  districtName: string | null;
  loadingStatus: string;
  loadingDuration: number | null;
  validUntilFormatted: string;
  validUntilRaw: string;
  availableFromRaw: string | null;
  status: string;
  match: MatchResult;
}

export type RankedMatchesResponse = {
  success: boolean;
  requirement?: MatchedRequirementDetail;
  matches?: RankedBrokerSupplyMatch[];
  error?: string;
};

export type LogMatchOverridePayload = {
  requirementId: string;
  availabilityId: string;
  reasonCode: string;
  notes?: string;
};

/**
 * Micro-Sprint 24.1: Fetch Ranked Matches for a Buyer Requirement
 *
 * CRITICAL GUARDRAILS:
 * 1. Broker Assignment Model: Verified caller is assigned broker.
 * 2. Privacy Consent: Zero Buyer contact PII (no phone, email, WhatsApp, GST).
 * 3. Authorized Confidential Floor: Exposes confidentialMinimumPrice to Broker.
 * 4. Deterministic Ranking: Sorted by calculateMatchScore totalScore descending.
 */
export async function getRankedMatchesForRequirementAction(
  requirementId: string
): Promise<RankedMatchesResponse> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User not found in system' };
    }

    const role = (dbUser.role || '').toLowerCase();
    if (role !== 'broker' && role !== 'admin') {
      return { success: false, error: 'Forbidden: Broker access privileges required' };
    }

    const brokerId = dbUser.id;

    // 1. Fetch Target Requirement (with zero Buyer contact PII)
    const reqRes = await db
      .select({
        id: requirements.id,
        quantity: requirements.quantity,
        fulfilledQuantity: requirements.fulfilledQuantity,
        targetPrice: requirements.targetPrice,
        deliveryTermsId: requirements.deliveryTermsId,
        targetDate: requirements.targetDate,
        visibility: requirements.visibility,
        brokerId: requirements.brokerId,
        status: requirements.status,
        createdAt: requirements.createdAt,
        // Buyer Company
        buyerCompanyName: companies.name,
        buyerCompanyVerified: companies.isVerified,
        buyerTrustScore: companies.trustScore,
        // Master Commodity
        commodityId: requirements.commodityId,
        commodityName: masterCommodities.name,
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
        // Master Grade
        gradeId: requirements.gradeId,
        gradeName: masterGrades.gradeName,
        // Master Unit
        unitName: masterUnits.name,
        unitSymbol: masterUnits.symbol,
      })
      .from(requirements)
      .innerJoin(companies, eq(requirements.companyId, companies.id))
      .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .leftJoin(masterCategories, eq(masterCommodities.categoryId, masterCategories.id))
      .leftJoin(masterIndustries, eq(masterCategories.industryId, masterIndustries.id))
      .innerJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
      .innerJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
      .where(eq(requirements.id, requirementId))
      .limit(1);

    if (!reqRes || reqRes.length === 0) {
      return { success: false, error: 'Requirement not found' };
    }

    const rawReq = reqRes[0];

    // Verify Broker Assignment
    if (role !== 'admin' && rawReq.brokerId !== brokerId) {
      return { success: false, error: 'Forbidden: Requirement is not assigned to you' };
    }

    const targetDate = new Date(rawReq.targetDate);
    const hoursRemaining = differenceInHours(targetDate, new Date());
    const isPastDue = isPast(targetDate);
    const isUrgent = hoursRemaining <= 48 && !isPastDue;
    const totalReqQty = Number(rawReq.quantity) || 0;
    const fulfilledReqQty = Number(rawReq.fulfilledQuantity) || 0;
    const remainingReqQty = Math.max(0, totalReqQty - fulfilledReqQty);

    const requirementDetail: MatchedRequirementDetail = {
      id: rawReq.id,
      requirementRef: `REQ-${rawReq.id.slice(0, 8).toUpperCase()}`,
      buyerCompanyName: rawReq.buyerCompanyName || 'Verified Buyer',
      buyerCompanyVerified: rawReq.buyerCompanyVerified ?? false,
      buyerTrustScore: rawReq.buyerTrustScore ?? 85,
      commodityId: rawReq.commodityId,
      commodityName: rawReq.commodityName,
      categoryName: rawReq.categoryName,
      industryName: rawReq.industryName,
      gradeId: rawReq.gradeId,
      gradeName: rawReq.gradeName,
      quantity: totalReqQty,
      fulfilledQuantity: fulfilledReqQty,
      remainingQuantity: remainingReqQty,
      unitName: rawReq.unitName,
      unitSymbol: rawReq.unitSymbol,
      targetPrice: Number(rawReq.targetPrice) || 0,
      deliveryTerms: rawReq.deliveryTermsId || 'Ex-Warehouse / Standard Dispatch',
      targetDateFormatted: format(targetDate, 'dd MMM yyyy'),
      targetDateRaw: rawReq.targetDate.toISOString(),
      isUrgent,
      status: rawReq.status,
      operationalStatus: rawReq.status === 'Open' ? (isUrgent ? 'Action Required' : 'New Demand') : rawReq.status,
    };

    // 2. Fetch Active Seller Supply Lots respecting visibility consent
    const now = new Date();
    const rawAvailabilities = await db
      .select({
        id: availabilities.id,
        lotNumber: availabilities.lotNumber,
        commodityId: availabilities.commodityId,
        commodityName: masterCommodities.name,
        gradeId: availabilities.gradeId,
        gradeName: masterGrades.gradeName,
        totalQuantity: availabilities.totalQuantity,
        availableQuantity: availabilities.availableQuantity,
        askingPrice: availabilities.askingPrice,
        confidentialMinimumPrice: availabilities.confidentialMinimumPrice,
        availableFrom: availabilities.availableFrom,
        validUntil: availabilities.validUntil,
        status: availabilities.status,
        visibility: availabilities.visibility,
        loadingStatus: availabilities.loadingStatus,
        loadingDuration: availabilities.loadingDuration,
        stateId: availabilities.stateId,
        stateName: masterStates.name,
        districtId: availabilities.districtId,
        districtName: masterDistricts.name,
        unitName: masterUnits.name,
        unitSymbol: masterUnits.symbol,
        sellerCompanyName: companies.name,
        sellerCompanyVerified: companies.isVerified,
        sellerTrustScore: companies.trustScore,
      })
      .from(availabilities)
      .innerJoin(companies, eq(availabilities.companyId, companies.id))
      .innerJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .innerJoin(masterGrades, eq(availabilities.gradeId, masterGrades.id))
      .innerJoin(masterUnits, eq(availabilities.unitId, masterUnits.id))
      .leftJoin(masterStates, eq(availabilities.stateId, masterStates.id))
      .leftJoin(masterDistricts, eq(availabilities.districtId, masterDistricts.id))
      .where(
        and(
          inArray(availabilities.status, ['Active', 'Open']),
          gt(availabilities.validUntil, now),
          gt(sql`CAST(${availabilities.availableQuantity} AS NUMERIC)`, 0),
          or(
            eq(availabilities.visibility, 'global'),
            and(eq(availabilities.visibility, 'restricted'), eq(availabilities.brokerId, brokerId)),
            eq(availabilities.brokerId, brokerId)
          )
        )
      );

    // 3. Compute Deterministic Scores & Rank
    const reqInput: RequirementData = {
      id: requirementDetail.id,
      commodityId: requirementDetail.commodityId,
      gradeId: requirementDetail.gradeId,
      quantity: requirementDetail.remainingQuantity > 0 ? requirementDetail.remainingQuantity : requirementDetail.quantity,
      targetPrice: requirementDetail.targetPrice,
      targetDate: rawReq.targetDate,
      status: rawReq.status,
      allowPartial: true,
    };

    const rankedMatches: RankedBrokerSupplyMatch[] = rawAvailabilities.map((lot) => {
      const availInput: AvailabilityData = {
        id: lot.id,
        commodityId: lot.commodityId,
        gradeId: lot.gradeId,
        quantity: Number(lot.availableQuantity) || 0,
        price: Number(lot.askingPrice) || 0,
        confidentialMinimumPrice: lot.confidentialMinimumPrice ? Number(lot.confidentialMinimumPrice) : null,
        stateId: lot.stateId,
        districtId: lot.districtId,
        availableFrom: lot.availableFrom,
        validUntil: lot.validUntil,
        status: lot.status,
      };

      const matchScore = calculateMatchScore(reqInput, availInput);

      return {
        id: lot.id,
        lotNumber: lot.lotNumber || `LOT-${lot.id.slice(0, 8).toUpperCase()}`,
        sellerCompanyName: lot.sellerCompanyName || 'Verified Seller',
        sellerCompanyVerified: lot.sellerCompanyVerified ?? false,
        sellerTrustScore: lot.sellerTrustScore ?? 85,
        commodityId: lot.commodityId,
        commodityName: lot.commodityName,
        gradeId: lot.gradeId,
        gradeName: lot.gradeName,
        availableQuantity: Number(lot.availableQuantity) || 0,
        totalQuantity: Number(lot.totalQuantity) || 0,
        unitName: lot.unitName,
        unitSymbol: lot.unitSymbol || lot.unitName || 'MT',
        askingPrice: Number(lot.askingPrice) || 0,
        confidentialMinimumPrice: lot.confidentialMinimumPrice ? Number(lot.confidentialMinimumPrice) : null,
        stateName: lot.stateName,
        districtName: lot.districtName,
        loadingStatus: lot.loadingStatus || 'Ready',
        loadingDuration: lot.loadingDuration,
        validUntilFormatted: format(new Date(lot.validUntil), 'dd MMM yyyy'),
        validUntilRaw: lot.validUntil.toISOString(),
        availableFromRaw: lot.availableFrom ? lot.availableFrom.toISOString() : null,
        status: lot.status,
        match: matchScore,
      };
    });

    // Sort descending by totalScore
    rankedMatches.sort((a, b) => b.match.totalScore - a.match.totalScore);

    return {
      success: true,
      requirement: requirementDetail,
      matches: rankedMatches,
    };
  } catch (error: any) {
    console.error('Error in getRankedMatchesForRequirementAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to calculate ranked matches for requirement',
    };
  }
}

/**
 * Persists a Broker's manual match override reason to audit_logs
 */
export async function logMatchOverrideAction(payload: LogMatchOverridePayload) {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized' };
    }

    await logDecisionGateAuditEventAction({
      actorId: authUser.id,
      actorRole: 'broker',
      action: 'AI_MATCH_REVIEWED',
      entity: 'ai_match',
      entityId: payload.requirementId,
      metadata: {
        requirementId: payload.requirementId,
        availabilityId: payload.availabilityId,
        reasonCode: payload.reasonCode,
        notes: payload.notes || undefined,
        brokerOverride: true,
        humanReviewed: true,
        timestamp: new Date().toISOString(),
      },
    });

    return {
      success: true,
      message: 'Broker match override successfully logged for compliance.',
    };
  } catch (error: any) {
    console.error('Error in logMatchOverrideAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to log match override',
    };
  }
}
