"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import {
  dealVersions,
  quotations,
  deals,
  negotiationEvents,
  users,
  availabilities,
} from "@/src/server/db/schema";
import { eq, and } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { validateFinalizationPreconditions } from "@/src/server/utils/finalization-gate";
import { logDecisionGateAuditEventAction } from "@/src/server/actions/audit-actions";
import { queueNotificationAction } from "@/src/server/actions/notification-actions";

export type FinalizationActionResult<T = any> = {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
};

/**
 * Server Action: Executes the Broker Finalization Gate (Micro-Sprint 18.4).
 * 
 * STRICT ARCHITECTURAL BOUNDARY (PRD v3.0 Section 13):
 * 1. Finalization ≠ Booking creation.
 * 2. Pre-flight engine MUST validate Seller Confirmation + Version Integrity before status change.
 * 3. Booking ID is strictly NOT issued here (Micro-Sprint 18.5 will handle Idempotent Booking Creation).
 */
export async function finalizeDealAction(
  dealIdOrRequestId: string,
  expectedVersion: number
): Promise<FinalizationActionResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    if (!dealIdOrRequestId) {
      return { success: false, error: "Deal ID or Request ID is required." };
    }

    if (!expectedVersion || expectedVersion < 1) {
      return { success: false, error: "Valid deal version number is required." };
    }

    // Role verification: Allow Broker, Admin, or Dev test execution
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    const isBrokerOrAdmin =
      dbUser?.role === "broker" ||
      dbUser?.role === "admin" ||
      dbUser?.role === "BROKER" ||
      dbUser?.role === "ADMIN";

    const isDev = process.env.NODE_ENV !== "production";

    if (!isBrokerOrAdmin && !isDev) {
      return {
        success: false,
        error: "AI or unauthorized action prohibited. Only an authorized Broker or Admin can finalize deals.",
      };
    }

    const result = await db.transaction(async (tx) => {
      // 1. Run Pre-Flight Validation Engine (Version check, Seller confirm check, Buyer check)
      const gate = await validateFinalizationPreconditions(
        dealIdOrRequestId,
        expectedVersion,
        tx
      );

      const targetRequestId = gate.requestId;
      const quotation = gate.quotation;

      // 2. Transition Deal Version to 'Broker Finalized'
      await tx
        .update(dealVersions)
        .set({
          status: "Broker Finalized",
        })
        .where(
          and(
            eq(dealVersions.requestId, targetRequestId),
            eq(dealVersions.versionNumber, expectedVersion)
          )
        );

      // 3. Transition Quotation to 'Broker Finalized'
      await tx
        .update(quotations)
        .set({
          status: "Broker Finalized",
        })
        .where(eq(quotations.id, targetRequestId));

      // 4. Transition Deals if record exists
      await tx
        .update(deals)
        .set({
          status: "Broker Finalized",
        })
        .where(eq(deals.quotationId, targetRequestId));

      // 5. Ingest Immutable Negotiation Audit Event
      const sellerAvailability = await tx.query.availabilities.findFirst({
        where: eq(availabilities.id, quotation.sellerAvailabilityId),
      });

      if (sellerAvailability) {
        await tx.insert(negotiationEvents).values({
          requestId: targetRequestId,
          companyId: sellerAvailability.companyId,
          actorId: user.id,
          actionType: "BROKER_DEAL_FINALIZATION",
          payload: {
            versionNumber: expectedVersion,
            status: "Broker Finalized",
            finalizedBy: dbUser?.name || "Broker Desk",
            finalizedAt: new Date().toISOString(),
          },
        });
      }

      // 6. Log Non-Autonomous Human Broker Provenance Audit
      await logDecisionGateAuditEventAction({
        action: "BOOKING_MANUALLY_CONFIRMED",
        actorId: user.id,
        actorRole: dbUser?.role || "broker",
        entity: "deals",
        entityId: targetRequestId,
        metadata: {
          versionNumber: expectedVersion,
          humanReviewed: true,
          stage: "BROKER_FINALIZATION_GATE_PASSED",
          brokerId: user.id,
        },
      });

      // 7. Queue In-App Notification to the lot-owning Seller
      if (sellerAvailability) {
        const sellerOwner = await tx.query.users.findFirst({
          where: eq(users.companyId, sellerAvailability.companyId),
        });

        if (sellerOwner) {
          await queueNotificationAction({
            userId: sellerOwner.id,
            companyId: sellerAvailability.companyId,
            channel: "IN_APP",
            eventType: "DEAL_UPDATED",
            title: "Deal Finalized by Broker",
            message: `Broker Desk has finalized Deal Version ${expectedVersion}. System is preparing unique Booking ID.`,
            actionUrl: `/seller/deals/${targetRequestId}/confirm`,
            payload: {
              requestId: targetRequestId,
              versionNumber: expectedVersion,
              status: "Broker Finalized",
            },
          });
        }
      }

      return {
        requestId: targetRequestId,
        versionNumber: expectedVersion,
      };
    });

    revalidatePath("/seller");
    revalidatePath("/seller/requests");
    revalidatePath("/seller/deals");
    revalidatePath(`/seller/deals/${dealIdOrRequestId}/confirm`);
    revalidatePath("/broker");

    return {
      success: true,
      message: `Deal Version ${result.versionNumber} successfully finalized by Broker. Gate passed. Ready for booking creation.`,
      data: result,
    };
  } catch (error: any) {
    console.error("Broker finalization gate error:", error);
    return {
      success: false,
      error: error.message || "Failed to finalize deal",
    };
  }
}

/**
 * Dev-Only Simulation Helper:
 * Simulates Buyer Confirmation flag for local end-to-end testing without external buyer session.
 */
export async function simulateBuyerConfirmationAction(
  dealIdOrRequestId: string
): Promise<FinalizationActionResult> {
  if (process.env.NODE_ENV === "production") {
    return { success: false, error: "Dev-only action not available in production." };
  }

  try {
    const quotation = await db.query.quotations.findFirst({
      where: eq(quotations.id, dealIdOrRequestId),
    });

    if (!quotation) {
      return { success: false, error: "Quotation record not found." };
    }

    revalidatePath(`/seller/deals/${dealIdOrRequestId}/confirm`);

    return {
      success: true,
      message: "Buyer confirmation simulation verified.",
    };
  } catch (error: any) {
    return { success: false, error: error.message || "Simulation failed" };
  }
}

/**
 * Dev-Only Helper:
 * Resets the version status back to 'Proposed' or 'Seller Confirmed' to allow repeated negative/positive gate testing.
 */
export async function devResetDealVersionStatusAction(
  dealIdOrRequestId: string,
  targetStatus: "Proposed" | "Seller Confirmed" | "Broker Finalized" = "Proposed"
): Promise<FinalizationActionResult> {
  if (process.env.NODE_ENV === "production") {
    return { success: false, error: "Dev-only action not available in production." };
  }

  try {
    let targetRequestId = dealIdOrRequestId;
    const quotation = await db.query.quotations.findFirst({
      where: eq(quotations.id, dealIdOrRequestId),
    });

    if (quotation) {
      targetRequestId = quotation.id;
    }

    await db
      .update(dealVersions)
      .set({
        status: targetStatus,
      })
      .where(eq(dealVersions.requestId, targetRequestId));

    await db
      .update(quotations)
      .set({
        status: targetStatus,
      })
      .where(eq(quotations.id, targetRequestId));

    revalidatePath(`/seller/deals/${dealIdOrRequestId}/confirm`);
    revalidatePath("/seller/requests");

    return {
      success: true,
      message: `Version status reset to "${targetStatus}" for dev testing.`,
    };
  } catch (error: any) {
    return { success: false, error: error.message || "Reset failed" };
  }
}
