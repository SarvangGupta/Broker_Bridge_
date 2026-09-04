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
  negotiationEvents,
  dealVersions,
} from "@/src/server/db/schema";
import {
  brokerResponseSchema,
  BrokerResponsePayload,
  SellerBrokerRequestItem,
} from "@/src/types/broker-request-schema";
import { createDealVersionInTransaction } from "@/src/server/actions/version-actions";
import { DealVersionSnapshot } from "@/src/types/deal-version-schema";
import { verifyLatestVersion } from "@/src/server/utils/version-engine";
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

    // Fetch latest deal version for these quotations to support optimistic locking
    const requestIds = rows.map((r) => r.id);
    const versionMap = new Map<string, number>();

    if (requestIds.length > 0) {
      const allVersions = await db
        .select({
          requestId: dealVersions.requestId,
          versionNumber: dealVersions.versionNumber,
        })
        .from(dealVersions)
        .where(inArray(dealVersions.requestId, requestIds))
        .orderBy(desc(dealVersions.versionNumber));

      for (const v of allVersions) {
        if (!versionMap.has(v.requestId)) {
          versionMap.set(v.requestId, v.versionNumber);
        }
      }
    }

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
        latestVersionNumber: versionMap.get(r.id) ?? 1,
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
 * Enforces company boundary, role permission checks, stale version guards, and logs immutable negotiation events.
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

    // Additional validation checks
    if (payload.action === 'reject') {
      if (!payload.rejectionReason || payload.rejectionReason.trim().length < 5) {
        return { success: false, error: "Please provide a valid rejection reason (at least 5 characters)." };
      }
    }

    if (payload.action === 'counter') {
      const hasPrice = payload.counterPrice !== undefined && payload.counterPrice !== null && payload.counterPrice > 0;
      const hasQuantity = payload.counterQuantity !== undefined && payload.counterQuantity !== null && payload.counterQuantity > 0;
      const hasRemarks = payload.counterRemarks !== undefined && payload.counterRemarks !== null && payload.counterRemarks.trim().length > 0;
      const hasDate = payload.counterDeliveryDate !== undefined && payload.counterDeliveryDate !== null && payload.counterDeliveryDate.trim().length > 0;

      if (!hasPrice && !hasQuantity && !hasRemarks && !hasDate) {
        return { success: false, error: "At least one counter proposal field (price, quantity, delivery date, or remarks) must be specified." };
      }
    }

    const actionType = payload.action === 'accept' ? 'ACCEPT' : payload.action === 'reject' ? 'REJECT' : 'COUNTER';

    // Execute atomic transaction for negotiation event logging and parent state update
    await db.transaction(async (tx) => {
      // Concurrency Stale-Version Guard (Unconditionally Enforced)
      const expectedVer = payload.expectedVersionNumber ?? (payload as any).expected_version_number;
      await verifyLatestVersion(tx, payload.requestId, expectedVer);

      // Verify existence of target broker request / quotation
      const quotation = await tx.query.quotations.findFirst({
        where: eq(quotations.id, payload.requestId),
      });

      if (!quotation) {
        throw new Error("Broker request not found.");
      }

      // Check if the availability lot belongs to this seller's company (Tenant Isolation)
      const linkedLot = await tx.query.availabilities.findFirst({
        where: eq(availabilities.id, quotation.sellerAvailabilityId),
      });

      if (!linkedLot || linkedLot.companyId !== session.data.companyId) {
        throw new Error("Unauthorized: You do not have permission to respond to this request.");
      }

      // Check if quotation is expired
      if (new Date(quotation.validUntil) < new Date()) {
        throw new Error("This broker proposal has expired and can no longer be modified.");
      }

      // Check if already finalized or closed
      if (quotation.status === 'Seller Accepted' || quotation.status === 'Accepted') {
        throw new Error("This request has already been accepted.");
      }

      // Construct immutable event payload
      const eventPayload: Record<string, any> = {
        action: actionType,
        timestamp: new Date().toISOString(),
      };

      if (actionType === 'REJECT') {
        eventPayload.rejectionReason = payload.rejectionReason;
      } else if (actionType === 'COUNTER') {
        eventPayload.counterPrice = payload.counterPrice ?? null;
        eventPayload.counterQuantity = payload.counterQuantity ?? null;
        eventPayload.counterDeliveryDate = payload.counterDeliveryDate ?? null;
        eventPayload.counterRemarks = payload.counterRemarks ?? null;
        eventPayload.originalOfferedPrice = quotation.offeredPrice;
      } else if (actionType === 'ACCEPT') {
        eventPayload.agreedPrice = quotation.offeredPrice;
      }

      // Step B: Insert immutable record into negotiation_events
      await tx.insert(negotiationEvents).values({
        requestId: payload.requestId,
        companyId: session.data.companyId,
        actorId: session.data.user.id,
        actionType: actionType,
        payload: eventPayload,
      });

      // Step C: Update status of parent broker request / quotation and create Deal Version
      if (actionType === 'ACCEPT') {
        await tx
          .update(quotations)
          .set({
            status: 'Seller Accepted',
          })
          .where(eq(quotations.id, payload.requestId));

        // Update active Deal Version status to 'Seller Confirmed' if it exists
        const latestVersion = await tx.query.dealVersions.findFirst({
          where: eq(dealVersions.requestId, payload.requestId),
          orderBy: desc(dealVersions.versionNumber),
        });

        if (latestVersion && latestVersion.status !== 'Superseded') {
          await tx
            .update(dealVersions)
            .set({ status: 'Seller Confirmed' })
            .where(eq(dealVersions.id, latestVersion.id));
        }
      } else if (actionType === 'REJECT') {
        await tx
          .update(quotations)
          .set({
            status: 'Seller Rejected',
            rejectionReason: payload.rejectionReason,
          })
          .where(eq(quotations.id, payload.requestId));
      } else if (actionType === 'COUNTER') {
        const notesParts = [];
        if (payload.counterRemarks) notesParts.push(payload.counterRemarks);
        if (payload.counterQuantity) notesParts.push(`Requested Qty: ${payload.counterQuantity}`);
        if (payload.counterDeliveryDate) notesParts.push(`Expected Date: ${payload.counterDeliveryDate}`);

        await tx
          .update(quotations)
          .set({
            status: 'Seller Countered',
            counterPrice: payload.counterPrice ? payload.counterPrice.toString() : quotation.offeredPrice,
            counterNotes: notesParts.join(" | ") || "Seller submitted counter-terms",
          })
          .where(eq(quotations.id, payload.requestId));

        // Fetch requirement and master records to construct accurate commercial snapshot
        const requirement = await tx.query.requirements.findFirst({
          where: eq(requirements.id, quotation.requirementId),
        });
        const commodity = await tx.query.masterCommodities.findFirst({
          where: eq(masterCommodities.id, linkedLot.commodityId),
        });
        const unit = await tx.query.masterUnits.findFirst({
          where: eq(masterUnits.id, linkedLot.unitId),
        });
        const grade = linkedLot.gradeId
          ? await tx.query.masterGrades.findFirst({
              where: eq(masterGrades.id, linkedLot.gradeId),
            })
          : null;

        const existingVersion = await tx.query.dealVersions.findFirst({
          where: eq(dealVersions.requestId, payload.requestId),
          orderBy: desc(dealVersions.versionNumber),
        });

        const baseSnapshot: any = existingVersion?.snapshotPayload || {};
        const counterSnapshot: DealVersionSnapshot = {
          commodityId: linkedLot.commodityId,
          commodityName: commodity?.name || baseSnapshot.commodityName || "Commodity",
          gradeId: linkedLot.gradeId || baseSnapshot.gradeId || null,
          gradeName: grade?.gradeName || baseSnapshot.gradeName || null,
          lotId: linkedLot.id,
          lotNumber: linkedLot.lotNumber || baseSnapshot.lotNumber || null,
          quantity: payload.counterQuantity
            ? Number(payload.counterQuantity)
            : (Number(baseSnapshot.quantity) || Number(requirement?.quantity) || Number(linkedLot.totalQuantity)),
          unitId: linkedLot.unitId || baseSnapshot.unitId || null,
          unitSymbol: unit?.symbol || baseSnapshot.unitSymbol || "MT",
          rate: payload.counterPrice
            ? Number(payload.counterPrice)
            : (Number(baseSnapshot.rate) || Number(quotation.offeredPrice)),
          deliveryState: baseSnapshot.deliveryState || null,
          deliveryDistrict: baseSnapshot.deliveryDistrict || null,
          deliveryLocation: baseSnapshot.deliveryLocation || null,
          deliveryTerms: requirement?.deliveryTermsId || baseSnapshot.deliveryTerms || "Ex-Warehouse",
          deliveryDate: payload.counterDeliveryDate || (requirement?.targetDate ? new Date(requirement.targetDate).toISOString().split("T")[0] : baseSnapshot.deliveryDate) || null,
          paymentTerms: baseSnapshot.paymentTerms || "Standard Commercial Terms",
          packagingType: baseSnapshot.packagingType || null,
          qualityNotes: baseSnapshot.qualityNotes || null,
          qualityParameters: baseSnapshot.qualityParameters || null,
          remarks: payload.counterRemarks || baseSnapshot.remarks || "Seller counter-offer submitted.",
          originatorRole: "seller",
          timestamp: new Date().toISOString(),
        };

        // Create new Deal Version with status 'Countered' (supersedes previous version)
        await createDealVersionInTransaction(tx, {
          requestId: payload.requestId,
          newSnapshot: counterSnapshot,
          actorId: session.data.user.id,
          status: "Countered",
          expectedVersionNumber: expectedVer,
        });
      }
    });

    // Log Decision Gate Audit Event for compliance and audit trail
    await logDecisionGateAuditEventAction({
      action: "SELLER_PROPOSAL_ACTION",
      actorId: session.data.user.id,
      actorRole: "seller",
      entity: "quotations",
      entityId: payload.requestId,
      metadata: {
        action: payload.action,
        actionType,
        sellerCompanyId: session.data.companyId,
        counterPrice: payload.counterPrice,
        counterQuantity: payload.counterQuantity,
        counterDeliveryDate: payload.counterDeliveryDate,
        rejectionReason: payload.rejectionReason,
        humanReviewed: true,
      },
    });

    revalidatePath('/seller');
    revalidatePath('/seller/requests');
    revalidatePath('/', 'layout');

    return {
      success: true,
      message: "Response submitted successfully to your Broker.",
    };
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

    // Insert Version 1 into deal_versions (Immutable Snapshot Engine)
    const targetLot = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, params.sellerAvailabilityId),
    });
    const targetReq = await db.query.requirements.findFirst({
      where: eq(requirements.id, params.requirementId),
    });
    if (targetLot && targetReq) {
      const comm = await db.query.masterCommodities.findFirst({
        where: eq(masterCommodities.id, targetLot.commodityId),
      });
      const grd = targetLot.gradeId
        ? await db.query.masterGrades.findFirst({
            where: eq(masterGrades.id, targetLot.gradeId),
          })
        : null;
      const unt = targetLot.unitId
        ? await db.query.masterUnits.findFirst({
            where: eq(masterUnits.id, targetLot.unitId),
          })
        : null;

      const initialAiSnapshot: DealVersionSnapshot = {
        commodityId: targetLot.commodityId,
        commodityName: comm?.name || "Commodity",
        gradeId: targetLot.gradeId || null,
        gradeName: grd?.gradeName || "Standard Grade",
        lotId: targetLot.id,
        lotNumber: targetLot.lotNumber || null,
        quantity: Number(targetReq.quantity || 50),
        unitId: targetLot.unitId || null,
        unitSymbol: unt?.symbol || "MT",
        rate: Number(params.offeredPrice),
        deliveryState: null,
        deliveryDistrict: null,
        deliveryLocation: null,
        deliveryTerms: targetReq.deliveryTermsId || "Ex-Warehouse",
        deliveryDate: targetReq.targetDate ? new Date(targetReq.targetDate).toISOString().split("T")[0] : null,
        paymentTerms: "Standard Escrow Settlement via Broker Desk",
        packagingType: "Standard Packaging",
        qualityNotes: null,
        qualityParameters: null,
        remarks: params.brokerNotes || "Broker curated proposal based on AI recommendation parameters.",
        originatorRole: "broker",
        timestamp: new Date().toISOString(),
      };

      await db.insert(dealVersions).values({
        requestId: inserted[0].id,
        versionNumber: 1,
        actorId: user.id,
        status: "Proposed",
        snapshotPayload: initialAiSnapshot,
      });
    }

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

    // 4b. Insert Version 1 into deal_versions (Deal Versioning Engine)
    const commodityRecord = await db.query.masterCommodities.findFirst({
      where: eq(masterCommodities.id, lot.commodityId),
    });
    const commodityName = commodityRecord?.name || 'Commodity';
    const gradeRecord = lot.gradeId
      ? await db.query.masterGrades.findFirst({
          where: eq(masterGrades.id, lot.gradeId),
        })
      : null;
    const unitRecord = lot.unitId
      ? await db.query.masterUnits.findFirst({
          where: eq(masterUnits.id, lot.unitId),
        })
      : null;

    const initialSnapshot: DealVersionSnapshot = {
      commodityId: lot.commodityId,
      commodityName: commodityName,
      gradeId: lot.gradeId || null,
      gradeName: gradeRecord?.gradeName || "Standard Grade",
      lotId: lot.id,
      lotNumber: lot.lotNumber || null,
      quantity: Number(requirement.quantity || 50),
      unitId: lot.unitId || null,
      unitSymbol: unitRecord?.symbol || "MT",
      rate: proposedRate,
      deliveryState: null,
      deliveryDistrict: null,
      deliveryLocation: null,
      deliveryTerms: requirement.deliveryTermsId || "Ex-Warehouse (Immediate Loading)",
      deliveryDate: requirement.targetDate ? new Date(requirement.targetDate).toISOString().split("T")[0] : null,
      paymentTerms: "Standard Escrow Settlement via Broker Desk",
      packagingType: "Standard Packaging",
      qualityNotes: null,
      qualityParameters: null,
      remarks: "Broker proposal: Verified buyer with immediate dispatch and 100% letter of credit settlement.",
      originatorRole: "broker",
      timestamp: new Date().toISOString(),
    };

    await db.insert(dealVersions).values({
      requestId: insertedQuotation[0].id,
      versionNumber: 1,
      actorId: broker.id,
      status: "Proposed",
      snapshotPayload: initialSnapshot,
    });

    // 5. Trigger In-App Notification with Deep Link (Sprint 16.4)
    // CRITICAL PRIVACY: Zero Buyer identifiers in title/message/payload
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
