'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  requirements,
  quotations,
  dealVersions,
  negotiationEvents,
  masterCommodities,
  masterGrades,
  masterUnits,
  companies,
  users,
} from '@/src/server/db/schema';
import { eq, and, desc, asc, inArray } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { queueNotificationAction } from '@/src/server/actions/notification-actions';
import { logDecisionGateAuditEventAction } from '@/src/server/actions/audit-actions';
import {
  sendProposalToBuyerSchema,
  type SendProposalToBuyerPayload,
  type BuyerNegotiationDetails,
} from '@/src/types/buyer-negotiation-schema';
import { createDealVersionInTransaction } from '@/src/server/utils/version-engine';
import { sanitizePayloadForBuyer } from '@/src/server/utils/privacy-scrubber';
import type { DealVersionSnapshot, NegotiationTimelineItem } from '@/src/types/deal-version-schema';

export type SendBuyerProposalResult = {
  success: boolean;
  newVersion?: number;
  message?: string;
  error?: string;
};

export type BuyerNegotiationDetailsResult = {
  success: boolean;
  data?: BuyerNegotiationDetails;
  error?: string;
};

/**
 * Task 1 (Micro-Sprint 25.2): Broker-to-Buyer Proposal Server Action
 *
 * Authenticates broker session, executes atomic Drizzle transaction to:
 * 1. Calculate next version_number (max + 1) and mark previous version as 'Superseded'.
 * 2. Insert new immutable Deal Version snapshot into deal_versions.
 * 3. Insert tracking event into negotiation_events (action_type: 'BROKER_PROPOSAL_TO_BUYER').
 * 4. Update requirement / request status to 'Proposed to Buyer'.
 * 5. Dispatch Buyer in-app notification.
 *
 * STRICT PRIVACY LOCK: Seller identity, seller company name, confidential minimum price,
 * and exact warehouse location are MATHEMATICALLY EXCLUDED.
 */
async function getAuthenticatedBrokerUser(authToken?: string) {
  let authUser = null;
  let authError = null;

  if (authToken) {
    try {
      const { createClient: createSupabaseClient } = await import('@supabase/supabase-js');
      const supabase = createSupabaseClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      );
      const { data, error } = await supabase.auth.getUser(authToken);
      authUser = data?.user;
      authError = error;
    } catch (e: any) {
      authError = e;
    }
  } else {
    try {
      const supabase = await createClient();
      const { data, error } = await supabase.auth.getUser();
      authUser = data?.user;
      authError = error;
    } catch (e: any) {
      authError = e;
    }
  }

  if (authError || !authUser) {
    return { success: false as const, error: 'Unauthorized: Valid broker session required' };
  }

  const dbUser = await db.query.users.findFirst({
    where: eq(users.id, authUser.id),
  });

  if (!dbUser) {
    return { success: false as const, error: 'User profile not found' };
  }

  const role = (dbUser.role || '').toLowerCase();
  if (role !== 'broker' && role !== 'admin') {
    return { success: false as const, error: 'Forbidden: Broker access privileges required' };
  }

  return { success: true as const, dbUser };
}

export async function sendProposalToBuyerAction(
  payload: SendProposalToBuyerPayload,
  authToken?: string
): Promise<SendBuyerProposalResult> {
  try {
    const auth = await getAuthenticatedBrokerUser(authToken);
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    const brokerId = auth.dbUser.id;

    // Validate payload with Zod
    const validation = sendProposalToBuyerSchema.safeParse(payload);
    if (!validation.success) {
      const firstErr = validation.error.errors[0]?.message || 'Invalid buyer proposal input';
      return { success: false, error: firstErr };
    }

    const validData = validation.data;

    // Atomic Drizzle Transaction
    const transactionResult = await db.transaction(async (tx) => {
      // 1. Query Buyer Requirement details
      const reqRes = await tx
        .select({
          id: requirements.id,
          companyId: requirements.companyId,
          commodityId: requirements.commodityId,
          commodityName: masterCommodities.name,
          gradeId: requirements.gradeId,
          gradeName: masterGrades.gradeName,
          unitId: requirements.unitId,
          unitSymbol: masterUnits.symbol,
          unitName: masterUnits.name,
          quantity: requirements.quantity,
          targetPrice: requirements.targetPrice,
          targetDate: requirements.targetDate,
          deliveryTermsId: requirements.deliveryTermsId,
          buyerCompanyName: companies.name,
        })
        .from(requirements)
        .innerJoin(companies, eq(requirements.companyId, companies.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .innerJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
        .innerJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
        .where(eq(requirements.id, validData.requirement_id))
        .limit(1);

      if (!reqRes || reqRes.length === 0) {
        throw new Error('Buyer requirement not found or inactive');
      }
      const req = reqRes[0];

      // 2. Resolve or query associated quotation / request ID
      let targetRequestId = validData.request_id || null;

      if (!targetRequestId) {
        const quotationRow = await tx.query.quotations.findFirst({
          where: eq(quotations.requirementId, validData.requirement_id),
          orderBy: desc(quotations.createdAt),
        });
        if (quotationRow) {
          targetRequestId = quotationRow.id;
        } else {
          // Use requirement ID as fallback request key for buyer-broker channel
          targetRequestId = validData.requirement_id;
        }
      }

      // Query latest deal version for fallback snapshot properties
      const existingVersions = await tx
        .select()
        .from(dealVersions)
        .where(eq(dealVersions.requestId, targetRequestId))
        .orderBy(desc(dealVersions.versionNumber));

      const latestVersionRow = existingVersions[0] || null;

      // 3. Synthesize Buyer-facing commercial snapshot (LANDED PRICE with Broker Margin)
      // PRIVACY LOCK: Exclude Seller company name, seller min floor, seller lot number, exact warehouse location
      const unitSymbol = req.unitSymbol || req.unitName || 'MT';
      const cleanRemarks = validData.broker_notes || 'Broker commercial proposal to Buyer.';
      const prevSnapshot: any = latestVersionRow?.snapshotPayload || {};

      const rawSnapshot: DealVersionSnapshot = {
        commodityId: req.commodityId,
        commodityName: req.commodityName || 'Commodity',
        gradeId: req.gradeId,
        gradeName: req.gradeName || 'Standard Quality',
        quantity: validData.quantity,
        unitId: req.unitId,
        unitSymbol: unitSymbol,
        rate: validData.offered_price, // Landed price for Buyer
        deliveryState: prevSnapshot.deliveryState || null,
        deliveryDistrict: prevSnapshot.deliveryDistrict || null,
        deliveryLocation: null, // Scrubbed exact warehouse
        deliveryTerms: validData.delivery_date ? `Delivery by ${validData.delivery_date}` : req.deliveryTermsId || 'Standard Destination Delivery',
        deliveryDate: validData.delivery_date || prevSnapshot.deliveryDate || (req.targetDate ? new Date(req.targetDate).toISOString().split('T')[0] : null),
        paymentTerms: validData.payment_terms || prevSnapshot.paymentTerms || 'Standard Escrow via Broker Desk',
        packagingType: validData.packaging || prevSnapshot.packagingType || 'Standard Packaging',
        qualityNotes: prevSnapshot.qualityNotes || null,
        qualityParameters: prevSnapshot.qualityParameters || null,
        remarks: cleanRemarks,
        originatorRole: 'broker',
        timestamp: new Date().toISOString(),
      };

      // PRIVACY LOCK: Sanitize snapshot payload for Buyer Channel
      const snapshot = sanitizePayloadForBuyer(rawSnapshot);

      // 4. Route version creation through version-engine (enforcing STALE_VERSION_DETECTED)
      const versionResult = await createDealVersionInTransaction(tx, {
        requestId: targetRequestId,
        newSnapshot: snapshot,
        actorId: brokerId,
        status: 'Proposed to Buyer',
        expectedVersionNumber: validData.expected_version_number,
      });

      const nextVersionNumber = versionResult.version.versionNumber;

      // 5. Insert tracking event into negotiation_events
      await tx.insert(negotiationEvents).values({
        requestId: targetRequestId,
        companyId: req.companyId,
        actorId: brokerId,
        actionType: 'BROKER_PROPOSAL_TO_BUYER',
        payload: sanitizePayloadForBuyer({
          versionNumber: nextVersionNumber,
          landedPrice: validData.offered_price,
          quantity: validData.quantity,
          deliveryDate: validData.delivery_date,
          paymentTerms: validData.payment_terms,
          packaging: validData.packaging,
          brokerNotes: cleanRemarks,
          originatorRole: 'broker',
        }),
      });

      // 8. Update requirement status
      await tx
        .update(requirements)
        .set({
          status: 'Proposed to Buyer',
        })
        .where(eq(requirements.id, validData.requirement_id));

      if (quotationRow) {
        await tx
          .update(quotations)
          .set({
            offeredPrice: validData.offered_price.toString(),
            status: 'Sent',
            counterNotes: cleanRemarks,
          })
          .where(eq(quotations.id, quotationRow.id));
      }

      // 9. Queue Buyer In-App Notification with deep link
      const notifMsg = `Broker proposed ₹${validData.offered_price.toLocaleString('en-IN')}/${unitSymbol} for ${validData.quantity} ${unitSymbol}.`;
      await queueNotificationAction({
        userId: brokerId,
        companyId: req.companyId,
        channel: 'IN_APP',
        eventType: 'DEAL_VERSION_UPDATE',
        title: `Commercial Proposal: ${req.commodityName}`,
        message: notifMsg,
        contextReason: `Broker submitted landed proposal (v${nextVersionNumber}) for Requirement #${req.id.slice(0, 8)}.`,
        actionLabel: 'Review Proposal',
        actionUrl: `/buyer/requirements`,
        payload: {
          requirementId: req.id,
          url: `/buyer/requirements`,
        },
      });

      // 10. Log Decision Gate Audit Entry
      await logDecisionGateAuditEventAction({
        actorId: brokerId,
        actorRole: 'broker',
        action: 'BROKER_REQUEST_INITIATED',
        entity: 'broker_requests',
        entityId: req.id,
        metadata: {
          versionNumber: nextVersionNumber,
          landedPrice: validData.offered_price,
          quantity: validData.quantity,
          humanReviewed: true,
          targetParty: 'buyer',
        },
      });

      return {
        nextVersionNumber,
        buyerCompanyName: req.buyerCompanyName,
      };
    });

    // Revalidate paths safely
    try {
      revalidatePath('/', 'layout');
      revalidatePath('/broker/work');
      revalidatePath('/broker/deals');
      revalidatePath('/buyer');
    } catch (_) {}

    return {
      success: true,
      newVersion: transactionResult.nextVersionNumber,
      message: `Proposal v${transactionResult.nextVersionNumber} successfully sent to Buyer (${transactionResult.buyerCompanyName})!`,
    };
  } catch (error: any) {
    console.error('Error in sendProposalToBuyerAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to send proposal to Buyer',
    };
  }
}

/**
 * Fetches Buyer Negotiation details for a specific buyer requirement.
 * Enforces strict PRIVACY LOCK: Seller identity, confidential min price, and exact lot location ARE EXCLUDED.
 */
export async function getBuyerNegotiationDetailsAction(
  requirementId: string,
  authToken?: string
): Promise<BuyerNegotiationDetailsResult> {
  try {
    const auth = await getAuthenticatedBrokerUser(authToken);
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    if (!requirementId) {
      return { success: false, error: 'Requirement ID is required' };
    }

    // Query requirement joined with buyer company and master tables
    const rows = await db
      .select({
        requirementId: requirements.id,
        buyerCompanyName: companies.name,
        buyerCompanyVerified: companies.isVerified,
        commodityId: requirements.commodityId,
        commodityName: masterCommodities.name,
        gradeId: requirements.gradeId,
        gradeName: masterGrades.gradeName,
        unitId: requirements.unitId,
        unitSymbol: masterUnits.symbol,
        targetQuantity: requirements.quantity,
        targetPrice: requirements.targetPrice,
        targetDate: requirements.targetDate,
        deliveryTermsId: requirements.deliveryTermsId,
        status: requirements.status,
        createdAt: requirements.createdAt,
      })
      .from(requirements)
      .innerJoin(companies, eq(requirements.companyId, companies.id))
      .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .innerJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
      .innerJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
      .where(eq(requirements.id, requirementId))
      .limit(1);

    if (!rows || rows.length === 0) {
      return { success: false, error: 'Buyer requirement details not found' };
    }

    const row = rows[0];

    // Find linked quotation (if any)
    const quotationRow = await db.query.quotations.findFirst({
      where: eq(quotations.requirementId, requirementId),
      orderBy: desc(quotations.createdAt),
    });

    const targetRequestId = quotationRow ? quotationRow.id : requirementId;

    // Fetch latest deal_version for buyer channel
    const versions = await db
      .select()
      .from(dealVersions)
      .where(eq(dealVersions.requestId, targetRequestId))
      .orderBy(desc(dealVersions.versionNumber));

    const latestVer = versions[0] || null;
    const snapPayload: any = latestVer?.snapshotPayload || {};

    const currentVersionNumber = latestVer ? latestVer.versionNumber : 1;

    const details: BuyerNegotiationDetails = {
      requirementId: row.requirementId,
      requestId: quotationRow ? quotationRow.id : null,
      buyerCompanyName: row.buyerCompanyName,
      buyerCompanyVerified: !!row.buyerCompanyVerified,
      commodityId: row.commodityId,
      commodityName: row.commodityName || 'Commodity',
      gradeId: row.gradeId,
      gradeName: row.gradeName || 'Standard Quality',
      unitId: row.unitId,
      unitSymbol: row.unitSymbol || 'MT',
      targetQuantity: Number(row.targetQuantity || 0),
      targetPrice: Number(row.targetPrice || 0),
      offeredPrice: snapPayload.rate ? Number(snapPayload.rate) : Number(row.targetPrice || 0),
      proposedQuantity: snapPayload.quantity ? Number(snapPayload.quantity) : Number(row.targetQuantity || 0),
      deliveryTerms: snapPayload.deliveryTerms || row.deliveryTermsId || 'Standard Destination Delivery',
      deliveryDate: snapPayload.deliveryDate || (row.targetDate ? new Date(row.targetDate).toISOString().split('T')[0] : null),
      paymentTerms: snapPayload.paymentTerms || 'Standard Escrow Settlement via Broker Desk',
      packagingType: snapPayload.packagingType || 'Standard Packaging',
      currentStatus: row.status || 'Active',
      currentVersionNumber,
      expectedVersionNumber: currentVersionNumber,
      updatedAt: latestVer ? new Date(latestVer.createdAt).toISOString() : new Date(row.createdAt).toISOString(),
    };

    return {
      success: true,
      data: details,
    };
  } catch (error: any) {
    console.error('Error in getBuyerNegotiationDetailsAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch buyer negotiation details',
    };
  }
}

/**
 * Task 3 (Micro-Sprint 25.2): Read-Only Buyer Channel History
 *
 * Retrieves historical negotiation_events strictly tied to Broker ↔ Buyer interaction.
 * Excludes all Seller-side events and seller confidential min price / lot location.
 */
export async function getBuyerNegotiationTimelineAction(
  requirementId: string,
  authToken?: string
): Promise<{ success: boolean; data?: NegotiationTimelineItem[]; error?: string }> {
  try {
    const auth = await getAuthenticatedBrokerUser(authToken);
    if (!auth.success) {
      return { success: false, error: auth.error };
    }

    if (!requirementId) {
      return { success: false, error: 'Requirement ID is required' };
    }

    // Resolve target request ID
    const quotationRow = await db.query.quotations.findFirst({
      where: eq(quotations.requirementId, requirementId),
      orderBy: desc(quotations.createdAt),
    });

    const targetRequestId = quotationRow ? quotationRow.id : requirementId;

    // Query deal versions for this requirement
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
      .where(eq(dealVersions.requestId, targetRequestId))
      .orderBy(asc(dealVersions.versionNumber));

    // Query buyer negotiation events strictly
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
      .where(
        and(
          eq(negotiationEvents.requestId, targetRequestId),
          inArray(negotiationEvents.actionType, [
            'BROKER_PROPOSAL_TO_BUYER',
            'BUYER_COUNTER',
            'BUYER_ACCEPTED',
            'BUYER_REJECTED',
          ])
        )
      )
      .orderBy(asc(negotiationEvents.createdAt));

    const timeline: NegotiationTimelineItem[] = [];

    // Map Deal Versions for Buyer Channel
    for (const v of versions) {
      const snap: any = v.snapshotPayload || {};
      const isBuyerActor = v.actorRole?.includes('buyer');
      const actorRoleDisplay = isBuyerActor ? 'Buyer' : 'Broker Desk';
      const actorNameDisplay = isBuyerActor ? 'Buyer' : 'Broker Desk';

      // PRIVACY LOCK: Exclude seller company name, seller min floor, exact seller lot location
      delete snap.sellerCompanyName;
      delete snap.confidentialMinimumPrice;
      delete snap.deliveryLocation;

      let summaryText = `Landed Rate: ₹${Number(snap.rate || 0).toLocaleString('en-IN')}/${snap.unitSymbol || 'MT'} • Qty: ${snap.quantity || 0} ${snap.unitSymbol || 'MT'}`;
      if (snap.deliveryTerms) summaryText += ` • ${snap.deliveryTerms}`;
      if (snap.deliveryDate) summaryText += ` • Delivery: ${snap.deliveryDate}`;

      timeline.push({
        id: `buyer_ver_${v.id}`,
        requestId: v.requestId,
        type: 'DEAL_VERSION',
        title: `Buyer Proposal Version ${v.versionNumber} (${v.status})`,
        status: v.status,
        actorName: actorNameDisplay,
        actorRole: actorRoleDisplay as any,
        isSeller: false,
        versionNumber: v.versionNumber,
        summary: summaryText,
        details: {
          rate: snap.rate,
          quantity: snap.quantity,
          unitSymbol: snap.unitSymbol,
          deliveryTerms: snap.deliveryTerms,
          deliveryDate: snap.deliveryDate,
          paymentTerms: snap.paymentTerms,
          packagingType: snap.packagingType,
          remarks: snap.remarks,
        },
        createdAt: new Date(v.createdAt).toISOString(),
      });
    }

    // Map Buyer Negotiation Events
    for (const e of events) {
      const p: any = e.payload || {};
      const isBuyerActor = e.actorRole?.includes('buyer');
      const actorRoleDisplay = isBuyerActor ? 'Buyer' : 'Broker';
      const actorNameDisplay = isBuyerActor ? 'Buyer' : 'Broker Desk';

      let title = 'Buyer Negotiation Update';
      let summary = '';

      if (e.actionType === 'BUYER_ACCEPTED') {
        title = 'Buyer Accepted Proposal';
        summary = `Buyer accepted landed proposal terms. Confirmation pending.`;
      } else if (e.actionType === 'BUYER_REJECTED') {
        title = 'Buyer Rejected Proposal';
        summary = `Reason: ${p.rejectionReason || 'Target terms not acceptable'}`;
      } else if (e.actionType === 'BUYER_COUNTER') {
        title = 'Buyer Counter-Offer Received';
        const parts = [];
        if (p.counterPrice) parts.push(`Target Rate: ₹${Number(p.counterPrice).toLocaleString('en-IN')}`);
        if (p.counterQuantity) parts.push(`Qty: ${p.counterQuantity}`);
        if (p.counterRemarks) parts.push(`Notes: ${p.counterRemarks}`);
        summary = parts.join(' • ') || 'Counter-terms proposed by Buyer.';
      } else if (e.actionType === 'BROKER_PROPOSAL_TO_BUYER') {
        title = 'Broker Landed Proposal Dispatched';
        summary = `Offered Landed Rate: ₹${Number(p.landedPrice || 0).toLocaleString('en-IN')} • Qty: ${p.quantity || 0}`;
      }

      timeline.push({
        id: `buyer_evt_${e.id}`,
        requestId: e.requestId,
        type: 'NEGOTIATION_ACTION',
        title,
        status: e.actionType,
        actorName: actorNameDisplay,
        actorRole: actorRoleDisplay as any,
        isSeller: false,
        summary,
        details: p,
        createdAt: new Date(e.createdAt).toISOString(),
      });
    }

    // Sort chronologically ascending
    timeline.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

    return {
      success: true,
      data: timeline,
    };
  } catch (error: any) {
    console.error('Error in getBuyerNegotiationTimelineAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch buyer negotiation timeline',
    };
  }
}
