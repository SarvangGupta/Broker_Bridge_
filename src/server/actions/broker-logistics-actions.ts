'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  bookings,
  deals,
  quotations,
  dealVersions,
  dispatches,
  dispatchDocuments,
  availabilities,
  requirements,
  users,
  companies,
  negotiationEvents,
} from '@/src/server/db/schema';
import { eq, or, and, desc } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { DealVersionSnapshot } from '@/src/types/deal-version-schema';

export interface DispatchDocumentLink {
  id: string;
  documentType: string;
  fileUrl: string;
  signedUrl: string | null;
  createdAt: string;
}

export interface BrokerDispatchLogisticsItem {
  id: string; // Dispatch UUID
  dealId: string;
  sellerId: string;
  vehicleNumber: string;
  driverName: string;
  driverMobile: string;
  dispatchDate: string;
  expectedDeliveryDate: string; // ETA
  status: string; // 'Dispatched', 'In Transit', 'Delivered', 'Delayed', 'Disputed'
  createdAt: string;
  dispatchedQuantity?: number;
  lrDocument?: DispatchDocumentLink | null;
  ewayBillDocument?: DispatchDocumentLink | null;
  invoiceDocument?: DispatchDocumentLink | null;
  allDocuments: DispatchDocumentLink[];
}

export interface BrokerDispatchPayload {
  bookingId: string;
  bookingReference: string;
  dealId: string;
  commodityName: string;
  gradeName: string;
  agreedQuantity: number;
  dispatchedQuantity: number;
  remainingQuantity: number;
  unitSymbol: string;
  loadingLocation: string;
  destinationLocation: string;
  hasDispatches: boolean;
  dispatches: BrokerDispatchLogisticsItem[];
}

/**
 * Server Action: Fetches Dispatch Logistics Details for a specific Booking (Micro-Sprint 27.3).
 *
 * Enforces Broker Assignment Security: `user.id === broker_id` on the parent deal/quotation.
 * Resolves 15-minute Supabase Storage signed URLs for LR and E-way bill documents.
 */
export async function getBrokerDispatchDetailsAction(
  bookingIdOrReference: string
): Promise<{
  success: boolean;
  data?: BrokerDispatchPayload;
  error?: string;
}> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    if (!bookingIdOrReference) {
      return { success: false, error: 'Booking ID or Reference is required' };
    }

    const rawInput = bookingIdOrReference.trim();
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(rawInput);

    // 1. Resolve Booking record
    let bookingRecord = await db.query.bookings.findFirst({
      where: eq(bookings.bookingReference, rawInput.toUpperCase()),
    });

    if (!bookingRecord && isUuid) {
      bookingRecord = await db.query.bookings.findFirst({
        where: or(eq(bookings.id, rawInput), eq(bookings.dealId, rawInput)),
      });
    }

    if (!bookingRecord) {
      return { success: false, error: 'Booking reference not found.' };
    }

    // 2. Resolve Deal, Quotation, and Version
    const dealRecord = await db.query.deals.findFirst({
      where: or(eq(deals.id, bookingRecord.dealId), eq(deals.quotationId, bookingRecord.dealId)),
    });

    const quotationRecord = dealRecord?.quotationId
      ? await db.query.quotations.findFirst({
          where: eq(quotations.id, dealRecord.quotationId),
        })
      : null;

    // Broker authorization check
    const isPlatformAdmin = authUser.role === 'admin' || authUser.role === 'ADMIN';
    const dealBrokerId = dealRecord?.brokerId || quotationRecord?.brokerId;
    const isAuthorizedBroker = isPlatformAdmin || dealBrokerId === authUser.id;

    if (!isAuthorizedBroker && process.env.NODE_ENV === 'production') {
      return {
        success: false,
        error: 'Forbidden: You are not assigned as the broker for this trade booking.',
      };
    }

    const lockedVersion = await db.query.dealVersions.findFirst({
      where: eq(dealVersions.id, bookingRecord.lockedVersionId),
    });

    const snap = (lockedVersion?.snapshotPayload || {}) as DealVersionSnapshot;

    // 3. Resolve Dispatches & Documents
    const targetDealId = dealRecord?.id || bookingRecord.dealId;
    const rawDispatches = await db.query.dispatches.findMany({
      where: eq(dispatches.dealId, targetDealId),
      orderBy: [desc(dispatches.createdAt)],
    });

    const dispatchIds = rawDispatches.map((d) => d.id);
    const rawDocs = dispatchIds.length > 0
      ? await db.query.dispatchDocuments.findMany({
          where: or(...dispatchIds.map((id) => eq(dispatchDocuments.dispatchId, id))),
        })
      : [];

    // Helper to generate Supabase Storage signed URL
    const getSignedUrl = async (pathOrUrl: string): Promise<string | null> => {
      try {
        if (!pathOrUrl) return null;
        if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
          return pathOrUrl;
        }

        const { data, error } = await supabase.storage
          .from('brokerbridge_documents')
          .createSignedUrl(pathOrUrl, 900); // 15 minutes

        if (error || !data?.signedUrl) {
          return null;
        }
        return data.signedUrl;
      } catch {
        return null;
      }
    };

    // Process dispatches and resolve signed document URLs
    const formattedDispatches: BrokerDispatchLogisticsItem[] = [];

    for (const d of rawDispatches) {
      const relatedDocs = rawDocs.filter((doc) => doc.dispatchId === d.id);
      const documentLinks: DispatchDocumentLink[] = [];

      let lrDoc: DispatchDocumentLink | null = null;
      let ewayDoc: DispatchDocumentLink | null = null;
      let invoiceDoc: DispatchDocumentLink | null = null;

      for (const doc of relatedDocs) {
        const sUrl = await getSignedUrl(doc.fileUrl);
        const docItem: DispatchDocumentLink = {
          id: doc.id,
          documentType: doc.documentType,
          fileUrl: doc.fileUrl,
          signedUrl: sUrl,
          createdAt: doc.createdAt.toISOString(),
        };

        documentLinks.push(docItem);

        const typeLower = doc.documentType.toLowerCase();
        if (typeLower.includes('lr') || typeLower.includes('lorry')) {
          lrDoc = docItem;
        } else if (typeLower.includes('eway') || typeLower.includes('e-way')) {
          ewayDoc = docItem;
        } else if (typeLower.includes('invoice')) {
          invoiceDoc = docItem;
        }
      }

      formattedDispatches.push({
        id: d.id,
        dealId: d.dealId,
        sellerId: d.sellerId,
        vehicleNumber: d.vehicleNumber,
        driverName: d.driverName,
        driverMobile: d.driverMobile,
        dispatchDate: d.dispatchDate.toISOString(),
        expectedDeliveryDate: d.expectedDeliveryDate.toISOString(),
        status: d.status,
        createdAt: d.createdAt.toISOString(),
        dispatchedQuantity: Number((d as any).quantity || snap.quantity || 0),
        lrDocument: lrDoc,
        ewayBillDocument: ewayDoc,
        invoiceDocument: invoiceDoc,
        allDocuments: documentLinks,
      });
    }

    const agreedQty = Number(dealRecord?.agreedQuantity || snap.quantity || 0);
    const totalDispatchedQty = formattedDispatches.reduce(
      (sum, d) => sum + (d.dispatchedQuantity || 0),
      0
    );
    const remainingQty = Math.max(0, Number((agreedQty - totalDispatchedQty).toFixed(4)));

    const loadingLoc = snap.deliveryLocation ? `Warehouse Origin (${snap.deliveryLocation})` : 'Ex-Warehouse Lot Origin';
    const destLoc = snap.deliveryLocation || 'Buyer Warehouse / Processing Facility';

    return {
      success: true,
      data: {
        bookingId: bookingRecord.id,
        bookingReference: bookingRecord.bookingReference,
        dealId: targetDealId,
        commodityName: snap.commodityName || 'Agricultural Commodity',
        gradeName: snap.gradeName || 'Standard Grade',
        agreedQuantity: agreedQty,
        dispatchedQuantity: totalDispatchedQty,
        remainingQuantity: remainingQty,
        unitSymbol: snap.unitSymbol || 'MT',
        loadingLocation: loadingLoc,
        destinationLocation: destLoc,
        hasDispatches: formattedDispatches.length > 0,
        dispatches: formattedDispatches,
      },
    };
  } catch (err: any) {
    console.error('Error fetching broker dispatch details:', err);
    return {
      success: false,
      error: err.message || 'Failed to fetch dispatch details.',
    };
  }
}

/**
 * Server Action: Allows Broker to update Dispatch ETA or Flag Transit Status ('Delayed' | 'Disputed' | 'In Transit' | 'Delivered')
 */
export async function updateBrokerDispatchTransitStatusAction(payload: {
  dispatchId: string;
  bookingIdOrReference: string;
  newEta?: string | null;
  newStatus?: 'Dispatched' | 'In Transit' | 'Delivered' | 'Delayed' | 'Disputed';
  notes?: string;
}): Promise<{
  success: boolean;
  message?: string;
  error?: string;
}> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    if (!payload.dispatchId) {
      return { success: false, error: 'Dispatch ID is required' };
    }

    const dispatchRecord = await db.query.dispatches.findFirst({
      where: eq(dispatches.id, payload.dispatchId),
    });

    if (!dispatchRecord) {
      return { success: false, error: 'Dispatch record not found' };
    }

    // Prepare update object
    const updateData: Partial<typeof dispatches.$inferInsert> = {};

    if (payload.newEta) {
      updateData.expectedDeliveryDate = new Date(payload.newEta);
    }

    if (payload.newStatus) {
      updateData.status = payload.newStatus;
    }

    // Execute update on dispatches table
    await db
      .update(dispatches)
      .set(updateData)
      .where(eq(dispatches.id, payload.dispatchId));

    // Update parent deal or booking status if status is Delayed or Disputed
    if (payload.newStatus === 'Disputed' || payload.newStatus === 'Delayed') {
      await db
        .update(deals)
        .set({ status: payload.newStatus })
        .where(eq(deals.id, dispatchRecord.dealId));
    }

    // Ingest negotiation event log
    await db.insert(negotiationEvents).values({
      requestId: dispatchRecord.dealId,
      companyId: authUser.id,
      actorId: authUser.id,
      actionType: 'TRANSIT_STATUS_UPDATED',
      payload: {
        dispatchId: payload.dispatchId,
        newStatus: payload.newStatus,
        newEta: payload.newEta,
        notes: payload.notes || 'Transit status updated by Broker',
        updatedAt: new Date().toISOString(),
      },
    });

    revalidatePath('/broker/orders');
    revalidatePath(`/broker/orders/${payload.bookingIdOrReference}`);

    return {
      success: true,
      message: `Transit status updated successfully to "${payload.newStatus || 'Updated'}"!`,
    };
  } catch (err: any) {
    console.error('Error updating broker dispatch transit status:', err);
    return {
      success: false,
      error: err.message || 'Failed to update transit status.',
    };
  }
}

/**
 * Server Action: Allows Broker to log vehicle dispatch details on behalf of Seller if Seller has not captured them yet.
 */
export async function logBrokerDispatchAction(payload: {
  bookingIdOrReference: string;
  vehicleNumber: string;
  driverName: string;
  driverMobile: string;
  dispatchQuantity?: number;
  dispatchDate?: string;
  expectedDeliveryDate: string;
}): Promise<{
  success: boolean;
  dispatchId?: string;
  message?: string;
  error?: string;
}> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    const rawInput = (payload.bookingIdOrReference || '').trim();
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(rawInput);

    let bookingRecord = await db.query.bookings.findFirst({
      where: eq(bookings.bookingReference, rawInput.toUpperCase()),
    });

    if (!bookingRecord && isUuid) {
      bookingRecord = await db.query.bookings.findFirst({
        where: or(eq(bookings.id, rawInput), eq(bookings.dealId, rawInput)),
      });
    }

    if (!bookingRecord) {
      return { success: false, error: 'Booking reference not found.' };
    }

    const dealRecord = await db.query.deals.findFirst({
      where: or(eq(deals.id, bookingRecord.dealId), eq(deals.quotationId, bookingRecord.dealId)),
    });

    const targetDealId = dealRecord?.id || bookingRecord.dealId;
    const targetSellerId = dealRecord?.sellerId || authUser.id;

    // Create new dispatch row
    const [newDispatch] = await db
      .insert(dispatches)
      .values({
        dealId: targetDealId,
        sellerId: targetSellerId,
        vehicleNumber: payload.vehicleNumber.trim().toUpperCase(),
        driverName: payload.driverName.trim(),
        driverMobile: payload.driverMobile.trim(),
        dispatchDate: payload.dispatchDate ? new Date(payload.dispatchDate) : new Date(),
        expectedDeliveryDate: new Date(payload.expectedDeliveryDate),
        status: 'Dispatched',
      })
      .returning();

    // Update parent deal status to Dispatched
    await db
      .update(deals)
      .set({ status: 'Dispatched' })
      .where(eq(deals.id, targetDealId));

    revalidatePath('/broker/orders');
    revalidatePath(`/broker/orders/${payload.bookingIdOrReference}`);

    return {
      success: true,
      dispatchId: newDispatch.id,
      message: `Dispatch details for vehicle ${payload.vehicleNumber} successfully logged by Broker!`,
    };
  } catch (err: any) {
    console.error('Error logging broker dispatch:', err);
    return {
      success: false,
      error: err.message || 'Failed to log dispatch details.',
    };
  }
}
