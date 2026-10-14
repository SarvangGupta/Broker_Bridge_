'use server';

import { db } from '@/src/server/db';
import {
  bookings,
  deals,
  quotations,
  requirements,
  requirementDocuments,
  dispatches,
  dispatchDocuments,
  invoices,
  labTests,
} from '@/src/server/db/schema';
import { eq, or, and, desc, sql } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';
import { createClient } from '@/lib/supabase/server';
import {
  STANDARD_DOCUMENT_TYPES,
  type StandardDocumentType,
  type BuyerDocumentActionResponse,
} from '@/src/types/requirement-document-types';
import {
  BuyerDocumentComplianceItem,
  BuyerDocumentMatrixData,
  BuyerDocumentMatrixResponse,
  DocumentComplianceStatus,
} from '@/src/types/buyer-document-types';

/**
 * Normalizes document type strings for robust cross-table matrix comparison.
 */
function normalizeDocType(type: string): string {
  if (!type) return 'other';
  const norm = type.toLowerCase().replace(/[^a-z0-9]/g, '');
  if (norm.includes('lorry') || norm === 'lr') return 'lr';
  if (norm.includes('invoice') || norm.includes('taxinv')) return 'invoice';
  if (norm.includes('weigh') || norm.includes('scale')) return 'weighmentslip';
  if (norm.includes('eway') || norm.includes('ewaybill')) return 'ewaybill';
  if (norm.includes('analysis') || norm === 'coa' || norm.includes('lab') || norm.includes('quality')) return 'coa';
  if (norm.includes('photo') || norm.includes('loading')) return 'loadingphoto';
  if (norm.includes('challan') || norm.includes('delivery')) return 'deliverychallan';
  if (norm.includes('insurance')) return 'insurance';
  return norm;
}

/**
 * Returns a human-friendly display label and categorized classification.
 */
function getDocumentDisplayMeta(type: string): {
  displayName: string;
  category: 'Commercial' | 'Logistics' | 'Quality' | 'Statutory' | 'Other';
} {
  const norm = normalizeDocType(type);
  switch (norm) {
    case 'coa':
      return { displayName: 'Certificate of Analysis (COA)', category: 'Quality' };
    case 'lr':
      return { displayName: 'Lorry Receipt (LR / Consignment Note)', category: 'Logistics' };
    case 'weighmentslip':
      return { displayName: 'Electronic Weighbridge Slip', category: 'Logistics' };
    case 'invoice':
      return { displayName: 'Commercial / Tax Invoice', category: 'Commercial' };
    case 'ewaybill':
      return { displayName: 'Statutory E-Way Bill', category: 'Statutory' };
    case 'loadingphoto':
      return { displayName: 'Vehicle Loading & Seal Photo', category: 'Logistics' };
    case 'deliverychallan':
      return { displayName: 'Delivery Challan & Dispatch Gate Pass', category: 'Logistics' };
    case 'insurance':
      return { displayName: 'Transit Cargo Insurance Policy', category: 'Commercial' };
    default:
      return { displayName: type || 'Fulfillment Document', category: 'Other' };
  }
}

/**
 * Task 1 (Micro-Sprint 39.2): Fetches the Buyer Document Matrix comparing
 * the original requirement checklist against actual seller dispatch documents.
 * 
 * Strict Security Guardrails:
 * 1. Read-Only Boundary: The Buyer NEVER uploads documents here; strictly tracks compliance.
 * 2. Multi-Tenant Isolation: Authenticates session and validates that calling Buyer company owns the booking.
 * 3. Short-lived signed URLs: 15-minute expiration with strict path traversal defenses.
 * 4. Zero Seller PII: No phone numbers, emails, or internal seller pricing exposed.
 */
export async function getBuyerDocumentMatrixAction(
  bookingIdOrRef: string
): Promise<BuyerDocumentMatrixResponse> {
  try {
    if (!bookingIdOrRef || typeof bookingIdOrRef !== 'string' || bookingIdOrRef.trim() === '') {
      return { success: false, error: 'Booking ID or Reference is required.' };
    }

    const rawInput = bookingIdOrRef.trim();

    // 1. Development & Demo Mock Dataset Fallback
    if (
      rawInput.startsWith('demo-') ||
      rawInput.startsWith('sample-') ||
      rawInput.startsWith('mock-') ||
      rawInput === 'demo' ||
      rawInput === 'BKG-2026-1042' ||
      rawInput === 'BKG-2026-8812' ||
      rawInput === 'BKG-2026-8790' ||
      rawInput === 'BKG-DEMO'
    ) {
      return {
        success: true,
        data: getMockDocumentMatrixData(rawInput),
      };
    }

    // 2. Authenticate Buyer Session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data?.companyId) {
      return {
        success: false,
        error: sessionRes.error || 'Unauthorized: Valid Buyer session required.',
      };
    }

    const { companyId: buyerCompanyId } = sessionRes.data;
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(rawInput);

    // 3. Resolve Booking & Deal Records
    let bookingRecord = await db.query.bookings.findFirst({
      where: eq(bookings.bookingReference, rawInput.toUpperCase()),
    });

    if (!bookingRecord && isUuid) {
      bookingRecord = await db.query.bookings.findFirst({
        where: or(eq(bookings.id, rawInput), eq(bookings.dealId, rawInput)),
      });
    }

    let dealRecord: any = null;
    if (bookingRecord) {
      dealRecord = await db.query.deals.findFirst({
        where: eq(deals.id, bookingRecord.dealId),
      });
    } else if (isUuid) {
      dealRecord = await db.query.deals.findFirst({
        where: eq(deals.id, rawInput),
      });
    }

    if (!dealRecord) {
      return {
        success: false,
        error: 'Order or Booking record not found.',
      };
    }

    // Resolve requirement record
    const requirementRecord = dealRecord.requirementId
      ? await db.query.requirements.findFirst({
          where: eq(requirements.id, dealRecord.requirementId),
        })
      : null;

    // Strict Tenant Isolation Check
    const isAuthorized =
      dealRecord.buyerId === buyerCompanyId ||
      (requirementRecord && requirementRecord.companyId === buyerCompanyId);

    if (!isAuthorized) {
      return {
        success: false,
        error: 'Access denied: You do not have permission to view documents for this booking under tenant isolation rules.',
      };
    }

    // 4. Query 1: Fetch Original Required Checklist from requirement_documents
    const requiredChecklist = requirementRecord
      ? await db.query.requirementDocuments.findMany({
          where: eq(requirementDocuments.requirementId, requirementRecord.id),
        })
      : [];

    // 5. Query 2: Fetch Actual Uploaded Files from dispatches & dispatch_documents
    const dispatchList = await db.query.dispatches.findMany({
      where: eq(dispatches.dealId, dealRecord.id),
      orderBy: [desc(dispatches.createdAt)],
    });

    const activeDispatch = dispatchList[0] || null;
    const dispatchStatus = activeDispatch?.status || 'Pending Dispatch';
    const isDispatchedOrInTransit = ['Dispatched', 'In Transit', 'Delivered'].includes(dispatchStatus);

    let uploadedDocs: any[] = [];
    if (activeDispatch) {
      uploadedDocs = await db.query.dispatchDocuments.findMany({
        where: eq(dispatchDocuments.dispatchId, activeDispatch.id),
        orderBy: [desc(dispatchDocuments.createdAt)],
      });
    }

    // Also check for tax invoices in invoices table
    const invoiceRecord = await db.query.invoices.findFirst({
      where: eq(invoices.dealId, dealRecord.id),
    });

    // Also check for laboratory COA in lab_tests table
    let labTestRecord: any = null;
    if (dealRecord.quotationId) {
      const q = await db.query.quotations.findFirst({
        where: eq(quotations.id, dealRecord.quotationId),
      });
      if (q?.sellerAvailabilityId) {
        labTestRecord = await db.query.labTests.findFirst({
          where: eq(labTests.availabilityId, q.sellerAvailabilityId),
          orderBy: [desc(labTests.createdAt)],
        });
      }
    }

    // 6. Server-Side Matrix Mapping: Compare Query 1 and Query 2 by normalized document_type
    const supabase = await createClient();
    const documentItems: BuyerDocumentComplianceItem[] = [];
    const matchedUploadedIds = new Set<string>();

    // A. Map from Required Checklist (Query 1)
    for (const reqDoc of requiredChecklist) {
      const normReq = normalizeDocType(reqDoc.documentType);
      const meta = getDocumentDisplayMeta(reqDoc.documentType);

      // Look for match in uploaded dispatch_documents
      let matchedUpload = uploadedDocs.find(
        (u) => !matchedUploadedIds.has(u.id) && normalizeDocType(u.documentType) === normReq
      );

      // If matching COA, check labTests fallback
      let matchedFileUrl = matchedUpload?.fileUrl || null;
      let matchedFileId = matchedUpload?.id || null;
      let matchedCreatedAt = matchedUpload?.createdAt ? matchedUpload.createdAt.toISOString() : null;

      if (!matchedFileUrl && normReq === 'coa' && labTestRecord?.fileUrl) {
        matchedFileUrl = labTestRecord.fileUrl;
        matchedFileId = labTestRecord.id;
        matchedCreatedAt = labTestRecord.createdAt ? labTestRecord.createdAt.toISOString() : null;
      }

      // If matching Invoice, check invoices table fallback
      if (!matchedFileUrl && normReq === 'invoice' && invoiceRecord?.fileUrl) {
        matchedFileUrl = invoiceRecord.fileUrl;
        matchedFileId = invoiceRecord.id;
        matchedCreatedAt = invoiceRecord.createdAt ? invoiceRecord.createdAt.toISOString() : null;
      }

      if (matchedUpload) {
        matchedUploadedIds.add(matchedUpload.id);
      }

      // Determine Document Compliance Status
      let status: DocumentComplianceStatus = 'Required';
      let statusDescription = 'Pending dispatch loading';
      let signedUrl: string | null = null;
      let fileName: string | null = null;

      if (matchedFileUrl) {
        // File exists
        fileName = matchedFileUrl.split('/').pop() || 'document.pdf';

        // Check if verified by Broker Desk
        const isVerified =
          (matchedUpload && (matchedUpload as any).isVerified === true) ||
          (normReq === 'coa' && labTestRecord?.status === 'Verified') ||
          (normReq === 'invoice' && invoiceRecord?.status === 'Confirmed') ||
          dealRecord.status === 'Delivered';

        status = isVerified ? 'Verified' : 'Received';
        statusDescription = isVerified
          ? 'Verified & approved by Broker Desk'
          : 'Uploaded by Seller, pending Broker audit';

        // Generate 15-minute short-lived signed URL
        signedUrl = await generateSafeSignedUrl(supabase, matchedFileUrl);
      } else {
        // File does not exist yet
        if (isDispatchedOrInTransit) {
          status = 'Missing';
          statusDescription = 'Dispatched without mandatory document upload';
        } else {
          status = 'Required';
          statusDescription = 'Contractual requirement due upon vehicle loading';
        }
      }

      documentItems.push({
        id: matchedFileId || reqDoc.id,
        documentType: reqDoc.documentType,
        displayName: meta.displayName,
        category: meta.category,
        isMandatory: reqDoc.isMandatory ?? true,
        status,
        statusDescription,
        fileId: matchedFileId,
        fileName,
        fileUrl: matchedFileUrl,
        signedUrl,
        uploadedAt: matchedCreatedAt,
        dispatchId: activeDispatch?.id || null,
      });
    }

    // B. Include any additional uploaded documents not in the original checklist
    for (const upDoc of uploadedDocs) {
      if (!matchedUploadedIds.has(upDoc.id)) {
        const meta = getDocumentDisplayMeta(upDoc.documentType);
        const fileName = upDoc.fileUrl.split('/').pop() || 'document.pdf';
        const signedUrl = await generateSafeSignedUrl(supabase, upDoc.fileUrl);

        documentItems.push({
          id: upDoc.id,
          documentType: upDoc.documentType,
          displayName: meta.displayName,
          category: meta.category,
          isMandatory: false,
          status: 'Received',
          statusDescription: 'Supplementary fulfillment evidence uploaded by Seller',
          fileId: upDoc.id,
          fileName,
          fileUrl: upDoc.fileUrl,
          signedUrl,
          uploadedAt: upDoc.createdAt ? upDoc.createdAt.toISOString() : null,
          dispatchId: activeDispatch?.id || null,
        });
      }
    }

    // 7. Calculate Aggregated Matrix Stats
    const totalRequired = documentItems.filter((d) => d.isMandatory).length;
    const totalUploaded = documentItems.filter((d) => d.status === 'Verified' || d.status === 'Received').length;
    const totalVerified = documentItems.filter((d) => d.status === 'Verified').length;
    const totalMissing = documentItems.filter((d) => d.status === 'Missing').length;

    const compliancePercentage = totalRequired > 0
      ? Math.round((totalVerified / totalRequired) * 100)
      : (totalUploaded > 0 ? 100 : 0);

    const isFullyCompliant = totalRequired > 0 ? totalVerified >= totalRequired : totalMissing === 0;

    const matrixData: BuyerDocumentMatrixData = {
      bookingId: bookingRecord ? bookingRecord.bookingReference : rawInput,
      dealId: dealRecord.id,
      dispatchStatus,
      dispatchReference: activeDispatch ? `DSP-${activeDispatch.id.substring(0, 8).toUpperCase()}` : null,
      totalRequired,
      totalUploaded,
      totalVerified,
      totalMissing,
      compliancePercentage,
      isFullyCompliant,
      documents: documentItems,
      lastUpdated: new Date().toISOString(),
      disclaimer: 'All fulfillment documents are audited and sealed by the Broker Deal Desk before release to the Buyer. Read-only audit records are retained for statutory GST compliance.',
    };

    return {
      success: true,
      data: matrixData,
    };
  } catch (err: any) {
    console.error('getBuyerDocumentMatrixAction error:', err);
    return {
      success: false,
      error: err.message || 'Failed to retrieve document compliance matrix.',
    };
  }
}

/**
 * Task 3 (Micro-Sprint 39.2): Generates an on-demand 15-minute signed URL
 * for any verified document in the Buyer Document Vault.
 */
export async function getBuyerDocumentSignedUrlAction(
  bookingIdOrRef: string,
  filePathOrId: string
): Promise<{ success: boolean; data?: { signedUrl: string }; error?: string }> {
  try {
    if (!bookingIdOrRef || !filePathOrId) {
      return { success: false, error: 'Booking reference and document path are required.' };
    }

    const rawInput = bookingIdOrRef.trim();

    // Support mock preview paths
    if (
      rawInput.startsWith('demo-') ||
      rawInput.startsWith('sample-') ||
      rawInput.startsWith('mock-') ||
      rawInput === 'demo' ||
      rawInput === 'BKG-2026-1042' ||
      rawInput === 'BKG-2026-8812' ||
      rawInput === 'BKG-2026-8790' ||
      rawInput === 'BKG-DEMO'
    ) {
      return {
        success: true,
        data: {
          signedUrl: `https://brokerbridge.internal/secure-vault/${encodeURIComponent(filePathOrId)}`,
        },
      };
    }

    // Authenticate session
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data?.companyId) {
      return { success: false, error: 'Unauthorized: Valid Buyer session required.' };
    }

    // Verify matrix ownership
    const matrixRes = await getBuyerDocumentMatrixAction(rawInput);
    if (!matrixRes.success || !matrixRes.data) {
      return { success: false, error: matrixRes.error || 'Booking document vault not accessible.' };
    }

    const doc = matrixRes.data.documents.find(
      (d) => d.fileUrl === filePathOrId || d.id === filePathOrId || d.fileId === filePathOrId
    );

    if (!doc || !doc.fileUrl) {
      return { success: false, error: 'Requested document not found in your authorized vault.' };
    }

    // Path traversal defense
    if (doc.fileUrl.includes('..') || doc.fileUrl.includes('\\') || doc.fileUrl.includes('\0')) {
      return { success: false, error: 'Invalid document file path format.' };
    }

    const supabase = await createClient();
    const signedUrl = await generateSafeSignedUrl(supabase, doc.fileUrl);

    if (!signedUrl) {
      return { success: false, error: 'Failed to generate temporary document preview link.' };
    }

    return {
      success: true,
      data: { signedUrl },
    };
  } catch (err: any) {
    console.error('getBuyerDocumentSignedUrlAction error:', err);
    return {
      success: false,
      error: err.message || 'Failed to retrieve document link.',
    };
  }
}

/**
 * Safely generates short-lived signed URLs from Supabase storage buckets.
 */
async function generateSafeSignedUrl(supabase: any, fileUrl: string): Promise<string | null> {
  if (!fileUrl) return null;

  // Path Traversal Defense
  if (fileUrl.includes('..') || fileUrl.includes('\\') || fileUrl.includes('\0')) {
    console.warn('Blocked path traversal attempt in document fileUrl:', fileUrl);
    return null;
  }

  try {
    // Determine bucket: lab evidence vs fulfillment documents
    const isLab = fileUrl.includes('lab-evidence') || fileUrl.includes('COA');
    const bucket = isLab ? 'brokerbridge_lab_evidence' : 'brokerbridge_documents';

    const { data, error } = await supabase.storage.from(bucket).createSignedUrl(fileUrl, 900);
    if (!error && data?.signedUrl) {
      return data.signedUrl;
    }

    // Fallback attempt to alternate bucket if first fails
    const fallbackBucket = isLab ? 'brokerbridge_documents' : 'fulfillment_documents';
    const altRes = await supabase.storage.from(fallbackBucket).createSignedUrl(fileUrl, 900);
    if (!altRes.error && altRes.data?.signedUrl) {
      return altRes.data.signedUrl;
    }
  } catch (e) {
    console.warn('Safe signed URL generation error for file:', fileUrl, e);
  }

  return null;
}

/**
 * Mock data generator for testing and seamless development harness.
 */
function getMockDocumentMatrixData(bookingId: string): BuyerDocumentMatrixData {
  const isDelivered = bookingId === 'BKG-2026-8790';
  const isWheat = bookingId === 'BKG-2026-8812';

  if (isWheat) {
    const documents: BuyerDocumentComplianceItem[] = [
      {
        id: 'doc-w-coa',
        documentType: 'Certificate of Analysis',
        displayName: 'Certificate of Analysis (COA)',
        category: 'Quality',
        isMandatory: true,
        status: 'Verified',
        statusDescription: 'Verified & certified by SGS India Agri-Testing Laboratory',
        fileId: 'file-w-coa',
        fileName: 'NABL_COA_Malwa_Wheat_9921.pdf',
        fileUrl: 'lab-evidence/BKG-2026-8812/COA_Malwa_Wheat.pdf',
        signedUrl: 'https://brokerbridge.internal/secure-vault/COA_Malwa_Wheat.pdf',
        uploadedAt: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString(),
        verifiedAt: new Date(Date.now() - 1000 * 60 * 60 * 20).toISOString(),
        dispatchId: 'DSP-2026-8812',
      },
      {
        id: 'doc-w-lr',
        documentType: 'Lorry Receipt',
        displayName: 'Lorry Receipt (LR / Consignment Note)',
        category: 'Logistics',
        isMandatory: true,
        status: 'Verified',
        statusDescription: 'Consignment verified with carrier Navkar Bulk Logistics',
        fileId: 'file-w-lr',
        fileName: 'Lorry_Receipt_LR-8821.pdf',
        fileUrl: 'dispatches/BKG-2026-8812/LR.pdf',
        signedUrl: 'https://brokerbridge.internal/secure-vault/Lorry_Receipt_LR-8821.pdf',
        uploadedAt: new Date(Date.now() - 1000 * 60 * 60 * 22).toISOString(),
        verifiedAt: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
        dispatchId: 'DSP-2026-8812',
      },
      {
        id: 'doc-w-weigh',
        documentType: 'Weighment Slip',
        displayName: 'Electronic Weighbridge Slip',
        category: 'Logistics',
        isMandatory: true,
        status: 'Verified',
        statusDescription: 'Indore Agro-Logistic Terminal scale certificate (Net: 50.00 MT)',
        fileId: 'file-w-weigh',
        fileName: 'Electronic_Weighbridge_Slip_50MT.pdf',
        fileUrl: 'dispatches/BKG-2026-8812/Weighment_Slip.pdf',
        signedUrl: 'https://brokerbridge.internal/secure-vault/Electronic_Weighbridge_Slip_50MT.pdf',
        uploadedAt: new Date(Date.now() - 1000 * 60 * 60 * 22).toISOString(),
        verifiedAt: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
        dispatchId: 'DSP-2026-8812',
      },
      {
        id: 'doc-w-eway',
        documentType: 'E-Way Bill',
        displayName: 'Statutory E-Way Bill',
        category: 'Statutory',
        isMandatory: true,
        status: 'Verified',
        statusDescription: 'GST portal generation authenticated (EWB #88210941203)',
        fileId: 'file-w-eway',
        fileName: 'EWay_Bill_88210941203.pdf',
        fileUrl: 'dispatches/BKG-2026-8812/Eway_Bill.pdf',
        signedUrl: 'https://brokerbridge.internal/secure-vault/EWay_Bill_88210941203.pdf',
        uploadedAt: new Date(Date.now() - 1000 * 60 * 60 * 21).toISOString(),
        verifiedAt: new Date(Date.now() - 1000 * 60 * 60 * 18).toISOString(),
        dispatchId: 'DSP-2026-8812',
      },
      {
        id: 'doc-w-inv',
        documentType: 'Commercial Invoice',
        displayName: 'Commercial / Tax Invoice',
        category: 'Commercial',
        isMandatory: true,
        status: 'Received',
        statusDescription: 'Seller invoice uploaded, pending Broker reconciliation with net weighment',
        fileId: 'file-w-inv',
        fileName: 'Tax_Invoice_INV-8812.pdf',
        fileUrl: 'invoices/BKG-2026-8812/Invoice.pdf',
        signedUrl: 'https://brokerbridge.internal/secure-vault/Tax_Invoice_INV-8812.pdf',
        uploadedAt: new Date(Date.now() - 1000 * 60 * 60 * 19).toISOString(),
        verifiedAt: null,
        dispatchId: 'DSP-2026-8812',
      },
    ];

    return {
      bookingId: 'BKG-2026-8812',
      dealId: 'DEAL-2026-8810',
      dispatchStatus: 'In Transit',
      dispatchReference: 'DSP-2026-8812',
      totalRequired: 5,
      totalUploaded: 5,
      totalVerified: 4,
      totalMissing: 0,
      compliancePercentage: 80,
      isFullyCompliant: false,
      documents,
      lastUpdated: new Date().toISOString(),
      disclaimer: 'All fulfillment documents are audited and sealed by the Broker Deal Desk before release to the Buyer. Read-only audit records are retained for statutory GST compliance.',
    };
  }

  // Soya Bean or Chana (Delivered)
  const isAllVerified = isDelivered;
  const documents: BuyerDocumentComplianceItem[] = [
    {
      id: 'doc-s-coa',
      documentType: 'Certificate of Analysis',
      displayName: 'Certificate of Analysis (COA)',
      category: 'Quality',
      isMandatory: true,
      status: 'Verified',
      statusDescription: 'NABL laboratory accredited quality certificate',
      fileId: 'file-s-coa',
      fileName: 'Certificate_of_Analysis_COA.pdf',
      fileUrl: `lab-evidence/${bookingId}/COA.pdf`,
      signedUrl: 'https://brokerbridge.internal/secure-vault/COA_Report.pdf',
      uploadedAt: new Date(Date.now() - 1000 * 60 * 60 * (isDelivered ? 72 : 36)).toISOString(),
      verifiedAt: new Date(Date.now() - 1000 * 60 * 60 * (isDelivered ? 58 : 18)).toISOString(),
      dispatchId: 'DSP-2026-9041',
    },
    {
      id: 'doc-s-lr',
      documentType: 'Lorry Receipt',
      displayName: 'Lorry Receipt (LR / Consignment Note)',
      category: 'Logistics',
      isMandatory: true,
      status: 'Verified',
      statusDescription: 'Transporter copy signed and sealed at loading terminal',
      fileId: 'file-s-lr',
      fileName: 'Lorry_Receipt_Signed.pdf',
      fileUrl: `dispatches/${bookingId}/LR.pdf`,
      signedUrl: 'https://brokerbridge.internal/secure-vault/Lorry_Receipt_Signed.pdf',
      uploadedAt: new Date(Date.now() - 1000 * 60 * 60 * (isDelivered ? 70 : 22)).toISOString(),
      verifiedAt: new Date(Date.now() - 1000 * 60 * 60 * (isDelivered ? 58 : 18)).toISOString(),
      dispatchId: 'DSP-2026-9041',
    },
    {
      id: 'doc-s-weigh',
      documentType: 'Weighment Slip',
      displayName: 'Electronic Weighbridge Slip',
      category: 'Logistics',
      isMandatory: true,
      status: 'Verified',
      statusDescription: 'Certified origin scale weight certificate',
      fileId: 'file-s-weigh',
      fileName: 'Weighbridge_Slip_Electronic.pdf',
      fileUrl: `dispatches/${bookingId}/Weighment_Slip.pdf`,
      signedUrl: 'https://brokerbridge.internal/secure-vault/Weighbridge_Slip_Electronic.pdf',
      uploadedAt: new Date(Date.now() - 1000 * 60 * 60 * (isDelivered ? 70 : 20)).toISOString(),
      verifiedAt: new Date(Date.now() - 1000 * 60 * 60 * (isDelivered ? 58 : 18)).toISOString(),
      dispatchId: 'DSP-2026-9041',
    },
    {
      id: 'doc-s-inv',
      documentType: 'Commercial Invoice',
      displayName: 'Commercial / Tax Invoice',
      category: 'Commercial',
      isMandatory: true,
      status: isAllVerified ? 'Verified' : 'Received',
      statusDescription: isAllVerified
        ? 'Tax invoice audited and verified against dispatch quantity'
        : 'Uploaded by Seller, pending final Broker audit',
      fileId: 'file-s-inv',
      fileName: 'Commercial_Tax_Invoice.pdf',
      fileUrl: `invoices/${bookingId}/Invoice.pdf`,
      signedUrl: 'https://brokerbridge.internal/secure-vault/Commercial_Tax_Invoice.pdf',
      uploadedAt: new Date(Date.now() - 1000 * 60 * 60 * (isDelivered ? 68 : 19)).toISOString(),
      verifiedAt: isAllVerified ? new Date(Date.now() - 1000 * 60 * 60 * 50).toISOString() : null,
      dispatchId: 'DSP-2026-9041',
    },
    {
      id: 'doc-s-challan',
      documentType: 'Delivery Challan',
      displayName: 'Delivery Challan & Dispatch Gate Pass',
      category: 'Logistics',
      isMandatory: false,
      status: isAllVerified ? 'Verified' : 'Missing',
      statusDescription: isAllVerified
        ? 'Origin gate pass stamped by loading supervisor'
        : 'Dispatched without optional gate pass upload',
      fileId: isAllVerified ? 'file-s-chal' : null,
      fileName: isAllVerified ? 'Delivery_Challan_Gate_Pass.pdf' : null,
      fileUrl: isAllVerified ? `dispatches/${bookingId}/Challan.pdf` : null,
      signedUrl: isAllVerified ? 'https://brokerbridge.internal/secure-vault/Challan.pdf' : null,
      uploadedAt: isAllVerified ? new Date(Date.now() - 1000 * 60 * 60 * 65).toISOString() : null,
      verifiedAt: isAllVerified ? new Date(Date.now() - 1000 * 60 * 60 * 50).toISOString() : null,
      dispatchId: 'DSP-2026-9041',
    },
  ];

  const totalRequired = documents.filter((d) => d.isMandatory).length;
  const totalUploaded = documents.filter((d) => d.status === 'Verified' || d.status === 'Received').length;
  const totalVerified = documents.filter((d) => d.status === 'Verified').length;
  const totalMissing = documents.filter((d) => d.status === 'Missing').length;

  return {
    bookingId: isDelivered ? 'BKG-2026-8790' : 'BKG-2026-1042',
    dealId: isDelivered ? 'DEAL-2026-7734' : 'DEAL-2026-9921',
    dispatchStatus: isDelivered ? 'Delivered' : 'In Transit',
    dispatchReference: isDelivered ? 'DSP-2026-7710' : 'DSP-2026-9041',
    totalRequired,
    totalUploaded,
    totalVerified,
    totalMissing,
    compliancePercentage: isAllVerified ? 100 : Math.round((totalVerified / totalRequired) * 100),
    isFullyCompliant: isAllVerified || totalVerified >= totalRequired,
    documents,
    lastUpdated: new Date().toISOString(),
    disclaimer: 'All fulfillment documents are audited and sealed by the Broker Deal Desk before release to the Buyer. Read-only audit records are retained for statutory GST compliance.',
  };
}

/**
 * Micro-Sprint 34.3: Save Mandatory Document Checklist for a Requirement
 */
export async function saveRequirementDocumentsAction(
  requirementId: string,
  documents: string[]
): Promise<BuyerDocumentActionResponse<{ count: number }>> {
  try {
    const session = await verifyBuyerSession();
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized: Authentication required.' };
    }

    if (session.data.role !== 'BUYER_ADMIN') {
      return { success: false, error: 'Forbidden: Insufficient privileges. BUYER_ADMIN role required.' };
    }

    const sessionCompanyId = session.data.companyId;

    if (!requirementId) {
      return { success: false, error: 'Requirement ID is required.' };
    }

    const reqResults = await db
      .select()
      .from(requirements)
      .where(and(eq(requirements.id, requirementId), eq(requirements.companyId, sessionCompanyId)));

    if (!reqResults.length) {
      return { success: false, error: 'Requirement not found or access denied.' };
    }

    const requirement = reqResults[0];

    const ALLOWED_STATUSES = ['Draft', 'Open'];
    if (!ALLOWED_STATUSES.includes(requirement.status)) {
      return {
        success: false,
        error: `Cannot modify document requirements for a requirement in '${requirement.status}' status. Editing is only permitted for 'Draft' or 'Open' requirements.`,
      };
    }

    const validDocuments = (documents || [])
      .map((d) => String(d).trim())
      .filter((d) => (STANDARD_DOCUMENT_TYPES as readonly string[]).includes(d));

    const uniqueDocuments = Array.from(new Set(validDocuments));

    await db.transaction(async (tx) => {
      await tx
        .delete(requirementDocuments)
        .where(eq(requirementDocuments.requirementId, requirementId));

      if (uniqueDocuments.length > 0) {
        await tx.insert(requirementDocuments).values(
          uniqueDocuments.map((docType) => ({
            requirementId,
            documentType: docType,
            isMandatory: true,
          }))
        );
      }
    });

    revalidatePath('/', 'layout');
    revalidatePath('/buyer/requirements');
    revalidatePath(`/buyer/requirements/${requirementId}`);

    return {
      success: true,
      data: { count: uniqueDocuments.length },
    };
  } catch (error: any) {
    console.error('saveRequirementDocumentsAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to save requirement document checklist.',
    };
  }
}

/**
 * Micro-Sprint 34.3: Fetch Required Documents for a Requirement
 */
export async function getRequirementDocumentsAction(
  requirementId: string
): Promise<BuyerDocumentActionResponse<string[]>> {
  try {
    const session = await verifyBuyerSession();
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized: Authentication required.' };
    }

    const sessionCompanyId = session.data.companyId;

    if (!requirementId) {
      return { success: false, error: 'Requirement ID is required.' };
    }

    const reqResults = await db
      .select({ id: requirements.id })
      .from(requirements)
      .where(and(eq(requirements.id, requirementId), eq(requirements.companyId, sessionCompanyId)));

    if (!reqResults.length) {
      return { success: false, error: 'Requirement not found or access denied.' };
    }

    const docs = await db
      .select({
        documentType: requirementDocuments.documentType,
        isMandatory: requirementDocuments.isMandatory,
      })
      .from(requirementDocuments)
      .where(eq(requirementDocuments.requirementId, requirementId));

    return {
      success: true,
      data: docs.map((d) => d.documentType),
    };
  } catch (error: any) {
    console.error('getRequirementDocumentsAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch requirement document checklist.',
    };
  }
}

