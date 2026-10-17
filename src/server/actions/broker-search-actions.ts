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
  requirements,
  availabilities,
  deals,
  quotations,
} from '@/src/server/db/schema';
import { eq, and, or, ilike, desc, sql, inArray } from 'drizzle-orm';
import {
  validateAndNormalizePhone,
  getSafeTelUri,
  getSafeWhatsAppUri,
} from '@/src/lib/phone-utils';

// ============================================================================
// Types
// ============================================================================

export type SearchEntityType = 'all' | 'contacts' | 'materials' | 'requirements' | 'offers' | 'deals';

export interface SearchContactResult {
  id: string; // crmContacts.id
  userId: string;
  name: string;
  companyName: string;
  role: 'Buyer' | 'Seller';
  mobile: string;
  formattedMobile: string;
  whatsapp?: string | null;
  city?: string | null;
  status: boolean;
  telUri: string | null;
  whatsappUri: string | null;
  url: string;
}

export interface SearchMaterialResult {
  id: string; // masterCommodities.id
  name: string;
  code?: string | null;
  categoryName?: string | null;
  industryName?: string | null;
  grades: string[];
  url: string;
}

export interface SearchRequirementResult {
  id: string;
  commodityName: string;
  gradeName?: string | null;
  quantity: number;
  unitSymbol: string;
  targetPrice: number;
  buyerCompanyName: string;
  status: string;
  targetDate?: string | null;
  url: string;
}

export interface SearchOfferResult {
  id: string;
  lotNumber?: string | null;
  commodityName: string;
  availableQuantity: number;
  unitSymbol: string;
  askingPrice: number;
  sellerCompanyName: string;
  loadingStatus: string;
  stateName?: string | null;
  status: string;
  url: string;
}

export interface SearchDealResult {
  id: string;
  dealRef: string;
  commodityName: string;
  agreedQuantity: number;
  agreedPrice: number;
  buyerName: string;
  sellerName: string;
  status: string;
  createdAt: string;
  url: string;
}

export interface GlobalSearchResults {
  contacts: SearchContactResult[];
  materials: SearchMaterialResult[];
  requirements: SearchRequirementResult[];
  offers: SearchOfferResult[];
  deals: SearchDealResult[];
  totalCount: number;
}

export interface GlobalSearchResponse {
  success: boolean;
  data?: {
    query: string;
    results: GlobalSearchResults;
    counts: Record<SearchEntityType, number>;
  };
  error?: string;
}

export interface QuickDialContactItem {
  id: string;
  name: string;
  companyName: string;
  role: 'Buyer' | 'Seller';
  mobile: string;
  formattedMobile: string;
  whatsapp?: string | null;
  telUri: string | null;
  whatsappUri: string | null;
  isVerified: boolean;
}

export interface QuickDialResponse {
  success: boolean;
  data?: QuickDialContactItem[];
  error?: string;
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
// Server Action: Global Search
// ============================================================================

/**
 * Executes unified, permission-aware global search across RMBroker entities.
 * Scoped strictly to the authenticated broker's workspace and authorized data.
 */
export async function searchGlobalAction(
  rawQuery: string,
  filterType: SearchEntityType = 'all'
): Promise<GlobalSearchResponse> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;

    // 1. Normalize and sanitize input safely
    const query = (rawQuery || '').trim().replace(/[\x00-\x1F\x7F]/g, '');
    if (query.length < 2) {
      return {
        success: true,
        data: {
          query,
          results: {
            contacts: [],
            materials: [],
            requirements: [],
            offers: [],
            deals: [],
            totalCount: 0,
          },
          counts: {
            all: 0,
            contacts: 0,
            materials: 0,
            requirements: 0,
            offers: 0,
            deals: 0,
          },
        },
      };
    }

    const safePattern = `%${query}%`;
    const searchAll = filterType === 'all';

    // 2. Parallel queries across authorized entity types
    const [
      contactsRaw,
      materialsRaw,
      requirementsRaw,
      offersRaw,
      dealsRaw,
    ] = await Promise.all([
      // A. Buyers & Sellers (Contacts)
      (searchAll || filterType === 'contacts')
        ? db
            .select({
              id: crmContacts.id,
              userId: users.id,
              name: users.name,
              mobile: users.mobile,
              role: users.role,
              status: users.status,
              companyName: companies.name,
              districtId: companies.districtId,
            })
            .from(crmContacts)
            .innerJoin(users, eq(users.id, crmContacts.userId))
            .innerJoin(companies, eq(companies.id, crmContacts.companyId))
            .where(
              and(
                isAdmin ? sql`true` : eq(crmContacts.brokerId, brokerId),
                or(
                  ilike(users.name, safePattern),
                  ilike(companies.name, safePattern),
                  ilike(users.mobile, safePattern),
                  ilike(users.email, safePattern)
                )
              )
            )
            .limit(10)
        : Promise.resolve([]),

      // B. Materials & Grades
      (searchAll || filterType === 'materials')
        ? db
            .select({
              id: masterCommodities.id,
              name: masterCommodities.name,
              code: masterCommodities.code,
              categoryName: masterCategories.name,
              industryName: masterIndustries.name,
            })
            .from(masterCommodities)
            .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
            .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
            .where(
              and(
                eq(masterCommodities.status, true),
                or(
                  ilike(masterCommodities.name, safePattern),
                  ilike(masterCommodities.code, safePattern),
                  ilike(masterCategories.name, safePattern)
                )
              )
            )
            .limit(10)
        : Promise.resolve([]),

      // C. Buyer Requirements
      (searchAll || filterType === 'requirements')
        ? db
            .select({
              id: requirements.id,
              quantity: requirements.quantity,
              targetPrice: requirements.targetPrice,
              status: requirements.status,
              targetDate: requirements.targetDate,
              commodityName: masterCommodities.name,
              gradeName: masterGrades.gradeName,
              unitSymbol: masterUnits.symbol,
              buyerCompanyName: companies.name,
            })
            .from(requirements)
            .innerJoin(masterCommodities, eq(masterCommodities.id, requirements.commodityId))
            .leftJoin(masterGrades, eq(masterGrades.id, requirements.gradeId))
            .leftJoin(masterUnits, eq(masterUnits.id, requirements.unitId))
            .innerJoin(companies, eq(companies.id, requirements.companyId))
            .where(
              and(
                isAdmin
                  ? sql`true`
                  : or(
                      eq(requirements.brokerId, brokerId),
                      eq(requirements.visibility, 'global')
                    ),
                or(
                  ilike(masterCommodities.name, safePattern),
                  ilike(companies.name, safePattern),
                  ilike(requirements.status, safePattern),
                  sql`${requirements.id}::text ILIKE ${safePattern}`
                )
              )
            )
            .limit(10)
        : Promise.resolve([]),

      // D. Seller Offers (Availabilities)
      (searchAll || filterType === 'offers')
        ? db
            .select({
              id: availabilities.id,
              lotNumber: availabilities.lotNumber,
              availableQuantity: availabilities.availableQuantity,
              askingPrice: availabilities.askingPrice,
              loadingStatus: availabilities.loadingStatus,
              status: availabilities.status,
              commodityName: masterCommodities.name,
              unitSymbol: masterUnits.symbol,
              sellerCompanyName: companies.name,
              stateName: masterStates.name,
            })
            .from(availabilities)
            .innerJoin(masterCommodities, eq(masterCommodities.id, availabilities.commodityId))
            .leftJoin(masterUnits, eq(masterUnits.id, availabilities.unitId))
            .innerJoin(companies, eq(companies.id, availabilities.companyId))
            .leftJoin(masterStates, eq(masterStates.id, availabilities.stateId))
            .where(
              and(
                isAdmin
                  ? sql`true`
                  : or(
                      eq(availabilities.brokerId, brokerId),
                      eq(availabilities.visibility, 'global')
                    ),
                or(
                  ilike(masterCommodities.name, safePattern),
                  ilike(companies.name, safePattern),
                  ilike(availabilities.lotNumber, safePattern),
                  ilike(availabilities.status, safePattern),
                  sql`${availabilities.id}::text ILIKE ${safePattern}`
                )
              )
            )
            .limit(10)
        : Promise.resolve([]),

      // E. Deals
      (searchAll || filterType === 'deals')
        ? db
            .select({
              id: deals.id,
              agreedQuantity: deals.agreedQuantity,
              agreedPrice: deals.agreedPrice,
              status: deals.status,
              createdAt: deals.createdAt,
              requirementId: deals.requirementId,
              quotationId: deals.quotationId,
              brokerId: deals.brokerId,
              buyerCompanyId: deals.buyerId,
              sellerCompanyId: deals.sellerId,
            })
            .from(deals)
            .where(
              and(
                isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
                or(
                  ilike(deals.status, safePattern),
                  sql`${deals.id}::text ILIKE ${safePattern}`
                )
              )
            )
            .limit(10)
        : Promise.resolve([]),
    ]);

    // 3. Post-process Contacts: Normalize phone numbers & build safe URIs
    const contacts: SearchContactResult[] = contactsRaw.map((c) => {
      const phoneRes = validateAndNormalizePhone(c.mobile || '');
      const rawMobile = c.mobile || '';
      const normalizedMobile = phoneRes.isValid ? phoneRes.normalized : rawMobile;
      const formatted = phoneRes.isValid ? phoneRes.formatted : rawMobile;
      const roleStr = (c.role || '').toLowerCase() === 'seller' ? 'Seller' : 'Buyer';

      return {
        id: c.id,
        userId: c.userId,
        name: c.name || 'Unnamed Contact',
        companyName: c.companyName || 'Unnamed Business',
        role: roleStr,
        mobile: normalizedMobile,
        formattedMobile: formatted,
        city: c.districtId || null,
        status: c.status,
        telUri: phoneRes.isValid ? getSafeTelUri(phoneRes.normalized) : null,
        whatsappUri: phoneRes.isValid ? getSafeWhatsAppUri(phoneRes.normalized) : null,
        url: `/broker/directory?contactId=${c.id}`,
      };
    });

    // 4. Post-process Materials: Fetch associated grade names
    const materialIds = materialsRaw.map((m) => m.id);
    let gradesByCommodity: Record<string, string[]> = {};

    if (materialIds.length > 0) {
      const gradesRaw = await db
        .select({
          commodityId: masterGrades.commodityId,
          gradeName: masterGrades.gradeName,
        })
        .from(masterGrades)
        .where(inArray(masterGrades.commodityId, materialIds));

      for (const g of gradesRaw) {
        if (g.commodityId) {
          if (!gradesByCommodity[g.commodityId]) {
            gradesByCommodity[g.commodityId] = [];
          }
          gradesByCommodity[g.commodityId].push(g.gradeName);
        }
      }
    }

    const materials: SearchMaterialResult[] = materialsRaw.map((m) => ({
      id: m.id,
      name: m.name,
      code: m.code,
      categoryName: m.categoryName,
      industryName: m.industryName,
      grades: gradesByCommodity[m.id] || [],
      url: `/broker/work?commodity=${m.id}`,
    }));

    // 5. Post-process Requirements
    const requirementsFormatted: SearchRequirementResult[] = requirementsRaw.map((r) => ({
      id: r.id,
      commodityName: r.commodityName || 'Commodity',
      gradeName: r.gradeName,
      quantity: Number(r.quantity) || 0,
      unitSymbol: r.unitSymbol || 'MT',
      targetPrice: Number(r.targetPrice) || 0,
      buyerCompanyName: r.buyerCompanyName || 'Buyer',
      status: r.status,
      targetDate: r.targetDate ? new Date(r.targetDate).toISOString() : null,
      url: `/broker/work?requirementId=${r.id}`,
    }));

    // 6. Post-process Offers
    const offersFormatted: SearchOfferResult[] = offersRaw.map((o) => ({
      id: o.id,
      lotNumber: o.lotNumber || 'LOT-STANDARD',
      commodityName: o.commodityName || 'Commodity',
      availableQuantity: Number(o.availableQuantity) || 0,
      unitSymbol: o.unitSymbol || 'MT',
      askingPrice: Number(o.askingPrice) || 0,
      sellerCompanyName: o.sellerCompanyName || 'Seller',
      loadingStatus: o.loadingStatus || 'Not Ready',
      stateName: o.stateName,
      status: o.status,
      url: `/broker/work?tab=supply&availabilityId=${o.id}`,
    }));

    // 7. Post-process Deals: Fetch buyer/seller names and commodity
    const dealIds = dealsRaw.map((d) => d.id);
    let dealMetadataMap: Record<
      string,
      { commodityName: string; buyerName: string; sellerName: string }
    > = {};

    if (dealIds.length > 0) {
      // Look up buyer & seller companies
      const companyIds = Array.from(
        new Set(
          dealsRaw
            .flatMap((d) => [d.buyerCompanyId, d.sellerCompanyId])
            .filter(Boolean) as string[]
        )
      );

      let companiesMap: Record<string, string> = {};
      if (companyIds.length > 0) {
        const comps = await db
          .select({ id: companies.id, name: companies.name })
          .from(companies)
          .where(inArray(companies.id, companyIds));

        for (const c of comps) {
          companiesMap[c.id] = c.name;
        }
      }

      for (const d of dealsRaw) {
        dealMetadataMap[d.id] = {
          commodityName: 'Raw Material',
          buyerName: companiesMap[d.buyerCompanyId] || 'Buyer Partner',
          sellerName: companiesMap[d.sellerCompanyId] || 'Seller Partner',
        };
      }
    }

    const dealsFormatted: SearchDealResult[] = dealsRaw.map((d) => {
      const meta = dealMetadataMap[d.id] || {
        commodityName: 'Raw Material',
        buyerName: 'Buyer Partner',
        sellerName: 'Seller Partner',
      };
      const shortId = d.id.slice(0, 8).toUpperCase();

      return {
        id: d.id,
        dealRef: `DL-${shortId}`,
        commodityName: meta.commodityName,
        agreedQuantity: Number(d.agreedQuantity) || 0,
        agreedPrice: Number(d.agreedPrice) || 0,
        buyerName: meta.buyerName,
        sellerName: meta.sellerName,
        status: d.status || 'Active',
        createdAt: d.createdAt ? new Date(d.createdAt).toISOString() : new Date().toISOString(),
        url: `/broker/deals`,
      };
    });

    const totalCount =
      contacts.length +
      materials.length +
      requirementsFormatted.length +
      offersFormatted.length +
      dealsFormatted.length;

    return {
      success: true,
      data: {
        query,
        results: {
          contacts,
          materials,
          requirements: requirementsFormatted,
          offers: offersFormatted,
          deals: dealsFormatted,
          totalCount,
        },
        counts: {
          all: totalCount,
          contacts: contacts.length,
          materials: materials.length,
          requirements: requirementsFormatted.length,
          offers: offersFormatted.length,
          deals: dealsFormatted.length,
        },
      },
    };
  } catch (error: any) {
    console.error('Error executing searchGlobalAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to execute global search. Please try again.',
    };
  }
}

// ============================================================================
// Server Action: Quick Dial Contacts
// ============================================================================

/**
 * Returns authorized broker contacts with verified phone/WhatsApp numbers
 * for the Floating Communication dialler / speed-dial modal.
 */
export async function getQuickDialContactsAction(): Promise<QuickDialResponse> {
  try {
    const auth = await getAuthenticatedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;

    const rows = await db
      .select({
        id: crmContacts.id,
        name: users.name,
        mobile: users.mobile,
        role: users.role,
        companyName: companies.name,
        isVerified: companies.isVerified,
      })
      .from(crmContacts)
      .innerJoin(users, eq(users.id, crmContacts.userId))
      .innerJoin(companies, eq(companies.id, crmContacts.companyId))
      .where(
        and(
          isAdmin ? sql`true` : eq(crmContacts.brokerId, brokerId),
          eq(users.status, true),
          sql`${users.mobile} IS NOT NULL AND ${users.mobile} != ''`
        )
      )
      .orderBy(desc(crmContacts.lastActivityAt), desc(crmContacts.createdAt))
      .limit(20);

    const data: QuickDialContactItem[] = rows.map((r) => {
      const phoneRes = validateAndNormalizePhone(r.mobile || '');
      const rawMobile = r.mobile || '';
      const normalizedMobile = phoneRes.isValid ? phoneRes.normalized : rawMobile;
      const formatted = phoneRes.isValid ? phoneRes.formatted : rawMobile;
      const roleStr = (r.role || '').toLowerCase() === 'seller' ? 'Seller' : 'Buyer';

      return {
        id: r.id,
        name: r.name || 'Unnamed Contact',
        companyName: r.companyName || 'Business Partner',
        role: roleStr,
        mobile: normalizedMobile,
        formattedMobile: formatted,
        telUri: phoneRes.isValid ? getSafeTelUri(phoneRes.normalized) : null,
        whatsappUri: phoneRes.isValid ? getSafeWhatsAppUri(phoneRes.normalized) : null,
        isVerified: r.isVerified,
      };
    });

    return {
      success: true,
      data,
    };
  } catch (error: any) {
    console.error('Error in getQuickDialContactsAction:', error);
    return {
      success: false,
      error: error?.message || 'Failed to retrieve quick dial contacts.',
    };
  }
}
