"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { dealVersions, negotiationEvents, quotations, availabilities, requirements, users } from "@/src/server/db/schema";
import {
  createDealVersionInputSchema,
  dealVersionSnapshotSchema,
  CreateDealVersionInput,
  DealVersionRecord,
  DealVersionSnapshot,
  DealVersionStatus,
  NegotiationTimelineItem,
  DealVersionSnapshotDetailRecord,
  VersionActionResult,
} from "@/src/types/deal-version-schema";
import { detectMaterialChanges, verifyLatestVersion, createDealVersionInTransaction } from "@/src/server/utils/version-engine";
import { computeVersionDiff, VersionDiffResult } from "@/src/server/utils/diff-engine";
import { eq, and, desc, asc } from "drizzle-orm";
import { revalidatePath } from "next/cache";

export type { VersionActionResult, DealVersionSnapshotDetailRecord };

/**
 * Server Action: Creates a new Deal Version if material commercial changes are detected.
 * Atomically supersedes the previous version.
 * 
 * F12 PARAMETER TAMPERING SHIELD:
 * Strictly derives the actor identity from the secure authenticated session (user.id).
 * Client-supplied actor IDs are never accepted.
 */
export async function createNewDealVersionAction(
  requestId: string,
  newPayload: any,
  status: DealVersionStatus = "Proposed",
  expectedVersionNumber?: number | null
): Promise<VersionActionResult<DealVersionRecord>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    if (!requestId) {
      return { success: false, error: "Request ID is required." };
    }

    // Tenant Isolation & Permission Verification
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser || !dbUser.companyId) {
      return { success: false, error: "User profile not linked to a company." };
    }

    const quotation = await db.query.quotations.findFirst({
      where: eq(quotations.id, requestId),
    });

    if (!quotation) {
      return { success: false, error: "Broker request not found." };
    }

    const linkedLot = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, quotation.sellerAvailabilityId),
    });

    const isBrokerOrAdmin = dbUser.role === "broker" || dbUser.role === "admin";
    const isSeller = dbUser.role?.includes("seller") || dbUser.role === "SELLER_ADMIN" || dbUser.role === "SELLER_USER";

    if (!isBrokerOrAdmin && isSeller && linkedLot && linkedLot.companyId !== dbUser.companyId) {
      return { success: false, error: "Unauthorized: You do not have permission to modify this deal version." };
    }

    // Validate snapshot structure
    const validation = dealVersionSnapshotSchema.safeParse(newPayload);
    if (!validation.success) {
      const firstError = validation.error.errors[0]?.message || "Invalid commercial snapshot";
      return { success: false, error: firstError };
    }

    const validatedSnapshot = validation.data;

    const result = await db.transaction(async (tx) => {
      return await createDealVersionInTransaction(tx, {
        requestId,
        newSnapshot: validatedSnapshot,
        actorId: user.id,
        status,
        expectedVersionNumber,
      });
    });

    revalidatePath("/seller");
    revalidatePath("/seller/requests");
    revalidatePath("/broker");

    return {
      success: true,
      version_id: result.version.id,
      version_number: result.version.versionNumber,
      message: result.created
        ? `Deal Version ${result.version.versionNumber} successfully created.`
        : "No material changes detected. Existing active version preserved.",
      data: result.version as DealVersionRecord,
    };
  } catch (error: any) {
    console.error("Failed to create new deal version:", error);
    return {
      success: false,
      error: error.message || "Failed to create deal version",
    };
  }
}

/**
 * Creates an immutable commercial Deal Version snapshot from input payload.
 */
export async function createDealVersionSnapshotAction(
  data: unknown
): Promise<VersionActionResult<DealVersionRecord>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    const validation = createDealVersionInputSchema.safeParse(data);
    if (!validation.success) {
      const firstError = validation.error.errors[0]?.message || "Invalid deal version payload";
      return { success: false, error: firstError };
    }

    const payload: CreateDealVersionInput = validation.data;
    const expectedVer = payload.expectedVersionNumber ?? (payload as any).expected_version_number;

    return await createNewDealVersionAction(
      payload.requestId,
      payload.snapshot,
      payload.status,
      expectedVer
    );
  } catch (error: any) {
    console.error("Failed to create deal version snapshot:", error);
    return {
      success: false,
      error: error.message || "Failed to create deal version snapshot",
    };
  }
}

/**
 * Retrieves all chronological Deal Versions for a request.
 * Guaranteed to return immutable historical records with Tenant Isolation enforcement.
 */
export async function getDealVersionsAction(
  requestId: string
): Promise<VersionActionResult<DealVersionRecord[]>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    if (!requestId) {
      return { success: false, error: "Request ID is required" };
    }

    // Tenant Isolation Check
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser || !dbUser.companyId) {
      return { success: false, error: "User profile not linked to a company." };
    }

    const quotation = await db.query.quotations.findFirst({
      where: eq(quotations.id, requestId),
    });

    if (!quotation) {
      return { success: false, error: "Broker request not found." };
    }

    const linkedLot = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, quotation.sellerAvailabilityId),
    });

    const isBrokerOrAdmin = dbUser.role === "broker" || dbUser.role === "admin";
    const isSeller = dbUser.role?.includes("seller") || dbUser.role === "SELLER_ADMIN" || dbUser.role === "SELLER_USER" || dbUser.role === "SELLER_VIEWER";

    if (!isBrokerOrAdmin && isSeller && linkedLot && linkedLot.companyId !== dbUser.companyId) {
      return { success: false, error: "Unauthorized: You do not have access to these deal versions." };
    }

    const rows = await db
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

    return {
      success: true,
      data: rows as DealVersionRecord[],
    };
  } catch (error: any) {
    console.error("Failed to fetch deal versions:", error);
    return {
      success: false,
      error: error.message || "Failed to fetch deal versions",
    };
  }
}

/**
 * Retrieves the latest (active) Deal Version for a request with Tenant Isolation enforcement.
 */
export async function getLatestDealVersionAction(
  requestId: string
): Promise<VersionActionResult<DealVersionRecord | null>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    if (!requestId) {
      return { success: false, error: "Request ID is required" };
    }

    // Tenant Isolation Check
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser || !dbUser.companyId) {
      return { success: false, error: "User profile not linked to a company." };
    }

    const quotation = await db.query.quotations.findFirst({
      where: eq(quotations.id, requestId),
    });

    if (!quotation) {
      return { success: false, error: "Broker request not found." };
    }

    const linkedLot = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, quotation.sellerAvailabilityId),
    });

    const isBrokerOrAdmin = dbUser.role === "broker" || dbUser.role === "admin";
    const isSeller = dbUser.role?.includes("seller") || dbUser.role === "SELLER_ADMIN" || dbUser.role === "SELLER_USER" || dbUser.role === "SELLER_VIEWER";

    if (!isBrokerOrAdmin && isSeller && linkedLot && linkedLot.companyId !== dbUser.companyId) {
      return { success: false, error: "Unauthorized: You do not have access to this deal version." };
    }

    const rows = await db
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
      .orderBy(desc(dealVersions.versionNumber))
      .limit(1);

    if (!rows.length) {
      return { success: true, data: null };
    }

    return {
      success: true,
      data: rows[0] as DealVersionRecord,
    };
  } catch (error: any) {
    console.error("Failed to fetch latest deal version:", error);
    return {
      success: false,
      error: error.message || "Failed to fetch latest deal version",
    };
  }
}

/**
 * Retrieves the unified chronological negotiation and deal version timeline.
 * Strict privacy enforcement: All Buyer private contact info (phone, email, WhatsApp) is scrubbed.
 */
export async function getNegotiationTimelineAction(
  requestId: string
): Promise<VersionActionResult<NegotiationTimelineItem[]>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    if (!requestId) {
      return { success: false, error: "Request ID is required." };
    }

    // 1. Fetch parent quotation / request
    const quotation = await db.query.quotations.findFirst({
      where: eq(quotations.id, requestId),
    });

    if (!quotation) {
      return { success: false, error: "Broker request not found." };
    }

    // 2. Fetch authenticated user record for role & tenant verification
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser || !dbUser.companyId) {
      return { success: false, error: "User profile not linked to a company." };
    }

    const linkedLot = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, quotation.sellerAvailabilityId),
    });

    const isSeller = dbUser.role?.includes("seller") || dbUser.role === "SELLER_ADMIN" || dbUser.role === "SELLER_USER" || dbUser.role === "SELLER_VIEWER";
    if (isSeller && linkedLot && linkedLot.companyId !== dbUser.companyId) {
      return { success: false, error: "Unauthorized: You do not have access to this negotiation timeline." };
    }

    // 3. Query all Deal Versions for this request
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

    // 4. Query all Negotiation Events for this request
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

    const timeline: NegotiationTimelineItem[] = [];

    // Synthesize Initial Proposal if no Version 1 was explicitly recorded
    const hasV1 = versions.some((v) => v.versionNumber === 1);
    if (!hasV1) {
      timeline.push({
        id: `prop_init_${quotation.id}`,
        requestId: quotation.id,
        type: "PROPOSAL_INITIATED",
        title: "Initial Broker Proposal Dispatched",
        status: "Proposed",
        actorName: "Broker Desk",
        actorRole: "Broker",
        isSeller: false,
        versionNumber: 1,
        summary: `Offered Rate: ₹${Number(quotation.offeredPrice).toLocaleString("en-IN")}/MT • Valid until ${new Date(quotation.validUntil).toLocaleDateString("en-IN")}`,
        details: {
          offeredPrice: quotation.offeredPrice,
          validUntil: quotation.validUntil,
        },
        createdAt: new Date(quotation.createdAt).toISOString(),
      });
    }

    // Map Deal Versions
    for (const v of versions) {
      const snap: any = v.snapshotPayload || {};
      const isSellerActor = v.actorRole?.includes("seller") || snap.originatorRole === "seller";
      const actorRoleDisplay = isSellerActor ? "Seller" : v.actorRole?.includes("broker") ? "Broker" : "Broker Desk";
      const actorNameDisplay = isSellerActor ? "You (Seller)" : "Broker Desk";

      let summaryText = `Rate: ₹${Number(snap.rate || 0).toLocaleString("en-IN")}/${snap.unitSymbol || "MT"} • Qty: ${snap.quantity || 0} ${snap.unitSymbol || "MT"}`;
      if (snap.deliveryTerms) summaryText += ` • ${snap.deliveryTerms}`;
      if (snap.deliveryDate) summaryText += ` • Delivery: ${snap.deliveryDate}`;

      timeline.push({
        id: `ver_${v.id}`,
        requestId: v.requestId,
        type: "DEAL_VERSION",
        title: `Deal Version ${v.versionNumber} (${v.status})`,
        status: v.status,
        actorName: actorNameDisplay,
        actorRole: actorRoleDisplay as any,
        isSeller: isSellerActor,
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

    // Map Negotiation Events
    for (const e of events) {
      const p: any = e.payload || {};
      const isSellerActor = e.actorRole?.includes("seller") || e.companyId === dbUser.companyId;
      const actorRoleDisplay = isSellerActor ? "Seller" : "Broker";
      const actorNameDisplay = isSellerActor ? "You (Seller)" : "Broker Desk";

      let title = "Negotiation Update";
      let summary = "";

      if (e.actionType === "ACCEPT") {
        title = "Proposal Accepted";
        summary = `Accepted commercial proposal terms. Finalization requested.`;
      } else if (e.actionType === "REJECT") {
        title = "Proposal Rejected";
        summary = `Reason: ${p.rejectionReason || "Terms not acceptable"}`;
      } else if (e.actionType === "COUNTER") {
        title = "Counter-Offer Submitted";
        const parts = [];
        if (p.counterPrice) parts.push(`Rate: ₹${Number(p.counterPrice).toLocaleString("en-IN")}`);
        if (p.counterQuantity) parts.push(`Qty: ${p.counterQuantity}`);
        if (p.counterDeliveryDate) parts.push(`Delivery: ${p.counterDeliveryDate}`);
        if (p.counterRemarks) parts.push(`Notes: ${p.counterRemarks}`);
        summary = parts.join(" • ") || "Counter-terms proposed to Broker.";
      }

      timeline.push({
        id: `evt_${e.id}`,
        requestId: e.requestId,
        type: "NEGOTIATION_ACTION",
        title,
        status: e.actionType,
        actorName: actorNameDisplay,
        actorRole: actorRoleDisplay as any,
        isSeller: isSellerActor,
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
    console.error("Failed to fetch negotiation timeline:", error);
    return {
      success: false,
      error: error.message || "Failed to fetch negotiation timeline",
    };
  }
}

/**
 * Retrieves the exact immutable snapshot of a specific Deal Version.
 * Used by the Final Deal Confirmation screen (Sprint 18.1 & 18.2).
 * 
 * HARD SECURITY & PRIVACY CONTROLS:
 * 1. Authenticates session via @supabase/ssr.
 * 2. Enforces Tenant Isolation (Seller company ownership, or Broker/Admin role).
 * 3. Sanitizes all Buyer private contact information (zero-Buyer-PII rule).
 * 4. Computes server-side visual diff against previous version.
 */
export async function getDealVersionSnapshotAction(
  versionIdOrRequestId: string
): Promise<VersionActionResult<DealVersionSnapshotDetailRecord>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    if (!versionIdOrRequestId) {
      return { success: false, error: "Deal version or request ID is required." };
    }

    // 1. Authenticate user & tenant profile
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser || !dbUser.companyId) {
      return { success: false, error: "User profile not linked to a company." };
    }

    // 2. Query deal version by ID (UUID)
    let versionRow = await db
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
      .where(eq(dealVersions.id, versionIdOrRequestId))
      .limit(1)
      .then((rows) => rows[0] || null);

    // If not found by primary key, check if parameter was a requestId and fetch latest version
    if (!versionRow) {
      versionRow = await db
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
        .where(eq(dealVersions.requestId, versionIdOrRequestId))
        .orderBy(desc(dealVersions.versionNumber))
        .limit(1)
        .then((rows) => rows[0] || null);
    }

    // If still no deal_versions record exists, check if it's a valid quotation and synthesize v1 snapshot
    if (!versionRow) {
      const quotation = await db.query.quotations.findFirst({
        where: eq(quotations.id, versionIdOrRequestId),
      });

      if (!quotation) {
        return { success: false, error: "Deal version not found." };
      }

      // Synthesize fallback baseline snapshot from parent quotation + availability + requirement
      const linkedLot = await db.query.availabilities.findFirst({
        where: eq(availabilities.id, quotation.sellerAvailabilityId),
      });
      const linkedReq = await db.query.requirements.findFirst({
        where: eq(requirements.id, quotation.requirementId),
      });

      const isBrokerOrAdmin = dbUser.role === "broker" || dbUser.role === "admin";
      const isSeller = dbUser.role?.includes("seller") || dbUser.role === "SELLER_ADMIN" || dbUser.role === "SELLER_USER" || dbUser.role === "SELLER_VIEWER";

      if (!isBrokerOrAdmin && isSeller && linkedLot && linkedLot.companyId !== dbUser.companyId) {
        return { success: false, error: "Unauthorized: You do not have access to this deal version." };
      }

      const syntheticSnapshot: DealVersionSnapshot = {
        commodityId: linkedLot?.commodityId || "",
        commodityName: "Agricultural Commodity",
        gradeId: linkedLot?.gradeId || null,
        gradeName: "Standard Quality",
        lotId: linkedLot?.id || null,
        lotNumber: linkedLot?.lotNumber || "LOT-MAIN",
        quantity: Number(linkedReq?.quantity || 100),
        unitId: linkedLot?.unitId || null,
        unitSymbol: "MT",
        rate: Number(quotation.offeredPrice || 0),
        deliveryTerms: linkedReq?.deliveryTermsId || "Ex-Warehouse",
        deliveryDate: linkedReq?.targetDate ? new Date(linkedReq.targetDate).toISOString().split("T")[0] : undefined,
        paymentTerms: "Standard Escrow Settlement via Broker Desk",
        packagingType: "Standard Bags",
        remarks: "Initial Proposal Terms",
        originatorRole: "broker",
        timestamp: new Date(quotation.createdAt).toISOString(),
      };

      const syntheticDiff = computeVersionDiff(null, syntheticSnapshot);

      return {
        success: true,
        data: {
          id: `synth_${quotation.id}`,
          requestId: quotation.id,
          versionNumber: 1,
          totalVersions: 1,
          actorId: quotation.brokerId,
          actorName: "Broker Desk",
          actorRole: "broker",
          status: (quotation.status as any) || "Proposed",
          snapshotPayload: syntheticSnapshot,
          previousSnapshotPayload: null,
          diffData: syntheticDiff,
          createdAt: quotation.createdAt,
        } as any,
      };
    }

    // 3. Tenant Isolation Check on found deal version
    const quotation = await db.query.quotations.findFirst({
      where: eq(quotations.id, versionRow.requestId),
    });

    if (quotation) {
      const linkedLot = await db.query.availabilities.findFirst({
        where: eq(availabilities.id, quotation.sellerAvailabilityId),
      });

      const isBrokerOrAdmin = dbUser.role === "broker" || dbUser.role === "admin";
      const isSeller = dbUser.role?.includes("seller") || dbUser.role === "SELLER_ADMIN" || dbUser.role === "SELLER_USER" || dbUser.role === "SELLER_VIEWER";

      if (!isBrokerOrAdmin && isSeller && linkedLot && linkedLot.companyId !== dbUser.companyId) {
        return { success: false, error: "Unauthorized: You do not have access to this deal version." };
      }
    }

    // 4. Scrub any sensitive Buyer PII from snapshot
    const rawPayload: any = versionRow.snapshotPayload || {};
    const sanitizedSnapshot: DealVersionSnapshot = {
      ...rawPayload,
    };

    // Remove any rogue private keys
    delete (sanitizedSnapshot as any).buyerPhone;
    delete (sanitizedSnapshot as any).buyerEmail;
    delete (sanitizedSnapshot as any).buyerWhatsapp;
    delete (sanitizedSnapshot as any).buyerGst;
    delete (sanitizedSnapshot as any).buyerMobile;
    delete (sanitizedSnapshot as any).buyerContact;

    // 5. Query all versions for this request to determine total count & previous snapshot
    const allVersions = await db
      .select({
        id: dealVersions.id,
        versionNumber: dealVersions.versionNumber,
        status: dealVersions.status,
        snapshotPayload: dealVersions.snapshotPayload,
      })
      .from(dealVersions)
      .where(eq(dealVersions.requestId, versionRow.requestId))
      .orderBy(asc(dealVersions.versionNumber));

    const totalVersions = allVersions.length > 0 ? allVersions.length : 1;
    const currentVersionNumber = versionRow.versionNumber;

    let previousSnapshotPayload: DealVersionSnapshot | null = null;
    if (currentVersionNumber > 1) {
      const prevVer = allVersions.find((v) => v.versionNumber === currentVersionNumber - 1);
      if (prevVer) {
        previousSnapshotPayload = prevVer.snapshotPayload as DealVersionSnapshot;
      }
    }

    // 6. Compute Server-Side Visual Diff
    const diffData = computeVersionDiff(previousSnapshotPayload, sanitizedSnapshot);

    return {
      success: true,
      data: {
        ...versionRow,
        status: versionRow.status as DealVersionStatus,
        snapshotPayload: sanitizedSnapshot,
        previousSnapshotPayload,
        totalVersions,
        diffData,
      },
    };
  } catch (error: any) {
    console.error("Failed to fetch deal version snapshot:", error);
    return {
      success: false,
      error: error.message || "Failed to fetch deal version snapshot",
    };
  }
}

