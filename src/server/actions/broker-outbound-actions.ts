'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  quotations,
  dealVersions,
  availabilities,
  requirements,
  masterCommodities,
  masterGrades,
  masterUnits,
  companies,
  users,
} from '@/src/server/db/schema';
import { eq, and } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { queueNotificationAction } from '@/src/server/actions/notification-actions';
import { logDecisionGateAuditEventAction } from '@/src/server/actions/audit-actions';
import type { DealVersionSnapshot } from '@/src/types/deal-version-schema';

export interface CreateBrokerRequestPayload {
  requirement_id: string;
  availability_id: string;
  proposed_quantity: number;
  proposed_price: number;
  delivery_date?: string | null;
  broker_message?: string | null;
}

export type OutboundRequestResponse = {
  success: boolean;
  data?: string; // requestId / quotationId
  message?: string;
  error?: string;
};

/**
 * Micro-Sprint 23.4: The Seller-Side Connection (Broker Request Trigger)
 *
 * Authenticates broker, creates commercial proposal in quotations table,
 * initializes Deal Version 1 snapshot, and dispatches Seller in-app notification.
 *
 * STRICT GUARDRAILS:
 * 1. Zero Buyer PII leakage in payload, messages, or notification text.
 * 2. Uses existing quotations / broker_requests and deal_versions tables.
 */
export async function createBrokerRequestToSellerAction(
  payload: CreateBrokerRequestPayload
): Promise<OutboundRequestResponse> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    // Verify user role & identity in database
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User not found in system' };
    }

    const role = (dbUser.role || '').toLowerCase();
    if (role !== 'broker' && role !== 'admin') {
      return { success: false, error: 'Forbidden: Broker access privileges required' };
    }

    const brokerId = dbUser.id;

    // Validate payload quantities & prices
    if (!payload.requirement_id) {
      return { success: false, error: 'Buyer Requirement ID is required.' };
    }
    if (!payload.availability_id) {
      return { success: false, error: 'Seller Availability Lot ID is required.' };
    }
    if (!payload.proposed_quantity || payload.proposed_quantity <= 0) {
      return { success: false, error: 'Proposed quantity must be greater than zero.' };
    }
    if (!payload.proposed_price || payload.proposed_price <= 0) {
      return { success: false, error: 'Proposed price must be greater than zero.' };
    }

    // 1. Fetch Seller Availability Lot details
    const lotRes = await db
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
      .where(eq(availabilities.id, payload.availability_id))
      .limit(1);

    if (!lotRes || lotRes.length === 0) {
      return { success: false, error: 'Seller availability lot not found or inactive.' };
    }
    const lot = lotRes[0];

    // 2. Fetch Buyer Requirement details
    const reqRes = await db
      .select({
        id: requirements.id,
        companyId: requirements.companyId,
        deliveryTermsId: requirements.deliveryTermsId,
        targetDate: requirements.targetDate,
        targetPrice: requirements.targetPrice,
        quantity: requirements.quantity,
      })
      .from(requirements)
      .where(eq(requirements.id, payload.requirement_id))
      .limit(1);

    if (!reqRes || reqRes.length === 0) {
      return { success: false, error: 'Buyer requirement not found or cancelled.' };
    }
    const req = reqRes[0];

    const cleanMessage = payload.broker_message?.trim() || 'Broker proposal: Commercial terms matching buyer demand.';
    const unitSymbol = lot.unitSymbol || lot.unitName || 'MT';

    // 3. Insert Quotation / Broker Request (48h expiry)
    const validUntilDate = new Date(Date.now() + 48 * 60 * 60 * 1000);
    const [insertedQuotation] = await db
      .insert(quotations)
      .values({
        requirementId: payload.requirement_id,
        brokerId: brokerId,
        sellerAvailabilityId: payload.availability_id,
        offeredPrice: payload.proposed_price.toString(),
        validUntil: validUntilDate,
        status: 'Sent',
        counterNotes: cleanMessage,
      })
      .returning();

    if (!insertedQuotation) {
      return { success: false, error: 'Failed to record broker commercial request.' };
    }

    const requestId = insertedQuotation.id;

    // 4. Initialize Version 1 Snapshot in deal_versions (PRD v3.0 Deal Versioning Engine)
    const initialSnapshot: DealVersionSnapshot = {
      commodityId: lot.commodityId,
      commodityName: lot.commodityName || 'Commodity',
      gradeId: lot.gradeId,
      gradeName: lot.gradeName || 'Standard Quality',
      lotId: lot.id,
      lotNumber: lot.lotNumber || `LOT-${lot.id.slice(0, 8).toUpperCase()}`,
      quantity: payload.proposed_quantity,
      unitId: lot.unitId,
      unitSymbol: unitSymbol,
      rate: payload.proposed_price,
      deliveryState: null,
      deliveryDistrict: null,
      deliveryLocation: null,
      deliveryTerms: req.deliveryTermsId || 'Ex-Warehouse / Standard Dispatch',
      deliveryDate: payload.delivery_date || (req.targetDate ? new Date(req.targetDate).toISOString().split('T')[0] : null),
      paymentTerms: 'Standard Settlement via Broker Desk',
      packagingType: 'Standard Packaging',
      qualityNotes: null,
      qualityParameters: null,
      remarks: cleanMessage,
      originatorRole: 'broker',
      timestamp: new Date().toISOString(),
    };

    await db.insert(dealVersions).values({
      requestId: requestId,
      versionNumber: 1,
      actorId: brokerId,
      status: 'Proposed',
      snapshotPayload: initialSnapshot,
    });

    // 5. Trigger In-App Notification with Deep Link (Seller Sprint 16.4 compatible)
    // CRITICAL PRIVACY RULE: Zero Buyer PII in notification text or payload
    const notifMessage = `Broker proposed ₹${payload.proposed_price}/${unitSymbol} for ${payload.proposed_quantity} ${unitSymbol}.`;
    await queueNotificationAction({
      userId: brokerId, // fallback actor
      companyId: lot.companyId,
      channel: 'IN_APP',
      eventType: 'NEW_BROKER_REQUEST',
      title: `New Broker Request: ${lot.commodityName}`,
      message: notifMessage,
      contextReason: notifMessage,
      actionLabel: 'Review Proposal',
      actionUrl: `/seller/requests?requestId=${requestId}`,
      payload: {
        requestId: requestId,
        url: `/seller/requests?requestId=${requestId}`,
      },
    });

    // 6. Log non-autonomous Decision Gate audit log
    await logDecisionGateAuditEventAction({
      actorId: brokerId,
      actorRole: 'broker',
      action: 'BROKER_REQUEST_INITIATED',
      entity: 'broker_requests',
      entityId: requestId,
      metadata: {
        requirementId: payload.requirement_id,
        availabilityId: payload.availability_id,
        rate: payload.proposed_price,
        quantity: payload.proposed_quantity,
        humanReviewed: true,
      },
    });

    // Revalidate paths
    revalidatePath('/', 'layout');
    revalidatePath('/broker/work');
    revalidatePath('/broker/deals');
    revalidatePath('/seller/requests');
    revalidatePath('/seller');

    return {
      success: true,
      data: requestId,
      message: `Commercial proposal successfully sent to ${lot.sellerCompanyName}!`,
    };
  } catch (error: any) {
    console.error('Error in createBrokerRequestToSellerAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to dispatch commercial request to seller',
    };
  }
}
