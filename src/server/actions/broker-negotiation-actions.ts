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
  companies,
  users,
} from '@/src/server/db/schema';
import { eq, and, desc, asc } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { queueNotificationAction } from '@/src/server/actions/notification-actions';
import { logDecisionGateAuditEventAction } from '@/src/server/actions/audit-actions';
import {
  sendProposalToSellerSchema,
  type SendProposalToSellerPayload,
  type SellerNegotiationDetails,
} from '@/src/types/negotiation-schema';
import { createDealVersionInTransaction } from '@/src/server/utils/version-engine';
import { sanitizePayloadForSeller } from '@/src/server/utils/privacy-scrubber';
import type { DealVersionSnapshot } from '@/src/types/deal-version-schema';

export type SendProposalResult = {
  success: boolean;
  newVersion?: number;
  message?: string;
  error?: string;
};

export type SellerNegotiationDetailsResult = {
  success: boolean;
  data?: SellerNegotiationDetails;
  error?: string;
};

/**
 * Task 1 (Micro-Sprint 25.1): Broker-to-Seller Proposal Server Action
 *
 * Authenticates broker session, executes atomic Drizzle transaction to:
 * 1. Compute next version_number (max + 1) and mark previous version as 'Superseded'.
 * 2. Insert new immutable Deal Version snapshot into deal_versions.
 * 3. Insert tracking event into negotiation_events (action_type: 'BROKER_PROPOSAL').
 * 4. Update parent broker_requests / quotations status to 'Broker Proposed'.
 * 5. Dispatch Seller in-app notification with action_url deep link.
 *
 * STRICT PRIVACY LOCK: Zero Buyer PII in payload, notification, or audit logs.
 */
export async function sendProposalToSellerAction(
  payload: SendProposalToSellerPayload
): Promise<SendProposalResult> {
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

    const brokerId = dbUser.id;

    // Validate payload with Zod preprocessing
    const validation = sendProposalToSellerSchema.safeParse(payload);
    if (!validation.success) {
      const firstErr = validation.error.errors[0]?.message || 'Invalid proposal input';
      return { success: false, error: firstErr };
    }

    const validData = validation.data;

    // Atomic Drizzle Transaction
    const transactionResult = await db.transaction(async (tx) => {
      // 1. Query parent quotation / request
      const quotation = await tx.query.quotations.findFirst({
        where: eq(quotations.id, validData.request_id),
      });

      if (!quotation) {
        throw new Error('Broker request not found or inactive');
      }

      // 2. Fetch linked Availability Lot details
      const lotRes = await tx
        .select({
          id: availabilities.id,
          companyId: availabilities.companyId,
          lotNumber: availabilities.lotNumber,
          commodityId: availabilities.commodityId,
          commodityName: masterCommodities.name,
          gradeId: availabilities.gradeId,
          gradeName: masterGrades.gradeName,
          unitId: availabilities.unitId,
          unitSymbol: masterUnits.symbol,
          unitName: masterUnits.name,
          availableQuantity: availabilities.availableQuantity,
          askingPrice: availabilities.askingPrice,
          sellerCompanyName: companies.name,
        })
        .from(availabilities)
        .innerJoin(companies, eq(availabilities.companyId, companies.id))
        .innerJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
        .innerJoin(masterGrades, eq(availabilities.gradeId, masterGrades.id))
        .innerJoin(masterUnits, eq(availabilities.unitId, masterUnits.id))
        .where(eq(availabilities.id, quotation.sellerAvailabilityId))
        .limit(1);

      if (!lotRes || lotRes.length === 0) {
        throw new Error('Seller availability lot details not found');
      }
      const lot = lotRes[0];

      // 3. Fetch Buyer Requirement details (for delivery terms fallback)
      const req = await tx.query.requirements.findFirst({
        where: eq(requirements.id, quotation.requirementId),
      });

      // Query latest deal version for fallback snapshot properties
      const existingVersions = await tx
        .select()
        .from(dealVersions)
        .where(eq(dealVersions.requestId, validData.request_id))
        .orderBy(desc(dealVersions.versionNumber));

      const latestVersionRow = existingVersions[0] || null;

      // 4. Synthesize commercial snapshot
      const unitSymbol = lot.unitSymbol || lot.unitName || 'MT';
      const cleanRemarks = validData.broker_notes || 'Broker commercial proposal to Seller.';
      const prevSnapshot: any = latestVersionRow?.snapshotPayload || {};

      const rawSnapshot: DealVersionSnapshot = {
        commodityId: lot.commodityId,
        commodityName: lot.commodityName || 'Commodity',
        gradeId: lot.gradeId,
        gradeName: lot.gradeName || 'Standard Quality',
        lotId: lot.id,
        lotNumber: lot.lotNumber || `LOT-${lot.id.slice(0, 8).toUpperCase()}`,
        quantity: validData.quantity,
        unitId: lot.unitId,
        unitSymbol: unitSymbol,
        rate: validData.offered_price,
        deliveryState: prevSnapshot.deliveryState || null,
        deliveryDistrict: prevSnapshot.deliveryDistrict || null,
        deliveryLocation: prevSnapshot.deliveryLocation || null,
        deliveryTerms: prevSnapshot.deliveryTerms || req?.deliveryTermsId || 'Ex-Warehouse / Standard Dispatch',
        deliveryDate: validData.delivery_date || prevSnapshot.deliveryDate || (req?.targetDate ? new Date(req.targetDate).toISOString().split('T')[0] : null),
        paymentTerms: validData.payment_terms || prevSnapshot.paymentTerms || 'Standard Settlement via Broker Desk',
        packagingType: validData.packaging || prevSnapshot.packagingType || 'Standard Packaging',
        qualityNotes: prevSnapshot.qualityNotes || null,
        qualityParameters: prevSnapshot.qualityParameters || null,
        remarks: cleanRemarks,
        originatorRole: 'broker',
        timestamp: new Date().toISOString(),
      };

      // PRIVACY LOCK: Sanitize snapshot payload for Seller Channel
      const snapshot = sanitizePayloadForSeller(rawSnapshot);

      // 5. Route version creation through version-engine (enforcing STALE_VERSION_DETECTED)
      const versionResult = await createDealVersionInTransaction(tx, {
        requestId: validData.request_id,
        newSnapshot: snapshot,
        actorId: brokerId,
        status: 'Proposed',
        expectedVersionNumber: validData.expected_version_number,
      });

      const nextVersionNumber = versionResult.version.versionNumber;

      // 6. Insert tracking event into negotiation_events
      await tx.insert(negotiationEvents).values({
        requestId: validData.request_id,
        companyId: lot.companyId,
        actorId: brokerId,
        actionType: 'BROKER_PROPOSAL',
        payload: sanitizePayloadForSeller({
          versionNumber: nextVersionNumber,
          offeredPrice: validData.offered_price,
          quantity: validData.quantity,
          deliveryDate: validData.delivery_date,
          paymentTerms: validData.payment_terms,
          packaging: validData.packaging,
          brokerNotes: cleanRemarks,
          originatorRole: 'broker',
        }),
      });

      // 9. Update parent broker_requests / quotations status
      await tx
        .update(quotations)
        .set({
          offeredPrice: validData.offered_price.toString(),
          counterNotes: cleanRemarks,
          status: 'Broker Proposed',
        })
        .where(eq(quotations.id, validData.request_id));

      // 10. Queue Seller In-App Notification with deep link
      const notifMsg = `Broker proposed ₹${validData.offered_price.toLocaleString('en-IN')}/${unitSymbol} for ${validData.quantity} ${unitSymbol}.`;
      await queueNotificationAction({
        userId: brokerId,
        companyId: lot.companyId,
        channel: 'IN_APP',
        eventType: 'BROKER_COUNTER',
        title: `Broker Proposal: ${lot.commodityName}`,
        message: notifMsg,
        contextReason: `Broker submitted updated proposal (v${nextVersionNumber}) for Lot ${lot.lotNumber}.`,
        actionLabel: 'Review Proposal',
        actionUrl: `/seller/requests?requestId=${validData.request_id}`,
        payload: {
          requestId: validData.request_id,
          url: `/seller/requests?requestId=${validData.request_id}`,
        },
      });

      // 11. Log Decision Gate Audit Entry
      await logDecisionGateAuditEventAction({
        actorId: brokerId,
        actorRole: 'broker',
        action: 'BROKER_REQUEST_INITIATED',
        entity: 'broker_requests',
        entityId: validData.request_id,
        metadata: {
          versionNumber: nextVersionNumber,
          offeredPrice: validData.offered_price,
          quantity: validData.quantity,
          humanReviewed: true,
        },
      });

      return {
        nextVersionNumber,
        sellerCompanyName: lot.sellerCompanyName,
      };
    });

    // Revalidate paths
    revalidatePath('/', 'layout');
    revalidatePath('/broker/work');
    revalidatePath('/broker/deals');
    revalidatePath('/seller/requests');

    return {
      success: true,
      newVersion: transactionResult.nextVersionNumber,
      message: `Proposal v${transactionResult.nextVersionNumber} successfully sent to ${transactionResult.sellerCompanyName}!`,
    };
  } catch (error: any) {
    console.error('Error in sendProposalToSellerAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to send proposal to Seller',
    };
  }
}

/**
 * Fetches Seller Negotiation details for a specific broker request.
 * Enforces strict zero-Buyer-PII scrubbing. Exposes confidential minimum price to authorized Broker.
 */
export async function getSellerNegotiationDetailsAction(
  requestId: string
): Promise<SellerNegotiationDetailsResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Active session required' };
    }

    if (!requestId) {
      return { success: false, error: 'Request ID is required' };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { success: false, error: 'Forbidden: Broker access required' };
    }

    // Query quotation joined with lot and master entities
    const rows = await db
      .select({
        requestId: quotations.id,
        requirementId: quotations.requirementId,
        sellerAvailabilityId: quotations.sellerAvailabilityId,
        offeredPrice: quotations.offeredPrice,
        status: quotations.status,
        validUntil: quotations.validUntil,
        counterNotes: quotations.counterNotes,
        createdAt: quotations.createdAt,
        // Lot & Seller info
        sellerCompanyName: companies.name,
        sellerCompanyVerified: companies.isVerified,
        lotNumber: availabilities.lotNumber,
        commodityId: availabilities.commodityId,
        commodityName: masterCommodities.name,
        gradeId: availabilities.gradeId,
        gradeName: masterGrades.gradeName,
        unitId: availabilities.unitId,
        unitSymbol: masterUnits.symbol,
        availableQuantity: availabilities.availableQuantity,
        askingPrice: availabilities.askingPrice,
        confidentialMinimumPrice: availabilities.confidentialMinimumPrice,
      })
      .from(quotations)
      .innerJoin(availabilities, eq(quotations.sellerAvailabilityId, availabilities.id))
      .innerJoin(companies, eq(availabilities.companyId, companies.id))
      .innerJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .innerJoin(masterGrades, eq(availabilities.gradeId, masterGrades.id))
      .innerJoin(masterUnits, eq(availabilities.unitId, masterUnits.id))
      .where(eq(quotations.id, requestId))
      .limit(1);

    if (!rows || rows.length === 0) {
      return { success: false, error: 'Negotiation details not found' };
    }

    const row = rows[0];

    // Fetch latest deal_version snapshot to get current proposed quantity & terms
    const versions = await db
      .select()
      .from(dealVersions)
      .where(eq(dealVersions.requestId, requestId))
      .orderBy(desc(dealVersions.versionNumber));

    const latestVer = versions[0] || null;
    const snapPayload: any = latestVer?.snapshotPayload || {};

    const req = await db.query.requirements.findFirst({
      where: eq(requirements.id, row.requirementId),
    });

    const currentVersionNumber = latestVer ? latestVer.versionNumber : 1;

    const details: SellerNegotiationDetails = {
      requestId: row.requestId,
      requirementId: row.requirementId,
      sellerAvailabilityId: row.sellerAvailabilityId,
      sellerCompanyName: row.sellerCompanyName,
      sellerCompanyVerified: !!row.sellerCompanyVerified,
      lotNumber: row.lotNumber || `LOT-${row.sellerAvailabilityId.slice(0, 8).toUpperCase()}`,
      commodityId: row.commodityId,
      commodityName: row.commodityName || 'Commodity',
      gradeId: row.gradeId,
      gradeName: row.gradeName || 'Standard Quality',
      unitId: row.unitId,
      unitSymbol: row.unitSymbol || 'MT',
      availableQuantity: Number(row.availableQuantity || 0),
      askingPrice: Number(row.askingPrice || 0),
      confidentialMinimumPrice: row.confidentialMinimumPrice ? Number(row.confidentialMinimumPrice) : null,
      offeredPrice: snapPayload.rate ? Number(snapPayload.rate) : Number(row.offeredPrice || row.askingPrice),
      proposedQuantity: snapPayload.quantity ? Number(snapPayload.quantity) : Number(req?.quantity || row.availableQuantity),
      deliveryTerms: snapPayload.deliveryTerms || req?.deliveryTermsId || 'Ex-Warehouse / Standard Dispatch',
      deliveryDate: snapPayload.deliveryDate || (req?.targetDate ? new Date(req.targetDate).toISOString().split('T')[0] : null),
      paymentTerms: snapPayload.paymentTerms || 'Standard Settlement via Broker Desk',
      packagingType: snapPayload.packagingType || 'Standard Packaging',
      currentStatus: row.status || 'Sent',
      currentVersionNumber,
      expectedVersionNumber: currentVersionNumber,
      updatedAt: latestVer ? new Date(latestVer.createdAt).toISOString() : new Date(row.createdAt).toISOString(),
    };

    return {
      success: true,
      data: details,
    };
  } catch (error: any) {
    console.error('Error in getSellerNegotiationDetailsAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch seller negotiation details',
    };
  }
}

/**
 * Task 3 (Micro-Sprint 25.3): Unified Broker Master Timeline Action
 * Retrieves unified chronological feed combining both Seller-side and Buyer-side negotiation events.
 * Strictly verifies that caller role is 'broker' or 'admin'.
 * Calculates current Margin Spread (Buyer Target / Landed Rate vs. Seller Asking / Min Floor).
 */
export async function getBrokerMasterTimelineAction(requestId: string) {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Active session required' };
    }

    if (!requestId) {
      return { success: false, error: 'Request ID is required' };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { success: false, error: 'Forbidden: Broker access required' };
    }

    // 1. Fetch quotation joined with lot and requirement
    const quotationRes = await db
      .select({
        id: quotations.id,
        requirementId: quotations.requirementId,
        sellerAvailabilityId: quotations.sellerAvailabilityId,
        offeredPrice: quotations.offeredPrice,
        status: quotations.status,
        validUntil: quotations.validUntil,
        // Lot & Seller info
        askingPrice: availabilities.askingPrice,
        confidentialMinimumPrice: availabilities.confidentialMinimumPrice,
        lotNumber: availabilities.lotNumber,
        sellerCompanyName: companies.name,
        // Requirement & Buyer info
        targetPrice: requirements.targetPrice,
        targetQuantity: requirements.quantity,
        unitSymbol: masterUnits.symbol,
        commodityName: masterCommodities.name,
      })
      .from(quotations)
      .innerJoin(availabilities, eq(quotations.sellerAvailabilityId, availabilities.id))
      .innerJoin(companies, eq(availabilities.companyId, companies.id))
      .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
      .leftJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .leftJoin(masterUnits, eq(availabilities.unitId, masterUnits.id))
      .where(eq(quotations.id, requestId))
      .limit(1);

    if (!quotationRes || quotationRes.length === 0) {
      return { success: false, error: 'Negotiation details not found' };
    }

    const q = quotationRes[0];

    // 2. Query all Deal Versions for this request
    const versions = await db
      .select({
        id: dealVersions.id,
        requestId: dealVersions.requestId,
        versionNumber: dealVersions.versionNumber,
        actorId: dealVersions.actorId,
        actorName: users.name,
        actorRole: users.role,
        status: dealVersions.status,
        snapshotPayload: dealVersions.snapshotPayload,
        createdAt: dealVersions.createdAt,
      })
      .from(dealVersions)
      .leftJoin(users, eq(dealVersions.actorId, users.id))
      .where(eq(dealVersions.requestId, requestId))
      .orderBy(asc(dealVersions.versionNumber));

    // 3. Query all Negotiation Events for this request (BOTH streams)
    const events = await db
      .select({
        id: negotiationEvents.id,
        requestId: negotiationEvents.requestId,
        companyId: negotiationEvents.companyId,
        actorId: negotiationEvents.actorId,
        actorName: users.name,
        actorRole: users.role,
        actionType: negotiationEvents.actionType,
        payload: negotiationEvents.payload,
        createdAt: negotiationEvents.createdAt,
      })
      .from(negotiationEvents)
      .leftJoin(users, eq(negotiationEvents.actorId, users.id))
      .where(eq(negotiationEvents.requestId, requestId))
      .orderBy(asc(negotiationEvents.createdAt));

    // Calculate Margin Spread
    const askingPrice = Number(q.askingPrice || 0);
    const minFloor = q.confidentialMinimumPrice ? Number(q.confidentialMinimumPrice) : askingPrice;
    const buyerTarget = Number(q.targetPrice || 0);
    const currentOffered = Number(q.offeredPrice || askingPrice);
    const grossSpread = buyerTarget > 0 ? buyerTarget - minFloor : 0;
    const currentMargin = currentOffered - askingPrice;

    const marginSpreadInfo = {
      askingPrice,
      confidentialMinimumPrice: q.confidentialMinimumPrice ? Number(q.confidentialMinimumPrice) : null,
      buyerTargetPrice: buyerTarget,
      currentOfferedPrice: currentOffered,
      grossSpread,
      currentMargin,
      unitSymbol: q.unitSymbol || 'MT',
      commodityName: q.commodityName,
      sellerCompanyName: q.sellerCompanyName,
    };

    const masterTimeline: any[] = [];

    // Map Versions
    for (const v of versions) {
      const snap: any = v.snapshotPayload || {};
      const isSeller = v.status?.toLowerCase().includes('seller') || snap.originatorRole === 'seller';
      const isBuyer = v.status?.toLowerCase().includes('buyer') || snap.originatorRole === 'buyer';

      let channel: 'seller' | 'buyer' | 'broker' = 'broker';
      if (isSeller) channel = 'seller';
      else if (isBuyer) channel = 'buyer';

      masterTimeline.push({
        id: `ver_${v.id}`,
        type: 'DEAL_VERSION',
        channel,
        versionNumber: v.versionNumber,
        title: `Deal Version ${v.versionNumber} (${v.status})`,
        status: v.status,
        actorName: v.actorName || 'Broker Desk',
        actorRole: v.actorRole || 'Broker',
        summary: `Rate: ₹${Number(snap.rate || 0).toLocaleString('en-IN')}/${snap.unitSymbol || 'MT'} • Qty: ${snap.quantity || 0} ${snap.unitSymbol || 'MT'}`,
        details: snap,
        createdAt: new Date(v.createdAt).toISOString(),
      });
    }

    // Map Events
    for (const e of events) {
      const p: any = e.payload || {};
      let channel: 'seller' | 'buyer' | 'broker' = 'broker';

      if (e.actionType?.includes('BUYER') || e.actionType?.includes('BROKER_PROPOSAL_TO_BUYER')) {
        channel = 'buyer';
      } else if (e.actionType?.includes('SELLER') || e.actionType === 'BROKER_PROPOSAL') {
        channel = 'seller';
      }

      // Format clean, human-readable action title
      let title = e.actionType;
      if (e.actionType === 'COUNTER' || p.action === 'COUNTER') {
        title = 'Counter-Offer Submitted';
      } else if (e.actionType === 'BROKER_PROPOSAL') {
        title = 'Proposal Sent to Seller';
      } else if (e.actionType === 'BROKER_PROPOSAL_TO_BUYER') {
        title = 'Landed Proposal Sent to Buyer';
      } else if (e.actionType === 'ACCEPT' || e.actionType === 'Seller Accepted' || e.actionType === 'BUYER_ACCEPTED') {
        title = 'Proposal Accepted';
      } else if (e.actionType === 'REJECT' || e.actionType === 'Seller Rejected' || e.actionType === 'BUYER_REJECTED') {
        title = 'Proposal Rejected';
      }

      // Format clean, human-readable summary text
      let summary = p.brokerNotes || p.broker_notes || p.remarks || p.counterRemarks || p.notes || '';
      if (!summary || (typeof summary === 'string' && summary.trim().startsWith('{'))) {
        const parts = [];
        const rateVal = p.counterPrice || p.offered_price || p.rate || p.offeredPrice || p.landedPrice;
        if (rateVal) {
          parts.push(`Rate: ₹${Number(rateVal).toLocaleString('en-IN')}`);
        }
        const qtyVal = p.counterQuantity || p.quantity;
        if (qtyVal) {
          parts.push(`Qty: ${qtyVal}`);
        }
        const delDate = p.counterDeliveryDate || p.delivery_date || p.deliveryDate;
        if (delDate) {
          parts.push(`Delivery: ${delDate}`);
        }

        if (parts.length > 0) {
          summary = parts.join(' • ');
        } else if (e.actionType === 'COUNTER' || p.action === 'COUNTER') {
          summary = 'Counter terms proposed.';
        } else if (e.actionType === 'ACCEPT' || e.actionType?.includes('ACCEPTED')) {
          summary = 'Commercial proposal terms accepted.';
        } else if (e.actionType === 'REJECT' || e.actionType?.includes('REJECTED')) {
          summary = p.rejectionReason ? `Reason: ${p.rejectionReason}` : 'Commercial terms rejected.';
        } else {
          summary = 'Commercial negotiation event logged.';
        }
      }

      masterTimeline.push({
        id: `evt_${e.id}`,
        type: 'NEGOTIATION_ACTION',
        channel,
        title,
        status: e.actionType,
        actorName: e.actorName || 'System',
        actorRole: e.actorRole || 'User',
        summary,
        details: p,
        createdAt: new Date(e.createdAt).toISOString(),
      });
    }

    masterTimeline.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

    return {
      success: true,
      data: {
        marginSpread: marginSpreadInfo,
        timeline: masterTimeline,
      },
    };
  } catch (error: any) {
    console.error('Error in getBrokerMasterTimelineAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch master negotiation timeline',
    };
  }
}

/**
 * Fetches all active broker negotiations assigned to the current broker.
 * Used by BrokerNegotiationsHub in the Negotiations tab.
 */
export async function getBrokerActiveNegotiationsAction() {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Active session required' };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { success: false, error: 'Forbidden: Broker access required' };
    }

    // Query active quotations / broker_requests for broker
    const rows = await db
      .select({
        requestId: quotations.id,
        requirementId: quotations.requirementId,
        sellerAvailabilityId: quotations.sellerAvailabilityId,
        offeredPrice: quotations.offeredPrice,
        status: quotations.status,
        validUntil: quotations.validUntil,
        counterNotes: quotations.counterNotes,
        createdAt: quotations.createdAt,
        // Lot & Seller Info
        sellerCompanyName: companies.name,
        sellerCompanyVerified: companies.isVerified,
        lotNumber: availabilities.lotNumber,
        commodityId: availabilities.commodityId,
        commodityName: masterCommodities.name,
        gradeName: masterGrades.gradeName,
        unitSymbol: masterUnits.symbol,
        availableQuantity: availabilities.availableQuantity,
        askingPrice: availabilities.askingPrice,
        confidentialMinimumPrice: availabilities.confidentialMinimumPrice,
      })
      .from(quotations)
      .innerJoin(availabilities, eq(quotations.sellerAvailabilityId, availabilities.id))
      .innerJoin(companies, eq(availabilities.companyId, companies.id))
      .innerJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .innerJoin(masterGrades, eq(availabilities.gradeId, masterGrades.id))
      .innerJoin(masterUnits, eq(availabilities.unitId, masterUnits.id))
      .where(eq(quotations.brokerId, dbUser.id))
      .orderBy(desc(quotations.createdAt));

    return {
      success: true,
      data: rows,
    };
  } catch (error: any) {
    console.error('Error in getBrokerActiveNegotiationsAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch broker negotiations',
    };
  }
}



