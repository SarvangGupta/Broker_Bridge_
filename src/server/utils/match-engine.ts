/**
 * Deterministic Match Engine for BrokerBridge Enterprise
 * PRD v2.2 / Sprint 24: Matching + Quality
 *
 * CRITICAL PRINCIPLE: AI is recommendation-only.
 * The scoring engine is 100% deterministic (no external LLM API dependencies).
 * The licensed human Broker is the required decision-maker and can override match rankings.
 */

export type RequirementData = {
  id: string;
  companyId?: string;
  commodityId: string;
  gradeId: string;
  quantity: number;
  unitId?: string;
  targetPrice: number;
  deliveryTermsId?: string;
  targetDate: Date | string;
  status: string;
  stateId?: string | null;
  districtId?: string | null;
  allowPartial?: boolean;
  acceptableGradeIds?: string[];
};

export type AvailabilityData = {
  id: string;
  companyId?: string;
  commodityId: string;
  gradeId: string;
  quantity: number;
  unitId?: string;
  price: number;
  confidentialMinimumPrice?: number | null;
  stateId?: string | null;
  districtId?: string | null;
  availableFrom?: Date | string | null;
  validUntil: Date | string;
  status: string;
};

export type MatchBreakdown = {
  commodity: number;
  grade: number;
  price: number;
  location: number;
  quantity: number;
  deliveryDate: number;
};

export type MatchClassification = 'Strong Match' | 'Good Match' | 'Partial' | 'Low';

export type MatchResult = {
  availabilityId: string;
  totalScore: number;
  classification: MatchClassification;
  breakdown: MatchBreakdown;
  quantity: {
    required: number;
    available: number;
    coveragePercent: number;
  };
  price: {
    buyerTarget: number;
    sellerPrice: number;
    difference: number;
    differencePercent: number;
  };
  reasons: string[];
  risks: string[];
  recommendedAction?: string;
};

/**
 * Computes deterministic match score (0-100) between a Buyer Requirement and a Seller Availability Lot.
 *
 * WEIGHT DISTRIBUTION:
 * - Commodity Match: 35%
 * - Grade Match: 25%
 * - Price Proximity: 20%
 * - Location Index: 10%
 * - Quantity Match: 7%
 * - Delivery Date: 3%
 */
export function calculateMatchScore(
  req: RequirementData,
  avail: AvailabilityData
): MatchResult {
  const now = new Date();
  const validUntilDate = new Date(avail.validUntil);
  const availStatus = (avail.status || '').toLowerCase();
  const isStatusActive = ['active', 'open'].includes(availStatus);
  const isCommodityMatch = req.commodityId === avail.commodityId;
  const isValidDate = validUntilDate > now;
  const reqQty = Number(req.quantity) || 0;
  const availQty = Number(avail.quantity) || 0;
  const hasQuantity = availQty > 0 && reqQty > 0;

  const buyerTarget = Number(req.targetPrice) || 0;
  const sellerPrice = Number(avail.price) || 0;
  const difference = sellerPrice - buyerTarget;
  const differencePercent = buyerTarget > 0 ? (difference / buyerTarget) * 100 : 0;
  const coveragePercent = reqQty > 0 ? (availQty / reqQty) * 100 : 0;

  // 1. HARD ELIGIBILITY FILTERS: Return score = 0 immediately on mismatch/expiry
  if (!isCommodityMatch || !isStatusActive || !isValidDate || !hasQuantity) {
    const hardRisks: string[] = [];
    if (!isCommodityMatch) hardRisks.push('❌ Commodity does not match target requirement');
    if (!isStatusActive) hardRisks.push('❌ Supply lot is currently inactive or closed');
    if (!isValidDate) hardRisks.push('❌ Supply lot validity date has expired');
    if (!hasQuantity) hardRisks.push('❌ No available quantity remaining in this lot');

    return {
      availabilityId: avail.id,
      totalScore: 0,
      classification: 'Low',
      breakdown: {
        commodity: 0,
        grade: 0,
        price: 0,
        location: 0,
        quantity: 0,
        deliveryDate: 0,
      },
      quantity: {
        required: reqQty,
        available: availQty,
        coveragePercent,
      },
      price: {
        buyerTarget,
        sellerPrice,
        difference,
        differencePercent,
      },
      reasons: [],
      risks: hardRisks,
      recommendedAction: 'Not Recommended (Hard Filter Rejection)',
    };
  }

  const breakdown: MatchBreakdown = {
    commodity: 0,
    grade: 0,
    price: 0,
    location: 0,
    quantity: 0,
    deliveryDate: 0,
  };

  const reasons: string[] = [];
  const risks: string[] = [];

  // 2. COMMODITY MATCH (35%)
  breakdown.commodity = 35;
  reasons.push('✅ Commodity matches exactly (35/35)');

  // 3. GRADE MATCH (25%)
  if (req.gradeId === avail.gradeId) {
    breakdown.grade = 25;
    reasons.push('✅ Grade specification matches exactly (25/25)');
  } else if (req.acceptableGradeIds && req.acceptableGradeIds.includes(avail.gradeId)) {
    breakdown.grade = 12.5;
    reasons.push('ℹ Acceptable substitute grade (12.5/25)');
    risks.push('⚠ Specification differs but matches substitute tolerance');
  } else {
    breakdown.grade = 0;
    risks.push('⚠ Grade specification differs from buyer requirement (0/25)');
  }

  // 4. PRICE PROXIMITY (20%)
  if (sellerPrice <= buyerTarget) {
    breakdown.price = 20;
    reasons.push(`✅ Asking price (₹${sellerPrice}) is at or below target (₹${buyerTarget}) (20/20)`);
  } else if (differencePercent <= 5) {
    breakdown.price = 16; // 80% of 20
    reasons.push(`✅ Asking price is within 5% (+₹${difference.toFixed(0)}) of target (16/20)`);
    risks.push(`⚠ Asking price is ${differencePercent.toFixed(1)}% above buyer target`);
  } else if (differencePercent <= 10) {
    breakdown.price = 10; // 50% of 20
    risks.push(`⚠ Asking price is ${differencePercent.toFixed(1)}% (+₹${difference.toFixed(0)}) above target (10/20)`);
  } else {
    breakdown.price = 0;
    risks.push(`❌ Asking price is ${differencePercent.toFixed(1)}% (+₹${difference.toFixed(0)}) above target (0/20)`);
  }

  // 5. LOCATION INDEX (10%)
  if (req.districtId && avail.districtId && req.districtId === avail.districtId) {
    breakdown.location = 10;
    reasons.push('✅ Warehouse in same district (10/10)');
  } else if (req.stateId && avail.stateId && req.stateId === avail.stateId) {
    breakdown.location = 7;
    reasons.push('✅ Intra-state supply within same state (7/10)');
  } else if (req.stateId || avail.stateId) {
    breakdown.location = 3;
    reasons.push('ℹ Inter-state logistics dispatch (3/10)');
  } else {
    // If location not specified, estimate general regional transit
    breakdown.location = 7;
    reasons.push('ℹ Regional location estimated (7/10)');
  }

  // 6. QUANTITY MATCH (7%)
  const allowPartial = req.allowPartial !== false;
  if (availQty >= reqQty) {
    breakdown.quantity = 7;
    reasons.push(`✅ Full volume coverage (${availQty} available vs ${reqQty} required) (7/7)`);
  } else if (allowPartial) {
    const ratio = reqQty > 0 ? Math.min(1, availQty / reqQty) : 0;
    const qtyScore = Number((ratio * 7).toFixed(1));
    breakdown.quantity = qtyScore;
    reasons.push(`ℹ Partial volume coverage (${coveragePercent.toFixed(0)}% available) (${qtyScore}/7)`);
    risks.push(`⚠ Lot covers ${availQty} of ${reqQty} required (partial fulfillment required)`);
  } else {
    breakdown.quantity = 0;
    risks.push(`❌ Insufficient volume and partial fulfillment is disabled (0/7)`);
  }

  // 7. DELIVERY DATE (3%)
  if (avail.availableFrom && req.targetDate) {
    const availFrom = new Date(avail.availableFrom);
    const reqTarget = new Date(req.targetDate);
    if (availFrom <= reqTarget) {
      breakdown.deliveryDate = 3;
      reasons.push('✅ Stock ready on or before target delivery date (3/3)');
    } else {
      breakdown.deliveryDate = 0;
      risks.push('⚠ Stock availability date is later than target delivery date (0/3)');
    }
  } else {
    breakdown.deliveryDate = 3;
    reasons.push('✅ Stock ready for immediate dispatch (3/3)');
  }

  // 8. TOTAL SCORE & CLASSIFICATION
  const rawTotal =
    breakdown.commodity +
    breakdown.grade +
    breakdown.price +
    breakdown.location +
    breakdown.quantity +
    breakdown.deliveryDate;

  const totalScore = Math.min(100, Math.max(0, Math.round(rawTotal)));

  let classification: MatchClassification = 'Low';
  let recommendedAction = 'Review & Compare';

  if (totalScore >= 85) {
    classification = 'Strong Match';
    recommendedAction = 'Recommended for Immediate Proposal';
  } else if (totalScore >= 70) {
    classification = 'Good Match';
    recommendedAction = 'Viable Supply — Negotiate Terms';
  } else if (totalScore >= 50) {
    classification = 'Partial';
    recommendedAction = 'Partial / Alternative Option';
  } else {
    classification = 'Low';
    recommendedAction = 'Requires Broker Override or Spec Adjustment';
  }

  return {
    availabilityId: avail.id,
    totalScore,
    classification,
    breakdown,
    quantity: {
      required: reqQty,
      available: availQty,
      coveragePercent,
    },
    price: {
      buyerTarget,
      sellerPrice,
      difference,
      differencePercent,
    },
    reasons,
    risks,
    recommendedAction,
  };
}
