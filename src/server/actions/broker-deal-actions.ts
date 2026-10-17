'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  quotations,
  dealVersions,
  negotiationEvents,
  availabilities,
  requirements,
  masterCommodities,
  masterGrades,
  masterUnits,
  requirementAllocations,
  deals,
  bookings,
  companies,
  users,
} from '@/src/server/db/schema';
import { eq, desc, and, or, sql, inArray } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { queueNotificationAction } from '@/src/server/actions/notification-actions';
import { logDecisionGateAuditEventAction } from '@/src/server/actions/audit-actions';
import {
  generateFinalDealSnapshotSchema,
  type GenerateFinalDealSnapshotPayload,
} from '@/src/types/deal-builder-schema';
import {
  verifyLatestVersion,
  detectMaterialChanges,
  getMaterialDiffList,
  type MaterialFieldDiff,
} from '@/src/server/utils/version-engine';

export type GenerateFinalDealResult = {
  success: boolean;
  version_id?: string;
  version_number?: number;
  message?: string;
  error?: string;
};

export type DealContextResult = {
  success: boolean;
  data?: {
    requestId: string;
    requirementId: string;
    sellerAvailabilityId?: string | null;
    lotId?: string | null;
    lotNumber?: string | null;
    commodityName: string;
    gradeName?: string | null;
    quantity: number;
    baseRate: number;
    deliveryDate: string;
    buyerMarkup: number;
    sellerDeduction: number;
    deliveryTerms: string;
    deliveryLocation: string;
    packagingType: string;
    paymentTerms: string;
    specialConditions: string;
    unitSymbol: string;
    expectedVersionNumber: number;
    currentStatus: string;
  };
  error?: string;
};

// ==========================================
// RB-10 TYPE DEFINITIONS
// ==========================================

export type DealLifecycleStatus =
  | 'Draft'
  | 'Negotiation'
  | 'Awaiting Buyer Confirmation'
  | 'Awaiting Seller Confirmation'
  | 'Ready to Finalize'
  | 'Finalized'
  | 'In Fulfillment'
  | 'Completed'
  | 'Cancelled'
  | 'Disputed';

export interface CreateDealFromAllocationInput {
  allocationId: string;
  customTerms?: {
    agreedPrice?: number;
    agreedQuantity?: number;
    priceBasis?: string;
    deliveryLocation?: string;
    deliveryDate?: string;
    deliveryTerms?: string;
    paymentTerms?: string;
    packagingType?: string;
    brokerCommissionRate?: number;
    commissionBasis?: string;
    notes?: string;
  };
}

export interface CreateDealResult {
  success: boolean;
  dealId?: string;
  versionNumber?: number;
  message?: string;
  error?: string;
}

export interface UpdateDealTermsInput {
  dealId: string;
  expectedVersion: number;
  terms: {
    agreedPrice?: number;
    agreedQuantity?: number;
    priceBasis?: string;
    deliveryLocation?: string;
    deliveryDate?: string;
    deliveryTerms?: string;
    paymentTerms?: string;
    packagingType?: string;
    brokerCommissionRate?: number;
    commissionBasis?: string;
    notes?: string;
    reason?: string;
  };
}

export interface UpdateDealTermsResult {
  success: boolean;
  dealId?: string;
  versionNumber?: number;
  diffs?: MaterialFieldDiff[];
  message?: string;
  error?: string;
}

export interface RecordPartyConfirmationInput {
  dealId: string;
  party: 'BUYER' | 'SELLER';
  versionNumber: number;
  verificationNotes?: string;
}

export interface RecordPartyConfirmationResult {
  success: boolean;
  dealId?: string;
  versionNumber?: number;
  currentStatus?: string;
  buyerConfirmed?: boolean;
  sellerConfirmed?: boolean;
  canFinalize?: boolean;
  message?: string;
  error?: string;
}

export interface FinalizeDealResult {
  success: boolean;
  dealId?: string;
  bookingReference?: string;
  versionNumber?: number;
  message?: string;
  error?: string;
}

export interface CancelDealInput {
  dealId: string;
  reason: string;
}

export interface CancelDealResult {
  success: boolean;
  dealId?: string;
  message?: string;
  error?: string;
}

export interface BrokerDealSummary {
  id: string; // deals.id
  quotationId: string;
  requirementId: string;
  allocationId?: string | null;
  allocationReference?: string | null;
  bookingId?: string | null;
  bookingReference?: string | null;
  commodityName: string;
  gradeName?: string | null;
  buyerCompanyId: string;
  buyerCompanyName: string;
  sellerCompanyId: string;
  sellerCompanyName: string;
  agreedQuantity: number;
  unitSymbol: string;
  agreedPrice: number;
  totalValuation: number;
  priceBasis: string;
  deliveryLocation?: string | null;
  deliveryDate?: string | null;
  status: string;
  latestVersionNumber: number;
  buyerConfirmed: boolean;
  sellerConfirmed: boolean;
  createdAt: string;
  closedAt?: string | null;
}

export interface DealVersionTimelineItem {
  id: string;
  versionNumber: number;
  status: string;
  actorId: string;
  actorName: string;
  actorRole: string;
  createdAt: string;
  snapshot: any;
  diffs: MaterialFieldDiff[];
  changeReason?: string | null;
}

export interface BrokerDealDetail {
  deal: {
    id: string;
    requirementId: string;
    quotationId: string;
    buyerId: string;
    sellerId: string;
    brokerId?: string | null;
    agreedPrice: number;
    agreedQuantity: number;
    status: string;
    createdAt: string;
    closedAt?: string | null;
  };
  summary: BrokerDealSummary;
  allocation?: {
    id: string;
    allocationReference: string;
    allocatedQuantity: number;
    allocatedPrice: number | null;
    priceBasis: string;
    status: string;
    notes: string | null;
  } | null;
  requirement?: {
    id: string;
    quantity: number;
    targetPrice: number;
    targetDate: string;
    status: string;
  } | null;
  availability?: {
    id: string;
    lotNumber: string | null;
    availableQuantity: number;
    askingPrice: number;
    status: string;
  } | null;
  buyerCompany: {
    id: string;
    name: string;
    verified: boolean;
  };
  sellerCompany: {
    id: string;
    name: string;
    verified: boolean;
  };
  versions: DealVersionTimelineItem[];
  confirmations: {
    latestVersionNumber: number;
    buyerConfirmed: boolean;
    buyerConfirmedAt?: string | null;
    buyerConfirmedBy?: string | null;
    buyerNotes?: string | null;
    sellerConfirmed: boolean;
    sellerConfirmedAt?: string | null;
    sellerConfirmedBy?: string | null;
    sellerNotes?: string | null;
    canFinalize: boolean;
  };
  booking?: {
    id: string;
    bookingReference: string;
    status: string;
    createdAt: string;
  } | null;
  events: Array<{
    id: string;
    actionType: string;
    actorId: string;
    createdAt: string;
    payload: any;
  }>;
}

// ==========================================
// SESSION AUTH HELPER
// ==========================================

async function getAuthorizedBrokerSession() {
  let authUser: any = null;
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (!authError && user) authUser = user;
  } catch (_e) {
    authUser = null;
  }

  if (!authUser) {
    return { success: false as const, error: 'Unauthorized: Valid broker session required' };
  }

  const dbUser = await db.query.users.findFirst({
    where: eq(users.id, authUser.id),
  });

  if (!dbUser) {
    return { success: false as const, error: 'User profile not found' };
  }

  const role = (dbUser.role || '').toLowerCase();
  if (role !== 'broker' && role !== 'admin') {
    return { success: false as const, error: 'Forbidden: Broker access privileges required' };
  }

  return { success: true as const, user: dbUser, isAdmin: role === 'admin' };
}

// ==========================================
// 1. CREATE DEAL FROM ALLOCATION ACTION
// ==========================================

/**
 * Creates an authorized deal record and initial immutable Version 1 from an eligible confirmed allocation.
 * Transactionally commits allocation to deal and locks quantity.
 */
export async function createDealFromAllocationAction(
  input: CreateDealFromAllocationInput
): Promise<CreateDealResult> {
  try {
    const auth = await getAuthorizedBrokerSession();
    if (!auth.success) return { success: false, error: auth.error };
    const { user: brokerUser, isAdmin } = auth;

    if (!input.allocationId) {
      return { success: false, error: 'Allocation ID is required' };
    }

    return await db.transaction(async (tx) => {
      // 1. Load and validate allocation
      const allocRes = await tx
        .select()
        .from(requirementAllocations)
        .where(eq(requirementAllocations.id, input.allocationId))
        .limit(1);

      if (!allocRes || allocRes.length === 0) {
        throw new Error('Allocation record not found');
      }

      const allocation = allocRes[0];

      // Authorization guard
      if (!isAdmin && allocation.brokerId !== brokerUser.id) {
        throw new Error('Forbidden: You are not authorized to create a deal for this allocation');
      }

      // State guard: Must be CONFIRMED
      if (allocation.status !== 'CONFIRMED') {
        throw new Error(
          `Selected allocation is not eligible for deal creation. Current status: "${allocation.status}". Allocation must be confirmed first.`
        );
      }

      // Conflict / Idempotency guard: Must not already have a deal
      if (allocation.dealId) {
        throw new Error(
          `This allocation is already committed to an existing deal (${allocation.dealId}). Conflicting duplicate deals are prohibited.`
        );
      }

      // 2. Validate linked requirement
      const reqRes = await tx
        .select()
        .from(requirements)
        .where(eq(requirements.id, allocation.requirementId))
        .limit(1);

      if (!reqRes || reqRes.length === 0) {
        throw new Error('Linked buyer requirement record not found');
      }

      const req = reqRes[0];
      if (['Cancelled', 'Expired', 'Rejected'].includes(req.status)) {
        throw new Error(`Linked buyer requirement is inactive (${req.status})`);
      }

      // 3. Validate linked seller availability
      const availRes = await tx
        .select()
        .from(availabilities)
        .where(eq(availabilities.id, allocation.availabilityId))
        .limit(1);

      if (!availRes || availRes.length === 0) {
        throw new Error('Linked seller availability record not found');
      }

      const avail = availRes[0];
      if (['Cancelled', 'Rejected', 'Expired'].includes(avail.status)) {
        throw new Error(`Linked seller offer is inactive (${avail.status})`);
      }

      // 4. Fetch Commodity, Grade, Unit
      const commodity = req.commodityId
        ? await tx.query.masterCommodities.findFirst({
            where: eq(masterCommodities.id, req.commodityId),
          })
        : null;

      const grade = req.gradeId
        ? await tx.query.masterGrades.findFirst({
            where: eq(masterGrades.id, req.gradeId),
          })
        : null;

      const unit = allocation.unitId
        ? await tx.query.masterUnits.findFirst({
            where: eq(masterUnits.id, allocation.unitId),
          })
        : null;

      // 5. Find or Create Quotation link
      let quote = await tx.query.quotations.findFirst({
        where: and(
          eq(quotations.requirementId, req.id),
          eq(quotations.sellerAvailabilityId, avail.id)
        ),
      });

      const agreedPrice = Number(
        input.customTerms?.agreedPrice ??
          allocation.allocatedPrice ??
          avail.askingPrice ??
          50000
      );

      if (!quote) {
        const [newQuote] = await tx
          .insert(quotations)
          .values({
            requirementId: req.id,
            brokerId: brokerUser.id,
            sellerAvailabilityId: avail.id,
            offeredPrice: String(agreedPrice),
            status: 'Accepted',
            validUntil: new Date(Date.now() + 30 * 86400000),
          })
          .returning();
        quote = newQuote;
      }

      // 6. Find Buyer & Seller counterparty user identities
      const buyerUser = await tx.query.users.findFirst({
        where: eq(users.companyId, req.companyId),
      });

      const sellerUser = await tx.query.users.findFirst({
        where: eq(users.companyId, avail.companyId),
      });

      const agreedQuantity = Number(
        input.customTerms?.agreedQuantity ?? allocation.allocatedQuantity
      );

      // 7. Insert authoritative `deals` record
      const [newDeal] = await tx
        .insert(deals)
        .values({
          requirementId: req.id,
          quotationId: quote.id,
          buyerId: buyerUser?.id || brokerUser.id,
          sellerId: sellerUser?.id || brokerUser.id,
          brokerId: brokerUser.id,
          agreedPrice: String(agreedPrice),
          agreedQuantity: agreedQuantity,
          status: 'Draft',
        })
        .returning();

      // 8. Atomically commit allocation to deal
      await tx
        .update(requirementAllocations)
        .set({
          dealId: newDeal.id,
          status: 'COMMITTED_TO_DEAL',
          version: sql`${requirementAllocations.version} + 1`,
        })
        .where(eq(requirementAllocations.id, allocation.id));

      // 9. Create immutable Deal Version 1 terms snapshot
      const deliveryLocation =
        input.customTerms?.deliveryLocation ||
        req.deliveryTermsId ||
        'Destination Mill / Warehouse';

      const deliveryDate =
        input.customTerms?.deliveryDate ||
        (req.targetDate
          ? new Date(req.targetDate).toISOString().split('T')[0]
          : new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0]);

      const priceBasis =
        input.customTerms?.priceBasis ||
        allocation.priceBasis ||
        'FOR_DESTINATION';

      const deliveryTerms =
        input.customTerms?.deliveryTerms || 'Ex-Warehouse / FOR';

      const paymentTerms =
        input.customTerms?.paymentTerms || '100% Advance / RTGS against Invoice';

      const packagingType =
        input.customTerms?.packagingType || '50kg Jute Bags';

      const brokerCommissionRate = Number(
        input.customTerms?.brokerCommissionRate ?? 0
      );

      const commissionBasis =
        input.customTerms?.commissionBasis || '₹/MT';

      const initialSnapshot = {
        dealId: newDeal.id,
        quotationId: quote.id,
        allocationId: allocation.id,
        allocationReference: allocation.allocationReference,
        requirementId: req.id,
        availabilityId: avail.id,
        commodityId: req.commodityId,
        commodityName: commodity?.name || 'Raw Material',
        gradeId: req.gradeId,
        gradeName: grade?.gradeName || 'Standard Commercial Grade',
        quantity: agreedQuantity,
        unitSymbol: unit?.symbol || 'MT',
        agreedPrice: agreedPrice,
        rate: agreedPrice,
        baseRate: agreedPrice,
        priceBasis: priceBasis,
        deliveryLocation: deliveryLocation,
        deliveryDate: deliveryDate,
        deliveryTerms: deliveryTerms,
        paymentTerms: paymentTerms,
        packagingType: packagingType,
        brokerCommissionRate: brokerCommissionRate,
        commissionBasis: commissionBasis,
        notes: input.customTerms?.notes || allocation.notes || '',
        buyerCompanyId: req.companyId,
        sellerCompanyId: avail.companyId,
        buyerConfirmed: false,
        buyerConfirmedAt: null,
        buyerConfirmedBy: null,
        buyerNotes: null,
        sellerConfirmed: false,
        sellerConfirmedAt: null,
        sellerConfirmedBy: null,
        sellerNotes: null,
        changedFields: [],
        versionReason: 'Initial deal draft created from confirmed allocation',
        originatorRole: 'broker',
        timestamp: new Date().toISOString(),
      };

      await tx.insert(dealVersions).values({
        requestId: newDeal.id,
        versionNumber: 1,
        actorId: brokerUser.id,
        status: 'Draft',
        snapshotPayload: initialSnapshot,
      });

      // 10. Record tracking event in negotiation_events
      await tx.insert(negotiationEvents).values({
        requestId: newDeal.id,
        companyId: brokerUser.companyId || req.companyId || avail.companyId,
        actorId: brokerUser.id,
        actionType: 'DEAL_CREATED',
        payload: {
          dealId: newDeal.id,
          allocationReference: allocation.allocationReference,
          agreedQuantity,
          agreedPrice,
          versionNumber: 1,
        },
      });

      // 11. Decision Gate Audit Log
      await logDecisionGateAuditEventAction({
        action: 'DEAL_CREATED',
        actorId: brokerUser.id,
        actorRole: 'broker',
        entity: 'deals',
        entityId: newDeal.id,
        metadata: {
          allocationReference: allocation.allocationReference,
          requirementId: req.id,
          availabilityId: avail.id,
          agreedQuantity,
          agreedPrice,
          versionNumber: 1,
          humanReviewed: true,
        },
      });

      // 12. Dispatch notification to buyer and seller
      if (buyerUser) {
        await queueNotificationAction({
          userId: buyerUser.id,
          companyId: req.companyId,
          channel: 'IN_APP',
          eventType: 'DEAL_VERSION_UPDATE',
          title: `New Deal Draft Created: ${commodity?.name || 'Raw Material'}`,
          message: `Broker created Deal Draft for ${agreedQuantity} ${unit?.symbol || 'MT'} @ ₹${agreedPrice}/${unit?.symbol || 'MT'}. Review terms in Deal Workspace.`,
          actionLabel: 'View Deal',
          actionUrl: `/broker/deals/${newDeal.id}`,
        });
      }

      if (sellerUser) {
        await queueNotificationAction({
          userId: sellerUser.id,
          companyId: avail.companyId,
          channel: 'IN_APP',
          eventType: 'DEAL_VERSION_UPDATE',
          title: `New Deal Draft Created: ${commodity?.name || 'Raw Material'}`,
          message: `Broker created Deal Draft for ${agreedQuantity} ${unit?.symbol || 'MT'} @ ₹${agreedPrice}/${unit?.symbol || 'MT'}. Review terms in Deal Workspace.`,
          actionLabel: 'View Deal',
          actionUrl: `/broker/deals/${newDeal.id}`,
        });
      }

      revalidatePath('/broker/deals');
      revalidatePath('/broker/work');

      return {
        success: true,
        dealId: newDeal.id,
        versionNumber: 1,
        message: 'Deal created successfully from allocation! Draft terms ready for negotiation.',
      };
    });
  } catch (error: any) {
    console.error('Error in createDealFromAllocationAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to create deal from allocation',
    };
  }
}

// ==========================================
// 2. UPDATE DEAL TERMS ACTION (VERSIONED NEGOTIATION)
// ==========================================

/**
 * Material terms change action:
 * - Checks optimistic version concurrency.
 * - Detects material differences against current snapshot.
 * - If material changes detected: creates new immutable Deal Version, supersedes previous versions,
 *   strictly INVALIDATES prior buyer/seller confirmations, and resets status to 'Negotiation'.
 */
export async function updateDealTermsAction(
  input: UpdateDealTermsInput
): Promise<UpdateDealTermsResult> {
  try {
    const auth = await getAuthorizedBrokerSession();
    if (!auth.success) return { success: false, error: auth.error };
    const { user: brokerUser, isAdmin } = auth;

    if (!input.dealId) return { success: false, error: 'Deal ID is required' };
    if (!input.expectedVersion || input.expectedVersion < 1) {
      return { success: false, error: 'Valid expectedVersion number is required' };
    }

    return await db.transaction(async (tx) => {
      // 1. Locate Deal
      const dealRes = await tx
        .select()
        .from(deals)
        .where(eq(deals.id, input.dealId))
        .limit(1);

      if (!dealRes || dealRes.length === 0) {
        throw new Error('Deal record not found');
      }

      const deal = dealRes[0];

      // Authorization check
      if (!isAdmin && deal.brokerId !== brokerUser.id) {
        throw new Error('Forbidden: You are not authorized to edit this deal');
      }

      // Lifecycle check: Cannot edit finalized, cancelled, or in-fulfillment deals
      if (['Finalized', 'In Fulfillment', 'Completed', 'Cancelled'].includes(deal.status)) {
        throw new Error(
          `Cannot edit terms of a "${deal.status}" deal. Finalized or closed contracts are immutable.`
        );
      }

      // 2. Fetch latest version record with concurrency check
      const latestVersions = await tx
        .select()
        .from(dealVersions)
        .where(eq(dealVersions.requestId, deal.id))
        .orderBy(desc(dealVersions.versionNumber))
        .limit(1);

      if (!latestVersions || latestVersions.length === 0) {
        throw new Error('No deal versions exist for this record');
      }

      const latestVersion = latestVersions[0];

      if (latestVersion.versionNumber !== input.expectedVersion) {
        throw new Error(
          `STALE_VERSION_DETECTED: Active terms are at Version ${latestVersion.versionNumber}, but you submitted edits for Version ${input.expectedVersion}. Please refresh the latest terms.`
        );
      }

      const prevSnapshot = (latestVersion.snapshotPayload as any) || {};

      // 3. Construct proposed snapshot
      const proposedSnapshot = {
        ...prevSnapshot,
        agreedPrice: input.terms.agreedPrice !== undefined ? Number(input.terms.agreedPrice) : prevSnapshot.agreedPrice,
        rate: input.terms.agreedPrice !== undefined ? Number(input.terms.agreedPrice) : prevSnapshot.rate,
        quantity: input.terms.agreedQuantity !== undefined ? Number(input.terms.agreedQuantity) : prevSnapshot.quantity,
        priceBasis: input.terms.priceBasis !== undefined ? input.terms.priceBasis : prevSnapshot.priceBasis,
        deliveryLocation: input.terms.deliveryLocation !== undefined ? input.terms.deliveryLocation : prevSnapshot.deliveryLocation,
        deliveryDate: input.terms.deliveryDate !== undefined ? input.terms.deliveryDate : prevSnapshot.deliveryDate,
        deliveryTerms: input.terms.deliveryTerms !== undefined ? input.terms.deliveryTerms : prevSnapshot.deliveryTerms,
        paymentTerms: input.terms.paymentTerms !== undefined ? input.terms.paymentTerms : prevSnapshot.paymentTerms,
        packagingType: input.terms.packagingType !== undefined ? input.terms.packagingType : prevSnapshot.packagingType,
        brokerCommissionRate: input.terms.brokerCommissionRate !== undefined ? Number(input.terms.brokerCommissionRate) : prevSnapshot.brokerCommissionRate,
        commissionBasis: input.terms.commissionBasis !== undefined ? input.terms.commissionBasis : prevSnapshot.commissionBasis,
        notes: input.terms.notes !== undefined ? input.terms.notes : prevSnapshot.notes,
        // Invalidate confirmations on material revision!
        buyerConfirmed: false,
        buyerConfirmedAt: null,
        buyerConfirmedBy: null,
        buyerNotes: null,
        sellerConfirmed: false,
        sellerConfirmedAt: null,
        sellerConfirmedBy: null,
        sellerNotes: null,
        versionReason: input.terms.reason || 'Deal terms revised during negotiation',
        originatorRole: 'broker',
        timestamp: new Date().toISOString(),
      };

      // 4. Calculate material differences
      const hasMaterialChanges = detectMaterialChanges(prevSnapshot, proposedSnapshot);
      const diffs = getMaterialDiffList(prevSnapshot, proposedSnapshot);

      if (!hasMaterialChanges && diffs.length === 0) {
        return {
          success: true,
          dealId: deal.id,
          versionNumber: latestVersion.versionNumber,
          diffs: [],
          message: 'No material terms were altered. Existing version maintained.',
        };
      }

      // 5. Increment version and mark previous as Superseded
      const nextVersionNumber = latestVersion.versionNumber + 1;

      await tx
        .update(dealVersions)
        .set({ status: 'Superseded' })
        .where(eq(dealVersions.requestId, deal.id));

      proposedSnapshot.changedFields = diffs.map((d) => d.field);

      const [newVersionRow] = await tx
        .insert(dealVersions)
        .values({
          requestId: deal.id,
          versionNumber: nextVersionNumber,
          actorId: brokerUser.id,
          status: 'Negotiation',
          snapshotPayload: proposedSnapshot,
        })
        .returning();

      // 6. Update parent Deal state
      await tx
        .update(deals)
        .set({
          agreedPrice: String(proposedSnapshot.agreedPrice),
          agreedQuantity: Number(proposedSnapshot.quantity),
          status: 'Negotiation',
        })
        .where(eq(deals.id, deal.id));

      // 7. Insert negotiation event
      await tx.insert(negotiationEvents).values({
        requestId: deal.id,
        companyId: brokerUser.companyId || prevSnapshot.buyerCompanyId || prevSnapshot.sellerCompanyId,
        actorId: brokerUser.id,
        actionType: 'DEAL_TERMS_REVISED',
        payload: {
          versionNumber: nextVersionNumber,
          diffs,
          reason: input.terms.reason || null,
        },
      });

      // 8. Log Decision Gate Audit
      await logDecisionGateAuditEventAction({
        action: 'DEAL_TERMS_REVISED',
        actorId: brokerUser.id,
        actorRole: 'broker',
        entity: 'deals',
        entityId: deal.id,
        metadata: {
          versionNumber: nextVersionNumber,
          changedFields: diffs.map((d) => d.field),
          confirmationsInvalidated: true,
          humanReviewed: true,
        },
      });

      revalidatePath('/broker/deals');
      revalidatePath(`/broker/deals/${deal.id}`);

      return {
        success: true,
        dealId: deal.id,
        versionNumber: nextVersionNumber,
        diffs,
        message: `Deal terms updated to Version ${nextVersionNumber}. Prior confirmations have been invalidated. Both parties must re-confirm.`,
      };
    });
  } catch (error: any) {
    console.error('Error in updateDealTermsAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to update deal terms',
    };
  }
}

// ==========================================
// 3. RECORD COUNTERPARTY CONFIRMATION ACTION
// ==========================================

/**
 * Records an authorized confirmation (Buyer or Seller) against the exact latest deal version.
 * Transitions lifecycle:
 * - 1 of 2 confirmations -> 'Awaiting Buyer Confirmation' / 'Awaiting Seller Confirmation'
 * - 2 of 2 confirmations -> 'Ready to Finalize'
 */
export async function recordPartyConfirmationAction(
  input: RecordPartyConfirmationInput
): Promise<RecordPartyConfirmationResult> {
  try {
    const auth = await getAuthorizedBrokerSession();
    if (!auth.success) return { success: false, error: auth.error };
    const { user: brokerUser, isAdmin } = auth;

    if (!input.dealId) return { success: false, error: 'Deal ID is required' };
    if (!['BUYER', 'SELLER'].includes(input.party)) {
      return { success: false, error: 'Party must be BUYER or SELLER' };
    }

    return await db.transaction(async (tx) => {
      // 1. Locate Deal
      const dealRes = await tx
        .select()
        .from(deals)
        .where(eq(deals.id, input.dealId))
        .limit(1);

      if (!dealRes || dealRes.length === 0) {
        throw new Error('Deal record not found');
      }

      const deal = dealRes[0];

      if (!isAdmin && deal.brokerId !== brokerUser.id) {
        throw new Error('Forbidden: You are not authorized to manage this deal');
      }

      if (['Finalized', 'Cancelled'].includes(deal.status)) {
        throw new Error(`Cannot record confirmation for a "${deal.status}" deal.`);
      }

      // 2. Fetch latest version
      const latestVersions = await tx
        .select()
        .from(dealVersions)
        .where(eq(dealVersions.requestId, deal.id))
        .orderBy(desc(dealVersions.versionNumber))
        .limit(1);

      if (!latestVersions || latestVersions.length === 0) {
        throw new Error('No deal versions exist for this record');
      }

      const latestVersion = latestVersions[0];

      // Stale version guard
      if (latestVersion.versionNumber !== input.versionNumber) {
        throw new Error(
          `STALE_VERSION_DETECTED: Active terms are at Version ${latestVersion.versionNumber}, but confirmation was submitted for Version ${input.versionNumber}. Confirmations must target the latest version.`
        );
      }

      const snapshot = (latestVersion.snapshotPayload as any) || {};

      // 3. Apply party confirmation
      let buyerConfirmed = Boolean(snapshot.buyerConfirmed);
      let sellerConfirmed = Boolean(snapshot.sellerConfirmed);
      const now = new Date().toISOString();

      if (input.party === 'BUYER') {
        buyerConfirmed = true;
        snapshot.buyerConfirmed = true;
        snapshot.buyerConfirmedAt = now;
        snapshot.buyerConfirmedBy = brokerUser.id;
        snapshot.buyerNotes = input.verificationNotes || 'Verified by Broker Desk';
      } else {
        sellerConfirmed = true;
        snapshot.sellerConfirmed = true;
        snapshot.sellerConfirmedAt = now;
        snapshot.sellerConfirmedBy = brokerUser.id;
        snapshot.sellerNotes = input.verificationNotes || 'Verified by Broker Desk';
      }

      // 4. Calculate next status
      let nextStatus: DealLifecycleStatus = 'Negotiation';
      let canFinalize = false;

      if (buyerConfirmed && sellerConfirmed) {
        nextStatus = 'Ready to Finalize';
        canFinalize = true;
      } else if (buyerConfirmed && !sellerConfirmed) {
        nextStatus = 'Awaiting Seller Confirmation';
      } else if (!buyerConfirmed && sellerConfirmed) {
        nextStatus = 'Awaiting Buyer Confirmation';
      }

      // 5. Update deal version snapshot and status
      await tx
        .update(dealVersions)
        .set({
          status: nextStatus,
          snapshotPayload: snapshot,
        })
        .where(eq(dealVersions.id, latestVersion.id));

      // 6. Update parent deal status
      await tx
        .update(deals)
        .set({ status: nextStatus })
        .where(eq(deals.id, deal.id));

      // 7. Insert negotiation event
      await tx.insert(negotiationEvents).values({
        requestId: deal.id,
        companyId: brokerUser.companyId || snapshot.buyerCompanyId || snapshot.sellerCompanyId,
        actorId: brokerUser.id,
        actionType: 'DEAL_PARTY_CONFIRMED',
        payload: {
          party: input.party,
          versionNumber: latestVersion.versionNumber,
          status: nextStatus,
          notes: input.verificationNotes || null,
        },
      });

      // 8. Log Decision Gate Audit
      await logDecisionGateAuditEventAction({
        action: 'DEAL_PARTY_CONFIRMED',
        actorId: brokerUser.id,
        actorRole: 'broker',
        entity: 'deals',
        entityId: deal.id,
        metadata: {
          party: input.party,
          versionNumber: latestVersion.versionNumber,
          nextStatus,
          canFinalize,
          humanReviewed: true,
        },
      });

      revalidatePath('/broker/deals');
      revalidatePath(`/broker/deals/${deal.id}`);

      return {
        success: true,
        dealId: deal.id,
        versionNumber: latestVersion.versionNumber,
        currentStatus: nextStatus,
        buyerConfirmed,
        sellerConfirmed,
        canFinalize,
        message: `${input.party === 'BUYER' ? 'Buyer' : 'Seller'} confirmation recorded for Version ${latestVersion.versionNumber}. Current status: "${nextStatus}".`,
      };
    });
  } catch (error: any) {
    console.error('Error in recordPartyConfirmationAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to record party confirmation',
    };
  }
}

// ==========================================
// 4. PRE-FLIGHT FINALIZATION & BOOKING ACTION
// ==========================================

/**
 * Pre-Flight Finalization Gate:
 * Strictly blocks finalization until BOTH Buyer and Seller have confirmed the identical latest version.
 * Creates immutable booking reference BKG-YYYY-XXXX and freezes deal in 'Finalized' state.
 */
export async function finalizeBrokerDealAction(
  dealId: string,
  expectedVersion: number
): Promise<FinalizeDealResult> {
  try {
    const auth = await getAuthorizedBrokerSession();
    if (!auth.success) return { success: false, error: auth.error };
    const { user: brokerUser, isAdmin } = auth;

    if (!dealId) return { success: false, error: 'Deal ID is required' };
    if (!expectedVersion || expectedVersion < 1) {
      return { success: false, error: 'Valid expectedVersion number is required' };
    }

    return await db.transaction(async (tx) => {
      // 1. Locate Deal
      const dealRes = await tx
        .select()
        .from(deals)
        .where(eq(deals.id, dealId))
        .limit(1);

      if (!dealRes || dealRes.length === 0) {
        throw new Error('Deal record not found');
      }

      const deal = dealRes[0];

      if (!isAdmin && deal.brokerId !== brokerUser.id) {
        throw new Error('Forbidden: Only an authorized broker can finalize this deal');
      }

      if (deal.status === 'Finalized') {
        throw new Error('This deal has already been finalized.');
      }

      if (deal.status === 'Cancelled') {
        throw new Error('Cannot finalize a cancelled deal.');
      }

      // 2. Fetch latest version
      const latestVersions = await tx
        .select()
        .from(dealVersions)
        .where(eq(dealVersions.requestId, deal.id))
        .orderBy(desc(dealVersions.versionNumber))
        .limit(1);

      if (!latestVersions || latestVersions.length === 0) {
        throw new Error('No deal versions exist for this record');
      }

      const latestVersion = latestVersions[0];

      // Concurrency check
      if (latestVersion.versionNumber !== expectedVersion) {
        throw new Error(
          `STALE_VERSION_DETECTED: Active deal terms are at Version ${latestVersion.versionNumber}, but finalization was requested for Version ${expectedVersion}. Please refresh.`
        );
      }

      const snapshot = (latestVersion.snapshotPayload as any) || {};

      // 3. PRE-FLIGHT GATE: Require BOTH Buyer and Seller confirmation on identical version
      const buyerConfirmed = Boolean(snapshot.buyerConfirmed);
      const sellerConfirmed = Boolean(snapshot.sellerConfirmed);

      if (!buyerConfirmed || !sellerConfirmed) {
        const missing: string[] = [];
        if (!buyerConfirmed) missing.push('Buyer');
        if (!sellerConfirmed) missing.push('Seller');

        throw new Error(
          `MISSING_CONFIRMATION: Both Buyer and Seller must confirm the identical latest version (Version ${expectedVersion}) before finalization. Missing confirmation: ${missing.join(', ')}.`
        );
      }

      // 4. Generate unique Booking Reference
      const bookingRef = `BKG-${new Date().getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;

      // 5. Insert Booking record
      const [newBooking] = await tx
        .insert(bookings)
        .values({
          bookingReference: bookingRef,
          dealId: deal.id,
          lockedVersionId: latestVersion.id,
          status: 'Confirmed',
        })
        .returning();

      // 6. Freeze deal version to 'Broker Finalized'
      await tx
        .update(dealVersions)
        .set({ status: 'Broker Finalized' })
        .where(eq(dealVersions.id, latestVersion.id));

      // 7. Update parent deal to 'Finalized'
      await tx
        .update(deals)
        .set({
          status: 'Finalized',
          closedAt: new Date(),
        })
        .where(eq(deals.id, deal.id));

      // 8. Update parent quotation if exists
      if (deal.quotationId) {
        await tx
          .update(quotations)
          .set({ status: 'Broker Finalized' })
          .where(eq(quotations.id, deal.quotationId));
      }

      // 9. Insert negotiation event
      await tx.insert(negotiationEvents).values({
        requestId: deal.id,
        companyId: brokerUser.companyId || snapshot.buyerCompanyId || snapshot.sellerCompanyId,
        actorId: brokerUser.id,
        actionType: 'BROKER_DEAL_FINALIZATION',
        payload: {
          versionNumber: expectedVersion,
          bookingReference: bookingRef,
          bookingId: newBooking.id,
          agreedPrice: deal.agreedPrice,
          agreedQuantity: deal.agreedQuantity,
        },
      });

      // 10. Log Decision Gate Audit
      await logDecisionGateAuditEventAction({
        action: 'DEAL_FINALIZED',
        actorId: brokerUser.id,
        actorRole: 'broker',
        entity: 'deals',
        entityId: deal.id,
        metadata: {
          versionNumber: expectedVersion,
          bookingReference: bookingRef,
          humanReviewed: true,
        },
      });

      // 11. Dispatch notifications
      if (deal.buyerId) {
        await queueNotificationAction({
          userId: deal.buyerId,
          companyId: snapshot.buyerCompanyId,
          channel: 'IN_APP',
          eventType: 'BOOKING_CREATED',
          title: `Deal Finalized — Booking Reference ${bookingRef}`,
          message: `Broker Desk has finalized commercial contract for ${deal.agreedQuantity} MT @ ₹${deal.agreedPrice}/MT. Booking ID: ${bookingRef}.`,
          actionLabel: 'View Contract',
          actionUrl: `/broker/deals/${deal.id}`,
        });
      }

      if (deal.sellerId) {
        await queueNotificationAction({
          userId: deal.sellerId,
          companyId: snapshot.sellerCompanyId,
          channel: 'IN_APP',
          eventType: 'BOOKING_CREATED',
          title: `Deal Finalized — Booking Reference ${bookingRef}`,
          message: `Broker Desk has finalized commercial contract for ${deal.agreedQuantity} MT @ ₹${deal.agreedPrice}/MT. Booking ID: ${bookingRef}.`,
          actionLabel: 'View Contract',
          actionUrl: `/broker/deals/${deal.id}`,
        });
      }

      revalidatePath('/broker/deals');
      revalidatePath(`/broker/deals/${deal.id}`);
      revalidatePath('/broker/orders');

      return {
        success: true,
        dealId: deal.id,
        bookingReference: bookingRef,
        versionNumber: expectedVersion,
        message: `Deal finalized successfully! Booking reference ${bookingRef} issued.`,
      };
    });
  } catch (error: any) {
    console.error('Error in finalizeBrokerDealAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to finalize deal',
    };
  }
}

// Alias for universal compatibility
export async function finalizeDealAction(...args: Parameters<typeof finalizeBrokerDealAction>) {
  return finalizeBrokerDealAction(...args);
}



// ==========================================
// 5. CANCEL DEAL ACTION (TRANSACTIONAL RELEASE)
// ==========================================

/**
 * Cancels a deal with mandatory non-empty reason.
 * Transactionally releases linked allocations back to available inventory.
 */
export async function cancelDealAction(
  input: CancelDealInput
): Promise<CancelDealResult> {
  try {
    if (!input.dealId) return { success: false, error: 'Deal ID is required' };
    if (!input.reason || input.reason.trim().length < 3) {
      return {
        success: false,
        error: 'A valid cancellation reason (minimum 3 characters) is required',
      };
    }

    const auth = await getAuthorizedBrokerSession();
    if (!auth.success) return { success: false, error: auth.error };
    const { user: brokerUser, isAdmin } = auth;

    return await db.transaction(async (tx) => {
      // 1. Locate Deal
      const dealRes = await tx
        .select()
        .from(deals)
        .where(eq(deals.id, input.dealId))
        .limit(1);

      if (!dealRes || dealRes.length === 0) {
        throw new Error('Deal record not found');
      }

      const deal = dealRes[0];

      if (!isAdmin && deal.brokerId !== brokerUser.id) {
        throw new Error('Forbidden: You are not authorized to cancel this deal');
      }

      if (['Finalized', 'In Fulfillment', 'Completed'].includes(deal.status)) {
        throw new Error(`Cannot cancel a "${deal.status}" deal.`);
      }

      if (deal.status === 'Cancelled') {
        throw new Error('This deal has already been cancelled.');
      }

      const now = new Date();

      // 2. Update Deal status to Cancelled
      await tx
        .update(deals)
        .set({
          status: 'Cancelled',
          closedAt: now,
        })
        .where(eq(deals.id, deal.id));

      // 3. Mark latest version as Cancelled
      await tx
        .update(dealVersions)
        .set({ status: 'Cancelled' })
        .where(eq(dealVersions.requestId, deal.id));

      // 4. Release linked allocations and restore inventory balances
      const linkedAllocations = await tx
        .select()
        .from(requirementAllocations)
        .where(eq(requirementAllocations.dealId, deal.id));

      for (const alloc of linkedAllocations) {
        await tx
          .update(requirementAllocations)
          .set({
            status: 'RELEASED',
            releaseReason: input.reason.trim(),
            releasedAt: now,
            version: sql`${requirementAllocations.version} + 1`,
          })
          .where(eq(requirementAllocations.id, alloc.id));

        // Restore availability and requirement quantities
        const allocatedQty = Number(alloc.allocatedQuantity) || 0;
        if (allocatedQty > 0) {
          await tx
            .update(availabilities)
            .set({
              availableQuantity: sql`${availabilities.availableQuantity} + ${allocatedQty}`,
              reservedQuantity: sql`GREATEST(0, ${availabilities.reservedQuantity} - ${allocatedQty})`,
              version: sql`${availabilities.version} + 1`,
            })
            .where(eq(availabilities.id, alloc.availabilityId));

          await tx
            .update(requirements)
            .set({
              fulfilledQuantity: sql`GREATEST(0, ${requirements.fulfilledQuantity} - ${allocatedQty})`,
            })
            .where(eq(requirements.id, alloc.requirementId));
        }
      }

      // 5. Insert negotiation event
      await tx.insert(negotiationEvents).values({
        requestId: deal.id,
        companyId: brokerUser.companyId || brokerUser.id,
        actorId: brokerUser.id,
        actionType: 'DEAL_CANCELLED',
        payload: {
          reason: input.reason.trim(),
          releasedAllocationsCount: linkedAllocations.length,
        },
      });

      // 6. Log Decision Gate Audit
      await logDecisionGateAuditEventAction({
        action: 'DEAL_CANCELLED',
        actorId: brokerUser.id,
        actorRole: 'broker',
        entity: 'deals',
        entityId: deal.id,
        metadata: {
          reason: input.reason.trim(),
          releasedAllocationsCount: linkedAllocations.length,
          humanReviewed: true,
        },
      });

      revalidatePath('/broker/deals');
      revalidatePath(`/broker/deals/${deal.id}`);
      revalidatePath('/broker/work');

      return {
        success: true,
        dealId: deal.id,
        message: 'Deal cancelled successfully and linked allocations restored to inventory.',
      };
    });
  } catch (error: any) {
    console.error('Error in cancelDealAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to cancel deal',
    };
  }
}

// ==========================================
// 6. GET BROKER DEALS LIST ACTION
// ==========================================

export async function getBrokerDealsListAction(filters?: {
  status?: string;
  search?: string;
  limit?: number;
}): Promise<{
  success: boolean;
  deals?: BrokerDealSummary[];
  error?: string;
}> {
  try {
    const auth = await getAuthorizedBrokerSession();
    if (!auth.success) return { success: false, error: auth.error };
    const { user: brokerUser, isAdmin } = auth;

    // Fetch deals
    let dealQuery = db
      .select({
        id: deals.id,
        requirementId: deals.requirementId,
        quotationId: deals.quotationId,
        buyerId: deals.buyerId,
        sellerId: deals.sellerId,
        brokerId: deals.brokerId,
        agreedPrice: deals.agreedPrice,
        agreedQuantity: deals.agreedQuantity,
        status: deals.status,
        createdAt: deals.createdAt,
        closedAt: deals.closedAt,
      })
      .from(deals)
      .orderBy(desc(deals.createdAt));

    const rows = await dealQuery;

    // Filter by broker ownership if not admin
    const filteredRows = isAdmin
      ? rows
      : rows.filter((r) => r.brokerId === brokerUser.id || !r.brokerId);

    // Collect related IDs
    const dealIds = filteredRows.map((r) => r.id);
    if (dealIds.length === 0) {
      return { success: true, deals: [] };
    }

    // Load latest versions
    const allVersions = await db
      .select()
      .from(dealVersions)
      .where(inArray(dealVersions.requestId, dealIds))
      .orderBy(desc(dealVersions.versionNumber));

    // Load bookings
    const allBookings = await db
      .select()
      .from(bookings)
      .where(inArray(bookings.dealId, dealIds));

    // Load linked allocations
    const allAllocations = await db
      .select()
      .from(requirementAllocations)
      .where(inArray(requirementAllocations.dealId, dealIds));

    // Load requirements, commodities, companies
    const reqIds = Array.from(new Set(filteredRows.map((r) => r.requirementId)));
    const allReqs = reqIds.length > 0
      ? await db.select().from(requirements).where(inArray(requirements.id, reqIds))
      : [];

    const commodityIds = Array.from(new Set(allReqs.map((r) => r.commodityId)));
    const allCommodities = commodityIds.length > 0
      ? await db.select().from(masterCommodities).where(inArray(masterCommodities.id, commodityIds))
      : [];

    const gradeIds = Array.from(new Set(allReqs.map((r) => r.gradeId).filter(Boolean))) as string[];
    const allGrades = gradeIds.length > 0
      ? await db.select().from(masterGrades).where(inArray(masterGrades.id, gradeIds))
      : [];

    const allCompanies = await db.select().from(companies);

    // Assemble summaries
    const summaries: BrokerDealSummary[] = filteredRows.map((d) => {
      const versions = allVersions.filter((v) => v.requestId === d.id);
      const latestVersion = versions[0];
      const snapshot = (latestVersion?.snapshotPayload as any) || {};

      const booking = allBookings.find((b) => b.dealId === d.id);
      const alloc = allAllocations.find((a) => a.dealId === d.id);

      const req = allReqs.find((r) => r.id === d.requirementId);
      const commodity = allCommodities.find((c) => c.id === req?.commodityId);
      const grade = allGrades.find((g) => g.id === req?.gradeId);

      const buyerComp = allCompanies.find(
        (c) => c.id === snapshot.buyerCompanyId || c.id === req?.companyId
      );
      const sellerComp = allCompanies.find(
        (c) => c.id === snapshot.sellerCompanyId
      );

      const agreedPrice = Number(d.agreedPrice || snapshot.agreedPrice || 0);
      const agreedQuantity = Number(d.agreedQuantity || snapshot.quantity || 0);

      return {
        id: d.id,
        quotationId: d.quotationId,
        requirementId: d.requirementId,
        allocationId: alloc?.id || snapshot.allocationId || null,
        allocationReference: alloc?.allocationReference || snapshot.allocationReference || null,
        bookingId: booking?.id || null,
        bookingReference: booking?.bookingReference || null,
        commodityName: commodity?.name || snapshot.commodityName || 'Raw Material',
        gradeName: grade?.gradeName || snapshot.gradeName || null,
        buyerCompanyId: buyerComp?.id || '',
        buyerCompanyName: buyerComp?.name || 'Buyer Enterprise',
        sellerCompanyId: sellerComp?.id || '',
        sellerCompanyName: sellerComp?.name || 'Seller Enterprise',
        agreedQuantity,
        unitSymbol: snapshot.unitSymbol || 'MT',
        agreedPrice,
        totalValuation: agreedPrice * agreedQuantity,
        priceBasis: snapshot.priceBasis || 'FOR_DESTINATION',
        deliveryLocation: snapshot.deliveryLocation || null,
        deliveryDate: snapshot.deliveryDate || null,
        status: d.status,
        latestVersionNumber: latestVersion?.versionNumber || 1,
        buyerConfirmed: Boolean(snapshot.buyerConfirmed),
        sellerConfirmed: Boolean(snapshot.sellerConfirmed),
        createdAt: new Date(d.createdAt).toISOString(),
        closedAt: d.closedAt ? new Date(d.closedAt).toISOString() : null,
      };
    });

    // Apply optional status and search filters
    let result = summaries;
    if (filters?.status && filters.status !== 'All') {
      result = result.filter((s) => s.status.toLowerCase() === filters.status!.toLowerCase());
    }

    if (filters?.search && filters.search.trim()) {
      const q = filters.search.toLowerCase().trim();
      result = result.filter(
        (s) =>
          s.commodityName.toLowerCase().includes(q) ||
          s.buyerCompanyName.toLowerCase().includes(q) ||
          s.sellerCompanyName.toLowerCase().includes(q) ||
          (s.bookingReference && s.bookingReference.toLowerCase().includes(q)) ||
          (s.allocationReference && s.allocationReference.toLowerCase().includes(q))
      );
    }

    if (filters?.limit && filters.limit > 0) {
      result = result.slice(0, filters.limit);
    }

    return { success: true, deals: result };
  } catch (error: any) {
    console.error('Error in getBrokerDealsListAction:', error);
    return { success: false, error: error.message || 'Failed to fetch deals' };
  }
}

// ==========================================
// 7. GET BROKER DEAL DETAIL ACTION
// ==========================================

export async function getBrokerDealDetailAction(
  dealId: string
): Promise<{
  success: boolean;
  data?: BrokerDealDetail;
  error?: string;
}> {
  try {
    const auth = await getAuthorizedBrokerSession();
    if (!auth.success) return { success: false, error: auth.error };
    const { user: brokerUser, isAdmin } = auth;

    if (!dealId) return { success: false, error: 'Deal ID is required' };

    // 1. Fetch deal
    let dealRes = await db
      .select()
      .from(deals)
      .where(eq(deals.id, dealId))
      .limit(1);

    if (!dealRes || dealRes.length === 0) {
      dealRes = await db
        .select()
        .from(deals)
        .where(eq(deals.quotationId, dealId))
        .limit(1);
    }

    if (!dealRes || dealRes.length === 0) {
      return { success: false, error: 'Deal not found' };
    }

    const deal = dealRes[0];

    // Auth check
    if (!isAdmin && deal.brokerId !== brokerUser.id) {
      return { success: false, error: 'Forbidden: You are not authorized to view this deal' };
    }

    // 2. Fetch versions
    const rawVersions = await db
      .select()
      .from(dealVersions)
      .where(eq(dealVersions.requestId, deal.id))
      .orderBy(desc(dealVersions.versionNumber));

    // 3. Fetch users for actor names
    const allUsers = await db.select().from(users);

    // 4. Assemble version timeline with diffs
    const versions: DealVersionTimelineItem[] = rawVersions.map((v, idx) => {
      const nextIdx = idx + 1;
      const olderVersion = rawVersions[nextIdx];
      const olderSnapshot = (olderVersion?.snapshotPayload as any) || null;
      const currentSnapshot = (v.snapshotPayload as any) || {};

      const diffs = getMaterialDiffList(olderSnapshot, currentSnapshot);
      const actor = allUsers.find((u) => u.id === v.actorId);

      return {
        id: v.id,
        versionNumber: v.versionNumber,
        status: v.status,
        actorId: v.actorId,
        actorName: actor?.name || 'Broker Desk',
        actorRole: (actor?.role || 'broker').toUpperCase(),
        createdAt: new Date(v.createdAt).toISOString(),
        snapshot: currentSnapshot,
        diffs,
        changeReason: currentSnapshot.versionReason || null,
      };
    });

    const latestVersion = versions[0];
    const latestSnapshot = latestVersion?.snapshot || {};

    // 5. Load allocation
    const allocRes = await db
      .select()
      .from(requirementAllocations)
      .where(eq(requirementAllocations.dealId, deal.id))
      .limit(1);

    const alloc = allocRes[0] || null;

    // 6. Load requirement & availability
    const reqRes = await db
      .select()
      .from(requirements)
      .where(eq(requirements.id, deal.requirementId))
      .limit(1);

    const req = reqRes[0] || null;

    const avail = alloc?.availabilityId
      ? (
          await db
            .select()
            .from(availabilities)
            .where(eq(availabilities.id, alloc.availabilityId))
            .limit(1)
        )[0] || null
      : null;

    // 7. Load companies
    const allCompanies = await db.select().from(companies);
    const buyerCompany = allCompanies.find(
      (c) => c.id === latestSnapshot.buyerCompanyId || c.id === req?.companyId
    ) || { id: '', name: 'Buyer Enterprise', verified: true };

    const sellerCompany = allCompanies.find(
      (c) => c.id === latestSnapshot.sellerCompanyId || c.id === avail?.companyId
    ) || { id: '', name: 'Seller Enterprise', verified: true };

    // 8. Load booking if finalized
    const bookingRes = await db
      .select()
      .from(bookings)
      .where(eq(bookings.dealId, deal.id))
      .limit(1);

    const booking = bookingRes[0] || null;

    // 9. Load negotiation events
    const rawEvents = await db
      .select()
      .from(negotiationEvents)
      .where(eq(negotiationEvents.requestId, deal.id))
      .orderBy(desc(negotiationEvents.createdAt));

    const events = rawEvents.map((e) => ({
      id: e.id,
      actionType: e.actionType,
      actorId: e.actorId,
      createdAt: new Date(e.createdAt).toISOString(),
      payload: e.payload,
    }));

    const agreedPrice = Number(deal.agreedPrice || latestSnapshot.agreedPrice || 0);
    const agreedQuantity = Number(deal.agreedQuantity || latestSnapshot.quantity || 0);

    const summary: BrokerDealSummary = {
      id: deal.id,
      quotationId: deal.quotationId,
      requirementId: deal.requirementId,
      allocationId: alloc?.id || latestSnapshot.allocationId || null,
      allocationReference: alloc?.allocationReference || latestSnapshot.allocationReference || null,
      bookingId: booking?.id || null,
      bookingReference: booking?.bookingReference || null,
      commodityName: latestSnapshot.commodityName || 'Raw Material',
      gradeName: latestSnapshot.gradeName || null,
      buyerCompanyId: buyerCompany.id,
      buyerCompanyName: buyerCompany.name,
      sellerCompanyId: sellerCompany.id,
      sellerCompanyName: sellerCompany.name,
      agreedQuantity,
      unitSymbol: latestSnapshot.unitSymbol || 'MT',
      agreedPrice,
      totalValuation: agreedPrice * agreedQuantity,
      priceBasis: latestSnapshot.priceBasis || 'FOR_DESTINATION',
      deliveryLocation: latestSnapshot.deliveryLocation || null,
      deliveryDate: latestSnapshot.deliveryDate || null,
      status: deal.status,
      latestVersionNumber: latestVersion?.versionNumber || 1,
      buyerConfirmed: Boolean(latestSnapshot.buyerConfirmed),
      sellerConfirmed: Boolean(latestSnapshot.sellerConfirmed),
      createdAt: new Date(deal.createdAt).toISOString(),
      closedAt: deal.closedAt ? new Date(deal.closedAt).toISOString() : null,
    };

    const buyerConfirmed = Boolean(latestSnapshot.buyerConfirmed);
    const sellerConfirmed = Boolean(latestSnapshot.sellerConfirmed);

    return {
      success: true,
      data: {
        deal: {
          id: deal.id,
          requirementId: deal.requirementId,
          quotationId: deal.quotationId,
          buyerId: deal.buyerId,
          sellerId: deal.sellerId,
          brokerId: deal.brokerId,
          agreedPrice,
          agreedQuantity,
          status: deal.status,
          createdAt: new Date(deal.createdAt).toISOString(),
          closedAt: deal.closedAt ? new Date(deal.closedAt).toISOString() : null,
        },
        summary,
        allocation: alloc
          ? {
              id: alloc.id,
              allocationReference: alloc.allocationReference,
              allocatedQuantity: alloc.allocatedQuantity,
              allocatedPrice: alloc.allocatedPrice ? Number(alloc.allocatedPrice) : null,
              priceBasis: alloc.priceBasis || 'FOR_DESTINATION',
              status: alloc.status,
              notes: alloc.notes,
            }
          : null,
        requirement: req
          ? {
              id: req.id,
              quantity: req.quantity,
              targetPrice: req.targetPrice,
              targetDate: new Date(req.targetDate).toISOString(),
              status: req.status,
            }
          : null,
        availability: avail
          ? {
              id: avail.id,
              lotNumber: avail.lotNumber,
              availableQuantity: Number(avail.availableQuantity) || 0,
              askingPrice: Number(avail.askingPrice) || 0,
              status: avail.status,
            }
          : null,
        buyerCompany: {
          id: buyerCompany.id,
          name: buyerCompany.name,
          verified: Boolean((buyerCompany as any).isVerified ?? true),
        },
        sellerCompany: {
          id: sellerCompany.id,
          name: sellerCompany.name,
          verified: Boolean((sellerCompany as any).isVerified ?? true),
        },
        versions,
        confirmations: {
          latestVersionNumber: latestVersion?.versionNumber || 1,
          buyerConfirmed,
          buyerConfirmedAt: latestSnapshot.buyerConfirmedAt || null,
          buyerConfirmedBy: latestSnapshot.buyerConfirmedBy || null,
          buyerNotes: latestSnapshot.buyerNotes || null,
          sellerConfirmed,
          sellerConfirmedAt: latestSnapshot.sellerConfirmedAt || null,
          sellerConfirmedBy: latestSnapshot.sellerConfirmedBy || null,
          sellerNotes: latestSnapshot.sellerNotes || null,
          canFinalize: buyerConfirmed && sellerConfirmed && !['Finalized', 'Cancelled'].includes(deal.status),
        },
        booking: booking
          ? {
              id: booking.id,
              bookingReference: booking.bookingReference,
              status: booking.status,
              createdAt: new Date(booking.createdAt).toISOString(),
            }
          : null,
        events,
      },
    };
  } catch (error: any) {
    console.error('Error in getBrokerDealDetailAction:', error);
    return { success: false, error: error.message || 'Failed to fetch deal details' };
  }
}

// ==========================================
// 8. PRE-EXISTING COMPATIBILITY ACTIONS
// ==========================================

export async function generateFinalDealSnapshotAction(
  payload: GenerateFinalDealSnapshotPayload
): Promise<GenerateFinalDealResult> {
  try {
    const auth = await getAuthorizedBrokerSession();
    if (!auth.success) return { success: false, error: auth.error };
    const { user: dbUser, isAdmin } = auth;
    const authUser = dbUser;

    // Validate payload
    const validation = generateFinalDealSnapshotSchema.safeParse(payload);
    if (!validation.success) {
      const firstErr = validation.error.errors[0]?.message || 'Invalid deal snapshot input';
      return { success: false, error: firstErr };
    }

    const data = validation.data;

    // Mathematical Calculations
    const baseRate = data.baseRate;
    const quantity = data.quantity;
    const buyerMarkup = data.buyerMarkup || 0;
    const sellerDeduction = data.sellerDeduction || 0;

    const totalBuyerRate = baseRate + buyerMarkup;
    const totalSellerRate = Math.max(0, baseRate - sellerDeduction);
    const totalBuyerPayable = totalBuyerRate * quantity;
    const totalSellerSettlement = totalSellerRate * quantity;
    const brokerSpreadPerMT = buyerMarkup + sellerDeduction;
    const totalBrokerCommission = brokerSpreadPerMT * quantity;

    // Construct Privacy-Isolated Sub-Snapshots
    const buyer_snapshot = {
      requestId: data.requestId,
      requirementId: data.requirementId,
      commodityName: data.commodityName,
      gradeName: data.gradeName || null,
      quantity: quantity,
      unitSymbol: data.unitSymbol || 'MT',
      agreedRate: totalBuyerRate,
      totalPayable: totalBuyerPayable,
      deliveryDate: data.deliveryDate,
      deliveryLocation: data.deliveryLocation || null,
      deliveryTerms: data.deliveryTerms || null,
      packagingType: data.packagingType || null,
      paymentTerms: data.paymentTerms || null,
      specialConditions: data.specialConditions || null,
      originatorRole: 'broker' as const,
      timestamp: new Date().toISOString(),
    };

    const seller_snapshot = {
      requestId: data.requestId,
      lotId: data.lotId || data.sellerAvailabilityId || null,
      lotNumber: data.lotNumber || null,
      commodityName: data.commodityName,
      gradeName: data.gradeName || null,
      quantity: quantity,
      unitSymbol: data.unitSymbol || 'MT',
      agreedRate: totalSellerRate,
      totalSettlement: totalSellerSettlement,
      deliveryDate: data.deliveryDate,
      deliveryLocation: data.deliveryLocation || null,
      deliveryTerms: data.deliveryTerms || null,
      packagingType: data.packagingType || null,
      paymentTerms: data.paymentTerms || null,
      specialConditions: data.specialConditions || null,
      originatorRole: 'broker' as const,
      timestamp: new Date().toISOString(),
    };

    const result = await db.transaction(async (tx) => {
      // Concurrency check
      if (data.expectedVersionNumber) {
        await verifyLatestVersion(tx, data.requestId, data.expectedVersionNumber);
      }

      // Query parent quotation
      const quotation = await tx.query.quotations.findFirst({
        where: eq(quotations.id, data.requestId),
      });

      if (!quotation) {
        throw new Error(`Quotation / Request with ID ${data.requestId} not found.`);
      }

      const isAuthorizedBroker = isAdmin || quotation.brokerId === authUser.id;
      if (!isAuthorizedBroker) {
        throw new Error('Forbidden: You are not authorized to finalize this quotation.');
      }

      if (quotation.status === 'Rejected' || quotation.status === 'Cancelled') {
        throw new Error(`Forbidden: Cannot finalize deal because quotation is ${quotation.status}.`);
      }

      const req = await tx.query.requirements.findFirst({
        where: eq(requirements.id, data.requirementId),
      });

      const avail = data.sellerAvailabilityId
        ? await tx.query.availabilities.findFirst({
            where: eq(availabilities.id, data.sellerAvailabilityId),
          })
        : null;

      let effectiveCompanyId = dbUser.companyId || req?.companyId || avail?.companyId;
      if (!effectiveCompanyId) {
        const firstCompany = await tx.query.companies.findFirst();
        effectiveCompanyId = firstCompany?.id;
      }

      if (!effectiveCompanyId) {
        throw new Error('No valid company ID found to log negotiation events.');
      }

      const existingVersions = await tx
        .select({
          id: dealVersions.id,
          versionNumber: dealVersions.versionNumber,
        })
        .from(dealVersions)
        .where(eq(dealVersions.requestId, data.requestId))
        .orderBy(desc(dealVersions.versionNumber));

      const nextVersionNumber =
        existingVersions.length > 0 ? existingVersions[0].versionNumber + 1 : 1;

      if (existingVersions.length > 0) {
        await tx
          .update(dealVersions)
          .set({ status: 'Superseded' })
          .where(eq(dealVersions.requestId, data.requestId));
      }

      const snapshotPayload = {
        commodityName: data.commodityName,
        gradeName: data.gradeName || null,
        lotId: data.lotId || data.sellerAvailabilityId || null,
        lotNumber: data.lotNumber || null,
        requirementId: data.requirementId,
        quantity: quantity,
        unitSymbol: data.unitSymbol || 'MT',
        baseRate: baseRate,
        rate: baseRate,
        buyerMarkup: buyerMarkup,
        sellerDeduction: sellerDeduction,
        totalBuyerRate: totalBuyerRate,
        totalSellerRate: totalSellerRate,
        totalBuyerPayable: totalBuyerPayable,
        totalSellerSettlement: totalSellerSettlement,
        brokerSpreadPerMT: brokerSpreadPerMT,
        totalBrokerCommission: totalBrokerCommission,
        deliveryDate: data.deliveryDate,
        deliveryLocation: data.deliveryLocation || null,
        deliveryTerms: data.deliveryTerms || null,
        packagingType: data.packagingType || null,
        paymentTerms: data.paymentTerms || null,
        specialConditions: data.specialConditions || null,
        buyer_snapshot,
        seller_snapshot,
        originatorRole: 'broker' as const,
        timestamp: new Date().toISOString(),
      };

      const [newVersion] = await tx
        .insert(dealVersions)
        .values({
          requestId: data.requestId,
          versionNumber: nextVersionNumber,
          actorId: dbUser.id,
          status: 'Awaiting Confirmations',
          snapshotPayload: snapshotPayload,
        })
        .returning();

      await tx.insert(negotiationEvents).values({
        requestId: data.requestId,
        companyId: effectiveCompanyId,
        actorId: dbUser.id,
        actionType: 'FINAL_DEAL_GENERATED',
        payload: {
          versionId: newVersion.id,
          versionNumber: nextVersionNumber,
          totalBuyerRate: totalBuyerRate,
          totalSellerRate: totalSellerRate,
          totalBrokerCommission: totalBrokerCommission,
        },
      });

      await tx
        .update(quotations)
        .set({ status: 'Pending Confirmations' })
        .where(eq(quotations.id, data.requestId));

      return {
        success: true,
        version_id: newVersion.id,
        version_number: nextVersionNumber,
      };
    });

    await logDecisionGateAuditEventAction({
      action: 'SELLER_PROPOSAL_ACTION',
      actorId: dbUser.id,
      actorRole: 'broker',
      entity: 'quotations',
      entityId: result.version_id,
      metadata: {
        gateName: 'FINAL_DEAL_GENERATION_GATE',
        requestId: data.requestId,
        versionNumber: result.version_number,
        totalBuyerRate: totalBuyerRate,
        totalSellerRate: totalSellerRate,
      },
    });

    revalidatePath('/broker/deals');
    revalidatePath(`/broker/deals/${data.requestId}`);
    revalidatePath('/broker/work');

    return {
      success: true,
      version_id: result.version_id,
      version_number: result.version_number,
      message: `Final Deal Version ${result.version_number} generated successfully! Sent for dual confirmations.`,
    };
  } catch (err: any) {
    console.error('Error generating final deal snapshot:', err);
    return {
      success: false,
      error: err.message || 'Failed to generate final deal snapshot.',
    };
  }
}

export async function getBrokerDealContextAction(requestId: string): Promise<DealContextResult> {
  try {
    const auth = await getAuthorizedBrokerSession();
    if (!auth.success) return { success: false, error: auth.error };
    const { user: dbUser, isAdmin } = auth;

    // Support both quotation ID and deal ID
    let quote = await db.query.quotations.findFirst({
      where: eq(quotations.id, requestId),
    });

    let dealRecord: any = null;
    if (!quote) {
      dealRecord = await db.query.deals.findFirst({
        where: eq(deals.id, requestId),
      });
      if (dealRecord) {
        quote = await db.query.quotations.findFirst({
          where: eq(quotations.id, dealRecord.quotationId),
        });
      }
    }

    if (!quote && !dealRecord) {
      return { success: false, error: 'Deal or quotation request not found' };
    }

    if (!isAdmin && quote && quote.brokerId !== dbUser.id && dealRecord?.brokerId !== dbUser.id) {
      return { success: false, error: 'Forbidden: You do not have permission to access this deal context' };
    }

    const requirementId = quote?.requirementId || dealRecord?.requirementId;
    const req = requirementId
      ? await db.query.requirements.findFirst({
          where: eq(requirements.id, requirementId),
        })
      : null;

    const avail = quote?.sellerAvailabilityId
      ? await db.query.availabilities.findFirst({
          where: eq(availabilities.id, quote.sellerAvailabilityId),
        })
      : null;

    const commodity = req?.commodityId
      ? await db.query.masterCommodities.findFirst({
          where: eq(masterCommodities.id, req.commodityId),
        })
      : null;

    const grade = req?.gradeId
      ? await db.query.masterGrades.findFirst({
          where: eq(masterGrades.id, req.gradeId),
        })
      : null;

    const lookupIds = [requestId];
    if (dealRecord?.id) lookupIds.push(dealRecord.id);
    if (quote?.id) lookupIds.push(quote.id);

    const latestVersion = await db.query.dealVersions.findFirst({
      where: inArray(dealVersions.requestId, lookupIds),
      orderBy: [desc(dealVersions.versionNumber)],
    });

    const snapshot = (latestVersion?.snapshotPayload as any) || {};

    const baseRate = Number(
      snapshot.baseRate ||
        snapshot.rate ||
        dealRecord?.agreedPrice ||
        quote?.offeredPrice ||
        50000
    );
    const quantity = Number(
      snapshot.quantity ||
        dealRecord?.agreedQuantity ||
        req?.quantity ||
        avail?.availableQuantity ||
        100
    );

    const defaultDeliveryDate = snapshot.deliveryDate
      ? snapshot.deliveryDate
      : req?.targetDate
      ? new Date(req.targetDate).toISOString().split('T')[0]
      : new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0];

    return {
      success: true,
      data: {
        requestId,
        requirementId: requirementId || '',
        sellerAvailabilityId: quote?.sellerAvailabilityId || null,
        lotId: avail?.id || snapshot.lotId || null,
        lotNumber:
          avail?.lotNumber ||
          snapshot.lotNumber ||
          'LOT-' + (quote?.sellerAvailabilityId?.slice(0, 8).toUpperCase() || 'AV-LATEST'),
        commodityName: commodity?.name || snapshot.commodityName || 'Agricultural Commodity',
        gradeName: grade?.gradeName || snapshot.gradeName || 'Standard Commercial Grade',
        quantity: quantity > 0 ? quantity : 100,
        baseRate: baseRate > 0 ? baseRate : 50000,
        deliveryDate: defaultDeliveryDate,
        buyerMarkup: Number(snapshot.buyerMarkup ?? 250),
        sellerDeduction: Number(snapshot.sellerDeduction ?? 250),
        deliveryTerms: snapshot.deliveryTerms || 'Ex-Warehouse / FOR',
        deliveryLocation: snapshot.deliveryLocation || 'Warehouse Hub',
        packagingType: snapshot.packagingType || '50kg Jute Bags',
        paymentTerms: snapshot.paymentTerms || '100% Advance against Invoice / Bank Transfer',
        specialConditions: snapshot.specialConditions || '',
        unitSymbol: snapshot.unitSymbol || 'MT',
        expectedVersionNumber: latestVersion?.versionNumber || 1,
        currentStatus: dealRecord?.status || latestVersion?.status || quote?.status || 'Draft',
      },
    };
  } catch (err: any) {
    console.error('Error fetching deal context:', err);
    return { success: false, error: err.message || 'Failed to fetch deal context.' };
  }
}
