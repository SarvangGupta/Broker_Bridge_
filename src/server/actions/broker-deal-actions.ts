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
  companies,
  users,
} from '@/src/server/db/schema';
import { eq, desc } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { queueNotificationAction } from '@/src/server/actions/notification-actions';
import { logDecisionGateAuditEventAction } from '@/src/server/actions/audit-actions';
import {
  generateFinalDealSnapshotSchema,
  type GenerateFinalDealSnapshotPayload,
} from '@/src/types/deal-builder-schema';
import { verifyLatestVersion } from '@/src/server/utils/version-engine';

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

/**
 * Task 2 (Micro-Sprint 26.2): Final Deal Server Action
 *
 * Authenticates broker session via `@supabase/ssr`, executes atomic transaction to:
 * 1. Calculate net buyer rate (base + markup) and net seller rate (base - deduction).
 * 2. Construct two strict JSONB payloads:
 *    - `buyer_snapshot`: Excludes Seller data, min price, and seller deduction.
 *    - `seller_snapshot`: Excludes Buyer data, target price, and buyer markup.
 * 3. Enforce optimistic concurrency guard via `expectedVersionNumber`.
 * 4. Increment `version_number` and mark previous active deal versions as 'Superseded'.
 * 5. Insert new immutable record into `deal_versions` with `status: 'Awaiting Confirmations'`.
 * 6. Update parent `quotations` status to 'Pending Confirmations'.
 * 7. Dispatch in-app notifications to Buyer and Seller.
 * 8. Log structured decision gate audit entry.
 */
export async function generateFinalDealSnapshotAction(
  payload: GenerateFinalDealSnapshotPayload
): Promise<GenerateFinalDealResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    // Authenticate broker role
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User profile not found' };
    }

    const role = (dbUser.role || '').toLowerCase();
    if (role !== 'broker' && role !== 'admin') {
      return { success: false, error: 'Forbidden: Broker access privileges required' };
    }

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

    // Execute Atomic Drizzle Transaction
    const result = await db.transaction(async (tx) => {
      // Stale Version Concurrency Guard
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

      // Fetch requirement & availability to determine valid companyId referencing companies.id
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

      // Query highest existing version number
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

      // Mark older versions as Superseded
      if (existingVersions.length > 0) {
        await tx
          .update(dealVersions)
          .set({ status: 'Superseded' })
          .where(eq(dealVersions.requestId, data.requestId));
      }

      // Full consolidated snapshot payload
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

      // Insert new immutable deal version record
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

      // Insert tracking event into negotiation_events with valid companyId
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

      // Update parent quotation status
      await tx
        .update(quotations)
        .set({ status: 'Pending Confirmations' })
        .where(eq(quotations.id, data.requestId));

      // Dispatch in-app notifications
      if (req?.companyId) {
        const buyerUser = await tx.query.users.findFirst({
          where: eq(users.companyId, req.companyId),
        });
        if (buyerUser) {
          await queueNotificationAction({
            userId: buyerUser.id,
            companyId: req.companyId,
            channel: 'IN_APP',
            eventType: 'FINAL_CONFIRMATION_REQUIRED',
            title: `Final Contract Confirmation: ${data.commodityName}`,
            message: `Broker has finalized commercial deal terms for ${quantity} ${data.unitSymbol || 'MT'} @ ₹${totalBuyerRate.toLocaleString('en-IN')}/MT. Please review and confirm.`,
            actionLabel: 'Confirm Contract',
            actionUrl: `/buyer/confirmations?requestId=${data.requestId}`,
          });
        }
      }

      if (avail?.companyId) {
        const sellerUser = await tx.query.users.findFirst({
          where: eq(users.companyId, avail.companyId),
        });
        if (sellerUser) {
          await queueNotificationAction({
            userId: sellerUser.id,
            companyId: avail.companyId,
            channel: 'IN_APP',
            eventType: 'FINAL_CONFIRMATION_REQUIRED',
            title: `Final Contract Confirmation: ${data.commodityName}`,
            message: `Broker has finalized commercial deal terms for ${quantity} ${data.unitSymbol || 'MT'} @ ₹${totalSellerRate.toLocaleString('en-IN')}/MT. Please review and confirm.`,
            actionLabel: 'Confirm Contract',
            actionUrl: `/seller/requests?requestId=${data.requestId}`,
          });
        }
      }

      return {
        success: true,
        version_id: newVersion.id,
        version_number: nextVersionNumber,
      };
    });

    // Log Decision Gate Audit Event
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

/**
 * Fetches existing request and latest deal version context to pre-fill the Deal Builder UI
 */
export async function getBrokerDealContextAction(requestId: string): Promise<DealContextResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
    } = await supabase.auth.getUser();

    if (!authUser) {
      return { success: false, error: 'Unauthorized: Valid session required' };
    }

    const quote = await db.query.quotations.findFirst({
      where: eq(quotations.id, requestId),
    });

    if (!quote) {
      return { success: false, error: 'Deal or quotation request not found' };
    }

    const req = await db.query.requirements.findFirst({
      where: eq(requirements.id, quote.requirementId),
    });

    const avail = quote.sellerAvailabilityId
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

    const latestVersion = await db.query.dealVersions.findFirst({
      where: eq(dealVersions.requestId, requestId),
      orderBy: [desc(dealVersions.versionNumber)],
    });

    const snapshot = (latestVersion?.snapshotPayload as any) || {};

    const baseRate = Number(snapshot.baseRate || snapshot.rate || quote.offeredPrice || 50000);
    const quantity = Number(snapshot.quantity || req?.quantity || avail?.totalQuantity || 100);

    const defaultDeliveryDate = snapshot.deliveryDate
      ? snapshot.deliveryDate
      : req?.targetDate
      ? new Date(req.targetDate).toISOString().split('T')[0]
      : new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0];

    return {
      success: true,
      data: {
        requestId,
        requirementId: quote.requirementId,
        sellerAvailabilityId: quote.sellerAvailabilityId,
        lotId: avail?.id || snapshot.lotId || null,
        lotNumber: avail?.lotNumber || snapshot.lotNumber || 'LOT-' + (quote.sellerAvailabilityId?.slice(0, 8).toUpperCase() || 'AV-LATEST'),
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
        currentStatus: latestVersion?.status || quote.status || 'Draft',
      },
    };
  } catch (err: any) {
    console.error('Error fetching deal context:', err);
    return { success: false, error: err.message || 'Failed to fetch deal context.' };
  }
}
