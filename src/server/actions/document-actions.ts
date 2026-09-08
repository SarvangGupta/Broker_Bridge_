"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import {
  dispatchDocuments,
  dispatches,
  deals,
  quotations,
  availabilities,
  bookings,
  negotiationEvents,
  users,
} from "@/src/server/db/schema";
import { eq, or, and, desc } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { verifySellerSession } from "@/src/server/utils/seller-auth";
import { logDecisionGateAuditEventAction } from "@/src/server/actions/audit-actions";
import { DocumentTypeEnum } from "@/src/types/dispatch-schema";

export type { DocumentTypeEnum };

export interface AttachDocumentPayload {
  dispatchId: string;
  documentType: DocumentTypeEnum | string;
  fileUrl: string;
}

export interface DispatchDocumentItem {
  id: string;
  dispatchId: string;
  documentType: DocumentTypeEnum | string;
  fileUrl: string;
  signedUrl: string | null;
  uploadedBy: string | null;
  uploaderName?: string;
  createdAt: string;
  fileName: string;
}

/**
 * Server Action: Uploads a physical fulfillment document (LR, Invoice, E-Way Bill, Weighment Slip, Loading Photo)
 * to Supabase Storage ('brokerbridge_documents' bucket) via Server Action.
 * 
 * GUARANTEES & SECURITY POSTURE:
 * 1. Authenticates session on the server via verifySellerSession / @supabase/ssr (resolving httpOnly cookie & RLS rejection).
 * 2. Verifies dispatch record and tenant ownership.
 * 3. Sanitizes file names and uploads to private bucket structure `${bookingId}/${dispatchId}/${Date.now()}_${sanitizedFileName}`.
 */
export async function uploadFulfillmentDocumentAction(
  formData: FormData
): Promise<{
  success: boolean;
  data?: { path: string };
  error?: string;
}> {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return {
        success: false,
        error: session.error || "Unauthorized: Valid seller session required to upload documents.",
      };
    }

    const file = formData.get("file") as File | null;
    const bookingId = formData.get("bookingId") as string | null;
    const dispatchId = formData.get("dispatchId") as string | null;

    if (!file || !dispatchId) {
      return { success: false, error: "File and Dispatch ID are required." };
    }

    // Client-side & server-side size check (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      return { success: false, error: "File size exceeds 5MB limit." };
    }

    // MIME type check
    const allowedTypes = ["application/pdf", "image/jpeg", "image/png"];
    const isExtensionValid = [".pdf", ".jpg", ".jpeg", ".png"].some((ext) =>
      file.name.toLowerCase().endsWith(ext)
    );
    if (!allowedTypes.includes(file.type) && !isExtensionValid) {
      return {
        success: false,
        error: "Invalid file format. Only PDF, JPG, and PNG documents are supported.",
      };
    }

    // Verify Dispatch Record & Tenant Ownership
    const dispatchRecord = await db.query.dispatches.findFirst({
      where: eq(dispatches.id, dispatchId),
    });

    if (!dispatchRecord) {
      return { success: false, error: "Dispatch record not found." };
    }

    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" || session.data.user.role === "ADMIN";

    const dealRecord = await db.query.deals.findFirst({
      where: eq(deals.id, dispatchRecord.dealId),
    });

    const isAuthorized =
      isPlatformAdmin ||
      dispatchRecord.sellerId === session.data.user.id ||
      dealRecord?.sellerId === sellerCompanyId ||
      dealRecord?.sellerId === session.data.user.id;

    if (!isAuthorized) {
      return {
        success: false,
        error: "Unauthorized: You do not have permission to upload documents for this dispatch.",
      };
    }

    // Format sanitized storage path
    const safeBookingId = (bookingId || dealRecord?.id || "dispatch").replace(/[^a-zA-Z0-9_-]/g, "_");
    const cleanFileName = file.name.replace(/[^a-zA-Z0-9.-]/g, "_");
    const filePath = `${safeBookingId}/${dispatchId}/${Date.now()}_${cleanFileName}`;

    // Convert file to Buffer for server-side upload
    const arrayBuffer = await file.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    const supabase = await createClient();
    const { data, error } = await supabase.storage
      .from("brokerbridge_documents")
      .upload(filePath, buffer, {
        contentType: file.type || "application/octet-stream",
        cacheControl: "3600",
        upsert: false,
      });

    if (error) {
      console.error("Supabase storage upload error:", error);
      return { success: false, error: error.message };
    }

    return {
      success: true,
      data: { path: data.path },
    };
  } catch (error: any) {
    console.error("uploadFulfillmentDocumentAction error:", error);
    return {
      success: false,
      error: error.message || "Failed to upload fulfillment document.",
    };
  }
}

/**
 * Server Action: Attaches an uploaded fulfillment document to a specific dispatch record (Micro-Sprint 19.3).
 * 
 * STRICT AUTHORIZATION GATE:
 * 1. Authenticates Seller session via @supabase/ssr.
 * 2. Checks tenant ownership: Verified Seller company must own the dispatch lot/deal.
 * 3. Rejects unauthorized or spoofed dispatch attachments at the query boundary.
 */
export async function attachDispatchDocumentAction(
  payload: AttachDocumentPayload
): Promise<{
  success: boolean;
  documentId?: string;
  message?: string;
  error?: string;
}> {
  try {
    // 1. Authorize Seller Session (Gated against SELLER_VIEWER)
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return {
        success: false,
        error: session.error || "Unauthorized: Valid seller session required to attach documents.",
      };
    }

    const { dispatchId, documentType, fileUrl } = payload;

    if (!dispatchId || !documentType || !fileUrl) {
      return {
        success: false,
        error: "Dispatch ID, document type, and file URL are all required.",
      };
    }

    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" || session.data.user.role === "ADMIN";

    // 2. AUTHORIZATION GATE: Verify Dispatch Ownership
    const dispatchRecord = await db.query.dispatches.findFirst({
      where: eq(dispatches.id, dispatchId),
    });

    if (!dispatchRecord) {
      return {
        success: false,
        error: "DISPATCH_NOT_FOUND: The referenced dispatch record does not exist.",
      };
    }

    // Resolve associated deal, quotation, and availability lot
    const dealRecord = await db.query.deals.findFirst({
      where: eq(deals.id, dispatchRecord.dealId),
    });

    const targetQuotationId = dealRecord
      ? dealRecord.quotationId
      : dispatchRecord.dealId;

    const quotationRecord = targetQuotationId
      ? await db.query.quotations.findFirst({
          where: eq(quotations.id, targetQuotationId),
        })
      : null;

    const lotRecord = quotationRecord?.sellerAvailabilityId
      ? await db.query.availabilities.findFirst({
          where: eq(availabilities.id, quotationRecord.sellerAvailabilityId),
        })
      : null;

    const dealSellerId = dealRecord?.sellerId;
    const lotCompanyId = lotRecord?.companyId;

    const isAuthorized =
      isPlatformAdmin ||
      dispatchRecord.sellerId === session.data.user.id ||
      dealSellerId === sellerCompanyId ||
      dealSellerId === session.data.user.id ||
      lotCompanyId === sellerCompanyId;

    if (!isAuthorized) {
      return {
        success: false,
        error: "UNAUTHORIZED_DOCUMENT_ATTACHMENT: You do not own the shipment dispatch or inventory lot referenced by this document.",
      };
    }

    // 3. Insert Record into dispatch_documents Table
    const [newDoc] = await db
      .insert(dispatchDocuments)
      .values({
        dispatchId,
        documentType,
        fileUrl,
        uploadedBy: session.data.user.id,
      })
      .returning();

    // 4. Log Immutable Audit Record into negotiation_events (if quotation exists)
    if (targetQuotationId) {
      await db.insert(negotiationEvents).values({
        requestId: targetQuotationId,
        companyId: sellerCompanyId || session.data.user.id,
        actorId: session.data.user.id,
        actionType: "DISPATCH_SUBMITTED",
        payload: {
          eventSubtype: "DOCUMENT_ATTACHED",
          documentId: newDoc.id,
          dispatchId,
          documentType,
          fileUrl,
          uploadedBy: session.data.user.name,
          uploadedAt: new Date().toISOString(),
        },
      });
    }

    // 5. System Decision Gate Audit Log Drain
    await logDecisionGateAuditEventAction({
      action: "BOOKING_MANUALLY_CONFIRMED",
      actorId: session.data.user.id,
      actorRole: "seller",
      entity: "bookings",
      entityId: newDoc.id,
      metadata: {
        stage: "DOCUMENT_ATTACHED",
        dispatchId,
        documentType,
        fileUrl,
      },
    });

    revalidatePath("/seller");
    revalidatePath("/seller/dispatch");

    return {
      success: true,
      documentId: newDoc.id,
      message: `${documentType} document successfully attached to dispatch!`,
    };
  } catch (error: any) {
    console.error("attachDispatchDocumentAction error:", error);
    return {
      success: false,
      error: error.message || "Failed to attach fulfillment document.",
    };
  }
}

/**
 * Server Action: Fetches all fulfillment documents for a specific dispatch with short-lived 15-min signed URLs.
 * Strictly verifies Seller tenant ownership before generating signed access URLs.
 */
export async function getDispatchDocumentsAction(
  dispatchId: string
): Promise<{
  success: boolean;
  data?: DispatchDocumentItem[];
  error?: string;
}> {
  try {
    const session = await verifySellerSession({ allowViewer: true });
    if (!session.success || !session.data) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    if (!dispatchId) {
      return { success: false, error: "Dispatch ID is required." };
    }

    // Verify Dispatch Record & Tenant Ownership
    const dispatchRecord = await db.query.dispatches.findFirst({
      where: eq(dispatches.id, dispatchId),
    });

    if (!dispatchRecord) {
      return { success: false, error: "Dispatch record not found." };
    }

    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" || session.data.user.role === "ADMIN";

    const dealRecord = await db.query.deals.findFirst({
      where: eq(deals.id, dispatchRecord.dealId),
    });

    const quotationRecord = dealRecord?.quotationId
      ? await db.query.quotations.findFirst({
          where: eq(quotations.id, dealRecord.quotationId),
        })
      : null;

    const lotRecord = quotationRecord?.sellerAvailabilityId
      ? await db.query.availabilities.findFirst({
          where: eq(availabilities.id, quotationRecord.sellerAvailabilityId),
        })
      : null;

    const isAuthorized =
      isPlatformAdmin ||
      dispatchRecord.sellerId === session.data.user.id ||
      dealRecord?.sellerId === sellerCompanyId ||
      dealRecord?.sellerId === session.data.user.id ||
      lotRecord?.companyId === sellerCompanyId;

    if (!isAuthorized) {
      return {
        success: false,
        error: "Unauthorized: You do not have permission to view documents for this dispatch.",
      };
    }

    const docs = await db.query.dispatchDocuments.findMany({
      where: eq(dispatchDocuments.dispatchId, dispatchId),
      orderBy: desc(dispatchDocuments.createdAt),
    });

    const supabase = await createClient();

    // Generate short-lived signed URLs (15 minutes = 900 seconds)
    const docsWithSignedUrls: DispatchDocumentItem[] = await Promise.all(
      docs.map(async (doc) => {
        let signedUrl: string | null = null;
        try {
          const { data, error } = await supabase.storage
            .from("brokerbridge_documents")
            .createSignedUrl(doc.fileUrl, 900);

          if (!error && data?.signedUrl) {
            signedUrl = data.signedUrl;
          }
        } catch (e) {
          console.error("Failed to generate signed URL for doc:", doc.id, e);
        }

        const pathParts = doc.fileUrl.split("/");
        const rawFileName = pathParts[pathParts.length - 1] || "document.pdf";
        const fileName = rawFileName.replace(/^\d+_/, "");

        return {
          id: doc.id,
          dispatchId: doc.dispatchId,
          documentType: doc.documentType,
          fileUrl: doc.fileUrl,
          signedUrl,
          uploadedBy: doc.uploadedBy,
          createdAt: doc.createdAt.toISOString(),
          fileName,
        };
      })
    );

    return {
      success: true,
      data: docsWithSignedUrls,
    };
  } catch (error: any) {
    console.error("getDispatchDocumentsAction error:", error);
    return {
      success: false,
      error: error.message || "Failed to load dispatch documents.",
    };
  }
}

/**
 * Server Action: Deletes an attached fulfillment document from the database and storage vault.
 * Strictly verifies company tenant ownership and mutation permissions.
 */
export async function deleteDispatchDocumentAction(
  documentId: string
): Promise<{
  success: boolean;
  message?: string;
  error?: string;
}> {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: "Unauthorized: Valid seller session required." };
    }

    if (!documentId) {
      return { success: false, error: "Document ID is required." };
    }

    const docRecord = await db.query.dispatchDocuments.findFirst({
      where: eq(dispatchDocuments.id, documentId),
    });

    if (!docRecord) {
      return { success: false, error: "Document record not found." };
    }

    const dispatchRecord = await db.query.dispatches.findFirst({
      where: eq(dispatches.id, docRecord.dispatchId),
    });

    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" || session.data.user.role === "ADMIN";

    const dealRecord = dispatchRecord
      ? await db.query.deals.findFirst({
          where: eq(deals.id, dispatchRecord.dealId),
        })
      : null;

    const isAuthorizedTenant =
      isPlatformAdmin ||
      (dispatchRecord &&
        (dispatchRecord.sellerId === session.data.user.id ||
          dealRecord?.sellerId === sellerCompanyId ||
          dealRecord?.sellerId === session.data.user.id ||
          docRecord.uploadedBy === session.data.user.id));

    if (!isAuthorizedTenant) {
      return {
        success: false,
        error: "Unauthorized: You do not have permission to remove this document.",
      };
    }

    // Delete from Supabase Storage
    const supabase = await createClient();
    await supabase.storage.from("brokerbridge_documents").remove([docRecord.fileUrl]);

    // Delete from Database
    await db
      .delete(dispatchDocuments)
      .where(eq(dispatchDocuments.id, documentId));

    revalidatePath("/seller");
    revalidatePath("/seller/dispatch");

    return {
      success: true,
      message: "Fulfillment document successfully removed.",
    };
  } catch (error: any) {
    console.error("deleteDispatchDocumentAction error:", error);
    return {
      success: false,
      error: error.message || "Failed to delete document.",
    };
  }
}
