'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  requirements,
  companies,
  masterCommodities,
  masterCategories,
  masterIndustries,
  masterGrades,
  masterUnits,
  users,
} from '@/src/server/db/schema';
import { eq, desc, and } from 'drizzle-orm';
import { format, differenceInHours, isPast } from 'date-fns';

export type BrokerOperationalStatus =
  | 'Action Required'
  | 'New Demand'
  | 'Sourcing'
  | 'Matched'
  | 'Partially Fulfilled'
  | 'Fulfilled'
  | 'Closed';

export interface BrokerAssignedRequirement {
  id: string;
  requirementRef: string;
  buyerCompanyName: string;
  buyerCompanyVerified: boolean;
  buyerTrustScore: number;
  commodityId: string;
  commodityName: string;
  commodityCode: string | null;
  categoryName: string | null;
  industryName: string | null;
  gradeId: string;
  gradeName: string;
  qualityParameters: Record<string, any> | null;
  quantity: number;
  unitName: string;
  unitSymbol: string | null;
  targetPrice: number;
  deliveryTerms: string;
  targetDateFormatted: string;
  targetDateRaw: string;
  isUrgent: boolean;
  hoursUntilTarget: number;
  status: string;
  operationalStatus: BrokerOperationalStatus;
  fulfilledQuantity: number;
  fulfillmentPercentage: number;
  visibility: string;
  createdAtFormatted: string;
}

export type BrokerAssignedRequirementsResponse = {
  success: boolean;
  data?: BrokerAssignedRequirement[];
  error?: string;
};

/**
 * Micro-Sprint 23.1: Fetch Assigned Requirements (Broker Workspace)
 *
 * CRITICAL GUARDRAIL 1: BROKER ASSIGNMENT MODEL
 * Strictly filters by eq(requirements.brokerId, user.id).
 *
 * CRITICAL GUARDRAIL 2: READ-ONLY DATA
 * Pure SELECT queries. No mutations to the requirements table.
 *
 * PRIVACY RULE: Zero Buyer phone, email, WhatsApp, or GST details returned.
 */
const DEMO_BROKER_REQUIREMENTS: BrokerAssignedRequirement[] = [
  {
    id: 'req-mock-101',
    requirementRef: '#REQ-8812',
    buyerCompanyName: 'AgrInnovate Flour Mills',
    buyerCompanyVerified: true,
    buyerTrustScore: 95,
    commodityId: 'comm-101',
    commodityName: 'Sharbati Wheat',
    commodityCode: 'WHT-SHR',
    categoryName: 'Grains & Cereals',
    industryName: 'Agri Commodities',
    gradeId: 'grade-101',
    gradeName: 'Grade A Milling',
    qualityParameters: { moisture: '12%', protein: '14%' },
    quantity: 100,
    unitName: 'Metric Tonne',
    unitSymbol: 'MT',
    targetPrice: 28500,
    deliveryTerms: 'FOR Destination (Karnal)',
    targetDateFormatted: '25 Oct 2026',
    targetDateRaw: '2026-10-25T00:00:00Z',
    isUrgent: false,
    hoursUntilTarget: 192,
    status: 'Open',
    operationalStatus: 'Partially Fulfilled',
    fulfilledQuantity: 50,
    fulfillmentPercentage: 50,
    visibility: 'Broker Exclusive',
    createdAtFormatted: '2 hours ago',
  },
  {
    id: 'req-mock-102',
    requirementRef: '#REQ-7041',
    buyerCompanyName: 'North Dairy Feed Corp',
    buyerCompanyVerified: true,
    buyerTrustScore: 90,
    commodityId: 'comm-102',
    commodityName: 'Yellow Maize (Corn)',
    commodityCode: 'MAZ-YEL',
    categoryName: 'Feed Ingredients',
    industryName: 'Feed & Fodder',
    gradeId: 'grade-102',
    gradeName: 'Feed Grade Premium',
    qualityParameters: { moisture: '14%', starch: '68%' },
    quantity: 250,
    unitName: 'Metric Tonne',
    unitSymbol: 'MT',
    targetPrice: 21800,
    deliveryTerms: 'Ex-Warehouse Jaipur',
    targetDateFormatted: '22 Oct 2026',
    targetDateRaw: '2026-10-22T00:00:00Z',
    isUrgent: true,
    hoursUntilTarget: 120,
    status: 'Open',
    operationalStatus: 'Sourcing',
    fulfilledQuantity: 0,
    fulfillmentPercentage: 0,
    visibility: 'Broker Exclusive',
    createdAtFormatted: '5 hours ago',
  },
  {
    id: 'req-mock-103',
    requirementRef: '#REQ-6029',
    buyerCompanyName: 'Apex Cattle Nutrition',
    buyerCompanyVerified: true,
    buyerTrustScore: 98,
    commodityId: 'comm-103',
    commodityName: 'Soybean Meal (DOC)',
    commodityCode: 'SOY-DOC',
    categoryName: 'Protein Meals',
    industryName: 'Animal Nutrition',
    gradeId: 'grade-103',
    gradeName: '48% Protein Non-GMO',
    qualityParameters: { protein: '48%', fiber: '6%' },
    quantity: 75,
    unitName: 'Metric Tonne',
    unitSymbol: 'MT',
    targetPrice: 42500,
    deliveryTerms: 'FOR Destination (Anand)',
    targetDateFormatted: '28 Oct 2026',
    targetDateRaw: '2026-10-28T00:00:00Z',
    isUrgent: false,
    hoursUntilTarget: 264,
    status: 'Open',
    operationalStatus: 'Matched',
    fulfilledQuantity: 75,
    fulfillmentPercentage: 100,
    visibility: 'Global Mandate',
    createdAtFormatted: '1 day ago',
  },
];

export async function getBrokerAssignedRequirementsAction(): Promise<BrokerAssignedRequirementsResponse> {
  try {
    let authUser = null;
    let authError = null;

    try {
      const supabase = await createClient();
      const res = await supabase.auth.getUser();
      authUser = res.data.user;
      authError = res.error;
    } catch (_e) {
      // Supabase unconfigured in local dev
    }

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    // Verify user role & identity in database
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

    // Execute Read-Only Drizzle Query strictly filtered by Broker ID
    const rawRequirements = await db
      .select({
        id: requirements.id,
        quantity: requirements.quantity,
        targetPrice: requirements.targetPrice,
        deliveryTermsId: requirements.deliveryTermsId,
        targetDate: requirements.targetDate,
        visibility: requirements.visibility,
        status: requirements.status,
        fulfilledQuantity: requirements.fulfilledQuantity,
        createdAt: requirements.createdAt,
        // Buyer Company details (zero PII)
        buyerCompanyName: companies.name,
        buyerCompanyVerified: companies.isVerified,
        buyerTrustScore: companies.trustScore,
        // Master Commodity details
        commodityId: requirements.commodityId,
        commodityName: masterCommodities.name,
        commodityCode: masterCommodities.code,
        // Master Category & Industry details
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
        // Master Grade details
        gradeId: requirements.gradeId,
        gradeName: masterGrades.gradeName,
        qualityParameters: masterGrades.parameters,
        // Master Unit details
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
      .where(
        // Strict Broker Assignment Filter (Guardrail 1)
        eq(requirements.brokerId, brokerId)
      )
      .orderBy(desc(requirements.createdAt));

    // Map into clean Broker Operational View Model
    const mappedRequirements: BrokerAssignedRequirement[] = rawRequirements.map((req) => {
      const targetDate = new Date(req.targetDate);
      const hoursRemaining = differenceInHours(targetDate, new Date());
      const isPastDue = isPast(targetDate);
      const isUrgent = hoursRemaining <= 48 && !isPastDue;

      // Determine clean Broker-facing operational status label
      let operationalStatus: BrokerOperationalStatus = 'New Demand';
      const rawStatus = (req.status || 'Open').toLowerCase();

      if (rawStatus === 'open') {
        if (isPastDue || isUrgent) {
          operationalStatus = 'Action Required';
        } else {
          operationalStatus = 'New Demand';
        }
      } else if (rawStatus === 'in progress' || rawStatus === 'sourcing') {
        operationalStatus = 'Sourcing';
      } else if (rawStatus === 'matched') {
        operationalStatus = 'Matched';
      } else if (rawStatus === 'partially fulfilled') {
        operationalStatus = 'Partially Fulfilled';
      } else if (rawStatus === 'fulfilled' || rawStatus === 'completed') {
        operationalStatus = 'Fulfilled';
      } else if (rawStatus === 'cancelled' || rawStatus === 'closed') {
        operationalStatus = 'Closed';
      }

      const totalQty = Number(req.quantity) || 0;
      const fulfilledQty = Number(req.fulfilledQuantity) || 0;
      const fulfillmentPercentage =
        totalQty > 0 ? Math.min(100, Math.round((fulfilledQty / totalQty) * 100)) : 0;

      return {
        id: req.id,
        requirementRef: `REQ-${req.id.slice(0, 8).toUpperCase()}`,
        buyerCompanyName: req.buyerCompanyName || 'Registered Buyer',
        buyerCompanyVerified: Boolean(req.buyerCompanyVerified),
        buyerTrustScore: Number(req.buyerTrustScore) || 100,
        commodityId: req.commodityId,
        commodityName: req.commodityName,
        commodityCode: req.commodityCode,
        categoryName: req.categoryName,
        industryName: req.industryName,
        gradeId: req.gradeId,
        gradeName: req.gradeName || 'Standard Quality',
        qualityParameters: (req.qualityParameters as Record<string, any>) || null,
        quantity: totalQty,
        unitName: req.unitName,
        unitSymbol: req.unitSymbol,
        targetPrice: Number(req.targetPrice) || 0,
        deliveryTerms: req.deliveryTermsId || 'Ex-Warehouse / Standard Dispatch',
        targetDateFormatted: format(targetDate, 'dd MMM yyyy'),
        targetDateRaw: targetDate.toISOString(),
        isUrgent,
        hoursUntilTarget: hoursRemaining,
        status: req.status,
        operationalStatus,
        fulfilledQuantity: fulfilledQty,
        fulfillmentPercentage,
        visibility: req.visibility || 'global',
        createdAtFormatted: format(new Date(req.createdAt), 'dd MMM yyyy, hh:mm a'),
      };
    });

    return {
      success: true,
      data: mappedRequirements,
    };
  } catch (error: any) {
    console.error('Error fetching broker assigned requirements:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch assigned buyer requirements',
    };
  }
}
