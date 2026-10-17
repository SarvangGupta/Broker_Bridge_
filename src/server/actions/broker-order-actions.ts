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
  companies,
  users,
  masterCommodities,
  masterGrades,
} from '@/src/server/db/schema';
import { eq, or, and, desc, inArray, sql } from 'drizzle-orm';
import { DealVersionSnapshot } from '@/src/types/deal-version-schema';

export type FulfillmentStage =
  | 'Booked'
  | 'Dispatch Planned'
  | 'Dispatched'
  | 'In Transit'
  | 'Delivered'
  | 'Completed';

export type ExceptionFlag =
  | 'Delayed'
  | 'Cancelled'
  | 'Disputed'
  | 'Partially Fulfilled'
  | null;

export interface BrokerActiveOrderSummary {
  id: string; // Booking UUID or Deal UUID
  dealId: string;
  bookingId?: string;
  bookingReference: string; // 'BKG-YYYY-XXXX'
  quotationId: string;
  requirementId: string;
  versionNumber: number;
  buyerCompanyName: string;
  sellerCompanyName: string;
  commodityName: string;
  gradeName: string;
  lotNumber: string;
  agreedQuantity: number;
  dispatchedQuantity: number;
  remainingQuantity: number;
  unitSymbol: string;
  agreedPrice: number;
  totalValuation: number;
  deliveryLocation: string;
  deliveryDate?: string | null;
  paymentTerms: string;
  currentStatus: string;
  fulfillmentStage: FulfillmentStage;
  exceptionFlag: ExceptionFlag;
  createdAt: string;
  dispatchesCount: number;
  hasDispatches: boolean;
  isFullyDispatched: boolean;
}

export interface BrokerOrderDetailsPayload {
  order: BrokerActiveOrderSummary;
  deal: {
    id: string;
    agreedPrice: number;
    agreedQuantity: number;
    status: string;
    createdAt: string;
  };
  booking: {
    id: string;
    bookingReference: string;
    status: string;
    createdAt: string;
  };
  lockedVersion: {
    id: string;
    versionNumber: number;
    status: string;
    snapshot: DealVersionSnapshot;
    createdAt: string;
  };
  loadingReadiness?: {
    status: string;
    remarks?: string | null;
    capacity?: number | null;
    updatedAt?: string | null;
  } | null;
  dispatches: Array<{
    id: string;
    vehicleNumber: string;
    driverName: string;
    driverMobile: string;
    dispatchDate: string;
    expectedDeliveryDate: string;
    status: string;
    documentsCount: number;
    documents: Array<{
      id: string;
      documentType: string;
      fileUrl: string;
      createdAt: string;
    }>;
  }>;
}

/**
 * Server Action: Fetches active finalized deals & orders for the authenticated Broker (Micro-Sprint 27.2).
 *
 * STRICT ASSIGNMENT GUARDRAIL:
 * Enforces `broker_id === currentUser.id` (or broker assignment on requirement/quotation).
 */
const DEMO_BROKER_ORDERS: BrokerActiveOrderSummary[] = [
  {
    id: 'bkg-8812',
    dealId: 'deal-8812',
    bookingId: 'bkg-8812',
    bookingReference: 'BKG-2026-8812',
    quotationId: 'quot-8812',
    requirementId: 'req-8812',
    versionNumber: 2,
    buyerCompanyName: 'AgrInnovate Flour Mills',
    sellerCompanyName: 'Rajasthan Agro Trading',
    commodityName: 'Malwa Sharbati Wheat',
    gradeName: 'Grade A Milling (14% Protein)',
    lotNumber: 'LOT-2026-WHT-041',
    agreedQuantity: 100,
    dispatchedQuantity: 50,
    remainingQuantity: 50,
    unitSymbol: 'MT',
    agreedPrice: 28500,
    totalValuation: 2850000,
    deliveryLocation: 'Karnal, Haryana',
    deliveryDate: '2026-10-25',
    paymentTerms: '20% Advance, 80% on Delivery',
    currentStatus: 'Partially Dispatched',
    fulfillmentStage: 'In Transit',
    exceptionFlag: null,
    createdAt: new Date().toISOString(),
    dispatchesCount: 1,
    hasDispatches: true,
    isFullyDispatched: false,
  },
  {
    id: 'bkg-7041',
    dealId: 'deal-7041',
    bookingId: 'bkg-7041',
    bookingReference: 'BKG-2026-7041',
    quotationId: 'quot-7041',
    requirementId: 'req-7041',
    versionNumber: 3,
    buyerCompanyName: 'North Dairy Feed Corp',
    sellerCompanyName: 'Malwa Grain Exporters',
    commodityName: 'Yellow Maize (Feed Grade)',
    gradeName: 'Grade 1 High Starch',
    lotNumber: 'LOT-2026-MAZ-109',
    agreedQuantity: 250,
    dispatchedQuantity: 250,
    remainingQuantity: 0,
    unitSymbol: 'MT',
    agreedPrice: 21800,
    totalValuation: 5450000,
    deliveryLocation: 'Ludhiana, Punjab',
    deliveryDate: '2026-10-22',
    paymentTerms: '100% Escrow on Weighment Slip',
    currentStatus: 'Dispatched',
    fulfillmentStage: 'Dispatched',
    exceptionFlag: null,
    createdAt: new Date(Date.now() - 86400000 * 2).toISOString(),
    dispatchesCount: 2,
    hasDispatches: true,
    isFullyDispatched: true,
  },
  {
    id: 'bkg-6029',
    dealId: 'deal-6029',
    bookingId: 'bkg-6029',
    bookingReference: 'BKG-2026-6029',
    quotationId: 'quot-6029',
    requirementId: 'req-6029',
    versionNumber: 1,
    buyerCompanyName: 'Apex Cattle Nutrition',
    sellerCompanyName: 'Indore Agro Refineries',
    commodityName: 'Non-GMO Soybean Meal',
    gradeName: 'De-oiled Cake 48% Protein',
    lotNumber: 'LOT-2026-SOY-882',
    agreedQuantity: 75,
    dispatchedQuantity: 0,
    remainingQuantity: 75,
    unitSymbol: 'MT',
    agreedPrice: 42500,
    totalValuation: 3187500,
    deliveryLocation: 'Anand, Gujarat',
    deliveryDate: '2026-10-28',
    paymentTerms: '25% Advance, Balance on Quality Clearance',
    currentStatus: 'Confirmed',
    fulfillmentStage: 'Booked',
    exceptionFlag: null,
    createdAt: new Date(Date.now() - 86400000 * 4).toISOString(),
    dispatchesCount: 0,
    hasDispatches: false,
    isFullyDispatched: false,
  },
];

export async function getBrokerActiveOrdersAction(): Promise<{
  success: boolean;
  data?: BrokerActiveOrderSummary[];
  error?: string;
}> {
  try {
    let authUser = null;
    let authError = null;

    try {
      const supabase = await createClient();
      const res = await supabase.auth.getUser();
      authUser = res.data.user;
      authError = res.error;
    } catch (_e) {
      // Supabase unconfigured in local dev
    }

    if (authError || !authUser) {
      return { success: true, data: DEMO_BROKER_ORDERS };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User profile not found' };
    }

    const userId = authUser.id;
    const isPlatformAdmin = dbUser.role === 'admin' || dbUser.role === 'ADMIN';

    // 1. Fetch bookings joined with deals, quotations, deal_versions, availabilities
    const joinedRows = await db
      .select({
        bookingId: bookings.id,
        bookingReference: bookings.bookingReference,
        bookingStatus: bookings.status,
        bookingCreatedAt: bookings.createdAt,
        lockedVersionId: bookings.lockedVersionId,
        // Deal
        dealId: deals.id,
        dealQuotationId: deals.quotationId,
        dealRequirementId: deals.requirementId,
        dealBuyerId: deals.buyerId,
        dealSellerId: deals.sellerId,
        dealBrokerId: deals.brokerId,
        agreedPrice: deals.agreedPrice,
        agreedQuantity: deals.agreedQuantity,
        dealStatus: deals.status,
        dealCreatedAt: deals.createdAt,
        // Quotation
        quotationId: quotations.id,
        quotationBrokerId: quotations.brokerId,
        quotationRequirementId: quotations.requirementId,
        sellerAvailabilityId: quotations.sellerAvailabilityId,
        quotationStatus: quotations.status,
        // Requirement
        reqBrokerId: requirements.brokerId,
        reqCompanyId: requirements.companyId,
        // Lot
        lotNumber: availabilities.lotNumber,
        lotCompanyId: availabilities.companyId,
        // Version
        versionNumber: dealVersions.versionNumber,
        versionStatus: dealVersions.status,
        versionSnapshot: dealVersions.snapshotPayload,
      })
      .from(bookings)
      .leftJoin(deals, or(eq(bookings.dealId, deals.id), eq(bookings.dealId, deals.quotationId)))
      .leftJoin(quotations, eq(quotations.id, deals.quotationId))
      .leftJoin(requirements, eq(requirements.id, quotations.requirementId))
      .leftJoin(availabilities, eq(availabilities.id, quotations.sellerAvailabilityId))
      .leftJoin(dealVersions, eq(dealVersions.id, bookings.lockedVersionId))
      .orderBy(desc(bookings.createdAt));

    // 2. Strict Assignment Filtering: `broker_id === currentUser.id`
    const filteredRows = joinedRows.filter((r) => {
      if (isPlatformAdmin) return true;
      const isBrokerAssigned =
        r.dealBrokerId === userId ||
        r.quotationBrokerId === userId ||
        r.reqBrokerId === userId;
      return isBrokerAssigned;
    });

    if (!filteredRows.length) {
      return { success: true, data: [] };
    }

    // Collect IDs for batch subqueries
    const dealIds = Array.from(new Set(filteredRows.map((r) => r.dealId).filter(Boolean))) as string[];
    const companyIds = Array.from(
      new Set(
        filteredRows
          .flatMap((r) => [r.dealBuyerId, r.dealSellerId, r.reqCompanyId, r.lotCompanyId])
          .filter(Boolean)
      )
    ) as string[];

    // 3. Batch fetch company names and dispatches in parallel
    const [fetchedCompanies, allDispatches] = await Promise.all([
      companyIds.length > 0
        ? db.query.companies.findMany({
            where: inArray(companies.id, companyIds),
          })
        : Promise.resolve([]),
      dealIds.length > 0
        ? db.query.dispatches.findMany({
            where: inArray(dispatches.dealId, dealIds),
          })
        : Promise.resolve([]),
    ]);

    const companyMap = new Map(fetchedCompanies.map((c) => [c.id, c.name || 'Trading Enterprise']));

    const dispatchesMap = new Map<string, typeof allDispatches>();
    for (const d of allDispatches) {
      const list = dispatchesMap.get(d.dealId) || [];
      list.push(d);
      dispatchesMap.set(d.dealId, list);
    }

    // 4. Transform into structured payload
    const activeOrders: BrokerActiveOrderSummary[] = [];

    for (const r of filteredRows) {
      const snap = (r.versionSnapshot || {}) as DealVersionSnapshot;
      const targetDealId = r.dealId || r.bookingId;
      const existingDispatches = dispatchesMap.get(targetDealId) || [];

      // Calculate quantities
      const bookedQty = Number(r.agreedQuantity || snap.quantity || 0);
      const lockedRate = Number(r.agreedPrice || snap.rate || 0);
      const totalVal = bookedQty * lockedRate;

      // Dispatched calculation
      const dispatchedQty = existingDispatches.reduce(
        (sum, d) => sum + Number((d as any).quantity || 0),
        0
      );
      const remainingQty = Math.max(0, Number((bookedQty - dispatchedQty).toFixed(4)));

      // Resolve Company names (Privacy-safe display)
      const buyerName =
        companyMap.get(r.dealBuyerId || r.reqCompanyId || '') ||
        'Verified Buyer Enterprise';
      const sellerName =
        companyMap.get(r.dealSellerId || r.lotCompanyId || '') ||
        'Verified Seller Enterprise';

      // Current overall status string
      const rawStatus = r.bookingStatus || r.dealStatus || r.versionStatus || 'Booked';

      // Determine PRD v2.2 Fulfillment Stage
      let fulfillmentStage: FulfillmentStage = 'Booked';
      const statusLower = rawStatus.toLowerCase();

      if (statusLower.includes('completed') || statusLower.includes('settled')) {
        fulfillmentStage = 'Completed';
      } else if (statusLower.includes('delivered')) {
        fulfillmentStage = 'Delivered';
      } else if (statusLower.includes('transit')) {
        fulfillmentStage = 'In Transit';
      } else if (statusLower.includes('dispatch') && (existingDispatches.length > 0 || dispatchedQty > 0)) {
        fulfillmentStage = 'Dispatched';
      } else if (statusLower.includes('dispatch') || statusLower.includes('planned')) {
        fulfillmentStage = 'Dispatch Planned';
      } else {
        fulfillmentStage = 'Booked';
      }

      // Determine Exception Flag
      let exceptionFlag: ExceptionFlag = null;
      if (statusLower.includes('dispute')) {
        exceptionFlag = 'Disputed';
      } else if (statusLower.includes('cancel')) {
        exceptionFlag = 'Cancelled';
      } else if (statusLower.includes('delay')) {
        exceptionFlag = 'Delayed';
      } else if (dispatchedQty > 0 && remainingQty > 0) {
        exceptionFlag = 'Partially Fulfilled';
      }

      const destParts = [snap.deliveryLocation, snap.deliveryDistrict, snap.deliveryState].filter(Boolean);
      const destString = destParts.length > 0 ? destParts.join(', ') : 'Ex-Warehouse / Destination';

      activeOrders.push({
        id: r.bookingId,
        dealId: targetDealId,
        bookingId: r.bookingId,
        bookingReference: r.bookingReference,
        quotationId: r.quotationId || r.dealQuotationId || targetDealId,
        requirementId: r.dealRequirementId || r.quotationRequirementId || '',
        versionNumber: r.versionNumber || 1,
        buyerCompanyName: buyerName,
        sellerCompanyName: sellerName,
        commodityName: snap.commodityName || 'Agricultural Commodity',
        gradeName: snap.gradeName || 'Standard Grade',
        lotNumber: snap.lotNumber || r.lotNumber || 'N/A',
        agreedQuantity: bookedQty,
        dispatchedQuantity: dispatchedQty,
        remainingQuantity: remainingQty,
        unitSymbol: snap.unitSymbol || 'MT',
        agreedPrice: lockedRate,
        totalValuation: totalVal,
        deliveryLocation: destString,
        deliveryDate: snap.deliveryDate || null,
        paymentTerms: snap.paymentTerms || 'Broker Escrow Settlement',
        currentStatus: rawStatus,
        fulfillmentStage,
        exceptionFlag,
        createdAt: r.bookingCreatedAt.toISOString(),
        dispatchesCount: existingDispatches.length,
        hasDispatches: existingDispatches.length > 0,
        isFullyDispatched: remainingQty === 0 && bookedQty > 0,
      });
    }

    return {
      success: true,
      data: activeOrders,
    };
  } catch (err: any) {
    console.error('Error fetching broker active orders:', err);
    return {
      success: false,
      error: err.message || 'Failed to fetch broker active orders.',
    };
  }
}

/**
 * Server Action: Fetches detailed logistics & fulfillment details for a single Order/Booking.
 */
export async function getBrokerOrderDetailsAction(
  bookingIdOrReference: string
): Promise<{
  success: boolean;
  data?: BrokerOrderDetailsPayload;
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
      return { success: false, error: 'Booking record not found.' };
    }

    // 2. Resolve Deal, Version, and Availability
    const dealRecord = await db.query.deals.findFirst({
      where: or(eq(deals.id, bookingRecord.dealId), eq(deals.quotationId, bookingRecord.dealId)),
    });

    const quotationRecord = dealRecord?.quotationId
      ? await db.query.quotations.findFirst({
          where: eq(quotations.id, dealRecord.quotationId),
        })
      : null;

    const lockedVersion = await db.query.dealVersions.findFirst({
      where: eq(dealVersions.id, bookingRecord.lockedVersionId),
    });

    if (!lockedVersion) {
      return { success: false, error: 'Locked deal version snapshot not found.' };
    }

    // Resolve Lot Loading Readiness
    const availabilityLot = quotationRecord?.sellerAvailabilityId
      ? await db.query.availabilities.findFirst({
          where: eq(availabilities.id, quotationRecord.sellerAvailabilityId),
        })
      : null;

    // Resolve Dispatches & Documents
    const targetDealId = dealRecord?.id || bookingRecord.dealId;
    const dispatchList = await db.query.dispatches.findMany({
      where: eq(dispatches.dealId, targetDealId),
      orderBy: [desc(dispatches.createdAt)],
    });

    const dispatchIds = dispatchList.map((d) => d.id);
    const docs = dispatchIds.length > 0
      ? await db.query.dispatchDocuments.findMany({
          where: inArray(dispatchDocuments.dispatchId, dispatchIds),
        })
      : [];

    const docsMap = new Map<string, typeof docs>();
    for (const doc of docs) {
      const list = docsMap.get(doc.dispatchId) || [];
      list.push(doc);
      docsMap.set(doc.dispatchId, list);
    }

    // Format dispatches
    const formattedDispatches = dispatchList.map((d) => {
      const dDocs = docsMap.get(d.id) || [];
      return {
        id: d.id,
        vehicleNumber: d.vehicleNumber,
        driverName: d.driverName,
        driverMobile: d.driverMobile,
        dispatchDate: d.dispatchDate.toISOString(),
        expectedDeliveryDate: d.expectedDeliveryDate.toISOString(),
        status: d.status,
        documentsCount: dDocs.length,
        documents: dDocs.map((doc) => ({
          id: doc.id,
          documentType: doc.documentType,
          fileUrl: doc.fileUrl,
          createdAt: doc.createdAt.toISOString(),
        })),
      };
    });

    // Helper synthesis for order summary
    const snap = lockedVersion.snapshotPayload as DealVersionSnapshot;
    const bookedQty = Number(dealRecord?.agreedQuantity || snap.quantity || 0);
    const lockedRate = Number(dealRecord?.agreedPrice || snap.rate || 0);
    const totalVal = bookedQty * lockedRate;

    const dispatchedQty = formattedDispatches.length * (bookedQty / (formattedDispatches.length || 1));
    const remainingQty = Math.max(0, Number((bookedQty - dispatchedQty).toFixed(4)));

    const rawStatus = bookingRecord.status || dealRecord?.status || lockedVersion.status;
    let fulfillmentStage: FulfillmentStage = 'Booked';
    const statusLower = rawStatus.toLowerCase();

    if (statusLower.includes('completed')) fulfillmentStage = 'Completed';
    else if (statusLower.includes('delivered')) fulfillmentStage = 'Delivered';
    else if (statusLower.includes('transit')) fulfillmentStage = 'In Transit';
    else if (formattedDispatches.length > 0) fulfillmentStage = 'Dispatched';
    else if (availabilityLot?.loadingStatus === 'Ready') fulfillmentStage = 'Dispatch Planned';
    else fulfillmentStage = 'Booked';

    let exceptionFlag: ExceptionFlag = null;
    if (statusLower.includes('dispute')) exceptionFlag = 'Disputed';
    else if (statusLower.includes('cancel')) exceptionFlag = 'Cancelled';
    else if (statusLower.includes('delay')) exceptionFlag = 'Delayed';
    else if (formattedDispatches.length > 0 && remainingQty > 0) exceptionFlag = 'Partially Fulfilled';

    const orderSummary: BrokerActiveOrderSummary = {
      id: bookingRecord.id,
      dealId: targetDealId,
      bookingId: bookingRecord.id,
      bookingReference: bookingRecord.bookingReference,
      quotationId: quotationRecord?.id || targetDealId,
      requirementId: dealRecord?.requirementId || '',
      versionNumber: lockedVersion.versionNumber,
      buyerCompanyName: 'Verified Buyer Enterprise',
      sellerCompanyName: 'Verified Seller Enterprise',
      commodityName: snap.commodityName || 'Agricultural Commodity',
      gradeName: snap.gradeName || 'Standard Grade',
      lotNumber: snap.lotNumber || availabilityLot?.lotNumber || 'N/A',
      agreedQuantity: bookedQty,
      dispatchedQuantity: dispatchedQty,
      remainingQuantity: remainingQty,
      unitSymbol: snap.unitSymbol || 'MT',
      agreedPrice: lockedRate,
      totalValuation: totalVal,
      deliveryLocation: snap.deliveryLocation || 'Ex-Warehouse / Destination',
      deliveryDate: snap.deliveryDate || null,
      paymentTerms: snap.paymentTerms || 'Broker Escrow Settlement',
      currentStatus: rawStatus,
      fulfillmentStage,
      exceptionFlag,
      createdAt: bookingRecord.createdAt.toISOString(),
      dispatchesCount: formattedDispatches.length,
      hasDispatches: formattedDispatches.length > 0,
      isFullyDispatched: remainingQty === 0 && bookedQty > 0,
    };

    return {
      success: true,
      data: {
        order: orderSummary,
        deal: {
          id: targetDealId,
          agreedPrice: lockedRate,
          agreedQuantity: bookedQty,
          status: dealRecord?.status || 'Broker Finalized',
          createdAt: dealRecord?.createdAt?.toISOString() || bookingRecord.createdAt.toISOString(),
        },
        booking: {
          id: bookingRecord.id,
          bookingReference: bookingRecord.bookingReference,
          status: bookingRecord.status,
          createdAt: bookingRecord.createdAt.toISOString(),
        },
        lockedVersion: {
          id: lockedVersion.id,
          versionNumber: lockedVersion.versionNumber,
          status: lockedVersion.status,
          snapshot: snap,
          createdAt: lockedVersion.createdAt.toISOString(),
        },
        loadingReadiness: availabilityLot
          ? {
              status: availabilityLot.loadingStatus,
              remarks: availabilityLot.loadingRemarks,
              capacity: Number(availabilityLot.loadingCapacity || 0),
              updatedAt: availabilityLot.loadingUpdatedAt?.toISOString() || null,
            }
          : null,
        dispatches: formattedDispatches,
      },
    };
  } catch (err: any) {
    console.error('Error fetching broker order details:', err);
    return {
      success: false,
      error: err.message || 'Failed to fetch order details.',
    };
  }
}
