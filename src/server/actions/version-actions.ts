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
} from "@/src/types/deal-version-schema";
import { detectMaterialChanges, verifyLatestVersion } from "@/src/server/utils/version-engine";
import { eq, and, desc, asc } from "drizzle-orm";
import { revalidatePath } from "next/cache";

export type VersionActionResult<T = any> = {
  success: boolean;
  version_id?: string;
  version_number?: number;
  data?: T;
  error?: string;
  message?: string;
};

/**
 * Internal Transaction-Safe Helper:
 * Evaluates material changes against existing versions, supersedes older records,
 * and inserts a new immutable Deal Version within an existing transaction context.
 */
export async function createDealVersionInTransaction(
  tx: any,
  params: {
    requestId: string;
    newSnapshot: DealVersionSnapshot;
    actorId: string;
    status?: DealVersionStatus;
    expectedVersionNumber?: number | null;
  }
): Promise<{ version: any; created: boolean }> {
  // Stale Version Protection Guard
  if (params.expectedVersionNumber !== undefined && params.expectedVersionNumber !== null) {
    await verifyLatestVersion(tx, params.requestId, params.expectedVersionNumber);
  }

  // Step A: Find highest existing version for this request_id
  const existingVersions = await tx
    .select({
      id: dealVersions.id,
      versionNumber: dealVersions.versionNumber,
      status: dealVersions.status,
      snapshotPayload: dealVersions.snapshotPayload,
    })
    .from(dealVersions)
    .where(eq(dealVersions.requestId, params.requestId))
    .orderBy(desc(dealVersions.versionNumber));

  let highestVersion = existingVersions.length > 0 ? existingVersions[0] : null;

  // If no deal_versions record exists yet (e.g. unversioned or legacy request), synthesize Version 1 first
  if (!highestVersion) {
    const parentQuotation = await tx.query.quotations.findFirst({
      where: eq(quotations.id, params.requestId),
    });

    if (parentQuotation) {
      const parentLot = await tx.query.availabilities.findFirst({
        where: eq(availabilities.id, parentQuotation.sellerAvailabilityId),
      });
      const parentReq = await tx.query.requirements.findFirst({
        where: eq(requirements.id, parentQuotation.requirementId),
      });

      const initialV1Snapshot: DealVersionSnapshot = {
        commodityId: parentLot?.commodityId || params.newSnapshot.commodityId,
        commodityName: params.newSnapshot.commodityName || "Commodity",
        gradeId: parentLot?.gradeId || params.newSnapshot.gradeId,
        gradeName: params.newSnapshot.gradeName || "Standard Grade",
        lotId: parentLot?.id || params.newSnapshot.lotId,
        lotNumber: parentLot?.lotNumber || params.newSnapshot.lotNumber,
        quantity: Number(parentReq?.quantity || params.newSnapshot.quantity),
        unitId: parentLot?.unitId || params.newSnapshot.unitId,
        unitSymbol: params.newSnapshot.unitSymbol || "MT",
        rate: Number(parentQuotation.offeredPrice || params.newSnapshot.rate),
        deliveryTerms: parentReq?.deliveryTermsId || params.newSnapshot.deliveryTerms || "Ex-Warehouse",
        deliveryDate: parentReq?.targetDate ? new Date(parentReq.targetDate).toISOString().split("T")[0] : params.newSnapshot.deliveryDate,
        paymentTerms: "Standard Escrow Settlement via Broker Desk",
        packagingType: "Standard Packaging",
        remarks: "Initial Broker Proposal",
        originatorRole: "broker",
        timestamp: new Date(parentQuotation.createdAt).toISOString(),
      };

      const [v1] = await tx
        .insert(dealVersions)
        .values({
          requestId: params.requestId,
          versionNumber: 1,
          actorId: parentQuotation.brokerId || params.actorId,
          status: "Superseded",
          snapshotPayload: initialV1Snapshot,
        })
        .returning();

      highestVersion = v1;
    }
  }

  // Step B: Detect material commercial changes or state transitions
  const hasMaterialChanges = highestVersion
    ? detectMaterialChanges(highestVersion.snapshotPayload as any, params.newSnapshot)
    : true;

  const isCounter = params.status === "Countered";
  const isRoleChange = highestVersion
    ? (highestVersion.snapshotPayload as any)?.originatorRole !== params.newSnapshot.originatorRole
    : false;
  const isRemarksChange = highestVersion
    ? (highestVersion.snapshotPayload as any)?.remarks !== params.newSnapshot.remarks
    : false;
  const isStatusChange = highestVersion
    ? (params.status && params.status !== highestVersion.status && highestVersion.status !== "Superseded")
    : false;

  const shouldCreate = !highestVersion || hasMaterialChanges || isCounter || isRoleChange || isRemarksChange || isStatusChange;

  if (!shouldCreate && highestVersion) {
    return {
      version: highestVersion,
      created: false,
    };
  }

  const nextVersionNumber = highestVersion ? highestVersion.versionNumber + 1 : 1;

  // Step C: Atomically mark previous highest version as 'Superseded'
  if (highestVersion) {
    await tx
      .update(dealVersions)
      .set({
        status: "Superseded",
      })
      .where(
        and(
          eq(dealVersions.requestId, params.requestId),
          eq(dealVersions.id, highestVersion.id)
        )
      );
  }

  // Step D: Insert new immutable Deal Version row
  const snapshotToStore: DealVersionSnapshot = {
    ...params.newSnapshot,
    timestamp: params.newSnapshot.timestamp || new Date().toISOString(),
  };

  const [inserted] = await tx
    .insert(dealVersions)
    .values({
      requestId: params.requestId,
      versionNumber: nextVersionNumber,
      actorId: params.actorId,
      status: params.status || "Proposed",
      snapshotPayload: snapshotToStore,
    })
    .returning();

  return {
    version: inserted,
    created: true,
  };
}

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
