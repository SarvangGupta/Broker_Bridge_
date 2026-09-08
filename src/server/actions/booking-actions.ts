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
  dispatches,
  masterVehicleTypes,
} from "@/src/server/db/schema";
import { eq, or, and, sql, desc, inArray } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { logDecisionGateAuditEventAction } from "@/src/server/actions/audit-actions";
import { queueNotificationAction } from "@/src/server/actions/notification-actions";
import { verifySellerSession } from "@/src/server/utils/seller-auth";
import { DealVersionSnapshot } from "@/src/types/deal-version-schema";

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

export interface BookedOrderSummary {
  id: string; // Booking UUID
  bookingReference: string; // 'BKG-2026-XXXX'
  dealId: string;
  quotationId?: string;
  lockedVersionId: string;
  versionNumber: number;
  commodityName: string;
  gradeName: string;
  lotNumber: string;
  bookedQuantity: number;
  alreadyDispatchedQuantity: number;
  remainingQuantity: number;
  unitSymbol: string;
  lockedRate: number;
  totalValuation: number;
  deliveryLocation: string;
  deliveryState?: string;
  deliveryDistrict?: string;
  deliveryTerms: string;
  expectedDeliveryDate?: string | null;
  paymentTerms: string;
  dealStatus: string;
  bookingStatus: string;
  bookingCreatedAt: string;
  dispatchesCount: number;
  hasDispatched: boolean;
  isFullyDispatched: boolean;
}

/**
 * Server Action: Fetches all booked orders for the authenticated Seller (Micro-Sprint 19.1).
 *
 * STRICT PRIVACY & ISOLATION RULES:
 * 1. Enforces tenant isolation: Returns only bookings owned by the authenticated seller's company.
 * 2. Zero Buyer PII: Strips all buyer personal/contact data at the query boundary.
 * 3. Read-Only Snapshot: Reads from immutable locked version snapshots.
 */
export async function getSellerBookedOrdersAction(): Promise<{
  success: boolean;
  data?: BookedOrderSummary[];
  error?: string;
}> {
  try {
    const session = await verifySellerSession({ allowViewer: true });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized: Valid seller session required." };
    }

    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" ||
      session.data.user.role === "ADMIN";

    // 1. Fetch all bookings
    const allBookings = await db
      .select({
        id: bookings.id,
        bookingReference: bookings.bookingReference,
        dealId: bookings.dealId,
        lockedVersionId: bookings.lockedVersionId,
        status: bookings.status,
        createdAt: bookings.createdAt,
      })
      .from(bookings)
      .orderBy(desc(bookings.createdAt));

    if (!allBookings.length) {
      return { success: true, data: [] };
    }

    // 2. Fetch associated deals, quotations, versions, and lots
    const bookedOrders: BookedOrderSummary[] = [];

    for (const b of allBookings) {
      // Find deal record
      let dealRecord = await db.query.deals.findFirst({
        where: or(eq(deals.id, b.dealId), eq(deals.quotationId, b.dealId)),
      });

      // Find quotation
      const quotationId = dealRecord ? dealRecord.quotationId : b.dealId;
      const quotationRecord = await db.query.quotations.findFirst({
        where: eq(quotations.id, quotationId),
      });

      // Find availability/lot
      const lotRecord = quotationRecord?.sellerAvailabilityId
        ? await db.query.availabilities.findFirst({
            where: eq(availabilities.id, quotationRecord.sellerAvailabilityId),
          })
        : null;

      // Ownership Verification: Must match sellerCompanyId unless admin
      const dealSellerId = dealRecord?.sellerId;
      const lotCompanyId = lotRecord?.companyId;

      const isOwnedBySeller =
        isPlatformAdmin ||
        dealSellerId === sellerCompanyId ||
        dealSellerId === session.data.user.id ||
        lotCompanyId === sellerCompanyId;

      if (!isOwnedBySeller) {
        continue;
      }

      // Fetch locked version snapshot
      let versionRecord = await db.query.dealVersions.findFirst({
        where: eq(dealVersions.id, b.lockedVersionId),
      });

      if (!versionRecord && quotationId) {
        versionRecord = await db.query.dealVersions.findFirst({
          where: eq(dealVersions.requestId, quotationId),
          orderBy: desc(dealVersions.versionNumber),
        });
      }

      const snap = (versionRecord?.snapshotPayload || {}) as DealVersionSnapshot;

      // Fetch dispatches and negotiation dispatch events for partial fulfillment tracking
      const dealIdToQuery = dealRecord ? dealRecord.id : b.dealId;
      const [existingDispatches, dispatchEvents] = await Promise.all([
        db.query.dispatches.findMany({
          where: eq(dispatches.dealId, dealIdToQuery),
        }),
        quotationId
          ? db
              .select()
              .from(negotiationEvents)
              .where(
                and(
                  eq(negotiationEvents.requestId, quotationId),
                  eq(negotiationEvents.actionType, "DISPATCH_SUBMITTED")
                )
              )
          : [],
      ]);

      const bookedQty = Number(dealRecord?.agreedQuantity || snap.quantity || 0);
      const lockedRate = Number(dealRecord?.agreedPrice || snap.rate || 0);
      const totalVal = bookedQty * lockedRate;

      const alreadyDispatched = dispatchEvents.reduce(
        (sum, ev) => sum + Number((ev.payload as any)?.dispatchQuantity || 0),
        0
      );
      const remainingQty = Math.max(0, Number((bookedQty - alreadyDispatched).toFixed(4)));

      const destParts = [snap.deliveryLocation, snap.deliveryDistrict, snap.deliveryState].filter(Boolean);
      const destString = destParts.length > 0 ? destParts.join(", ") : "Ex-Warehouse";

      const orderSummary: BookedOrderSummary = {
        id: b.id,
        bookingReference: b.bookingReference,
        dealId: dealRecord ? dealRecord.id : b.dealId,
        quotationId: quotationRecord?.id,
        lockedVersionId: b.lockedVersionId,
        versionNumber: versionRecord?.versionNumber || 1,
        commodityName: snap.commodityName || "Agricultural Commodity",
        gradeName: snap.gradeName || "Standard Grade",
        lotNumber: snap.lotNumber || lotRecord?.lotNumber || "N/A",
        bookedQuantity: bookedQty,
        alreadyDispatchedQuantity: alreadyDispatched,
        remainingQuantity: remainingQty,
        unitSymbol: snap.unitSymbol || "MT",
        lockedRate: lockedRate,
        totalValuation: totalVal,
        deliveryLocation: destString,
        deliveryState: snap.deliveryState || undefined,
        deliveryDistrict: snap.deliveryDistrict || undefined,
        deliveryTerms: snap.deliveryTerms || "Ex-Warehouse",
        expectedDeliveryDate: snap.deliveryDate || null,
        paymentTerms: snap.paymentTerms || "Broker Escrow Settlement",
        dealStatus: dealRecord?.status || "Dispatch Pending",
        bookingStatus: b.status || "Confirmed",
        bookingCreatedAt: b.createdAt.toISOString(),
        dispatchesCount: existingDispatches.length,
        hasDispatched:
          existingDispatches.length > 0 ||
          alreadyDispatched > 0 ||
          dealRecord?.status === "In Transit" ||
          dealRecord?.status === "Dispatched" ||
          dealRecord?.status === "Partially Dispatched",
        isFullyDispatched: remainingQty === 0 && bookedQty > 0,
      };

      bookedOrders.push(orderSummary);
    }

    return {
      success: true,
      data: bookedOrders,
    };
  } catch (error: any) {
    console.error("Get seller booked orders error:", error);
    return {
      success: false,
      error: error.message || "Failed to load booked orders.",
    };
  }
}

export interface BookingForDispatchDetails {
  booking: {
    id: string;
    bookingReference: string;
    status: string;
    createdAt: string;
    lockedVersionId: string;
  };
  deal: {
    id: string;
    requirementId?: string;
    quotationId?: string;
    agreedQuantity: number;
    agreedPrice: number | string;
    status: string;
    createdAt: string;
    expectedDeliveryDate?: string | null;
  };
  quotation: {
    id: string;
    status: string;
  } | null;
  lockedVersion: {
    id: string;
    versionNumber: number;
    status: string;
    snapshotPayload: DealVersionSnapshot;
    createdAt: string;
  };
  commercials: {
    commodityName: string;
    gradeName: string;
    lotNumber: string;
    bookedQuantity: number;
    alreadyDispatchedQuantity: number;
    remainingQuantity: number;
    unitSymbol: string;
    lockedRate: number;
    totalValuation: number;
    deliveryLocation: string;
    deliveryTerms: string;
    expectedDeliveryDate: string | null;
    paymentTerms: string;
  };
  vehicleTypes: Array<{ id: string; name: string }>;
  existingDispatches: Array<any>;
}

/**
 * Server Action: Fetches specific Booking details for the Gated Dispatch Entry point (Micro-Sprint 19.1).
 *
 * GATE ENFORCEMENT:
 * 1. Checks if booking exists. If not, returns explicit error to block unbooked dispatches.
 * 2. Verifies Seller tenant ownership.
 * 3. Provides read-only locked commercial terms for pre-filling and boundary validation.
 */
export async function getBookingForDispatchAction(
  bookingIdOrReference: string
): Promise<{
  success: boolean;
  data?: BookingForDispatchDetails;
  error?: string;
}> {
  try {
    const session = await verifySellerSession({ allowViewer: true });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized: Valid seller session required." };
    }

    if (!bookingIdOrReference) {
      return { success: false, error: "Booking ID or Reference is required." };
    }

    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" ||
      session.data.user.role === "ADMIN";

    // 1. Find Booking record (supports both human-readable booking_reference and UUID)
    const rawInput = (bookingIdOrReference || "").trim();
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(rawInput);

    let bookingRecord = await db.query.bookings.findFirst({
      where: eq(bookings.bookingReference, rawInput.toUpperCase()),
    });

    if (!bookingRecord && isUuid) {
      bookingRecord = await db.query.bookings.findFirst({
        where: or(
          eq(bookings.id, rawInput),
          eq(bookings.dealId, rawInput)
        ),
      });
    }

    if (!bookingRecord) {
      return {
        success: false,
        error: "DISPATCH_GATE_REJECTED: Booking reference not found. Physical dispatches can only be initiated for booked transactions.",
      };
    }

    // 2. Resolve Deal
    let dealRecord = await db.query.deals.findFirst({
      where: or(
        eq(deals.id, bookingRecord.dealId),
        eq(deals.quotationId, bookingRecord.dealId)
      ),
    });

    // 3. Resolve Quotation
    const targetQuotationId = dealRecord
      ? dealRecord.quotationId
      : bookingRecord.dealId;

    const quotationRecord = await db.query.quotations.findFirst({
      where: eq(quotations.id, targetQuotationId),
    });

    // 4. Resolve Availability Lot
    const lotRecord = quotationRecord?.sellerAvailabilityId
      ? await db.query.availabilities.findFirst({
          where: eq(availabilities.id, quotationRecord.sellerAvailabilityId),
        })
      : null;

    // 5. Tenant Authorization Check
    const dealSellerId = dealRecord?.sellerId;
    const lotCompanyId = lotRecord?.companyId;

    const isAuthorized =
      isPlatformAdmin ||
      dealSellerId === sellerCompanyId ||
      dealSellerId === session.data.user.id ||
      lotCompanyId === sellerCompanyId;

    if (!isAuthorized) {
      return {
        success: false,
        error: "Unauthorized: You do not own the inventory or deal linked to this booking.",
      };
    }

    // 6. Fetch Locked Deal Version Snapshot
    let versionRecord = await db.query.dealVersions.findFirst({
      where: eq(dealVersions.id, bookingRecord.lockedVersionId),
    });

    if (!versionRecord && targetQuotationId) {
      versionRecord = await db.query.dealVersions.findFirst({
        where: eq(dealVersions.requestId, targetQuotationId),
        orderBy: desc(dealVersions.versionNumber),
      });
    }

    if (!versionRecord) {
      return {
        success: false,
        error: "Locked deal version snapshot not found for this booking.",
      };
    }

    const snap = versionRecord.snapshotPayload as DealVersionSnapshot;

    // 7. Fetch active Master Vehicle Types, Existing Dispatches & Negotiation Events
    const [vehicleTypesList, existingDispatchesList, dispatchEventsList] = await Promise.all([
      db
        .select({
          id: masterVehicleTypes.id,
          name: masterVehicleTypes.name,
        })
        .from(masterVehicleTypes)
        .where(eq(masterVehicleTypes.status, true)),
      dealRecord
        ? db.query.dispatches.findMany({
            where: eq(dispatches.dealId, dealRecord.id),
          })
        : [],
      targetQuotationId
        ? db
            .select()
            .from(negotiationEvents)
            .where(
              and(
                eq(negotiationEvents.requestId, targetQuotationId),
                eq(negotiationEvents.actionType, "DISPATCH_SUBMITTED")
              )
            )
        : [],
    ]);

    const bookedQty = Number(dealRecord?.agreedQuantity || snap.quantity || 0);
    const lockedRate = Number(dealRecord?.agreedPrice || snap.rate || 0);
    const totalVal = bookedQty * lockedRate;

    const alreadyDispatched = dispatchEventsList.reduce(
      (sum, ev) => sum + Number((ev.payload as any)?.dispatchQuantity || 0),
      0
    );
    const remainingQty = Math.max(0, Number((bookedQty - alreadyDispatched).toFixed(4)));

    const destParts = [snap.deliveryLocation, snap.deliveryDistrict, snap.deliveryState].filter(Boolean);
    const destString = destParts.length > 0 ? destParts.join(", ") : "Ex-Warehouse";

    return {
      success: true,
      data: {
        booking: {
          id: bookingRecord.id,
          bookingReference: bookingRecord.bookingReference,
          status: bookingRecord.status,
          createdAt: bookingRecord.createdAt.toISOString(),
          lockedVersionId: bookingRecord.lockedVersionId,
        },
        deal: {
          id: dealRecord ? dealRecord.id : bookingRecord.dealId,
          requirementId: dealRecord?.requirementId || quotationRecord?.requirementId,
          quotationId: targetQuotationId,
          agreedQuantity: bookedQty,
          agreedPrice: lockedRate,
          status: dealRecord?.status || "Dispatch Pending",
          createdAt: dealRecord?.createdAt?.toISOString() || bookingRecord.createdAt.toISOString(),
          expectedDeliveryDate: snap.deliveryDate || null,
        },
        quotation: quotationRecord
          ? {
              id: quotationRecord.id,
              status: quotationRecord.status,
            }
          : null,
        lockedVersion: {
          id: versionRecord.id,
          versionNumber: versionRecord.versionNumber,
          status: versionRecord.status,
          snapshotPayload: snap,
          createdAt: versionRecord.createdAt.toISOString(),
        },
        commercials: {
          commodityName: snap.commodityName || "Agricultural Commodity",
          gradeName: snap.gradeName || "Standard Grade",
          lotNumber: snap.lotNumber || lotRecord?.lotNumber || "N/A",
          bookedQuantity: bookedQty,
          alreadyDispatchedQuantity: alreadyDispatched,
          remainingQuantity: remainingQty,
          unitSymbol: snap.unitSymbol || "MT",
          lockedRate: lockedRate,
          totalValuation: totalVal,
          deliveryLocation: destString,
          deliveryTerms: snap.deliveryTerms || "Ex-Warehouse",
          expectedDeliveryDate: snap.deliveryDate || null,
          paymentTerms: snap.paymentTerms || "Broker Escrow Settlement",
        },
        vehicleTypes: vehicleTypesList,
        existingDispatches: existingDispatchesList,
      },
    };
  } catch (error: any) {
    console.error("Get booking for dispatch error:", error);
    return {
      success: false,
      error: error.message || "Failed to load booking details for dispatch.",
    };
  }
}

