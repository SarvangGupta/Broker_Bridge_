"use server";

import { db } from "@/src/server/db";
import {
  dealVersions,
  quotations,
  deals,
  availabilities,
  negotiationEvents,
  users,
} from "@/src/server/db/schema";
import { eq, and, desc } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { verifySellerSession } from "@/src/server/utils/seller-auth";
import { queueNotificationAction } from "@/src/server/actions/notification-actions";
import { logDecisionGateAuditEventAction } from "@/src/server/actions/audit-actions";

export type ConfirmationActionResult<T = any> = {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
};

/**
 * Server Action: Records an explicit, auditable Seller Confirmation against an exact Deal Version.
 * 
 * CORE RULES:
 * 1. Concurrency Guard: Rejects stale version confirmations if the Broker revised terms in the background.
 * 2. Immutable Snapshot: Does NOT edit commercial fields. Only marks status as 'Seller Confirmed'.
 * 3. Audit Trail: Injects an immutable audit entry into negotiation_events and system logs.
 * 4. Gating: Broker cannot finalize deals without this explicit Seller confirmation state.
 */
export async function confirmFinalDealTermsAction(
  requestId: string,
  expectedVersion: number
): Promise<ConfirmationActionResult> {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized: Valid seller session required." };
    }

    if (!requestId) {
      return { success: false, error: "Request ID is required." };
    }

    if (!expectedVersion || expectedVersion < 1) {
      return { success: false, error: "Valid deal version number is required." };
    }

    const sellerUser = session.data.user;
    const sellerCompanyId = session.data.companyId;

    const result = await db.transaction(async (tx) => {
      // 1. Concurrency Guard: Check highest version in DB
      const latestVersionRow = await tx
        .select({
          id: dealVersions.id,
          versionNumber: dealVersions.versionNumber,
          status: dealVersions.status,
        })
        .from(dealVersions)
        .where(eq(dealVersions.requestId, requestId))
        .orderBy(desc(dealVersions.versionNumber))
        .limit(1)
        .then((rows) => rows[0] || null);

      if (latestVersionRow && latestVersionRow.versionNumber > expectedVersion) {
        throw new Error(
          `STALE_VERSION_DETECTED: The Broker has updated the terms of this deal to Version ${latestVersionRow.versionNumber}. Please refresh to review the latest terms.`
        );
      }

      // 2. Fetch parent quotation / request
      const quotation = await tx.query.quotations.findFirst({
        where: eq(quotations.id, requestId),
      });

      if (!quotation) {
        throw new Error("Deal proposal not found.");
      }

      // 3. Tenant Ownership Check
      const linkedLot = await tx.query.availabilities.findFirst({
        where: eq(availabilities.id, quotation.sellerAvailabilityId),
      });

      if (linkedLot && linkedLot.companyId !== sellerCompanyId) {
        throw new Error("Unauthorized: You do not own the inventory lot referenced in this deal.");
      }

      // 4. Update Deal Version status to 'Seller Confirmed'
      if (latestVersionRow) {
        await tx
          .update(dealVersions)
          .set({
            status: "Seller Confirmed",
          })
          .where(
            and(
              eq(dealVersions.requestId, requestId),
              eq(dealVersions.versionNumber, expectedVersion)
            )
          );
      } else {
        // If unversioned, synthesize Version 1 as 'Seller Confirmed'
        await tx.insert(dealVersions).values({
          requestId,
          versionNumber: 1,
          actorId: sellerUser.id,
          status: "Seller Confirmed",
          snapshotPayload: {
            commodityId: linkedLot?.commodityId || "",
            commodityName: "Commodity",
            rate: Number(quotation.offeredPrice || 0),
            quantity: Number(linkedLot?.availableQuantity || 100),
            unitSymbol: "MT",
            originatorRole: "seller",
            timestamp: new Date().toISOString(),
          } as any,
        });
      }

      // 5. Update Parent Quotation / Deal Status
      await tx
        .update(quotations)
        .set({
          status: "Seller Confirmed",
        })
        .where(eq(quotations.id, requestId));

      await tx
        .update(deals)
        .set({
          status: "Seller Confirmed",
        })
        .where(eq(deals.quotationId, requestId));

      // 6. Record Immutable Audit Entry in negotiation_events
      await tx.insert(negotiationEvents).values({
        requestId,
        companyId: sellerCompanyId,
        actorId: sellerUser.id,
        actionType: "SELLER_FINAL_CONFIRMATION",
        payload: {
          versionNumber: expectedVersion,
          status: "Seller Confirmed",
          action: "CONFIRM_FINAL_TERMS",
          confirmedBy: sellerUser.name,
          confirmedAt: new Date().toISOString(),
        },
      });

      // 7. Audit Logging for Non-Autonomous Broker Gate
      await logDecisionGateAuditEventAction({
        action: "SELLER_PROPOSAL_ACTION",
        actorId: sellerUser.id,
        actorRole: "seller",
        entity: "deals",
        entityId: requestId,
        metadata: {
          versionNumber: expectedVersion,
          action: "SELLER_FINAL_CONFIRMATION",
          status: "Seller Confirmed",
        },
      });

      // 8. Queue Broker In-App Notification
      if (quotation.brokerId) {
        await queueNotificationAction({
          userId: quotation.brokerId,
          channel: "IN_APP",
          eventType: "DEAL_UPDATED",
          title: "Deal Terms Confirmed by Seller",
          message: `Seller confirmed final terms for Deal Version ${expectedVersion}. Ready for Broker Finalization.`,
          actionUrl: `/broker`,
          payload: {
            requestId,
            versionNumber: expectedVersion,
            status: "Seller Confirmed",
          },
        });
      }

      return {
        versionNumber: expectedVersion,
      };
    });

    revalidatePath("/seller");
    revalidatePath("/seller/requests");
    revalidatePath("/seller/deals");
    revalidatePath(`/seller/deals/${requestId}/confirm`);
    revalidatePath("/broker");

    return {
      success: true,
      message: `Final terms for Deal Version ${result.versionNumber} confirmed. Awaiting Broker Finalization.`,
    };
  } catch (error: any) {
    console.error("Failed to confirm final deal terms:", error);
    return {
      success: false,
      error: error.message || "Failed to confirm deal terms",
    };
  }
}

/**
 * Server Action: Dispatches a Seller Correction Request on an exact Deal Version back to the Broker.
 * 
 * CORE RULES:
 * 1. Zero Direct Edit: Sellers cannot edit commercial terms in-place; they submit structured correction remarks.
 * 2. Concurrency Guard: Enforces expectedVersion matches active version.
 * 3. Broker Action Trigger: Notifies Broker Desk to revise terms and issue an incremental Deal Version.
 */
export async function requestBrokerCorrectionAction(
  requestId: string,
  expectedVersion: number,
  reason: string
): Promise<ConfirmationActionResult> {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized: Valid seller session required." };
    }

    if (!requestId) {
      return { success: false, error: "Request ID is required." };
    }

    if (!expectedVersion || expectedVersion < 1) {
      return { success: false, error: "Valid deal version number is required." };
    }

    const trimmedReason = reason?.trim();
    if (!trimmedReason || trimmedReason.length < 5) {
      return { success: false, error: "Please provide a valid correction explanation (minimum 5 characters)." };
    }

    const sellerUser = session.data.user;
    const sellerCompanyId = session.data.companyId;

    const result = await db.transaction(async (tx) => {
      // 1. Concurrency Guard
      const latestVersionRow = await tx
        .select({
          id: dealVersions.id,
          versionNumber: dealVersions.versionNumber,
          status: dealVersions.status,
        })
        .from(dealVersions)
        .where(eq(dealVersions.requestId, requestId))
        .orderBy(desc(dealVersions.versionNumber))
        .limit(1)
        .then((rows) => rows[0] || null);

      if (latestVersionRow && latestVersionRow.versionNumber > expectedVersion) {
        throw new Error(
          `STALE_VERSION_DETECTED: The Broker has updated the terms of this deal to Version ${latestVersionRow.versionNumber}. Please refresh to review the latest terms.`
        );
      }

      // 2. Fetch parent quotation
      const quotation = await tx.query.quotations.findFirst({
        where: eq(quotations.id, requestId),
      });

      if (!quotation) {
        throw new Error("Deal proposal not found.");
      }

      // 3. Tenant Ownership Check
      const linkedLot = await tx.query.availabilities.findFirst({
        where: eq(availabilities.id, quotation.sellerAvailabilityId),
      });

      if (linkedLot && linkedLot.companyId !== sellerCompanyId) {
        throw new Error("Unauthorized: You do not own the inventory lot referenced in this deal.");
      }

      // 4. Update Deal Version status to 'Countered'
      if (latestVersionRow) {
        await tx
          .update(dealVersions)
          .set({
            status: "Countered",
          })
          .where(
            and(
              eq(dealVersions.requestId, requestId),
              eq(dealVersions.versionNumber, expectedVersion)
            )
          );
      }

      // 5. Update Quotation status & counter notes
      await tx
        .update(quotations)
        .set({
          status: "Seller Countered",
          counterNotes: trimmedReason,
        })
        .where(eq(quotations.id, requestId));

      await tx
        .update(deals)
        .set({
          status: "Correction Requested",
        })
        .where(eq(deals.quotationId, requestId));

      // 6. Record Immutable Negotiation Event
      await tx.insert(negotiationEvents).values({
        requestId,
        companyId: sellerCompanyId,
        actorId: sellerUser.id,
        actionType: "COUNTER",
        payload: {
          versionNumber: expectedVersion,
          reason: trimmedReason,
          counterRemarks: trimmedReason,
          action: "REQUEST_BROKER_CORRECTION",
          status: "Correction Requested",
          requestedBy: sellerUser.name,
          requestedAt: new Date().toISOString(),
        },
      });

      // 7. Audit Logging
      await logDecisionGateAuditEventAction({
        action: "SELLER_PROPOSAL_ACTION",
        actorId: sellerUser.id,
        actorRole: "seller",
        entity: "deals",
        entityId: requestId,
        metadata: {
          versionNumber: expectedVersion,
          action: "REQUEST_BROKER_CORRECTION",
          reason: trimmedReason,
        },
      });

      // 8. Queue Broker In-App Notification
      if (quotation.brokerId) {
        await queueNotificationAction({
          userId: quotation.brokerId,
          channel: "IN_APP",
          eventType: "DEAL_UPDATED",
          title: "Seller Requested Deal Correction",
          message: `Seller requested corrections on Version ${expectedVersion}: "${trimmedReason}"`,
          actionUrl: `/broker`,
          payload: {
            requestId,
            versionNumber: expectedVersion,
            reason: trimmedReason,
          },
        });
      }

      return {
        versionNumber: expectedVersion,
      };
    });

    revalidatePath("/seller");
    revalidatePath("/seller/requests");
    revalidatePath("/seller/deals");
    revalidatePath(`/seller/deals/${requestId}/confirm`);
    revalidatePath("/broker");

    return {
      success: true,
      message: "Correction request dispatched. The Broker Desk has been notified to issue a new Deal Version.",
    };
  } catch (error: any) {
    console.error("Failed to request broker correction:", error);
    return {
      success: false,
      error: error.message || "Failed to submit correction request",
    };
  }
}
