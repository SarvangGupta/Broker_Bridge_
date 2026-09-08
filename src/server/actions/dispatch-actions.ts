"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import {
  bookings,
  deals,
  quotations,
  dealVersions,
  availabilities,
  dispatches,
  negotiationEvents,
  users,
  masterVehicleTypes,
  disputes,
} from "@/src/server/db/schema";
import { eq, or, and, desc, asc } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { verifySellerSession } from "@/src/server/utils/seller-auth";
import { sellerDispatchSchema, SellerDispatchFormData } from "@/src/types/dispatch-schema";
import { logDecisionGateAuditEventAction } from "@/src/server/actions/audit-actions";
import { queueNotificationAction } from "@/src/server/actions/notification-actions";
import { DealVersionSnapshot } from "@/src/types/deal-version-schema";

export type DispatchActionResult<T = any> = {
  success: boolean;
  data?: T;
  dispatchId?: string;
  bookingReference?: string;
  dispatchQuantity?: number;
  remainingQuantity?: number;
  status?: string;
  message?: string;
  error?: string;
};

/**
 * Server Action: Submit Dispatch with Transactional Partial Fulfillment Validation (Micro-Sprint 19.2).
 * 
 * CORE RULES & CONCURRENCY GUARDS:
 * 1. Executes strictly inside db.transaction() to prevent race conditions.
 * 2. Concurrency & Math Check: Validates that dispatch_quantity <= remaining_quantity.
 * 3. Status Transition: Transitions Booking to 'Partially Dispatched' or 'Fully Dispatched'.
 * 4. Immutable Audit Trail: Ingests a structured record into negotiation_events and system audit logs.
 */
export async function submitDispatchAction(
  payload: SellerDispatchFormData
): Promise<DispatchActionResult> {
  try {
    // 1. Authorize Seller Session
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return {
        success: false,
        error: session.error || "Unauthorized: Valid seller session required.",
      };
    }

    // 2. Validate Payload with Zod Schema
    const parsed = sellerDispatchSchema.parse(payload);
    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" || session.data.user.role === "ADMIN";

    // 3. Execute Transactional Dispatch Creation
    const result = await db.transaction(async (tx) => {
      // 1. Find the target booking (supports both human-readable booking_reference and UUID)
      const rawBookingId = (parsed.booking_id || "").trim();
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(rawBookingId);

      let bookingRecord = await tx.query.bookings.findFirst({
        where: eq(bookings.bookingReference, rawBookingId.toUpperCase()),
      });

      if (!bookingRecord && isUuid) {
        bookingRecord = await tx.query.bookings.findFirst({
          where: or(
            eq(bookings.id, rawBookingId),
            eq(bookings.dealId, rawBookingId)
          ),
        });
      }

      if (!bookingRecord) {
        throw new Error(
          "BOOKING_NOT_FOUND: The referenced Booking ID does not exist or has not been issued. Cannot dispatch an unbooked trade."
        );
      }

      // 2. Find Deal & Quotation records
      let dealRecord = await tx.query.deals.findFirst({
        where: or(
          eq(deals.id, bookingRecord.dealId),
          eq(deals.quotationId, bookingRecord.dealId)
        ),
      });

      const targetQuotationId = dealRecord
        ? dealRecord.quotationId
        : bookingRecord.dealId;

      const quotationRecord = await tx.query.quotations.findFirst({
        where: eq(quotations.id, targetQuotationId),
      });

      const lotRecord = quotationRecord?.sellerAvailabilityId
        ? await tx.query.availabilities.findFirst({
            where: eq(availabilities.id, quotationRecord.sellerAvailabilityId),
          })
        : null;

      // 3. Verify Seller Tenant Ownership
      const dealSellerId = dealRecord?.sellerId;
      const lotCompanyId = lotRecord?.companyId;

      const isAuthorized =
        isPlatformAdmin ||
        dealSellerId === sellerCompanyId ||
        dealSellerId === session.data.user.id ||
        lotCompanyId === sellerCompanyId;

      if (!isAuthorized) {
        throw new Error(
          "UNAUTHORIZED_DISPATCH: You do not own the inventory lot or booked deal referenced in this dispatch."
        );
      }

      // 4. Resolve Total Booked Quantity from Deal or Snapshot
      let versionRecord = await tx.query.dealVersions.findFirst({
        where: eq(dealVersions.id, bookingRecord.lockedVersionId),
      });

      if (!versionRecord && targetQuotationId) {
        versionRecord = await tx.query.dealVersions.findFirst({
          where: eq(dealVersions.requestId, targetQuotationId),
          orderBy: desc(dealVersions.versionNumber),
        });
      }

      const snap = (versionRecord?.snapshotPayload || {}) as DealVersionSnapshot;
      const totalBookedQuantity = Number(
        dealRecord?.agreedQuantity || snap.quantity || 0
      );

      if (totalBookedQuantity <= 0) {
        throw new Error(
          "INVALID_BOOKING_QUANTITY: The booked transaction has a zero or invalid quantity."
        );
      }

      // 5. Compute Already Dispatched Quantity via Negotiation Events Ledger
      const existingDispatchEvents = await tx
        .select()
        .from(negotiationEvents)
        .where(
          and(
            eq(negotiationEvents.requestId, targetQuotationId),
            eq(negotiationEvents.actionType, "DISPATCH_SUBMITTED")
          )
        );

      const alreadyDispatchedQuantity = existingDispatchEvents.reduce(
        (sum, ev) => sum + Number((ev.payload as any)?.dispatchQuantity || 0),
        0
      );

      const remainingQuantity = Math.max(
        0,
        Number((totalBookedQuantity - alreadyDispatchedQuantity).toFixed(4))
      );

      // Strict Concurrency Math Guard:
      if (parsed.dispatch_quantity > remainingQuantity) {
        throw new Error(
          `DISPATCH_QUANTITY_EXCEEDED: Dispatch quantity (${parsed.dispatch_quantity} ${snap.unitSymbol || "MT"}) cannot exceed the remaining booked quantity of ${remainingQuantity} ${snap.unitSymbol || "MT"}.`
        );
      }

      // -----------------------------------------------------------------
      // STEP B: INSERT DISPATCH RECORD (Sprint 10 Table)
      // -----------------------------------------------------------------
      let effectiveVehicleTypeId = parsed.vehicle_type_id || null;

      if (!effectiveVehicleTypeId) {
        const matchingVehicleType = await tx.query.masterVehicleTypes.findFirst({
          where: eq(masterVehicleTypes.name, parsed.vehicle_type),
        });
        effectiveVehicleTypeId = matchingVehicleType?.id || null;
      }

      const targetDealId = dealRecord ? dealRecord.id : bookingRecord.dealId;

      const [newDispatch] = await tx
        .insert(dispatches)
        .values({
          dealId: targetDealId,
          sellerId: session.data.user.id,
          vehicleTypeId: effectiveVehicleTypeId,
          vehicleNumber: `${parsed.vehicle_number} (${parsed.transport_company})`,
          driverName: parsed.driver_name,
          driverMobile: parsed.driver_mobile,
          dispatchDate: parsed.dispatch_date,
          expectedDeliveryDate: parsed.eta,
          status: "Dispatched",
        })
        .returning();

      // -----------------------------------------------------------------
      // STEP C: UPDATE BOOKING & DEAL STATE MACHINE
      // -----------------------------------------------------------------
      const newRemainingQuantity = Math.max(
        0,
        Number((remainingQuantity - parsed.dispatch_quantity).toFixed(4))
      );
      const newTotalDispatchedQuantity = Number(
        (alreadyDispatchedQuantity + parsed.dispatch_quantity).toFixed(4)
      );

      const isFullyDispatched = newRemainingQuantity === 0;
      const newBookingStatus = isFullyDispatched
        ? "Fully Dispatched"
        : "Partially Dispatched";
      const newDealStatus = isFullyDispatched ? "In Transit" : "Partially Dispatched";

      // Update Bookings status
      await tx
        .update(bookings)
        .set({
          status: newBookingStatus,
        })
        .where(eq(bookings.id, bookingRecord.id));

      // Update Deals status if deal record exists
      if (dealRecord) {
        await tx
          .update(deals)
          .set({
            status: newDealStatus,
          })
          .where(eq(deals.id, dealRecord.id));
      }

      // -----------------------------------------------------------------
      // STEP D: RECORD IMMUTABLE AUDIT TRAIL IN NEGOTIATION EVENTS
      // -----------------------------------------------------------------
      await tx.insert(negotiationEvents).values({
        requestId: targetQuotationId,
        companyId: sellerCompanyId,
        actorId: session.data.user.id,
        actionType: "DISPATCH_SUBMITTED",
        payload: {
          bookingId: bookingRecord.id,
          bookingReference: bookingRecord.bookingReference,
          dispatchId: newDispatch.id,
          dispatchQuantity: parsed.dispatch_quantity,
          previouslyDispatched: alreadyDispatchedQuantity,
          totalDispatched: newTotalDispatchedQuantity,
          remainingQuantity: newRemainingQuantity,
          bookedQuantity: totalBookedQuantity,
          unitSymbol: snap.unitSymbol || "MT",
          vehicleNumber: parsed.vehicle_number,
          vehicleType: parsed.vehicle_type,
          driverName: parsed.driver_name,
          driverMobile: parsed.driver_mobile,
          transportCompany: parsed.transport_company,
          loadingLocation: parsed.loading_location,
          dispatchDate: parsed.dispatch_date.toISOString(),
          eta: parsed.eta.toISOString(),
          status: newBookingStatus,
          remarks: parsed.remarks || null,
          dispatchedBy: session.data.user.name,
          dispatchedAt: new Date().toISOString(),
        },
      });

      // -----------------------------------------------------------------
      // STEP E: AUDIT LOG DRAIN & IN-APP NOTIFICATIONS
      // -----------------------------------------------------------------
      await logDecisionGateAuditEventAction({
        action: "BOOKING_MANUALLY_CONFIRMED",
        actorId: session.data.user.id,
        actorRole: "seller",
        entity: "bookings",
        entityId: newDispatch.id,
        metadata: {
          stage: "DISPATCH_RECORDED",
          bookingReference: bookingRecord.bookingReference,
          dispatchQuantity: parsed.dispatch_quantity,
          remainingQuantity: newRemainingQuantity,
          isFullyDispatched,
          vehicleNumber: parsed.vehicle_number,
        },
      });

      // Queue Notification to the Seller
      await queueNotificationAction({
        userId: session.data.user.id,
        companyId: sellerCompanyId,
        channel: "IN_APP",
        eventType: "DEAL_UPDATED",
        title: isFullyDispatched
          ? `Booking #${bookingRecord.bookingReference} Fully Dispatched`
          : `Partial Dispatch: ${parsed.dispatch_quantity} ${snap.unitSymbol || "MT"} Logged`,
        message: `Dispatched ${parsed.dispatch_quantity} ${snap.unitSymbol || "MT"} on Vehicle ${parsed.vehicle_number}. Remaining: ${newRemainingQuantity} ${snap.unitSymbol || "MT"}.`,
        actionUrl: `/seller/dispatch/${bookingRecord.bookingReference}`,
        payload: {
          bookingReference: bookingRecord.bookingReference,
          dispatchId: newDispatch.id,
          status: newBookingStatus,
        },
      });

      // Queue Notification to the Broker if assigned
      if (quotationRecord?.brokerId) {
        await queueNotificationAction({
          userId: quotationRecord.brokerId,
          channel: "IN_APP",
          eventType: "DEAL_UPDATED",
          title: `Shipment Dispatched for Booking #${bookingRecord.bookingReference}`,
          message: `Seller logged shipment of ${parsed.dispatch_quantity} ${snap.unitSymbol || "MT"} on vehicle ${parsed.vehicle_number}.`,
          actionUrl: `/broker`,
          payload: {
            bookingReference: bookingRecord.bookingReference,
            dispatchId: newDispatch.id,
          },
        });
      }

      return {
        dispatchId: newDispatch.id,
        bookingReference: bookingRecord.bookingReference,
        dispatchQuantity: parsed.dispatch_quantity,
        remainingQuantity: newRemainingQuantity,
        status: newBookingStatus,
        message: isFullyDispatched
          ? `Full dispatch of ${parsed.dispatch_quantity} ${snap.unitSymbol || "MT"} successfully recorded. All booked inventory is now in transit!`
          : `Partial dispatch of ${parsed.dispatch_quantity} ${snap.unitSymbol || "MT"} recorded. Remaining to dispatch: ${newRemainingQuantity} ${snap.unitSymbol || "MT"}.`,
      };
    });

    // Revalidate paths for instant client freshness across entire Seller layout and nested views
    revalidatePath("/seller", "layout");
    revalidatePath("/seller");
    revalidatePath("/seller/dispatch");
    revalidatePath(`/seller/dispatch/${result.bookingReference}`);
    revalidatePath("/seller/deals");

    return {
      success: true,
      ...result,
    };
  } catch (error: any) {
    console.error("Submit dispatch action error:", error);
    return {
      success: false,
      error: error.message || "Failed to submit dispatch record.",
    };
  }
}

/**
 * Server Action: Fetches remaining quantity balance and dispatch audit history for a booking.
 */
export async function getBookingRemainingQuantityAction(
  bookingIdOrReference: string
): Promise<{
  success: boolean;
  data?: {
    bookingId: string;
    bookingReference: string;
    totalBookedQuantity: number;
    alreadyDispatchedQuantity: number;
    remainingQuantity: number;
    unitSymbol: string;
    isFullyDispatched: boolean;
    dispatchesHistory: Array<{
      id: string;
      quantity: number;
      vehicleNumber: string;
      driverName: string;
      driverMobile: string;
      transportCompany: string;
      dispatchDate: string;
      eta: string;
      status: string;
    }>;
  };
  error?: string;
}> {
  try {
    const session = await verifySellerSession({ allowViewer: true });
    if (!session.success || !session.data) {
      return { success: false, error: "Unauthorized" };
    }

    if (!bookingIdOrReference) {
      return { success: false, error: "Booking ID is required." };
    }

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
      return { success: false, error: "Booking not found." };
    }

    let dealRecord = await db.query.deals.findFirst({
      where: or(
        eq(deals.id, bookingRecord.dealId),
        eq(deals.quotationId, bookingRecord.dealId)
      ),
    });

    const targetQuotationId = dealRecord
      ? dealRecord.quotationId
      : bookingRecord.dealId;

    let versionRecord = await db.query.dealVersions.findFirst({
      where: eq(dealVersions.id, bookingRecord.lockedVersionId),
    });

    if (!versionRecord && targetQuotationId) {
      versionRecord = await db.query.dealVersions.findFirst({
        where: eq(dealVersions.requestId, targetQuotationId),
        orderBy: desc(dealVersions.versionNumber),
      });
    }

    const snap = (versionRecord?.snapshotPayload || {}) as DealVersionSnapshot;
    const totalBooked = Number(dealRecord?.agreedQuantity || snap.quantity || 0);

    // Tenant Authorization Check
    const lotRecord = targetQuotationId
      ? await db.query.quotations.findFirst({ where: eq(quotations.id, targetQuotationId) }).then(async (q) => {
          return q?.sellerAvailabilityId
            ? await db.query.availabilities.findFirst({ where: eq(availabilities.id, q.sellerAvailabilityId) })
            : null;
        })
      : null;

    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" || session.data.user.role === "ADMIN";

    const isAuthorized =
      isPlatformAdmin ||
      dealRecord?.sellerId === sellerCompanyId ||
      dealRecord?.sellerId === session.data.user.id ||
      lotRecord?.companyId === sellerCompanyId;

    if (!isAuthorized) {
      return { success: false, error: "Unauthorized: You do not have permission to view this booking balance." };
    }

    const dispatchEvents = await db
      .select()
      .from(negotiationEvents)
      .where(
        and(
          eq(negotiationEvents.requestId, targetQuotationId),
          eq(negotiationEvents.actionType, "DISPATCH_SUBMITTED")
        )
      )
      .orderBy(desc(negotiationEvents.createdAt));

    const alreadyDispatched = dispatchEvents.reduce(
      (sum, ev) => sum + Number((ev.payload as any)?.dispatchQuantity || 0),
      0
    );

    const remaining = Math.max(0, Number((totalBooked - alreadyDispatched).toFixed(4)));

    const dispatchesHistory = dispatchEvents.map((ev) => {
      const p = ev.payload as any;
      return {
        id: ev.id,
        quantity: Number(p.dispatchQuantity || 0),
        vehicleNumber: p.vehicleNumber || "N/A",
        driverName: p.driverName || "N/A",
        driverMobile: p.driverMobile || "N/A",
        transportCompany: p.transportCompany || "N/A",
        dispatchDate: p.dispatchDate || ev.createdAt.toISOString(),
        eta: p.eta || ev.createdAt.toISOString(),
        status: p.status || "Dispatched",
      };
    });

    return {
      success: true,
      data: {
        bookingId: bookingRecord.id,
        bookingReference: bookingRecord.bookingReference,
        totalBookedQuantity: totalBooked,
        alreadyDispatchedQuantity: alreadyDispatched,
        remainingQuantity: remaining,
        unitSymbol: snap.unitSymbol || "MT",
        isFullyDispatched: remaining === 0,
        dispatchesHistory,
      },
    };
  } catch (error: any) {
    console.error("Get booking remaining quantity error:", error);
    return {
      success: false,
      error: error.message || "Failed to load remaining quantity.",
    };
  }
}

export type DispatchTrackingData = {
  dispatchId: string;
  bookingId: string;
  bookingReference: string;
  dealId: string;
  commodityName: string;
  gradeName: string;
  lotNumber: string;
  dispatchQuantity: number;
  totalBookedQuantity: number;
  shipmentNumber: number;
  totalShipments: number;
  isPartial: boolean;
  remainingAfterDispatch: number;
  unitSymbol: string;
  vehicleNumber: string;
  driverName: string;
  driverMobile: string;
  transportCompany?: string;
  dispatchDate: string;
  expectedDeliveryDate: string;
  status: "Dispatched" | "In Transit" | "Delivered" | "Delayed" | "Disputed" | string;
  delayReason?: string | null;
  dispute?: {
    id: string;
    reason: string;
    description?: string | null;
    status: string;
    createdAt: string;
  } | null;
  stepperStage: "Dispatched" | "In Transit" | "Delivered";
  stageIndex: number;
  isDelayed: boolean;
  isDisputed: boolean;
  destinationLocation?: string;
};

/**
 * Server Action: Fetches unified read-only delivery & logistics tracking details for a dispatch.
 * Micro-Sprint 19.5 Delivery State Integration.
 * Strictly verifies Seller tenant ownership.
 */
export async function getDispatchTrackingAction(
  dispatchId: string
): Promise<{
  success: boolean;
  data?: DispatchTrackingData;
  error?: string;
}> {
  try {
    const session = await verifySellerSession({ allowViewer: true });
    if (!session.success || !session.data) {
      return { success: false, error: "Unauthorized: Valid seller session required." };
    }

    if (!dispatchId) {
      return { success: false, error: "Dispatch ID is required." };
    }

    // 1. Locate the dispatch record
    let dispatchRecord = await db.query.dispatches.findFirst({
      where: eq(dispatches.id, dispatchId),
    });

    let targetBookingReference = "";
    let bookingRecord: any = null;

    if (!dispatchRecord) {
      // Check if dispatchId was passed as a booking Reference
      const normalizedDispatchId = (dispatchId || "").toUpperCase().trim();
      bookingRecord = await db.query.bookings.findFirst({
        where: eq(bookings.bookingReference, normalizedDispatchId),
      });

      if (bookingRecord) {
        targetBookingReference = bookingRecord.bookingReference;
        dispatchRecord = await db.query.dispatches.findFirst({
          where: eq(dispatches.dealId, bookingRecord.dealId),
          orderBy: desc(dispatches.createdAt),
        });
      }
    }

    if (!dispatchRecord) {
      return { success: false, error: "Dispatch record not found." };
    }

    // 2. Resolve Deal, Booking & Version Snapshot
    const dealRecord = await db.query.deals.findFirst({
      where: eq(deals.id, dispatchRecord.dealId),
    });

    if (!bookingRecord && dealRecord) {
      bookingRecord = await db.query.bookings.findFirst({
        where: eq(bookings.dealId, dealRecord.id),
      });
    }

    const quotationId = dealRecord ? dealRecord.quotationId : null;
    const quotationRecord = quotationId
      ? await db.query.quotations.findFirst({ where: eq(quotations.id, quotationId) })
      : null;

    const lotRecord = quotationRecord?.sellerAvailabilityId
      ? await db.query.availabilities.findFirst({
          where: eq(availabilities.id, quotationRecord.sellerAvailabilityId),
        })
      : null;

    // Tenant Ownership Authorization Check
    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" || session.data.user.role === "ADMIN";

    const isAuthorized =
      isPlatformAdmin ||
      dispatchRecord.sellerId === session.data.user.id ||
      dealRecord?.sellerId === sellerCompanyId ||
      dealRecord?.sellerId === session.data.user.id ||
      lotRecord?.companyId === sellerCompanyId;

    if (!isAuthorized) {
      return {
        success: false,
        error: "Unauthorized: You do not have permission to view tracking details for this dispatch.",
      };
    }

    let versionRecord = bookingRecord?.lockedVersionId
      ? await db.query.dealVersions.findFirst({
          where: eq(dealVersions.id, bookingRecord.lockedVersionId),
        })
      : null;

    if (!versionRecord && quotationId) {
      versionRecord = await db.query.dealVersions.findFirst({
        where: eq(dealVersions.requestId, quotationId),
        orderBy: desc(dealVersions.versionNumber),
      });
    }

    const snap = (versionRecord?.snapshotPayload || {}) as DealVersionSnapshot;
    const totalBooked = Number(dealRecord?.agreedQuantity || snap.quantity || 0);

    // 3. Resolve Exact Dispatched Quantity and Sequence from Negotiation Events Ledger
    let specificDispatchQuantity = totalBooked;
    let shipmentNumber = 1;
    let totalShipments = 1;
    let isPartial = false;
    let remainingAfterDispatch = 0;

    if (quotationId) {
      const allDispatchEvents = await db
        .select()
        .from(negotiationEvents)
        .where(
          and(
            eq(negotiationEvents.requestId, quotationId),
            eq(negotiationEvents.actionType, "DISPATCH_SUBMITTED")
          )
        )
        .orderBy(asc(negotiationEvents.createdAt));

      if (allDispatchEvents.length > 0) {
        totalShipments = allDispatchEvents.length;
        const matchingIndex = allDispatchEvents.findIndex(
          (ev) => (ev.payload as any)?.dispatchId === dispatchRecord.id
        );

        if (matchingIndex !== -1) {
          shipmentNumber = matchingIndex + 1;
          const p = allDispatchEvents[matchingIndex].payload as any;
          specificDispatchQuantity = Number(p?.dispatchQuantity || specificDispatchQuantity);
          remainingAfterDispatch = Number(p?.remainingQuantity ?? 0);
          isPartial = specificDispatchQuantity < totalBooked;
        }
      }
    }

    // 4. Resolve Dispute if any (Sprint 11 table)
    const dealDispute = await db.query.disputes.findFirst({
      where: and(
        eq(disputes.dealId, dispatchRecord.dealId),
        eq(disputes.status, "Open")
      ),
      orderBy: desc(disputes.createdAt),
    });

    // 5. Resolve Stage & Deterministic Logistics State
    const status = dispatchRecord.status || "Dispatched";
    const isDisputed = !!dealDispute || status === "Disputed";
    const isDelayed = status === "Delayed";

    let stepperStage: "Dispatched" | "In Transit" | "Delivered" = "Dispatched";
    let stageIndex = 0;

    if (status === "Delivered" || status === "Completed") {
      stepperStage = "Delivered";
      stageIndex = 2;
    } else if (status === "In Transit" || status === "Delayed" || isDisputed) {
      stepperStage = "In Transit";
      stageIndex = 1;
    } else {
      stepperStage = "Dispatched";
      stageIndex = 0;
    }

    return {
      success: true,
      data: {
        dispatchId: dispatchRecord.id,
        bookingId: bookingRecord?.id || "",
        bookingReference: bookingRecord?.bookingReference || targetBookingReference || "BK-CONFIRMED",
        dealId: dispatchRecord.dealId,
        commodityName: snap.commodityName || "Agricultural Commodity",
        gradeName: snap.gradeName || "Standard Quality",
        lotNumber: snap.lotNumber || lotRecord?.lotNumber || "N/A",
        dispatchQuantity: specificDispatchQuantity,
        totalBookedQuantity: totalBooked,
        shipmentNumber,
        totalShipments,
        isPartial,
        remainingAfterDispatch,
        unitSymbol: snap.unitSymbol || "MT",
        vehicleNumber: dispatchRecord.vehicleNumber,
        driverName: dispatchRecord.driverName,
        driverMobile: dispatchRecord.driverMobile,
        dispatchDate: dispatchRecord.dispatchDate.toISOString(),
        expectedDeliveryDate: dispatchRecord.expectedDeliveryDate.toISOString(),
        status,
        delayReason: isDelayed ? "Transit delay reported by logistics carrier or transport checkpoint." : null,
        dispute: dealDispute
          ? {
              id: dealDispute.id,
              reason: dealDispute.reason,
              description: dealDispute.description || null,
              status: dealDispute.status,
              createdAt: dealDispute.createdAt.toISOString(),
            }
          : null,
        stepperStage,
        stageIndex,
        isDelayed,
        isDisputed,
        destinationLocation: snap.deliveryLocation || "Warehouse Delivery Hub",
      },
    };
  } catch (error: any) {
    console.error("getDispatchTrackingAction error:", error);
    return {
      success: false,
      error: error.message || "Failed to load logistics tracking state.",
    };
  }
}

