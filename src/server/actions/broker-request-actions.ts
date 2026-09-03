"use server";

import { db } from "@/src/server/db";
import {
  quotations,
  availabilities,
  requirements,
  masterCommodities,
  masterCategories,
  masterIndustries,
  masterGrades,
  masterUnits,
  masterStates,
  masterDistricts,
  users,
  companies,
} from "@/src/server/db/schema";
import {
  brokerResponseSchema,
  BrokerResponsePayload,
  SellerBrokerRequestItem,
} from "@/src/types/broker-request-schema";
import { eq, and, desc, inArray, sql, aliasedTable } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { verifySellerSession } from "@/src/server/utils/seller-auth";
import { queueNotificationAction } from "@/src/server/actions/notification-actions";
import { logDecisionGateAuditEventAction } from "@/src/server/actions/audit-actions";
import { createClient } from "@/lib/supabase/server";

export type BrokerActionResponse<T = any> = {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
};

/**
 * Fetches broker-originated commercial proposals/requests for the authenticated Seller company.
 * 
 * HARD PRIVACY RULE:
 * Strips all Buyer private identity (phone, email, WhatsApp, GST, company name).
 * Returns only operational, commercial, and delivery specifications + Verified Broker Attribution.
 */
export async function getSellerBrokerRequestsAction(
  statusFilter?: string
): Promise<BrokerActionResponse<SellerBrokerRequestItem[]>> {
  try {
    const session = await verifySellerSession({ allowViewer: true });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const sellerCompanyId = session.data.companyId;
    const brokerCompanies = aliasedTable(companies, "broker_companies");

    // Join quotations with the owning seller's availabilities and requirement specs
    const query = db
      .select({
        id: quotations.id,
        requirementId: quotations.requirementId,
        sellerAvailabilityId: quotations.sellerAvailabilityId,
        offeredPrice: quotations.offeredPrice,
        status: quotations.status,
        validUntil: quotations.validUntil,
        createdAt: quotations.createdAt,
        rejectionReason: quotations.rejectionReason,
        counterPrice: quotations.counterPrice,
        counterNotes: quotations.counterNotes,
        // Lot / Availability specs
        lotNumber: availabilities.lotNumber,
        askingPrice: availabilities.askingPrice,
        commodityName: masterCommodities.name,
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
        gradeName: masterGrades.gradeName,
        unitSymbol: masterUnits.symbol,
        // Requirement specs (Requested terms from Broker)
        requestedQuantity: requirements.quantity,
        targetDate: requirements.targetDate,
        deliveryTermsId: requirements.deliveryTermsId,
        // Broker info (Broker name + firm name is safe; zero buyer contact info)
        brokerName: users.name,
        brokerCompanyName: brokerCompanies.name,
        isBrokerCompanyVerified: brokerCompanies.isVerified,
      })
      .from(quotations)
      .innerJoin(availabilities, eq(quotations.sellerAvailabilityId, availabilities.id))
      .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
      .leftJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
      .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
      .leftJoin(masterGrades, eq(availabilities.gradeId, masterGrades.id))
      .leftJoin(masterUnits, eq(availabilities.unitId, masterUnits.id))
      .leftJoin(users, eq(quotations.brokerId, users.id))
      .leftJoin(brokerCompanies, eq(users.companyId, brokerCompanies.id))
      .where(eq(availabilities.companyId, sellerCompanyId))
      .orderBy(desc(quotations.createdAt));

    const rows = await query;

    // Normalize & sanitize into strict Seller-Safe items
    const now = new Date();
    const items: SellerBrokerRequestItem[] = rows.map((r) => {
      const isExpired = new Date(r.validUntil) < now && (r.status === 'Sent' || r.status === 'Pending');
      let effectiveStatus = (isExpired ? 'Expired' : r.status) as SellerBrokerRequestItem['status'];

      return {
        id: r.id,
        requirementId: r.requirementId,
        sellerAvailabilityId: r.sellerAvailabilityId,
        commodityName: r.commodityName || 'Commodity',
        categoryName: r.categoryName || null,
        industryName: r.industryName || null,
        gradeName: r.gradeName || 'Standard Grade',
        lotNumber: r.lotNumber || null,
        requestedQuantity: Number(r.requestedQuantity || 0),
        unitSymbol: r.unitSymbol || 'MT',
        proposedRate: Number(r.offeredPrice || 0),
        askingPrice: r.askingPrice ? Number(r.askingPrice) : null,
        deliveryTerms: r.deliveryTermsId || 'Ex-Warehouse / Standard Dispatch',
        paymentTerms: 'Standard Escrow Settlement via Broker Desk',
        targetDate: r.targetDate,
        brokerNotes: r.counterNotes || null,
        brokerName: r.brokerName || 'Assigned Broker Desk',
        brokerCompany: r.brokerCompanyName || 'BrokerBridge Institutional Partner',
        isBrokerVerified: r.isBrokerCompanyVerified ?? true,
        status: effectiveStatus,
        expiresAt: r.validUntil,
        createdAt: r.createdAt,
        counterPrice: r.counterPrice ? Number(r.counterPrice) : null,
        counterNotes: r.counterNotes || null,
        rejectionReason: r.rejectionReason || null,
      };
    });

    if (statusFilter && statusFilter !== 'all') {
      const filtered = items.filter((item) => {
        if (statusFilter === 'pending') {
          return item.status === 'Pending' || item.status === 'Sent';
        }
        if (statusFilter === 'accepted') {
          return item.status === 'Seller Accepted' || item.status === 'Accepted';
        }
        if (statusFilter === 'rejected') {
          return item.status === 'Seller Rejected' || item.status === 'Rejected';
        }
        if (statusFilter === 'countered') {
          return item.status === 'Seller Countered' || item.status === 'Countered';
        }
        if (statusFilter === 'expired') {
          return item.status === 'Expired';
        }
        return true;
      });
      return { success: true, data: filtered };
    }

    return { success: true, data: items };
  } catch (error: any) {
    console.error("Failed to fetch seller broker requests:", error);
    return { success: false, error: error.message || "Failed to fetch broker requests" };
  }
}

/**
 * Responds to a broker-originated commercial proposal (Accept / Reject / Counter).
 * Enforces company boundary and permission checks.
 */
export async function respondToBrokerRequestAction(
  data: unknown
): Promise<BrokerActionResponse> {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized: Mutation privileges required." };
    }

    // Validate payload against schema
    const validation = brokerResponseSchema.safeParse(data);
    if (!validation.success) {
      const firstError = validation.error.errors[0]?.message || "Invalid response payload";
      return { success: false, error: firstError };
    }

    const payload = validation.data;

    // Verify ownership of the target request/quotation
    const quotation = await db.query.quotations.findFirst({
      where: eq(quotations.id, payload.requestId),
    });

    if (!quotation) {
      return { success: false, error: "Broker request not found." };
    }

    // Check if the availability lot belongs to this seller's company
    const linkedLot = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, quotation.sellerAvailabilityId),
    });

    if (!linkedLot || linkedLot.companyId !== session.data.companyId) {
      return { success: false, error: "Unauthorized: You do not have permission to respond to this request." };
    }

    // Check if quotation is expired
    if (new Date(quotation.validUntil) < new Date()) {
      return { success: false, error: "This broker proposal has expired and can no longer be modified." };
    }

    // Check if already finalized or closed
    if (quotation.status === 'Seller Accepted' || quotation.status === 'Accepted') {
      return { success: false, error: "This request has already been accepted." };
    }

    // Log Decision Gate Audit Event
    await logDecisionGateAuditEventAction({
      action: "SELLER_PROPOSAL_ACTION",
      actorId: session.data.user.id,
      actorRole: "seller",
      entity: "quotations",
      entityId: payload.requestId,
      metadata: {
        action: payload.action,
        sellerCompanyId: session.data.companyId,
        counterPrice: payload.counterPrice,
        rejectionReason: payload.rejectionReason,
        humanReviewed: true,
      },
    });

    if (payload.action === 'accept') {
      await db
        .update(quotations)
        .set({
          status: 'Seller Accepted',
        })
        .where(eq(quotations.id, payload.requestId));

      revalidatePath('/seller');
      revalidatePath('/seller/requests');
      revalidatePath('/', 'layout');

      return {
        success: true,
        message: "Broker proposal accepted. The Broker has been notified to proceed with deal finalization.",
      };
    }

    if (payload.action === 'reject') {
      await db
        .update(quotations)
        .set({
          status: 'Seller Rejected',
          rejectionReason: payload.rejectionReason,
        })
        .where(eq(quotations.id, payload.requestId));

      revalidatePath('/seller');
      revalidatePath('/seller/requests');
      revalidatePath('/', 'layout');

      return {
        success: true,
        message: "Broker proposal rejected with documented reason.",
      };
    }

    if (payload.action === 'counter') {
      const notesParts = [];
      if (payload.counterRemarks) notesParts.push(payload.counterRemarks);
      if (payload.counterQuantity) notesParts.push(`Requested Qty: ${payload.counterQuantity}`);
      if (payload.counterDeliveryDate) notesParts.push(`Expected Date: ${payload.counterDeliveryDate}`);

      await db
        .update(quotations)
        .set({
          status: 'Seller Countered',
          counterPrice: payload.counterPrice ? payload.counterPrice.toString() : quotation.offeredPrice,
          counterNotes: notesParts.join(" | ") || "Seller submitted counter-terms",
        })
        .where(eq(quotations.id, payload.requestId));

      revalidatePath('/seller');
      revalidatePath('/seller/requests');
      revalidatePath('/', 'layout');

      return {
        success: true,
        message: "Counter-proposal submitted to Broker for negotiation review.",
      };
    }

    return { success: false, error: "Invalid action." };
  } catch (error: any) {
    console.error("Failed to respond to broker request:", error);
    return { success: false, error: error.message || "Failed to process response" };
  }
}

/**
 * Initiates a Broker Commercial Proposal to a Seller based on an AI Match Recommendation.
 * 
 * STRICT PROVENANCE ENFORCEMENT (Phase 1):
 * Must be executed by an authenticated human Broker session.
 * Explicitly rejects any unauthenticated, automated background, or AI-autonomous invocation.
 */
export async function initiateBrokerRequestFromAiMatchAction(params: {
  requirementId: string;
  sellerAvailabilityId: string;
  offeredPrice: number;
  matchScore?: number;
  brokerNotes?: string;
  validityHours?: number;
}): Promise<BrokerActionResponse> {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return { 
        success: false, 
        error: "AI autonomous action prohibited. Only an authorized Broker can initiate commercial proposals." 
      };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { 
        success: false, 
        error: "AI autonomous action prohibited. Only an authorized Broker can initiate commercial proposals." 
      };
    }

    const validityHours = params.validityHours || 48;
    const validUntil = new Date(Date.now() + validityHours * 60 * 60 * 1000);

    const inserted = await db.insert(quotations).values({
      requirementId: params.requirementId,
      brokerId: user.id,
      sellerAvailabilityId: params.sellerAvailabilityId,
      offeredPrice: params.offeredPrice.toString(),
      validUntil,
      status: 'Sent',
      counterNotes: params.brokerNotes || "Broker curated proposal based on AI recommendation parameters.",
    }).returning();

    // Log Non-Autonomous Audit Event
    await logDecisionGateAuditEventAction({
      action: "BROKER_REQUEST_INITIATED",
      actorId: user.id,
      actorRole: dbUser.role || "broker",
      entity: "broker_requests",
      entityId: inserted[0].id,
      metadata: {
        matchScore: params.matchScore,
        aiRecommended: true,
        brokerOverride: false,
        humanReviewed: true,
        offeredPrice: params.offeredPrice,
      },
    });

    // Notify Seller with Deep Link
    const availability = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, params.sellerAvailabilityId),
    });

    if (availability) {
      const sellerUsers = await db.select().from(users).where(eq(users.companyId, availability.companyId));
      for (const sellerUser of sellerUsers) {
        await queueNotificationAction({
          userId: sellerUser.id,
          companyId: availability.companyId,
          channel: 'IN_APP',
          eventType: 'NEGOTIATION_RECEIVED',
          title: 'New Broker Proposal',
          message: `Your broker has structured a commercial proposal for review. Action required before deadline.`,
          actionUrl: `/seller/requests?requestId=${inserted[0].id}`,
          payload: {
            requestId: inserted[0].id,
            url: `/seller/requests?requestId=${inserted[0].id}`,
          },
        });
      }
    }

    revalidatePath('/seller');
    revalidatePath('/seller/requests');

    return {
      success: true,
      message: "Commercial proposal successfully initiated by Broker and dispatched to Seller.",
      data: inserted[0],
    };
  } catch (error: any) {
    console.error("Failed to initiate broker request:", error);
    return { success: false, error: error.message || "Failed to initiate commercial proposal" };
  }
}

/**
 * Dev Test Seeder: Creates a realistic broker-originated commercial proposal
 * attached to the logged-in Seller's first active inventory lot.
 */
export async function createMockBrokerRequestAction(): Promise<BrokerActionResponse> {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const sellerCompanyId = session.data.companyId;

    // 1. Find or create an active availability lot
    let lot = await db.query.availabilities.findFirst({
      where: and(
        eq(availabilities.companyId, sellerCompanyId),
        inArray(availabilities.status, ['Active', 'Open'])
      ),
    });

    if (!lot) {
      // Find a commodity and grade to seed an availability
      const commodity = await db.query.masterCommodities.findFirst();
      if (!commodity) return { success: false, error: "No master commodity found to seed test request." };

      const grade = await db.query.masterGrades.findFirst({
        where: eq(masterGrades.commodityId, commodity.id),
      }) || (await db.query.masterGrades.findFirst());
      if (!grade) return { success: false, error: "No master grade found." };

      const unit = await db.query.masterUnits.findFirst();
      if (!unit) return { success: false, error: "No master unit found." };

      const state = await db.query.masterStates.findFirst();
      const district = await db.query.masterDistricts.findFirst();
      if (!state || !district) return { success: false, error: "No state/district found." };

      const insertedLot = await db.insert(availabilities).values({
        companyId: sellerCompanyId,
        commodityId: commodity.id,
        gradeId: grade.id,
        quantity: 100,
        unitId: unit.id,
        price: '3500',
        stateId: state.id,
        districtId: district.id,
        lotNumber: `TEST-${Math.floor(1000 + Math.random() * 9000)}`,
        totalQuantity: '100',
        availableQuantity: '100',
        askingPrice: '3500',
        availableFrom: new Date(),
        validUntil: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        status: 'Active',
      }).returning();

      lot = insertedLot[0];
    }

    // 2. Find or create a Broker user
    let broker = await db.query.users.findFirst({
      where: eq(users.role, 'broker'),
    }) || (await db.query.users.findFirst({
      where: eq(users.role, 'admin'),
    }));

    if (!broker) {
      broker = session.data.user; // Fallback to current user as broker
    }

    // 3. Find or create a Requirement
    let requirement = await db.query.requirements.findFirst({
      where: eq(requirements.commodityId, lot.commodityId),
    });

    if (!requirement) {
      // Find any buyer company
      let buyerCompany = await db.query.companies.findFirst({
        where: sql`${companies.id} != ${sellerCompanyId}`,
      });

      if (!buyerCompany) {
        buyerCompany = await db.query.companies.findFirst();
      }

      if (!buyerCompany) {
        return { success: false, error: "Cannot create requirement: No buyer company found." };
      }

      const insertedReq = await db.insert(requirements).values({
        companyId: buyerCompany.id,
        commodityId: lot.commodityId,
        gradeId: lot.gradeId,
        quantity: 50,
        unitId: lot.unitId,
        targetPrice: 3400,
        deliveryTermsId: 'Ex-Warehouse (Immediate Loading)',
        targetDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        brokerId: broker.id,
        status: 'Open',
      }).returning();

      requirement = insertedReq[0];
    }

    // 4. Create the broker quotation / commercial request
    const askingNum = Number(lot.askingPrice || lot.price || 3500);
    const proposedRate = Math.max(100, askingNum - Math.floor(Math.random() * 100) - 20); // slightly negotiated price

    const insertedQuotation = await db.insert(quotations).values({
      requirementId: requirement.id,
      brokerId: broker.id,
      sellerAvailabilityId: lot.id,
      offeredPrice: proposedRate.toString(),
      validUntil: new Date(Date.now() + 48 * 60 * 60 * 1000), // 48h deadline
      status: 'Sent',
      counterNotes: "Broker proposal: Verified buyer with immediate dispatch and 100% letter of credit settlement.",
    }).returning();

    // 5. Trigger In-App Notification with Deep Link (Sprint 16.4)
    // CRITICAL PRIVACY: Zero Buyer identifiers in title/message/payload
    const commodityRecord = await db.query.masterCommodities.findFirst({
      where: eq(masterCommodities.id, lot.commodityId),
    });
    const commodityName = commodityRecord?.name || 'Commodity';

    await queueNotificationAction({
      userId: session.data.user.id,
      companyId: sellerCompanyId,
      channel: 'IN_APP',
      eventType: 'NEGOTIATION_RECEIVED',
      title: `New Broker Request: ${commodityName}`,
      message: 'You have a new commercial request. Action required before deadline.',
      actionUrl: `/seller/requests?requestId=${insertedQuotation[0].id}`,
      payload: {
        requestId: insertedQuotation[0].id,
        url: `/seller/requests?requestId=${insertedQuotation[0].id}`,
      },
    });

    revalidatePath('/', 'layout');
    revalidatePath('/seller');
    revalidatePath('/seller/requests');

    return {
      success: true,
      message: `Test Broker Request (#REQ-${insertedQuotation[0].id.slice(0, 6).toUpperCase()}) generated successfully!`,
      data: insertedQuotation[0],
    };
  } catch (error: any) {
    console.error("Failed to seed mock broker request:", error);
    return { success: false, error: error.message || "Failed to generate mock request" };
  }
}
