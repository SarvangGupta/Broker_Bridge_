'use server';

import { db } from '@/src/server/db';
import { requirements, requirementDocuments } from '@/src/server/db/schema';
import { eq, and, sql } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';

import { 
  STANDARD_DOCUMENT_TYPES, 
  type StandardDocumentType, 
  type BuyerDocumentActionResponse 
} from '@/src/types/requirement-document-types';

/**
 * Micro-Sprint 34.3: Save Mandatory Document Checklist for a Requirement
 * 
 * Enforces authenticated Buyer session, requirement ownership,
 * and status integrity ('Draft' | 'Open').
 * Replaces existing document requirements atomically in a transaction.
 * 
 * @param requirementId UUID of the requirement
 * @param documents Array of standardized document type names
 */
export async function saveRequirementDocumentsAction(
  requirementId: string,
  documents: string[]
): Promise<BuyerDocumentActionResponse<{ count: number }>> {
  try {
    // 1. Authenticate session & enforce BUYER_ADMIN role
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

    // 2. Fetch requirement and verify organization ownership
    const reqResults = await db
      .select()
      .from(requirements)
      .where(and(eq(requirements.id, requirementId), eq(requirements.companyId, sessionCompanyId)));

    if (!reqResults.length) {
      return { success: false, error: 'Requirement not found or access denied.' };
    }

    const requirement = reqResults[0];

    // 3. State Machine Guard: only Draft and Open requirements can have their document rules altered
    const ALLOWED_STATUSES = ['Draft', 'Open'];
    if (!ALLOWED_STATUSES.includes(requirement.status)) {
      return {
        success: false,
        error: `Cannot modify document requirements for a requirement in '${requirement.status}' status. Editing is only permitted for 'Draft' or 'Open' requirements.`,
      };
    }

    // 4. Validate documents against standardized list (Strict Guardrail: No free-text)
    const validDocuments = (documents || [])
      .map((d) => String(d).trim())
      .filter((d) => (STANDARD_DOCUMENT_TYPES as readonly string[]).includes(d));

    // Deduplicate documents
    const uniqueDocuments = Array.from(new Set(validDocuments));

    // 5. DB Resilience: Ensure requirement_documents table exists
    try {
      await db.execute(sql`
        CREATE TABLE IF NOT EXISTS "requirement_documents" (
          "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
          "requirement_id" uuid NOT NULL REFERENCES "public"."requirements"("id") ON DELETE CASCADE,
          "document_type" text NOT NULL,
          "is_mandatory" boolean DEFAULT true NOT NULL,
          "created_at" timestamp DEFAULT now() NOT NULL,
          "updated_at" timestamp DEFAULT now() NOT NULL
        );
        CREATE INDEX IF NOT EXISTS "idx_req_documents_req_id" ON "requirement_documents"("requirement_id");
      `);
    } catch (tblErr) {
      // Table already created
    }

    // 6. Atomic Transaction: Delete previous rows & bulk-insert new selection
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

    // 7. Revalidate Next.js cache
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

    // Verify ownership
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
