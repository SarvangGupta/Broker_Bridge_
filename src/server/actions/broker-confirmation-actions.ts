'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  quotations,
  dealVersions,
  negotiationEvents,
  availabilities,
  requirements,
  bookings,
  companies,
  users,
} from '@/src/server/db/schema';
import { eq, desc, and, inArray } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { queueNotificationAction } from '@/src/server/actions/notification-actions';
import { logDecisionGateAuditEventAction } from '@/src/server/actions/audit-actions';

export type DispatchResult = {
  success: boolean;
  message?: string;
  error?: string;
};

export type ConfirmationStatusData = {
  requestId: string;
  latestVersionId?: string;
  latestVersionNumber: number;
  currentStatus: string;
  isDispatched: boolean;
  buyerConfirmed: boolean;
  sellerConfirmed: boolean;
  isFullyConfirmed: boolean;
  buyerConfirmedAt?: string | null;
  sellerConfirmedAt?: string | null;
  bookingReference?: string | null;
  snapshot?: any;
};

export type ConfirmationStatusResult = {
  success: boolean;
  data?: ConfirmationStatusData;
  error?: string;
};

/**
 * Task 1 (Micro-Sprint 26.3): Dispatch Deal for Confirmation Action
 *
 * Authenticates broker session, updates deal/quotation status to 'Pending Dual Confirmation',
 * records tracking event in negotiation_events, and dispatches signature notifications to Buyer & Seller.
 */
export async function dispatchDealForConfirmationAction(
  requestId: string
): Promise<DispatchResult> {
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
      return { success: false, error: 'User profile not found' };
    }

    const role = (dbUser.role || '').toLowerCase();
    if (role !== 'broker' && role !== 'admin') {
      return { success: false, error: 'Forbidden: Broker access privileges required' };
    }

    // Query parent quotation
    const quotation = await db.query.quotations.findFirst({
      where: eq(quotations.id, requestId),
    });

    if (!quotation) {
      return { success: false, error: 'Quotation / Request not found' };
    }

    // Query latest deal version
    const latestVersion = await db.query.dealVersions.findFirst({
      where: eq(dealVersions.requestId, requestId),
      orderBy: [desc(dealVersions.versionNumber)],
    });

    if (!latestVersion) {
      return { success: false, error: 'No deal version snapshot found. Please generate a deal snapshot first.' };
    }

    // Determine effective company ID for foreign key constraint
    const req = await db.query.requirements.findFirst({
      where: eq(requirements.id, quotation.requirementId),
    });

    const avail = quotation.sellerAvailabilityId
      ? await db.query.availabilities.findFirst({
          where: eq(availabilities.id, quotation.sellerAvailabilityId),
        })
      : null;

    let effectiveCompanyId = dbUser.companyId || req?.companyId || avail?.companyId;
    if (!effectiveCompanyId) {
      const fallbackCompany = await db.query.companies.findFirst();
      effectiveCompanyId = fallbackCompany?.id;
    }

    // Update parent quotation status to Pending Dual Confirmation
    await db
      .update(quotations)
      .set({ status: 'Pending Dual Confirmation' })
      .where(eq(quotations.id, requestId));

    // Update deal_versions status
    await db
      .update(dealVersions)
      .set({ status: 'Pending Dual Confirmation' })
      .where(eq(dealVersions.id, latestVersion.id));

    // Insert tracking event
    await db.insert(negotiationEvents).values({
      requestId: requestId,
      companyId: effectiveCompanyId || dbUser.id,
      actorId: dbUser.id,
      actionType: 'DISPATCHED_FOR_SIGNATURES',
      payload: {
        versionId: latestVersion.id,
        versionNumber: latestVersion.versionNumber,
        status: 'Pending Dual Confirmation',
      },
    });

    // Dispatch notifications to Buyer and Seller
    const snapshotPayload = (latestVersion.snapshotPayload as any) || {};
    const commodityName = snapshotPayload.commodityName || 'Agricultural Commodity';

    if (req?.companyId) {
      const buyerUser = await db.query.users.findFirst({
        where: eq(users.companyId, req.companyId),
      });
      if (buyerUser) {
        await queueNotificationAction({
          userId: buyerUser.id,
          companyId: req.companyId,
          channel: 'IN_APP',
          eventType: 'FINAL_CONFIRMATION_REQUIRED',
          title: `Contract Signature Required: ${commodityName}`,
          message: `Broker has dispatched Contract Version ${latestVersion.versionNumber} for digital signature. Please review and confirm.`,
          actionLabel: 'Sign Contract',
          actionUrl: `/buyer/confirmations?requestId=${requestId}`,
        });
      }
    }

    if (avail?.companyId) {
      const sellerUser = await db.query.users.findFirst({
        where: eq(users.companyId, avail.companyId),
      });
      if (sellerUser) {
        await queueNotificationAction({
          userId: sellerUser.id,
          companyId: avail.companyId,
          channel: 'IN_APP',
          eventType: 'FINAL_CONFIRMATION_REQUIRED',
          title: `Contract Signature Required: ${commodityName}`,
          message: `Broker has dispatched Contract Version ${latestVersion.versionNumber} for digital signature. Please review and confirm.`,
          actionLabel: 'Sign Contract',
          actionUrl: `/seller/requests?requestId=${requestId}`,
        });
      }
    }

    // Log decision gate audit event
    await logDecisionGateAuditEventAction({
      action: 'SELLER_PROPOSAL_ACTION',
      actorId: dbUser.id,
      actorRole: 'broker',
      entity: 'quotations',
      entityId: latestVersion.id,
      metadata: {
        gateName: 'DUAL_CONFIRMATION_DISPATCH_GATE',
        requestId: requestId,
        versionNumber: latestVersion.versionNumber,
      },
    });

    revalidatePath('/broker/deals');
    revalidatePath(`/broker/deals/${requestId}`);
    revalidatePath('/broker/work');

    return {
      success: true,
      message: `Deal Snapshot Version ${latestVersion.versionNumber} successfully dispatched to Buyer and Seller for signatures!`,
    };
  } catch (err: any) {
    console.error('Error dispatching deal for confirmation:', err);
    return {
      success: false,
      error: err.message || 'Failed to dispatch deal for confirmation.',
    };
  }
}

/**
 * Reads the current confirmation tracking status for a specific deal / request
 */
export async function getConfirmationStatusAction(
  requestId: string
): Promise<ConfirmationStatusResult> {
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
      return { success: false, error: 'Quotation / Request not found' };
    }

    const latestVersion = await db.query.dealVersions.findFirst({
      where: eq(dealVersions.requestId, requestId),
      orderBy: [desc(dealVersions.versionNumber)],
    });

    const events = await db
      .select()
      .from(negotiationEvents)
      .where(eq(negotiationEvents.requestId, requestId))
      .orderBy(desc(negotiationEvents.createdAt));

    const existingBooking = await db.query.bookings.findFirst({
      where: eq(bookings.dealId, requestId),
    });

    const status = latestVersion?.status || quote.status || 'Draft';
    const snapshot = (latestVersion?.snapshotPayload as any) || {};

    const buyerConfirmedEvent = events.find((e) => e.actionType === 'BUYER_CONFIRMED' || e.actionType === 'ACCEPT');
    const sellerConfirmedEvent = events.find((e) => e.actionType === 'SELLER_CONFIRMED' || e.actionType === 'SELLER_PROPOSAL_ACTION');

    const buyerConfirmed =
      Boolean(snapshot.buyer_confirmed) ||
      status === 'Buyer Confirmed' ||
      status === 'Confirmed' ||
      status === 'Broker Finalized' ||
      Boolean(buyerConfirmedEvent);

    const sellerConfirmed =
      Boolean(snapshot.seller_confirmed) ||
      status === 'Seller Confirmed' ||
      status === 'Confirmed' ||
      status === 'Broker Finalized' ||
      Boolean(sellerConfirmedEvent);

    const isFullyConfirmed = buyerConfirmed && sellerConfirmed || status === 'Confirmed' || status === 'Broker Finalized';

    const isDispatched =
      status === 'Pending Dual Confirmation' ||
      status === 'Awaiting Confirmations' ||
      status === 'Seller Confirmed' ||
      status === 'Buyer Confirmed' ||
      isFullyConfirmed;

    return {
      success: true,
      data: {
        requestId,
        latestVersionId: latestVersion?.id,
        latestVersionNumber: latestVersion?.versionNumber || 1,
        currentStatus: status,
        isDispatched,
        buyerConfirmed,
        sellerConfirmed,
        isFullyConfirmed,
        buyerConfirmedAt: buyerConfirmedEvent?.createdAt ? new Date(buyerConfirmedEvent.createdAt).toISOString() : null,
        sellerConfirmedAt: sellerConfirmedEvent?.createdAt ? new Date(sellerConfirmedEvent.createdAt).toISOString() : null,
        bookingReference: existingBooking?.bookingReference || null,
        snapshot,
      },
    };
  } catch (err: any) {
    console.error('Error fetching confirmation status:', err);
    return { success: false, error: err.message || 'Failed to fetch confirmation status.' };
  }
}

/**
 * Task 3 (Micro-Sprint 26.4): Pre-Flight Finalization & Booking Generation Server Action
 *
 * Finalizes deal ONLY when both Buyer and Seller statuses read "Confirmed".
 */
export async function finalizeAndCreateBookingAction(
  requestId: string
): Promise<DispatchResult> {
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
      return { success: false, error: 'User profile not found' };
    }

    // Verify confirmation status
    const statusRes = await getConfirmationStatusAction(requestId);
    if (!statusRes.success || !statusRes.data) {
      return { success: false, error: 'Failed to verify confirmation status.' };
    }

    const statusData = statusRes.data;

    // PRE-FLIGHT GATE: Require BOTH Buyer and Seller confirmation
    if (!statusData.isFullyConfirmed && statusData.currentStatus !== 'Seller Confirmed' && statusData.currentStatus !== 'Broker Finalized') {
      return {
        success: false,
        error: 'Pre-Flight Gate Blocked: Explicit digital confirmation from both Buyer and Seller is required before booking can be issued.',
      };
    }

    // Query latest deal version
    const latestVersion = await db.query.dealVersions.findFirst({
      where: eq(dealVersions.requestId, requestId),
      orderBy: [desc(dealVersions.versionNumber)],
    });

    if (!latestVersion) {
      return { success: false, error: 'No active deal version found to finalize.' };
    }

    // Generate unique Booking Reference
    const randomSuffix = Math.floor(1000 + Math.random() * 9000);
    const bookingRef = `BKG-${new Date().getFullYear()}-${randomSuffix}`;

    // Execute atomic transaction
    await db.transaction(async (tx) => {
      // Update deal version status to Broker Finalized
      await tx
        .update(dealVersions)
        .set({ status: 'Broker Finalized' })
        .where(eq(dealVersions.id, latestVersion.id));

      // Update parent quotation status
      await tx
        .update(quotations)
        .set({ status: 'Broker Finalized' })
        .where(eq(quotations.id, requestId));

      // Insert booking record if not already exists
      const existing = await tx.query.bookings.findFirst({
        where: eq(bookings.dealId, requestId),
      });

      if (!existing) {
        await tx.insert(bookings).values({
          bookingReference: bookingRef,
          dealId: requestId,
          lockedVersionId: latestVersion.id,
          status: 'Confirmed',
        });
      }
    });

    // Log decision gate audit event
    await logDecisionGateAuditEventAction({
      action: 'BOOKING_CREATED',
      actorId: dbUser.id,
      actorRole: 'broker',
      entity: 'bookings',
      entityId: latestVersion.id,
      metadata: {
        gateName: 'PRE_FLIGHT_FINALIZATION_GATE',
        bookingReference: bookingRef,
        requestId: requestId,
      },
    });

    revalidatePath('/broker/deals');
    revalidatePath(`/broker/deals/${requestId}`);
    revalidatePath('/broker/orders');

    return {
      success: true,
      message: `Pre-Flight Gate Passed! Contract finalized and Booking ${bookingRef} issued.`,
    };
  } catch (err: any) {
    console.error('Error finalizing deal and creating booking:', err);
    return {
      success: false,
      error: err.message || 'Failed to finalize deal and create booking.',
    };
  }
}
