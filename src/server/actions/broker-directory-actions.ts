'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  users,
  companies,
  crmContacts,
  crmActivities,
  requirements,
  availabilities,
  deals,
  masterCommodities,
} from '@/src/server/db/schema';
import { eq, and, or, ilike, desc, sql, notInArray, inArray } from 'drizzle-orm';
import { z } from 'zod';
import { validateAndNormalizePhone } from '@/src/lib/phone-utils';
import {
  pgTimestampToIso,
  publicDirectoryError,
  queryDirectoryPage,
  queryDirectoryStats,
  type DirectoryCursor,
} from '@/src/server/utils/broker-directory-query';

// ============================================================================
// Types & Zod Schemas
// ============================================================================

import {
  contactRoleEnum,
  createContactSchema,
  updateContactSchema,
  type ContactRole,
  type CreateContactInput,
  type UpdateContactInput,
} from '@/src/lib/validations/broker-directory-schema';

export type { ContactRole, CreateContactInput, UpdateContactInput };


export interface DirectoryContactItem {
  id: string; // crmContacts.id
  userId: string;
  companyId: string;
  name: string;
  companyName: string;
  mobile: string;
  whatsapp?: string | null;
  email?: string | null;
  role: 'Buyer' | 'Seller';
  status: boolean;
  isVerified: boolean;
  trustScore: number;
  city?: string | null;
  state?: string | null;
  createdAt: string;
  openRequirementsCount: number;
  availableOffersCount: number;
  activeDealsCount: number;
}

export interface DirectorySummaryStats {
  totalContacts: number;
  buyersCount: number;
  sellersCount: number;
  activeMandatesCount: number;
}

export interface DirectoryListResponse {
  success: boolean;
  data?: {
    contacts: DirectoryContactItem[];
    /** Present on the first page (no cursor); omitted on later pages. */
    stats?: DirectorySummaryStats;
    pageInfo: { hasMore: boolean; nextCursor: string | null };
  };
  error?: string;
}

export interface DuplicateCheckResult {
  isDuplicate: boolean;
  matchType?: 'exact_mobile' | 'company_name';
  existingContact?: {
    id: string;
    name: string;
    companyName: string;
    mobile: string;
    role: string;
  };
}

export interface ContactDetailsPayload {
  contact: DirectoryContactItem;
  associatedRequirements: Array<{
    id: string;
    commodityName: string;
    quantity: number;
    targetPrice: number;
    status: string;
    targetDate: string;
  }>;
  associatedOffers: Array<{
    id: string;
    commodityName: string;
    quantity: number;
    price: number | string;
    status: string;
  }>;
  linkedDeals: Array<{
    id: string;
    commodityName: string;
    agreedQuantity: number;
    agreedPrice: number | string;
    status: string;
    createdAt: string;
  }>;
  activities: Array<{
    id: string;
    type: string;
    notes: string;
    createdAt: string;
  }>;
}

export interface ContactDetailsResponse {
  success: boolean;
  data?: ContactDetailsPayload;
  error?: string;
}

// ============================================================================
// Internal Auth & Role Verification Helper
// ============================================================================

type AuthResult =
  | { success: true; brokerId: string; isAdmin: boolean; dbUser: typeof users.$inferSelect }
  | { success: false; error: string };

export async function getAuthenticatedBroker(authToken?: string): Promise<AuthResult> {
  let authUser = null;
  let authError = null;

  if (authToken) {
    try {
      const { createClient: createSupabaseClient } = await import('@supabase/supabase-js');
      const supabase = createSupabaseClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        { auth: { persistSession: false } }
      );
      const res = await supabase.auth.getUser(authToken);
      authUser = res.data.user;
      authError = res.error;
    } catch (err: any) {
      authError = err;
    }
  }

  if (!authUser) {
    try {
      const supabase = await createClient();
      const res = await supabase.auth.getUser();
      authUser = res.data.user;
      authError = res.error;
    } catch (_e) {
      // Supabase cookies outside request context (e.g. CLI test environment)
    }
  }

  if (authError || !authUser) {
    return { success: false, error: 'Unauthorized: Valid broker session required' };
  }

  const dbUser = await db.query.users.findFirst({
    where: eq(users.id, authUser.id),
  });

  if (!dbUser) {
    return { success: false, error: 'User profile not found in system' };
  }

  const role = (dbUser.role || '').toLowerCase();
  if (role !== 'broker' && role !== 'admin') {
    return { success: false, error: 'Forbidden: Broker access privileges required' };
  }

  return {
    success: true,
    brokerId: dbUser.id,
    isAdmin: role === 'admin',
    dbUser,
  };
}

/**
 * Creates the missing crm_contacts row for every company that assigned
 * [brokerId] on a requirement (buyer) or availability (seller). The contact
 * user is that company's user of the matching role. Existing links (by
 * company) are left untouched, so this is idempotent.
 */
async function linkAssignedCounterparties(brokerId: string): Promise<void> {
  await db.execute(sql`
    insert into crm_contacts (broker_id, user_id, company_id, last_activity_at)
    select distinct on (src.company_id) ${brokerId}::uuid, u.id, src.company_id, now()
    from (
      select company_id, 'buyer' as role from requirements where broker_id = ${brokerId}::uuid
      union
      select company_id, 'seller' as role from availabilities where broker_id = ${brokerId}::uuid
    ) src
    join users u on u.company_id = src.company_id and lower(u.role) = src.role
    where not exists (
      select 1 from crm_contacts c
      where c.broker_id = ${brokerId}::uuid and c.company_id = src.company_id
    )
    order by src.company_id, u.created_at
  `);
}

// ============================================================================
// 1. Fetch Authorized Directory Contacts List with Summary Stats
// ============================================================================

export async function getBrokerDirectoryContactsAction(
  filter?: {
    role?: 'all' | 'buyer' | 'seller';
    search?: string;
    status?: 'all' | 'active' | 'inactive';
    /** Page size; omitted returns the full list (web workspace). */
    limit?: number;
    cursor?: DirectoryCursor | null;
  },
  authToken?: string
): Promise<DirectoryListResponse> {
  try {
    const auth = await getAuthenticatedBroker(authToken);
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;
    const scope = { brokerId, isAdmin };

    // 0. Buyers/sellers who assigned this broker on a requirement or lot get a
    //    CRM link once, so they appear without manual entry. First page only.
    if (!filter?.cursor) {
      await linkAssignedCounterparties(brokerId).catch((err) =>
        console.error('linkAssignedCounterparties error:', err)
      );
    }

    // 1. Filtered page (or full list without a limit), filters applied in SQL
    const page = await queryDirectoryPage(db, scope, filter ?? {}, {
      limit: filter?.limit,
      after: filter?.cursor,
    });

    // 2. Mandate counts for this page only: three grouped queries
    const companyIds = [...new Set(page.rows.map((r) => r.companyId))];
    const reqMap = new Map<string, number>();
    const availMap = new Map<string, number>();
    const dealsMap = new Map<string, number>();
    if (companyIds.length > 0) {
      const [reqRows, availRows, dealRows] = await Promise.all([
        db
          .select({ companyId: requirements.companyId, count: sql<number>`count(*)::int` })
          .from(requirements)
          .where(
            and(
              inArray(requirements.companyId, companyIds),
              isAdmin ? sql`true` : eq(requirements.brokerId, brokerId),
              inArray(requirements.status, ['Open', 'Partially Fulfilled'])
            )
          )
          .groupBy(requirements.companyId)
          .catch(() => []),
        db
          .select({ companyId: availabilities.companyId, count: sql<number>`count(*)::int` })
          .from(availabilities)
          .where(
            and(
              inArray(availabilities.companyId, companyIds),
              isAdmin ? sql`true` : eq(availabilities.brokerId, brokerId),
              eq(availabilities.status, 'Open')
            )
          )
          .groupBy(availabilities.companyId)
          .catch(() => []),
        db
          .select({ buyerId: deals.buyerId, sellerId: deals.sellerId })
          .from(deals)
          .where(
            and(
              or(inArray(deals.buyerId, companyIds), inArray(deals.sellerId, companyIds)),
              isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
              notInArray(deals.status, ['Closed', 'Cancelled'])
            )
          )
          .catch(() => []),
      ]);
      for (const r of reqRows) reqMap.set(r.companyId, r.count);
      for (const a of availRows) availMap.set(a.companyId, a.count);
      for (const d of dealRows) {
        dealsMap.set(d.buyerId, (dealsMap.get(d.buyerId) ?? 0) + 1);
        if (d.sellerId !== d.buyerId) dealsMap.set(d.sellerId, (dealsMap.get(d.sellerId) ?? 0) + 1);
      }
    }

    const contacts: DirectoryContactItem[] = page.rows.map((row) => ({
      id: row.contactId,
      userId: row.userId,
      companyId: row.companyId,
      name: row.userName,
      companyName: row.companyName,
      mobile: row.userMobile || '',
      email: row.userEmail,
      role: (row.userRole || '').toLowerCase().trim() === 'seller' ? 'Seller' : 'Buyer',
      status: row.userStatus && row.companyStatus,
      isVerified: row.isVerified,
      trustScore: row.trustScore,
      city: row.districtId,
      state: row.stateId,
      createdAt: pgTimestampToIso(row.createdAt),
      openRequirementsCount: reqMap.get(row.companyId) ?? 0,
      availableOffersCount: availMap.get(row.companyId) ?? 0,
      activeDealsCount: dealsMap.get(row.companyId) ?? 0,
    }));

    // 3. Stats cover all of the broker's contacts; computed once per list
    //    (first page), not again for each further page.
    const stats = filter?.cursor ? undefined : await queryDirectoryStats(db, scope);

    return {
      success: true,
      data: {
        contacts,
        stats,
        pageInfo: { hasMore: page.hasMore, nextCursor: page.nextCursor },
      },
    };
  } catch (error: any) {
    console.error('getBrokerDirectoryContactsAction error:', error);
    return {
      success: false,
      error: 'Failed to fetch directory contacts',
    };
  }
}

// ============================================================================
// 2. Duplicate Prevention Check Action
// ============================================================================

export async function checkContactDuplicateAction(
  data: {
    mobile: string;
    companyName: string;
  },
  authToken?: string
): Promise<DuplicateCheckResult> {
  try {
    const auth = await getAuthenticatedBroker(authToken);
    if (!auth.success) {
      return { isDuplicate: false };
    }

    const { brokerId, isAdmin } = auth;
    const phoneRes = validateAndNormalizePhone(data.mobile);

    if (!phoneRes.isValid) {
      return { isDuplicate: false };
    }

    // 1. Exact Match on Normalized Mobile under this broker
    const existingByPhone = await db
      .select({
        contactId: crmContacts.id,
        userName: users.name,
        userMobile: users.mobile,
        userRole: users.role,
        companyName: companies.name,
      })
      .from(crmContacts)
      .innerJoin(users, eq(crmContacts.userId, users.id))
      .innerJoin(companies, eq(crmContacts.companyId, companies.id))
      .where(
        and(
          isAdmin ? sql`true` : eq(crmContacts.brokerId, brokerId),
          or(
            eq(users.mobile, phoneRes.normalized),
            eq(users.mobile, phoneRes.rawDigits),
            eq(users.mobile, phoneRes.formatted)
          )
        )
      )
      .limit(1);

    if (existingByPhone.length > 0) {
      const row = existingByPhone[0];
      return {
        isDuplicate: true,
        matchType: 'exact_mobile',
        existingContact: {
          id: row.contactId,
          name: row.userName,
          companyName: row.companyName,
          mobile: row.userMobile || '',
          role: (row.userRole || '').toLowerCase() === 'seller' ? 'Seller' : 'Buyer',
        },
      };
    }

    // 2. Potential Match on Exact Company Name under this broker
    if (data.companyName && data.companyName.trim().length >= 3) {
      const existingByCompany = await db
        .select({
          contactId: crmContacts.id,
          userName: users.name,
          userMobile: users.mobile,
          userRole: users.role,
          companyName: companies.name,
        })
        .from(crmContacts)
        .innerJoin(users, eq(crmContacts.userId, users.id))
        .innerJoin(companies, eq(crmContacts.companyId, companies.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(crmContacts.brokerId, brokerId),
            ilike(companies.name, data.companyName.trim())
          )
        )
        .limit(1);

      if (existingByCompany.length > 0) {
        const row = existingByCompany[0];
        return {
          isDuplicate: true,
          matchType: 'company_name',
          existingContact: {
            id: row.contactId,
            name: row.userName,
            companyName: row.companyName,
            mobile: row.userMobile || '',
            role: (row.userRole || '').toLowerCase() === 'seller' ? 'Seller' : 'Buyer',
          },
        };
      }
    }

    return { isDuplicate: false };
  } catch (error) {
    console.error('checkContactDuplicateAction error:', error);
    return { isDuplicate: false };
  }
}

// ============================================================================
// 3. Create Validated Contact with Duplicate Prevention
// ============================================================================

export async function createBrokerContactAction(
  rawInput: CreateContactInput,
  authToken?: string
): Promise<{ success: boolean; contactId?: string; error?: string; isDuplicate?: boolean }> {
  try {
    const auth = await getAuthenticatedBroker(authToken);
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId } = auth;
    const parsed = createContactSchema.parse(rawInput);

    // Validate and normalize phone
    const phoneRes = validateAndNormalizePhone(parsed.mobile);
    if (!phoneRes.isValid) {
      return { success: false, error: phoneRes.error || 'Invalid mobile number' };
    }

    // Server-side Duplicate Prevention. The token must be passed on: without
    // it a Bearer-only (mobile) caller has no session here and the check
    // silently reported "no duplicate".
    const dupCheck = await checkContactDuplicateAction(
      {
        mobile: phoneRes.normalized,
        companyName: parsed.companyName,
      },
      authToken
    );

    if (dupCheck.isDuplicate && dupCheck.matchType === 'exact_mobile') {
      return {
        success: false,
        isDuplicate: true,
        error: `A contact with mobile number ${phoneRes.formatted} already exists (${dupCheck.existingContact?.companyName}). Duplicate creation prevented.`,
      };
    }

    // 1. Create or link Company
    const [insertedCompany] = await db
      .insert(companies)
      .values({
        name: parsed.companyName.trim(),
        districtId: parsed.city ? parsed.city.trim() : null,
        stateId: parsed.state ? parsed.state.trim() : null,
        status: true,
        isVerified: false,
        trustScore: 100,
      })
      .returning();

    // 2. Create User Contact Person
    const [insertedUser] = await db
      .insert(users)
      .values({
        name: parsed.name.trim(),
        mobile: phoneRes.normalized,
        email: parsed.email ? parsed.email.trim() : null,
        role: parsed.role,
        status: true,
        companyId: insertedCompany.id,
      })
      .returning();

    // 3. Link Contact to Broker Workspace (crm_contacts)
    const [insertedContact] = await db
      .insert(crmContacts)
      .values({
        brokerId,
        companyId: insertedCompany.id,
        userId: insertedUser.id,
        lastActivityAt: new Date(),
      })
      .returning();

    // 4. Initial Note Activity (if provided)
    if (parsed.notes && parsed.notes.trim()) {
      await db
        .insert(crmActivities)
        .values({
          contactId: insertedContact.id,
          type: 'Note',
          notes: parsed.notes.trim(),
        })
        .catch(() => {});
    }

    return {
      success: true,
      contactId: insertedContact.id,
    };
  } catch (error: any) {
    console.error('createBrokerContactAction error:', error);
    return {
      success: false,
      error: publicDirectoryError(error, 'Failed to create contact record'),
    };
  }
}

// ============================================================================
// 4. Update Authorized Contact Record
// ============================================================================

export async function updateBrokerContactAction(
  contactId: string,
  rawInput: UpdateContactInput,
  authToken?: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker(authToken);
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;
    const parsed = updateContactSchema.parse(rawInput);

    // Verify contact exists and broker is authorized
    const existing = await db
      .select({
        id: crmContacts.id,
        brokerId: crmContacts.brokerId,
        userId: crmContacts.userId,
        companyId: crmContacts.companyId,
      })
      .from(crmContacts)
      .where(eq(crmContacts.id, contactId))
      .limit(1);

    if (existing.length === 0) {
      return { success: false, error: 'Contact record not found' };
    }

    const contactRow = existing[0];
    if (!isAdmin && contactRow.brokerId !== brokerId) {
      return { success: false, error: 'Unauthorized: You do not have permission to edit this contact' };
    }

    // Validate and normalize phone
    const phoneRes = validateAndNormalizePhone(parsed.mobile);
    if (!phoneRes.isValid) {
      return { success: false, error: phoneRes.error || 'Invalid mobile number' };
    }

    // Verify phone uniqueness against OTHER contacts of this broker
    if (contactRow.userId) {
      const otherSamePhone = await db
        .select({ id: crmContacts.id })
        .from(crmContacts)
        .innerJoin(users, eq(crmContacts.userId, users.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(crmContacts.brokerId, brokerId),
            sql`${crmContacts.id} != ${contactId}`,
            eq(users.mobile, phoneRes.normalized)
          )
        )
        .limit(1);

      if (otherSamePhone.length > 0) {
        return {
          success: false,
          error: `Another contact already exists with mobile number ${phoneRes.formatted}.`,
        };
      }

      // Update User
      await db
        .update(users)
        .set({
          name: parsed.name.trim(),
          mobile: phoneRes.normalized,
          email: parsed.email ? parsed.email.trim() : null,
          role: parsed.role,
          status: parsed.status !== undefined ? parsed.status : true,
        })
        .where(eq(users.id, contactRow.userId));
    }

    // Update Company
    if (contactRow.companyId) {
      await db
        .update(companies)
        .set({
          name: parsed.companyName.trim(),
          districtId: parsed.city ? parsed.city.trim() : null,
          stateId: parsed.state ? parsed.state.trim() : null,
          status: parsed.status !== undefined ? parsed.status : true,
        })
        .where(eq(companies.id, contactRow.companyId));
    }

    // Update crmContacts lastActivityAt
    await db
      .update(crmContacts)
      .set({ lastActivityAt: new Date() })
      .where(eq(crmContacts.id, contactId));

    return { success: true };
  } catch (error: any) {
    console.error('updateBrokerContactAction error:', error);
    return {
      success: false,
      error: publicDirectoryError(error, 'Failed to update contact record'),
    };
  }
}

// ============================================================================
// 5. Toggle Active/Inactive Status (Soft Archive)
// ============================================================================

export async function toggleContactStatusAction(
  contactId: string,
  authToken?: string
): Promise<{ success: boolean; newStatus?: boolean; error?: string }> {
  try {
    const auth = await getAuthenticatedBroker(authToken);
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;

    const existing = await db
      .select({
        id: crmContacts.id,
        brokerId: crmContacts.brokerId,
        userId: crmContacts.userId,
        userStatus: users.status,
      })
      .from(crmContacts)
      .innerJoin(users, eq(crmContacts.userId, users.id))
      .where(eq(crmContacts.id, contactId))
      .limit(1);

    if (existing.length === 0) {
      return { success: false, error: 'Contact record not found' };
    }

    const row = existing[0];
    if (!isAdmin && row.brokerId !== brokerId) {
      return { success: false, error: 'Unauthorized to modify this contact status' };
    }

    const newStatus = !row.userStatus;

    if (row.userId) {
      await db.update(users).set({ status: newStatus }).where(eq(users.id, row.userId));
    }

    return { success: true, newStatus };
  } catch (error: any) {
    console.error('toggleContactStatusAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to update contact status',
    };
  }
}

// ============================================================================
// 6. Fetch 360-Degree Contact Profile with Linked Business Records
// ============================================================================

export async function getBrokerContactDetailsAction(
  contactId: string,
  authToken?: string
): Promise<ContactDetailsResponse> {
  try {
    const auth = await getAuthenticatedBroker(authToken);
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const { brokerId, isAdmin } = auth;

    // 1. Fetch core contact
    const contactRows = await db
      .select({
        contactId: crmContacts.id,
        brokerId: crmContacts.brokerId,
        userId: users.id,
        userName: users.name,
        userMobile: users.mobile,
        userEmail: users.email,
        userRole: users.role,
        userStatus: users.status,
        companyId: companies.id,
        companyName: companies.name,
        companyStatus: companies.status,
        isVerified: companies.isVerified,
        trustScore: companies.trustScore,
        districtId: companies.districtId,
        stateId: companies.stateId,
        createdAt: crmContacts.createdAt,
      })
      .from(crmContacts)
      .innerJoin(users, eq(crmContacts.userId, users.id))
      .innerJoin(companies, eq(crmContacts.companyId, companies.id))
      .where(eq(crmContacts.id, contactId))
      .limit(1);

    if (contactRows.length === 0) {
      return { success: false, error: 'Contact record not found' };
    }

    const row = contactRows[0];
    if (!isAdmin && row.brokerId !== brokerId) {
      return { success: false, error: 'Unauthorized: You do not have permission to view this contact' };
    }

    const cRole = (row.userRole || '').toLowerCase();
    const roleNormalized: 'Buyer' | 'Seller' = cRole === 'seller' ? 'Seller' : 'Buyer';
    const targetCompanyId = row.companyId;

    // 2. Fetch linked business records in parallel (strictly broker-scoped)
    const [reqsRes, offersRes, dealsRes, activitiesRes] = await Promise.all([
      // Linked Requirements
      db
        .select({
          id: requirements.id,
          commodityName: masterCommodities.name,
          quantity: requirements.quantity,
          targetPrice: requirements.targetPrice,
          status: requirements.status,
          targetDate: requirements.targetDate,
        })
        .from(requirements)
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(
          and(
            eq(requirements.companyId, targetCompanyId),
            isAdmin ? sql`true` : eq(requirements.brokerId, brokerId)
          )
        )
        .orderBy(desc(requirements.createdAt))
        .limit(6)
        .catch(() => []),

      // Linked Seller Offers
      db
        .select({
          id: availabilities.id,
          commodityName: masterCommodities.name,
          quantity: availabilities.quantity,
          price: availabilities.askingPrice,
          status: availabilities.status,
        })
        .from(availabilities)
        .innerJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
        .where(
          and(
            eq(availabilities.companyId, targetCompanyId),
            isAdmin ? sql`true` : eq(availabilities.brokerId, brokerId)
          )
        )
        .orderBy(desc(availabilities.createdAt))
        .limit(6)
        .catch(() => []),

      // Linked Deals
      db
        .select({
          id: deals.id,
          commodityName: masterCommodities.name,
          agreedQuantity: deals.agreedQuantity,
          agreedPrice: deals.agreedPrice,
          status: deals.status,
          createdAt: deals.createdAt,
        })
        .from(deals)
        .innerJoin(requirements, eq(deals.requirementId, requirements.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(
          and(
            or(eq(deals.buyerId, targetCompanyId), eq(deals.sellerId, targetCompanyId)),
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId)
          )
        )
        .orderBy(desc(deals.createdAt))
        .limit(6)
        .catch(() => []),

      // CRM Activities
      db
        .select({
          id: crmActivities.id,
          type: crmActivities.type,
          notes: crmActivities.notes,
          createdAt: crmActivities.createdAt,
        })
        .from(crmActivities)
        .where(eq(crmActivities.contactId, contactId))
        .orderBy(desc(crmActivities.createdAt))
        .limit(10)
        .catch(() => []),
    ]);

    const contact: DirectoryContactItem = {
      id: row.contactId,
      userId: row.userId,
      companyId: row.companyId,
      name: row.userName,
      companyName: row.companyName,
      mobile: row.userMobile || '',
      email: row.userEmail,
      role: roleNormalized,
      status: row.userStatus && row.companyStatus,
      isVerified: row.isVerified,
      trustScore: row.trustScore,
      city: row.districtId,
      state: row.stateId,
      createdAt: row.createdAt.toISOString(),
      openRequirementsCount: reqsRes.filter((r) => r.status === 'Open' || r.status === 'Partially Fulfilled').length,
      availableOffersCount: offersRes.filter((o) => o.status === 'Open').length,
      activeDealsCount: dealsRes.filter((d) => d.status !== 'Closed' && d.status !== 'Cancelled').length,
    };

    return {
      success: true,
      data: {
        contact,
        associatedRequirements: reqsRes.map((r) => ({
          ...r,
          targetDate: r.targetDate ? r.targetDate.toISOString() : '',
        })),
        associatedOffers: offersRes,
        linkedDeals: dealsRes.map((d) => ({
          ...d,
          createdAt: d.createdAt ? d.createdAt.toISOString() : '',
        })),
        activities: activitiesRes.map((a) => ({
          ...a,
          createdAt: a.createdAt ? a.createdAt.toISOString() : '',
        })),
      },
    };
  } catch (error: any) {
    console.error('getBrokerContactDetailsAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch contact details',
    };
  }
}
