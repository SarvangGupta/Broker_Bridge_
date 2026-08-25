export type RequirementData = {
  id: string;
  companyId: string;
  commodityId: string;
  gradeId: string;
  quantity: number;
  unitId: string;
  targetPrice: number;
  deliveryTermsId: string;
  targetDate: Date;
  status: string;
};

export type AvailabilityData = {
  id: string;
  companyId: string;
  commodityId: string;
  gradeId: string;
  quantity: number;
  unitId: string;
  price: number;
  stateId: string;
  districtId: string;
  validUntil: Date;
  status: string;
};

export type MatchResult = {
  availabilityId: string;
  totalScore: number;
  classification: 'Strong Match' | 'Good Match' | 'Partial' | 'Weak';
  breakdown: {
    commodity: number;
    grade: number;
    price: number;
    quantity: number;
    location: number;
    logistics: number;
  };
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
  recommendedAction: string;
};

export function calculateMatchScore(
  req: RequirementData,
  avail: AvailabilityData
): MatchResult | null {
  // 1. Hard Eligibility Filters
  if (req.commodityId !== avail.commodityId) return null;
  if (!['Open', 'Partially Fulfilled'].includes(req.status) || avail.status !== 'Open') return null;
  if (req.quantity <= 0 || avail.quantity <= 0) return null;
  
  const now = new Date();
  if (req.targetDate < now || avail.validUntil < now) return null;

  // Initialize scoring
  let totalScore = 0;
  const breakdown = {
    commodity: 0,
    grade: 0,
    price: 0,
    quantity: 0,
    location: 5, // Auto-award 100% of 5% weight
    logistics: 5, // Auto-award 100% of 5% weight
  };

  const reasons: string[] = [];
  const risks: string[] = [];

  // 2. Commodity (35%)
  // Passed hard filter, so it's a match.
  breakdown.commodity = 35;
  totalScore += 35;
  reasons.push("✅ Commodity matches exactly");

  // 3. Grade / Specification (20%)
  if (req.gradeId === avail.gradeId) {
    breakdown.grade = 20;
    totalScore += 20;
    reasons.push("✅ Grade specification matches exactly");
  } else {
    risks.push("⚠ Grade specification differs");
  }

  // 4. Price Proximity (20%)
  // Calculate difference
  const difference = Number(avail.price) - Number(req.targetPrice);
  const differencePercent = (difference / Number(req.targetPrice)) * 100;
  
  if (Number(avail.price) <= Number(req.targetPrice)) {
    breakdown.price = 20;
    totalScore += 20;
    reasons.push(`✅ Seller price is equal to or below target (${avail.price})`);
  } else if (differencePercent <= 5) {
    breakdown.price = 16; // 80% of 20
    totalScore += 16;
    reasons.push(`✅ Seller price is within 5% of target`);
  } else if (differencePercent <= 10) {
    breakdown.price = 10; // 50% of 20
    totalScore += 10;
    risks.push(`⚠ Seller price is ${differencePercent.toFixed(1)}% above target`);
  } else {
    risks.push(`❌ Seller price is ${differencePercent.toFixed(1)}% above target`);
  }

  // 5. Quantity Coverage (15%)
  // (Seller Quantity / Buyer Required Quantity * 100. Cap at 100% of weight)
  let coveragePercent = (Number(avail.quantity) / Number(req.quantity)) * 100;
  if (coveragePercent > 100) coveragePercent = 100; // Cap at 100% coverage points

  const quantityScore = (coveragePercent / 100) * 15;
  breakdown.quantity = quantityScore;
  totalScore += quantityScore;

  if (coveragePercent >= 100) {
    reasons.push("✅ Seller covers 100% of required quantity");
  } else if (coveragePercent >= 50) {
    reasons.push(`✅ Seller covers ${coveragePercent.toFixed(0)}% of required quantity`);
  } else {
    risks.push(`⚠ Seller only covers ${coveragePercent.toFixed(0)}% of required quantity`);
  }

  // Add the auto-awarded weights
  totalScore += 10; // 5 location + 5 logistics

  // Ensure total score is rounded nicely
  totalScore = Math.round(totalScore);

  // 6. Classification & Recommendation
  let classification: MatchResult['classification'] = 'Weak';
  let recommendedAction = "Not Recommended";

  if (totalScore >= 90) {
    classification = 'Strong Match';
    recommendedAction = "Contact Seller Immediately";
  } else if (totalScore >= 75) {
    classification = 'Good Match';
    recommendedAction = "Review & Negotiate";
  } else if (totalScore >= 60) {
    classification = 'Partial';
    recommendedAction = "Consider as Backup";
  } else {
    classification = 'Weak';
  }

  return {
    availabilityId: avail.id,
    totalScore,
    classification,
    breakdown,
    quantity: {
      required: Number(req.quantity),
      available: Number(avail.quantity),
      coveragePercent: (Number(avail.quantity) / Number(req.quantity)) * 100, // Actual uncapped % for metadata
    },
    price: {
      buyerTarget: Number(req.targetPrice),
      sellerPrice: Number(avail.price),
      difference,
      differencePercent,
    },
    reasons,
    risks,
    recommendedAction,
  };
}
