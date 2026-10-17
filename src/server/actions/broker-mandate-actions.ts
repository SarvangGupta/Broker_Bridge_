'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  users,
  companies,
  crmContacts,
  masterCommodities,
  masterCategories,
  masterIndustries,
  masterGrades,
  masterUnits,
  masterStates,
  masterDistricts,
  requirements,
  availabilities,
  deals,
} from '@/src/server/db/schema';
import { eq, and, or, ilike, desc, sql, inArray } from 'drizzle-orm';
import { z } from 'zod';
import { differenceInHours, isPast } from 'date-fns';

// ============================================================================
// Types & Validation Schemas
// ============================================================================

import {
  createRequirementSchema,
  updateRequirementSchema,
  createOfferSchema,
  updateOfferSchema,
  type CreateRequirementInput,
  type UpdateRequirementInput,
  type CreateOfferInput,
  type UpdateOfferInput,
} from '@/src/lib/validations/broker-mandate-schema';

export type {
  CreateRequirementInput,
  UpdateRequirementInput,
  CreateOfferInput,
  UpdateOfferInput,
};


export interface BrokerRequirementItem {
  id: string;
  requirementRef: string;
  buyerCompanyId: string;
  buyerCompanyName: string;
  commodityId: string;
  commodityName: string;
  gradeId: string;
  gradeName: string;
  requestedQuantity: number;
  allocatedQuantity: number;
  remainingQuantity: number;
  fulfillmentPercentage: number;
  unitName: string;
  unitSymbol: string;
  targetPrice: number;
  deliveryTerms: string;
  targetDate: string;
  targetDateFormatted: string;
  isUrgent: boolean;
  hoursUntilTarget: number;
  isExpired: boolean;
  status: string;
  createdAt: string;
  createdAtFormatted: string;
}

export interface BrokerOfferItem {
  id: string;
  offerRef: string;
  lotNumber: string;
  sellerCompanyId: string;
  sellerCompanyName: string;
  commodityId: string;
  commodityName: string;
  gradeId: string;
  gradeName: string;
  offeredQuantity: number;
  availableQuantity: number;
  reservedQuantity: number;
  soldQuantity: number;
  unitName: string;
  unitSymbol: string;
  askingPrice: number;
  confidentialMinimumPrice: number | null;
  stateId: string;
  stateName: string;
  districtId: string;
  districtName: string;
  loadingStatus: string;
  loadingRemarks: string | null;
  availableFrom: string;
  validUntil: string;
  validUntilFormatted: string;
  isExpired: boolean;
  version: number;
  status: string;
  createdAt: string;
}

export interface TradeMasterData {
  buyerCompanies: Array<{ id: string; name: string }>;
  sellerCompanies: Array<{ id: string; name: string }>;
  commodities: Array<{ id: string; name: string; categoryName?: string | null }>;
  grades: Array<{ id: string; commodityId: string; name: string }>;
  units: Array<{ id: string; name: string; symbol: string }>;
  states: Array<{ id: string; name: string }>;
  districts: Array<{ id: string; stateId: string; name: string }>;
}

// ============================================================================
// Internal Auth & Role Verification Helper
// ============================================================================

type AuthResult =
  | { success: true; brokerId: string; isAdmin: boolean; dbUser: typeof users.$inferSelect }
  | { success: false; error: string };

async function getAuthenticatedBroker(): Promise<AuthResult> {
  let authUser = null;
  let authError = null;

  try {
    const supabase = await createClient();
    const res = await supabase.auth.getUser();
    authUser = res.data.user;
    authError = res.error;
  } catch (_e) {
    // Supabase cookies outside request context (e.g. CLI test environment)
  }

  if (authError || !authUser) {
    return { success: false, error: 'Unauthorized: Valid broker session required' };
  }

  const dbUser = await db.query.users.findFirst({
    where: eq(users.id, authUser.id),
  });

  if (!dbUser) {
    return { success: false, error: 'Unauthorized: Broker user profile not found' };
  }

  const role = (dbUser.role || '').toLowerCase();
  const isAdmin = role === 'admin';
  const isBroker = role === 'broker';

  if (!isAdmin && !isBroker) {
    return { success: false, error: 'Forbidden: Broker or admin permissions required' };
  }

  return {
    success: true,
    brokerId: dbUser.id,
    isAdmin,
    dbUser,
  };
}

// ============================================================================
// Action: Form Master Data Dropdowns
// ============================================================================

export async function getBrokerTradeFormMasterDataAction(): Promise<{
  success: boolean;
  data?: TradeMasterData;
  error?: string;
}> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;

    // 1. Fetch authorized buyer & seller companies from caller's CRM contacts
    const crmRows = await db
      .select({
        companyId: companies.id,
        companyName: companies.name,
        role: users.role,
      })
      .from(crmContacts)
      .innerJoin(users, eq(users.id, crmContacts.userId))
      .innerJoin(companies, eq(companies.id, crmContacts.companyId))
      .where(isAdmin ? sql`true` : eq(crmContacts.brokerId, brokerId));

    const buyerCompaniesMap = new Map<string, string>();
    const sellerCompaniesMap = new Map<string, string>();

    for (const r of crmRows) {
      const role = (r.role || '').toLowerCase();
      if (role === 'buyer' || role === 'both' || role === 'admin') {
        buyerCompaniesMap.set(r.companyId, r.companyName);
      }
      if (role === 'seller' || role === 'both' || role === 'admin') {
        sellerCompaniesMap.set(r.companyId, r.companyName);
      }
    }

    // Fallback: If CRM contacts are empty, fetch all verified companies for authorized brokers
    if (buyerCompaniesMap.size === 0 || sellerCompaniesMap.size === 0) {
      const allCompanies = await db.select({ id: companies.id, name: companies.name }).from(companies).limit(50);
      for (const c of allCompanies) {
        if (buyerCompaniesMap.size < 10) buyerCompaniesMap.set(c.id, c.name);
        if (sellerCompaniesMap.size < 10) sellerCompaniesMap.set(c.id, c.name);
      }
    }

    // 2. Fetch Master Commodities, Grades, Units, States, Districts
    const [commoditiesRaw, gradesRaw, unitsRaw, statesRaw, districtsRaw] = await Promise.all([
      db
        .select({
          id: masterCommodities.id,
          name: masterCommodities.name,
          categoryName: masterCategories.name,
        })
        .from(masterCommodities)
        .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
        .where(eq(masterCommodities.status, true)),

      db
        .select({
          id: masterGrades.id,
          commodityId: masterGrades.commodityId,
          name: masterGrades.gradeName,
        })
        .from(masterGrades),

      db
        .select({
          id: masterUnits.id,
          name: masterUnits.name,
          symbol: masterUnits.symbol,
        })
        .from(masterUnits),

      db.select({ id: masterStates.id, name: masterStates.name }).from(masterStates),
      db.select({ id: masterDistricts.id, stateId: masterDistricts.stateId, name: masterDistricts.name }).from(masterDistricts),
    ]);

    return {
      success: true,
      data: {
        buyerCompanies: Array.from(buyerCompaniesMap.entries()).map(([id, name]) => ({ id, name })),
        sellerCompanies: Array.from(sellerCompaniesMap.entries()).map(([id, name]) => ({ id, name })),
        commodities: commoditiesRaw,
        grades: gradesRaw.map((g) => ({
          id: g.id,
          commodityId: g.commodityId || '',
          name: g.name,
        })),
        units: unitsRaw.map((u) => ({
          id: u.id,
          name: u.name,
          symbol: u.symbol || u.name,
        })),
        states: statesRaw,
        districts: districtsRaw.map((d) => ({
          id: d.id,
          stateId: d.stateId || '',
          name: d.name,
        })),
      },
    };
  } catch (error: any) {
    console.error('Error in getBrokerTradeFormMasterDataAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to load master dropdown data.',
    };
  }
}

// ============================================================================
// Action: Buyer Requirements Management
// ============================================================================

export async function getBrokerRequirementsAction(): Promise<{
  success: boolean;
  data?: {
    requirements: BrokerRequirementItem[];
    stats: {
      totalRequirements: number;
      openCount: number;
      partiallyAllocatedCount: number;
      totalRequestedVolumeMT: number;
      expiringSoonCount: number;
    };
  };
  error?: string;
}> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;

    const rows = await db
      .select({
        id: requirements.id,
        quantity: requirements.quantity,
        fulfilledQuantity: requirements.fulfilledQuantity,
        targetPrice: requirements.targetPrice,
        deliveryTermsId: requirements.deliveryTermsId,
        targetDate: requirements.targetDate,
        status: requirements.status,
        createdAt: requirements.createdAt,
        companyId: companies.id,
        buyerCompanyName: companies.name,
        commodityId: masterCommodities.id,
        commodityName: masterCommodities.name,
        gradeId: masterGrades.id,
        gradeName: masterGrades.gradeName,
        unitName: masterUnits.name,
        unitSymbol: masterUnits.symbol,
      })
      .from(requirements)
      .innerJoin(companies, eq(companies.id, requirements.companyId))
      .innerJoin(masterCommodities, eq(masterCommodities.id, requirements.commodityId))
      .leftJoin(masterGrades, eq(masterGrades.id, requirements.gradeId))
      .leftJoin(masterUnits, eq(masterUnits.id, requirements.unitId))
      .where(isAdmin ? sql`true` : eq(requirements.brokerId, brokerId))
      .orderBy(desc(requirements.createdAt));

    let totalRequestedVolumeMT = 0;
    let openCount = 0;
    let partiallyAllocatedCount = 0;
    let expiringSoonCount = 0;

    const now = new Date();

    const items: BrokerRequirementItem[] = rows.map((r) => {
      const qty = Number(r.quantity) || 0;
      const fulfilled = Number(r.fulfilledQuantity) || 0;
      const remaining = Math.max(0, qty - fulfilled);
      const percentage = qty > 0 ? Math.min(100, Math.round((fulfilled / qty) * 100)) : 0;
      const targetDate = r.targetDate ? new Date(r.targetDate) : new Date();
      const hoursUntil = differenceInHours(targetDate, now);
      const isExpired = isPast(targetDate);
      const isUrgent = hoursUntil <= 48 && hoursUntil > 0;

      totalRequestedVolumeMT += qty;
      if (r.status === 'Open') openCount++;
      if (r.status === 'Partially Fulfilled' || (fulfilled > 0 && fulfilled < qty)) {
        partiallyAllocatedCount++;
      }
      if (isUrgent && r.status === 'Open') expiringSoonCount++;

      const shortId = r.id.slice(0, 6).toUpperCase();

      return {
        id: r.id,
        requirementRef: `#REQ-${shortId}`,
        buyerCompanyId: r.companyId,
        buyerCompanyName: r.buyerCompanyName,
        commodityId: r.commodityId,
        commodityName: r.commodityName,
        gradeId: r.gradeId || '',
        gradeName: r.gradeName || 'Standard Grade',
        requestedQuantity: qty,
        allocatedQuantity: fulfilled,
        remainingQuantity: remaining,
        fulfillmentPercentage: percentage,
        unitName: r.unitName || 'Metric Tonne',
        unitSymbol: r.unitSymbol || 'MT',
        targetPrice: Number(r.targetPrice) || 0,
        deliveryTerms: r.deliveryTermsId || 'FOR Destination',
        targetDate: targetDate.toISOString(),
        targetDateFormatted: targetDate.toLocaleDateString('en-IN', {
          day: 'numeric',
          month: 'short',
          year: 'numeric',
        }),
        isUrgent,
        hoursUntilTarget: hoursUntil,
        isExpired,
        status: isExpired && r.status === 'Open' ? 'Expired' : r.status,
        createdAt: r.createdAt ? new Date(r.createdAt).toISOString() : new Date().toISOString(),
        createdAtFormatted: r.createdAt
          ? new Date(r.createdAt).toLocaleDateString('en-IN', {
              day: 'numeric',
              month: 'short',
            })
          : '',
      };
    });

    return {
      success: true,
      data: {
        requirements: items,
        stats: {
          totalRequirements: items.length,
          openCount,
          partiallyAllocatedCount,
          totalRequestedVolumeMT: Math.round(totalRequestedVolumeMT),
          expiringSoonCount,
        },
      },
    };
  } catch (error: any) {
    console.error('Error in getBrokerRequirementsAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to fetch requirements.',
    };
  }
}

export async function createBrokerRequirementAction(
  rawInput: CreateRequirementInput
): Promise<{ success: boolean; requirementId?: string; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId } = auth;
    const parsed = createRequirementSchema.safeParse(rawInput);
    if (!parsed.success) {
      return {
        success: false,
        error: parsed.error.issues[0]?.message || 'Validation failed for requirement creation',
      };
    }

    const {
      companyId,
      commodityId,
      gradeId,
      quantity,
      unitId,
      targetPrice,
      deliveryTermsId,
      targetDate,
    } = parsed.data;

    // Verify future or today date
    const dateObj = new Date(targetDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (dateObj < today) {
      return {
        success: false,
        error: 'Required delivery date must be today or in the future',
      };
    }

    // Insert into requirements
    const [inserted] = await db
      .insert(requirements)
      .values({
        companyId,
        commodityId,
        gradeId,
        quantity,
        unitId,
        targetPrice,
        deliveryTermsId,
        targetDate: dateObj,
        brokerId,
        status: 'Open',
        fulfilledQuantity: 0,
        visibility: 'global',
      })
      .returning({ id: requirements.id });

    return {
      success: true,
      requirementId: inserted.id,
    };
  } catch (error: any) {
    console.error('Error in createBrokerRequirementAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to create requirement.',
    };
  }
}

export async function updateBrokerRequirementAction(
  id: string,
  rawInput: UpdateRequirementInput
): Promise<{ success: boolean; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;

    const existing = await db.query.requirements.findFirst({
      where: eq(requirements.id, id),
    });

    if (!existing) {
      return { success: false, error: 'Requirement not found' };
    }

    if (!isAdmin && existing.brokerId !== brokerId) {
      return { success: false, error: 'Forbidden: You cannot modify another broker\'s requirement' };
    }

    if (existing.status === 'Fulfilled' || existing.status === 'Closed') {
      return { success: false, error: `Cannot edit requirement in '${existing.status}' status` };
    }

    const parsed = updateRequirementSchema.safeParse(rawInput);
    if (!parsed.success) {
      return {
        success: false,
        error: parsed.error.issues[0]?.message || 'Validation failed for requirement update',
      };
    }

    // Quantity Integrity Guard: cannot reduce below allocated quantity
    const fulfilled = Number(existing.fulfilledQuantity) || 0;
    if (parsed.data.quantity < fulfilled) {
      return {
        success: false,
        error: `Requested quantity cannot be less than already allocated quantity (${fulfilled} MT)`,
      };
    }

    await db
      .update(requirements)
      .set({
        commodityId: parsed.data.commodityId,
        gradeId: parsed.data.gradeId,
        quantity: parsed.data.quantity,
        unitId: parsed.data.unitId,
        targetPrice: parsed.data.targetPrice,
        deliveryTermsId: parsed.data.deliveryTermsId,
        targetDate: new Date(parsed.data.targetDate),
        status: parsed.data.status || existing.status,
      })
      .where(eq(requirements.id, id));

    return { success: true };
  } catch (error: any) {
    console.error('Error in updateBrokerRequirementAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to update requirement.',
    };
  }
}

export async function cancelBrokerRequirementAction(
  id: string,
  reason: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;
    if (!reason || reason.trim().length < 3) {
      return { success: false, error: 'A valid cancellation reason is required' };
    }

    const existing = await db.query.requirements.findFirst({
      where: eq(requirements.id, id),
    });

    if (!existing) {
      return { success: false, error: 'Requirement not found' };
    }

    if (!isAdmin && existing.brokerId !== brokerId) {
      return { success: false, error: 'Forbidden: You cannot cancel another broker\'s requirement' };
    }

    await db
      .update(requirements)
      .set({
        status: 'Cancelled',
      })
      .where(eq(requirements.id, id));

    return { success: true };
  } catch (error: any) {
    console.error('Error in cancelBrokerRequirementAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to cancel requirement.',
    };
  }
}

export async function renewBrokerRequirementAction(
  id: string,
  newTargetDate: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;
    const dateObj = new Date(newTargetDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (dateObj < today) {
      return { success: false, error: 'Extended date must be in the future' };
    }

    const existing = await db.query.requirements.findFirst({
      where: eq(requirements.id, id),
    });

    if (!existing) {
      return { success: false, error: 'Requirement not found' };
    }

    if (!isAdmin && existing.brokerId !== brokerId) {
      return { success: false, error: 'Forbidden: You cannot renew another broker\'s requirement' };
    }

    await db
      .update(requirements)
      .set({
        status: 'Open',
        targetDate: dateObj,
      })
      .where(eq(requirements.id, id));

    return { success: true };
  } catch (error: any) {
    console.error('Error in renewBrokerRequirementAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to renew requirement.',
    };
  }
}

// ============================================================================
// Action: Seller Offers (Availabilities) Management
// ============================================================================

export async function getBrokerSellerOffersAction(): Promise<{
  success: boolean;
  data?: {
    offers: BrokerOfferItem[];
    stats: {
      totalOffers: number;
      activeCount: number;
      partiallyAvailableCount: number;
      totalAvailableVolumeMT: number;
      expiringSoonCount: number;
    };
  };
  error?: string;
}> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;

    const rows = await db
      .select({
        id: availabilities.id,
        lotNumber: availabilities.lotNumber,
        totalQuantity: availabilities.totalQuantity,
        availableQuantity: availabilities.availableQuantity,
        reservedQuantity: availabilities.reservedQuantity,
        soldQuantity: availabilities.soldQuantity,
        askingPrice: availabilities.askingPrice,
        confidentialMinimumPrice: availabilities.confidentialMinimumPrice,
        loadingStatus: availabilities.loadingStatus,
        loadingRemarks: availabilities.loadingRemarks,
        availableFrom: availabilities.availableFrom,
        validUntil: availabilities.validUntil,
        version: availabilities.version,
        status: availabilities.status,
        createdAt: availabilities.createdAt,
        companyId: companies.id,
        sellerCompanyName: companies.name,
        commodityId: masterCommodities.id,
        commodityName: masterCommodities.name,
        gradeId: masterGrades.id,
        gradeName: masterGrades.gradeName,
        unitName: masterUnits.name,
        unitSymbol: masterUnits.symbol,
        stateId: masterStates.id,
        stateName: masterStates.name,
        districtId: masterDistricts.id,
        districtName: masterDistricts.name,
      })
      .from(availabilities)
      .innerJoin(companies, eq(companies.id, availabilities.companyId))
      .innerJoin(masterCommodities, eq(masterCommodities.id, availabilities.commodityId))
      .leftJoin(masterGrades, eq(masterGrades.id, availabilities.gradeId))
      .leftJoin(masterUnits, eq(masterUnits.id, availabilities.unitId))
      .leftJoin(masterStates, eq(masterStates.id, availabilities.stateId))
      .leftJoin(masterDistricts, eq(masterDistricts.id, availabilities.districtId))
      .where(isAdmin ? sql`true` : or(eq(availabilities.brokerId, brokerId), eq(availabilities.visibility, 'global')))
      .orderBy(desc(availabilities.createdAt));

    let totalAvailableVolumeMT = 0;
    let activeCount = 0;
    let partiallyAvailableCount = 0;
    let expiringSoonCount = 0;

    const now = new Date();

    const items: BrokerOfferItem[] = rows.map((r) => {
      const totalQty = Number(r.totalQuantity) || 0;
      const availQty = Number(r.availableQuantity) || 0;
      const resQty = Number(r.reservedQuantity) || 0;
      const soldQty = Number(r.soldQuantity) || 0;
      const validUntilDate = r.validUntil ? new Date(r.validUntil) : new Date();
      const isExpired = isPast(validUntilDate);
      const hoursUntil = differenceInHours(validUntilDate, now);
      const isExpiringSoon = hoursUntil <= 48 && hoursUntil > 0;

      totalAvailableVolumeMT += availQty;
      if (r.status === 'Open' || r.status === 'Active') activeCount++;
      if (availQty < totalQty && availQty > 0) partiallyAvailableCount++;
      if (isExpiringSoon && (r.status === 'Open' || r.status === 'Active')) expiringSoonCount++;

      const shortId = r.id.slice(0, 6).toUpperCase();

      return {
        id: r.id,
        offerRef: `#OFF-${shortId}`,
        lotNumber: r.lotNumber || `LOT-${shortId}`,
        sellerCompanyId: r.companyId,
        sellerCompanyName: r.sellerCompanyName,
        commodityId: r.commodityId,
        commodityName: r.commodityName,
        gradeId: r.gradeId || '',
        gradeName: r.gradeName || 'Standard Lot',
        offeredQuantity: totalQty,
        availableQuantity: availQty,
        reservedQuantity: resQty,
        soldQuantity: soldQty,
        unitName: r.unitName || 'Metric Tonne',
        unitSymbol: r.unitSymbol || 'MT',
        askingPrice: Number(r.askingPrice) || 0,
        confidentialMinimumPrice: r.confidentialMinimumPrice ? Number(r.confidentialMinimumPrice) : null,
        stateId: r.stateId || '',
        stateName: r.stateName || 'Rajasthan',
        districtId: r.districtId || '',
        districtName: r.districtName || 'Jaipur Mandi',
        loadingStatus: r.loadingStatus || 'Not Ready',
        loadingRemarks: r.loadingRemarks,
        availableFrom: r.availableFrom ? new Date(r.availableFrom).toISOString() : new Date().toISOString(),
        validUntil: validUntilDate.toISOString(),
        validUntilFormatted: validUntilDate.toLocaleDateString('en-IN', {
          day: 'numeric',
          month: 'short',
          year: 'numeric',
        }),
        isExpired,
        version: r.version || 1,
        status: isExpired && (r.status === 'Open' || r.status === 'Active') ? 'Expired' : r.status,
        createdAt: r.createdAt ? new Date(r.createdAt).toISOString() : new Date().toISOString(),
      };
    });

    return {
      success: true,
      data: {
        offers: items,
        stats: {
          totalOffers: items.length,
          activeCount,
          partiallyAvailableCount,
          totalAvailableVolumeMT: Math.round(totalAvailableVolumeMT),
          expiringSoonCount,
        },
      },
    };
  } catch (error: any) {
    console.error('Error in getBrokerSellerOffersAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to fetch seller offers.',
    };
  }
}

export async function createBrokerSellerOfferAction(
  rawInput: CreateOfferInput
): Promise<{ success: boolean; offerId?: string; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId } = auth;
    const parsed = createOfferSchema.safeParse(rawInput);
    if (!parsed.success) {
      return {
        success: false,
        error: parsed.error.issues[0]?.message || 'Validation failed for offer creation',
      };
    }

    const {
      companyId,
      commodityId,
      gradeId,
      quantity,
      unitId,
      askingPrice,
      confidentialMinimumPrice,
      stateId,
      districtId,
      availableFrom,
      validUntil,
      loadingStatus,
      loadingRemarks,
    } = parsed.data;

    const fromDate = new Date(availableFrom);
    const untilDate = new Date(validUntil);
    if (untilDate <= fromDate) {
      return {
        success: false,
        error: 'Validity expiration date must be after available-from date',
      };
    }

    const lotNumber = `LOT-${Date.now().toString().slice(-6)}`;

    const [inserted] = await db
      .insert(availabilities)
      .values({
        companyId,
        commodityId,
        gradeId,
        quantity: Math.round(quantity), // Sprint 6 compatibility
        totalQuantity: quantity.toString(),
        availableQuantity: quantity.toString(),
        reservedQuantity: '0',
        soldQuantity: '0',
        unitId,
        price: askingPrice.toString(),
        askingPrice: askingPrice.toString(),
        confidentialMinimumPrice: confidentialMinimumPrice ? confidentialMinimumPrice.toString() : null,
        stateId,
        districtId,
        availableFrom: fromDate,
        validUntil: untilDate,
        loadingStatus,
        loadingRemarks,
        brokerId,
        lotNumber,
        status: 'Open',
        visibility: 'global',
        version: 1,
      })
      .returning({ id: availabilities.id });

    return {
      success: true,
      offerId: inserted.id,
    };
  } catch (error: any) {
    console.error('Error in createBrokerSellerOfferAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to create seller offer.',
    };
  }
}

export async function updateBrokerSellerOfferAction(
  id: string,
  rawInput: UpdateOfferInput
): Promise<{ success: boolean; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;

    const existing = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, id),
    });

    if (!existing) {
      return { success: false, error: 'Seller offer not found' };
    }

    if (!isAdmin && existing.brokerId !== brokerId) {
      return { success: false, error: 'Forbidden: You cannot modify another broker\'s offer' };
    }

    const parsed = updateOfferSchema.safeParse(rawInput);
    if (!parsed.success) {
      return {
        success: false,
        error: parsed.error.issues[0]?.message || 'Validation failed for offer update',
      };
    }

    // Optimistic Concurrency Guard
    if (parsed.data.expectedVersion && existing.version !== parsed.data.expectedVersion) {
      return {
        success: false,
        error: 'Concurrency conflict: This offer was updated by another session. Please refresh and retry.',
      };
    }

    // Quantity Integrity Guard
    const reserved = Number(existing.reservedQuantity) || 0;
    const sold = Number(existing.soldQuantity) || 0;
    const committed = reserved + sold;

    if (parsed.data.quantity < committed) {
      return {
        success: false,
        error: `Total quantity cannot be reduced below committed volume (${committed} MT)`,
      };
    }

    const newAvailable = Math.max(0, parsed.data.quantity - committed);

    await db
      .update(availabilities)
      .set({
        commodityId: parsed.data.commodityId,
        gradeId: parsed.data.gradeId,
        totalQuantity: parsed.data.quantity.toString(),
        availableQuantity: newAvailable.toString(),
        unitId: parsed.data.unitId,
        askingPrice: parsed.data.askingPrice.toString(),
        confidentialMinimumPrice: parsed.data.confidentialMinimumPrice
          ? parsed.data.confidentialMinimumPrice.toString()
          : null,
        stateId: parsed.data.stateId,
        districtId: parsed.data.districtId,
        availableFrom: new Date(parsed.data.availableFrom),
        validUntil: new Date(parsed.data.validUntil),
        loadingStatus: parsed.data.loadingStatus,
        loadingRemarks: parsed.data.loadingRemarks,
        status: parsed.data.status || existing.status,
        version: (existing.version || 1) + 1,
      })
      .where(eq(availabilities.id, id));

    return { success: true };
  } catch (error: any) {
    console.error('Error in updateBrokerSellerOfferAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to update seller offer.',
    };
  }
}

export async function cancelBrokerSellerOfferAction(
  id: string,
  reason: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;
    if (!reason || reason.trim().length < 3) {
      return { success: false, error: 'A valid cancellation reason is required' };
    }

    const existing = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, id),
    });

    if (!existing) {
      return { success: false, error: 'Seller offer not found' };
    }

    if (!isAdmin && existing.brokerId !== brokerId) {
      return { success: false, error: 'Forbidden: You cannot cancel another broker\'s offer' };
    }

    // Check if reserved
    const reserved = Number(existing.reservedQuantity) || 0;
    if (reserved > 0) {
      return {
        success: false,
        error: `Cannot cancel offer with active reserved quantities (${reserved} MT)`,
      };
    }

    await db
      .update(availabilities)
      .set({
        status: 'Unavailable',
      })
      .where(eq(availabilities.id, id));

    return { success: true };
  } catch (error: any) {
    console.error('Error in cancelBrokerSellerOfferAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to cancel offer.',
    };
  }
}

export async function renewBrokerSellerOfferAction(
  id: string,
  newValidUntil: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;
    const dateObj = new Date(newValidUntil);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (dateObj < today) {
      return { success: false, error: 'Extended validity date must be in the future' };
    }

    const existing = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, id),
    });

    if (!existing) {
      return { success: false, error: 'Seller offer not found' };
    }

    if (!isAdmin && existing.brokerId !== brokerId) {
      return { success: false, error: 'Forbidden: You cannot renew another broker\'s offer' };
    }

    await db
      .update(availabilities)
      .set({
        status: 'Open',
        validUntil: dateObj,
        version: (existing.version || 1) + 1,
      })
      .where(eq(availabilities.id, id));

    return { success: true };
  } catch (error: any) {
    console.error('Error in renewBrokerSellerOfferAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to renew seller offer.',
    };
  }
}
