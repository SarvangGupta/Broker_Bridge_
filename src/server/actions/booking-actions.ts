"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import {
  bookings,
  deals,
  quotations,
  dealVersions,
  availabilities,
  negotiationEvents,
  users,
  requirements,
} from "@/src/server/db/schema";
import { eq, or, and, sql, desc } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { logDecisionGateAuditEventAction } from "@/src/server/actions/audit-actions";
import { queueNotificationAction } from "@/src/server/actions/notification-actions";

export type BookingActionResult<T = any> = {
  success: boolean;
  bookingId?: string;
  data?: T;
  message?: string;
  error?: string;
};

/**
 * Generates a standard enterprise booking reference string.
 * Format: BKG-YYYY-[RANDOM_4_CHARS] (e.g., 'BKG-2026-X8K2')
 */
function generateBookingReference(): string {
  const year = new Date().getFullYear();
  const randomChars = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `BKG-${year}-${randomChars}`;
}

/**
 * Server Action: Idempotent Booking Creation (Micro-Sprint 18.5)
 * 
 * Strict Guardrails:
 * 1. Database-level UNIQUE constraint on `bookings.deal_id` prevents duplicate bookings.
 * 2. Idempotency Check: Returns existing booking immediately on replay.
 * 3. Gate Check: State must be 'Broker Finalized'.
 * 4. Atomic Inventory Lock: Transaction-safe lot quantity reservation.
 * 5. Full Audit & Notification Trail.
 */
export async function createIdempotentBookingAction(
  dealIdOrRequestId: string
): Promise<BookingActionResult> {
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

    const result = await db.transaction(async (tx) => {
      // 1. Resolve Deal, Quotation, and Target Deal ID
      let dealRecord = await tx.query.deals.findFirst({
        where: or(
          eq(deals.id, dealIdOrRequestId),
          eq(deals.quotationId, dealIdOrRequestId)
        ),
      });

      const quotationRecord = await tx.query.quotations.findFirst({
        where: eq(
          quotations.id,
          dealRecord ? dealRecord.quotationId : dealIdOrRequestId
        ),
      });

      const targetRequestId = quotationRecord
        ? quotationRecord.id
        : dealRecord?.quotationId || dealIdOrRequestId;

      // -------------------------------------------------------------
      // STEP A: IDEMPOTENCY CHECK
      // -------------------------------------------------------------
      // Query bookings table for any existing booking linked to deal ID or target request ID
      const existingBooking = await tx.query.bookings.findFirst({
        where: dealRecord
          ? or(
              eq(bookings.dealId, dealRecord.id),
              eq(bookings.dealId, targetRequestId)
            )
          : eq(bookings.dealId, targetRequestId),
      });

      if (existingBooking) {
        return {
          isExisting: true,
          booking: existingBooking,
          bookingReference: existingBooking.bookingReference,
          message: "Booking already exists.",
        };
      }

      // -------------------------------------------------------------
      // STEP B: GATE CHECK (Must be 'Broker Finalized')
      // -------------------------------------------------------------
      // Fetch latest deal version
      const latestVersion = await tx
        .select({
          id: dealVersions.id,
          versionNumber: dealVersions.versionNumber,
          status: dealVersions.status,
          snapshotPayload: dealVersions.snapshotPayload,
        })
        .from(dealVersions)
        .where(eq(dealVersions.requestId, targetRequestId))
        .orderBy(desc(dealVersions.versionNumber))
        .limit(1)
        .then((rows) => rows[0] || null);

      const dealStatus = dealRecord?.status;
      const quotationStatus = quotationRecord?.status;
      const versionStatus = latestVersion?.status;

      const isBrokerFinalized =
        versionStatus === "Broker Finalized" ||
        quotationStatus === "Broker Finalized" ||
        dealStatus === "Broker Finalized";

      if (!isBrokerFinalized) {
        throw new Error(
          `DEAL_NOT_FINALIZED: Cannot create booking. Deal must be in 'Broker Finalized' status before a Booking ID can be generated. Current Status: Version=${versionStatus || "None"}, Quotation=${quotationStatus || "None"}, Deal=${dealStatus || "None"}.`
        );
      }

      if (!latestVersion) {
        throw new Error(
          "INVALID_STATE: No deal version found for this proposal. Cannot lock booking to an unversioned deal."
        );
      }

      // If no deals record exists yet in the database, ensure one is created
      let finalDealId: string;
      if (dealRecord) {
        finalDealId = dealRecord.id;
      } else if (quotationRecord) {
        const req = await tx.query.requirements.findFirst({
          where: eq(requirements.id, quotationRecord.requirementId),
        });
        const lot = await tx.query.availabilities.findFirst({
          where: eq(availabilities.id, quotationRecord.sellerAvailabilityId),
        });

        const newDeals = await tx
          .insert(deals)
          .values({
            requirementId: quotationRecord.requirementId,
            quotationId: quotationRecord.id,
            buyerId: req?.companyId || quotationRecord.brokerId,
            sellerId: lot?.companyId || quotationRecord.brokerId,
            brokerId: quotationRecord.brokerId,
            agreedPrice: quotationRecord.offeredPrice,
            agreedQuantity: Number(
              (latestVersion.snapshotPayload as any)?.quantity || req?.quantity || 1
            ),
            status: "Broker Finalized",
          })
          .returning();

        dealRecord = newDeals[0];
        finalDealId = dealRecord.id;
      } else {
        finalDealId = dealIdOrRequestId;
      }

      // Check again for existing booking with the resolved finalDealId
      const finalCheck = await tx.query.bookings.findFirst({
        where: eq(bookings.dealId, finalDealId),
      });

      if (finalCheck) {
        return {
          isExisting: true,
          booking: finalCheck,
          bookingReference: finalCheck.bookingReference,
          message: "Booking already exists.",
        };
      }

      // -------------------------------------------------------------
      // STEP C: INVENTORY LOCK (Transaction-Safe Math)
      // -------------------------------------------------------------
      const lotId =
        quotationRecord?.sellerAvailabilityId ||
        (latestVersion.snapshotPayload as any)?.lotId;

      const dealQuantity = Number(
        dealRecord?.agreedQuantity ||
          (latestVersion.snapshotPayload as any)?.quantity ||
          0
      );

      if (lotId && dealQuantity > 0) {
        const targetLot = await tx.query.availabilities.findFirst({
          where: eq(availabilities.id, lotId),
        });

        if (targetLot) {
          // Atomically move quantity from available to reserved
          const updatedLots = await tx
            .update(availabilities)
            .set({
              availableQuantity: sql`${availabilities.availableQuantity} - ${dealQuantity}`,
              reservedQuantity: sql`${availabilities.reservedQuantity} + ${dealQuantity}`,
              version: sql`${availabilities.version} + 1`,
            })
            .where(
              and(
                eq(availabilities.id, lotId),
                sql`${availabilities.availableQuantity} >= ${dealQuantity}`
              )
            )
            .returning();

          if (updatedLots.length === 0) {
            throw new Error(
              `INVENTORY_LOCK_FAILED: Insufficient available quantity or concurrent modification on Lot #${targetLot.lotNumber || targetLot.id}. Required: ${dealQuantity}, Available: ${targetLot.availableQuantity}. Booking transaction aborted.`
            );
          }
        }
      }

      // -------------------------------------------------------------
      // STEP D: CREATION (Generate unique BKG- reference & insert row)
      // -------------------------------------------------------------
      let bookingReference = generateBookingReference();

      // Check for collision and regenerate if needed
      const collisionCheck = await tx.query.bookings.findFirst({
        where: eq(bookings.bookingReference, bookingReference),
      });
      if (collisionCheck) {
        bookingReference = generateBookingReference();
      }

      const [newBooking] = await tx
        .insert(bookings)
        .values({
          bookingReference,
          dealId: finalDealId,
          lockedVersionId: latestVersion.id,
          status: "Confirmed",
        })
        .returning();

      // Transition parent deal to 'Dispatch Pending' and quotation to 'Accepted (Booked)'
      await tx
        .update(deals)
        .set({ status: "Dispatch Pending" })
        .where(eq(deals.id, finalDealId));

      if (quotationRecord) {
        await tx
          .update(quotations)
          .set({ status: "Accepted" })
          .where(eq(quotations.id, quotationRecord.id));
      }

      // -------------------------------------------------------------
      // STEP E: AUDIT & IN-APP NOTIFICATION
      // -------------------------------------------------------------
      const dbUser = await tx.query.users.findFirst({
        where: eq(users.id, user.id),
      });

      const linkedLot = lotId
        ? await tx.query.availabilities.findFirst({
            where: eq(availabilities.id, lotId),
          })
        : null;

      const sellerCompanyId =
        linkedLot?.companyId || dealRecord?.sellerId || dbUser?.companyId;

      // 1. Ingest Immutable Negotiation Audit Event
      if (sellerCompanyId) {
        await tx.insert(negotiationEvents).values({
          requestId: targetRequestId,
          companyId: sellerCompanyId,
          actorId: user.id,
          actionType: "BOOKING_CREATED",
          payload: {
            bookingReference: newBooking.bookingReference,
            bookingId: newBooking.id,
            lockedVersionId: latestVersion.id,
            versionNumber: latestVersion.versionNumber,
            quantityLocked: dealQuantity,
            status: "Confirmed",
            createdAt: new Date().toISOString(),
          },
        });
      }

      // 2. Non-Autonomous Decision Gate Provenance Audit Log
      await logDecisionGateAuditEventAction({
        action: "BOOKING_CREATED",
        actorId: user.id,
        actorRole: dbUser?.role || "system",
        entity: "bookings",
        entityId: newBooking.id,
        metadata: {
          booking_reference: newBooking.bookingReference,
          dealId: finalDealId,
          lockedVersionId: latestVersion.id,
          versionNumber: latestVersion.versionNumber,
          dealQuantity,
          lotId,
        },
      });

      // 3. Queue In-App Notification to the lot owner
      if (sellerCompanyId) {
        const sellerOwner = await tx.query.users.findFirst({
          where: eq(users.companyId, sellerCompanyId),
        });

        if (sellerOwner) {
          await queueNotificationAction({
            userId: sellerOwner.id,
            companyId: sellerCompanyId,
            channel: "IN_APP",
            eventType: "DEAL_UPDATED",
            title: "Booking Reference Issued",
            message: `Official Booking ID ${newBooking.bookingReference} has been created and locked. You may now proceed to dispatch.`,
            actionUrl: `/seller/deals/${finalDealId}`,
            payload: {
              dealId: finalDealId,
              bookingReference: newBooking.bookingReference,
              status: "Confirmed",
            },
          });
        }
      }

      return {
        isExisting: false,
        booking: newBooking,
        bookingReference: newBooking.bookingReference,
        message: "Booking created successfully.",
      };
    });

    revalidatePath("/seller");
    revalidatePath("/seller/deals");
    revalidatePath("/seller/requests");
    revalidatePath(`/seller/deals/${dealIdOrRequestId}`);
    revalidatePath(`/seller/deals/${dealIdOrRequestId}/confirm`);
    revalidatePath("/broker");

    return {
      success: true,
      bookingId: result.bookingReference,
      data: result.booking,
      message: result.message,
    };
  } catch (error: any) {
    console.error("Idempotent booking creation error:", error);
    return {
      success: false,
      error: error.message || "Failed to create booking",
    };
  }
}

/**
 * Server Action: Fetches the booking associated with a Deal ID or Request ID.
 */
export async function getBookingByDealIdAction(
  dealIdOrRequestId: string
): Promise<BookingActionResult> {
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
      return { success: false, error: "Deal ID is required." };
    }

    // Check deal or quotation
    const dealRecord = await db.query.deals.findFirst({
      where: or(
        eq(deals.id, dealIdOrRequestId),
        eq(deals.quotationId, dealIdOrRequestId)
      ),
    });

    const quotationRecord = await db.query.quotations.findFirst({
      where: eq(
        quotations.id,
        dealRecord ? dealRecord.quotationId : dealIdOrRequestId
      ),
    });

    const targetRequestId = quotationRecord
      ? quotationRecord.id
      : dealRecord?.quotationId || dealIdOrRequestId;

    const bookingRecord = await db.query.bookings.findFirst({
      where: dealRecord
        ? or(
            eq(bookings.dealId, dealRecord.id),
            eq(bookings.dealId, targetRequestId)
          )
        : eq(bookings.dealId, targetRequestId),
    });

    return {
      success: true,
      bookingId: bookingRecord?.bookingReference,
      data: bookingRecord || null,
    };
  } catch (error: any) {
    console.error("Fetch booking error:", error);
    return {
      success: false,
      error: error.message || "Failed to fetch booking",
    };
  }
}
