'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  availabilities,
  requirements,
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
import { eq, and, or, gt, lte, inArray, desc, sql, SQL, ilike } from 'drizzle-orm';
import { format } from 'date-fns';

export interface SupplyFilters {
  commodityId?: string;
  gradeId?: string;
  stateId?: string;
  maxPrice?: number;
  searchQuery?: string;
}

export interface BrokerSupplyLot {
  id: string;
  lotNumber: string | null;
  sellerCompanyName: string;
  sellerCompanyVerified: boolean;
  sellerTrustScore: number;
  commodityId: string;
  commodityName: string;
  commodityCode: string | null;
  categoryName: string | null;
  industryName: string | null;
  gradeId: string;
  gradeName: string;
  totalQuantity: number;
  availableQuantity: number;
  reservedQuantity: number;
  soldQuantity: number;
  minimumOrderQuantity: number | null;
  unitName: string;
  unitSymbol: string | null;
  askingPrice: number;
  confidentialMinimumPrice: number | null; // CRITICAL GUARDRAIL 1: Broker authorized
  stateName: string | null;
  districtName: string | null;
  loadingStatus: string;
  loadingDuration: number | null;
  loadingStartDate: string | null;
  loadingCapacity: number | null;
  loadingRemarks: string | null;
  validUntil: string;
  validUntilFormatted: string;
  availableFromFormatted: string;
  visibility: string;
  status: string;
  createdAt: string;
}

export type BrokerSupplySearchResponse = {
  success: boolean;
  data?: BrokerSupplyLot[];
  error?: string;
};

/**
 * Micro-Sprint 23.2: Seller Supply Search Engine (Broker)
 *
 * CRITICAL GUARDRAIL 1: BROKER AUTHORIZATION
 * The Broker IS authorized to see the Seller's confidentialMinimumPrice to establish the negotiation floor.
 *
 * CRITICAL GUARDRAIL 2: VISIBILITY RULE
 * Query strictly enforces: status = 'Active' (or 'Open'), valid_until > NOW(), and (visibility = 'global' OR broker_id = user.id).
 *
 * CRITICAL GUARDRAIL 3: ZERO DATA-WALL & READ-ONLY DATA
 * Pure SELECT queries. No mutations to availabilities table. Zero Buyer data leaks.
 */
export async function getBrokerSupplySearchAction(
  filters: SupplyFilters = {}
): Promise<BrokerSupplySearchResponse> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    // Verify user role in database
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
    const now = new Date();

    // Base mandatory conditions
    const conditions: (SQL | undefined)[] = [
      // Status is active / open
      inArray(availabilities.status, ['Active', 'Open']),
      // Valid until must be in the future
      gt(availabilities.validUntil, now),
      // Available quantity must be positive
      gt(sql`CAST(${availabilities.availableQuantity} AS NUMERIC)`, 0),
      // Visibility rule: global supply OR specifically assigned to this broker
      or(
        eq(availabilities.visibility, 'global'),
        and(eq(availabilities.visibility, 'restricted'), eq(availabilities.brokerId, brokerId)),
        eq(availabilities.brokerId, brokerId)
      ),
    ];

    // Dynamic Filter: Commodity
    if (filters.commodityId && filters.commodityId !== 'all') {
      conditions.push(eq(availabilities.commodityId, filters.commodityId));
    }

    // Dynamic Filter: Grade
    if (filters.gradeId && filters.gradeId !== 'all') {
      conditions.push(eq(availabilities.gradeId, filters.gradeId));
    }

    // Dynamic Filter: State
    if (filters.stateId && filters.stateId !== 'all') {
      conditions.push(eq(availabilities.stateId, filters.stateId));
    }

    // Dynamic Filter: Max Asking Price
    if (filters.maxPrice !== undefined && filters.maxPrice > 0) {
      conditions.push(lte(sql`CAST(${availabilities.askingPrice} AS NUMERIC)`, filters.maxPrice));
    }

    // Filter by Search Query (Commodity name, Seller company, Lot number)
    if (filters.searchQuery && filters.searchQuery.trim()) {
      const q = `%${filters.searchQuery.trim()}%`;
      conditions.push(
        or(
          ilike(companies.name, q),
          ilike(masterCommodities.name, q),
          ilike(availabilities.lotNumber, q)
        )
      );
    }

    // Build the query
    const results = await db
      .select({
        id: availabilities.id,
        lotNumber: availabilities.lotNumber,
        totalQuantity: availabilities.totalQuantity,
        availableQuantity: availabilities.availableQuantity,
        reservedQuantity: availabilities.reservedQuantity,
        soldQuantity: availabilities.soldQuantity,
        minimumOrderQuantity: availabilities.minimumOrderQuantity,
        askingPrice: availabilities.askingPrice,
        confidentialMinimumPrice: availabilities.confidentialMinimumPrice,
        availableFrom: availabilities.availableFrom,
        validUntil: availabilities.validUntil,
        visibility: availabilities.visibility,
        status: availabilities.status,
        loadingStatus: availabilities.loadingStatus,
        loadingDuration: availabilities.loadingDuration,
        loadingStartDate: availabilities.loadingStartDate,
        loadingCapacity: availabilities.loadingCapacity,
        loadingRemarks: availabilities.loadingRemarks,
        createdAt: availabilities.createdAt,
        // Seller Company details (Zero Buyer data)
        sellerCompanyName: companies.name,
        sellerCompanyVerified: companies.isVerified,
        sellerTrustScore: companies.trustScore,
        // Commodity details
        commodityId: masterCommodities.id,
        commodityName: masterCommodities.name,
        commodityCode: masterCommodities.code,
        // Category & Industry details
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
        // Grade details
        gradeId: masterGrades.id,
        gradeName: masterGrades.gradeName,
        // Unit details
        unitName: masterUnits.name,
        unitSymbol: masterUnits.symbol,
        // Location details
        stateName: masterStates.name,
        districtName: masterDistricts.name,
      })
      .from(availabilities)
      .innerJoin(companies, eq(availabilities.companyId, companies.id))
      .innerJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .leftJoin(masterCategories, eq(masterCommodities.categoryId, masterCategories.id))
      .leftJoin(masterIndustries, eq(masterCategories.industryId, masterIndustries.id))
      .innerJoin(masterGrades, eq(availabilities.gradeId, masterGrades.id))
      .innerJoin(masterUnits, eq(availabilities.unitId, masterUnits.id))
      .leftJoin(masterStates, eq(availabilities.stateId, masterStates.id))
      .leftJoin(masterDistricts, eq(availabilities.districtId, masterDistricts.id))
      .where(and(...conditions))
      .orderBy(desc(availabilities.createdAt));

    // Map into clean Broker Supply View Model
    const mappedSupplyLots: BrokerSupplyLot[] = results.map((lot) => {
      const validUntilDate = new Date(lot.validUntil);
      const availableFromDate = new Date(lot.availableFrom);

      return {
        id: lot.id,
        lotNumber: lot.lotNumber || `LOT-${lot.id.slice(0, 8).toUpperCase()}`,
        sellerCompanyName: lot.sellerCompanyName || 'Registered Seller',
        sellerCompanyVerified: Boolean(lot.sellerCompanyVerified),
        sellerTrustScore: Number(lot.sellerTrustScore) || 100,
        commodityId: lot.commodityId,
        commodityName: lot.commodityName,
        commodityCode: lot.commodityCode,
        categoryName: lot.categoryName,
        industryName: lot.industryName,
        gradeId: lot.gradeId,
        gradeName: lot.gradeName || 'Standard Quality',
        totalQuantity: Number(lot.totalQuantity) || 0,
        availableQuantity: Number(lot.availableQuantity) || 0,
        reservedQuantity: Number(lot.reservedQuantity) || 0,
        soldQuantity: Number(lot.soldQuantity) || 0,
        minimumOrderQuantity: lot.minimumOrderQuantity ? Number(lot.minimumOrderQuantity) : null,
        unitName: lot.unitName,
        unitSymbol: lot.unitSymbol,
        askingPrice: Number(lot.askingPrice) || 0,
        // CRITICAL GUARDRAIL 1: Authorized for Broker
        confidentialMinimumPrice: lot.confidentialMinimumPrice
          ? Number(lot.confidentialMinimumPrice)
          : null,
        stateName: lot.stateName,
        districtName: lot.districtName,
        loadingStatus: lot.loadingStatus || 'Not Ready',
        loadingDuration: lot.loadingDuration ? Number(lot.loadingDuration) : null,
        loadingStartDate: lot.loadingStartDate ? new Date(lot.loadingStartDate).toISOString() : null,
        loadingCapacity: lot.loadingCapacity ? Number(lot.loadingCapacity) : null,
        loadingRemarks: lot.loadingRemarks,
        validUntil: validUntilDate.toISOString(),
        validUntilFormatted: format(validUntilDate, 'dd MMM yyyy'),
        availableFromFormatted: format(availableFromDate, 'dd MMM yyyy'),
        visibility: lot.visibility || 'global',
        status: lot.status,
        createdAt: new Date(lot.createdAt).toISOString(),
      };
    });

    return {
      success: true,
      data: mappedSupplyLots,
    };
  } catch (error: any) {
    console.error('Error in getBrokerSupplySearchAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to search seller supply inventory',
    };
  }
}

/**
 * Retrieves requirement summary context for the Supply Search header banner.
 * Zero Buyer PII returned.
 */
export async function getRequirementContextAction(requirementId: string) {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized' };
    }

    const res = await db
      .select({
        id: requirements.id,
        commodityId: requirements.commodityId,
        commodityName: masterCommodities.name,
        quantity: requirements.quantity,
        unitName: masterUnits.name,
        unitSymbol: masterUnits.symbol,
      })
      .from(requirements)
      .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .innerJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
      .where(eq(requirements.id, requirementId))
      .limit(1);

    if (!res || res.length === 0) {
      return { success: false, error: 'Requirement not found' };
    }

    const item = res[0];
    return {
      success: true,
      data: {
        id: item.id,
        ref: `REQ-${item.id.slice(0, 8).toUpperCase()}`,
        commodityId: item.commodityId,
        commodityName: item.commodityName,
        quantity: Number(item.quantity) || 0,
        unit: item.unitSymbol || item.unitName || 'MT',
      },
    };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch requirement context' };
  }
}

