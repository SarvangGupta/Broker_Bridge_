'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  disputes,
  deals,
  bookings,
  users,
  companies,
  dealVersions,
  dispatches,
  dispatchDocuments,
  quotations,
  requirements,
} from '@/src/server/db/schema';
import { eq, or, and, desc, inArray, sql } from 'drizzle-orm';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';

export type DisputeCategory =
  | 'Quality'
  | 'Quantity'
  | 'Delivery'
  | 'Document'
  | 'Payment'
  | 'Commercial'
  | 'Other';

export interface DisputeEvidenceDocument {
  id: string;
  documentType: string;
  fileUrl: string;
  createdAt: string;
}

export interface BrokerDisputeItem {
  id: string;
  dealId: string;
  bookingId?: string;
  bookingReference: string;
  category: DisputeCategory;
  reason: string;
  description: string;
  resolutionNotes: string | null;
  status: 'Open' | 'Under Broker Review' | 'Resolved';
  daysOpen: number;
  filedByUserId: string;
  filedByName: string;
  filedByRole: string;
  filedByCompanyName: string;
  buyerCompanyName: string;
  sellerCompanyName: string;
  commodityName: string;
  lotNumber: string;
  createdAt: string;
  resolvedAt: string | null;
  evidenceDocuments: DisputeEvidenceDocument[];
}

export interface DisputeLedgerSummary {
  totalDisputes: number;
  openDisputesCount: number;
  underReviewCount: number;
  resolvedDisputesCount: number;
}

export interface BrokerDisputeLedgerPayload {
  summary: DisputeLedgerSummary;
  disputes: BrokerDisputeItem[];
}

export interface DisputeLedgerResult {
  success: boolean;
  data?: BrokerDisputeLedgerPayload;
  error?: string;
}

/**
 * Helper to normalize raw reason string into strict PRD categories
 */
function normalizeDisputeCategory(reasonStr: string): DisputeCategory {
  const r = (reasonStr || '').toLowerCase();
  if (r.includes('quality') || r.includes('grade') || r.includes('spec') || r.includes('lab') || r.includes('coa')) {
    return 'Quality';
  }
  if (r.includes('quantity') || r.includes('weight') || r.includes('shortage') || r.includes('scale') || r.includes('weighbridge')) {
    return 'Quantity';
  }
  if (r.includes('delivery') || r.includes('transit') || r.includes('delay') || r.includes('truck') || r.includes('vehicle')) {
    return 'Delivery';
  }
  if (r.includes('document') || r.includes('invoice') || r.includes('waybill') || r.includes('lr') || r.includes('bill')) {
    return 'Document';
  }
  if (r.includes('payment') || r.includes('utr') || r.includes('bank') || r.includes('escrow') || r.includes('settlement')) {
    return 'Payment';
  }
  if (r.includes('commercial') || r.includes('price') || r.includes('rate') || r.includes('markup') || r.includes('terms')) {
    return 'Commercial';
  }
  return 'Other';
}

/**
 * Server Action: Fetches all active & historical dispute records assigned to the Broker.
 * (Micro-Sprint 28.4 - Task 1)
 *
 * STRICT GUARDRAIL:
 * Does NOT leak direct Buyer-Seller communication.
 * All evidence and notes are routed strictly through the Broker.
 */
export async function getBrokerActiveDisputesAction(): Promise<DisputeLedgerResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    // Authenticate broker / admin user profile
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

    const userId = authUser.id;
    const isPlatformAdmin = role === 'admin';

    // 1. Query disputes joined with deals, bookings, filing user & companies, and deal versions
    const joinedRows = await db
      .select({
        disputeId: disputes.id,
        disputeDealId: disputes.dealId,
        filedBy: disputes.filedBy,
        reason: disputes.reason,
        description: disputes.description,
        resolutionNotes: disputes.resolutionNotes,
        disputeStatus: disputes.status,
        disputeCreatedAt: disputes.createdAt,
        disputeResolvedAt: disputes.resolvedAt,
        // Deal
        dealId: deals.id,
        dealRequirementId: deals.requirementId,
        dealQuotationId: deals.quotationId,
        dealBuyerId: deals.buyerId,
        dealSellerId: deals.sellerId,
        dealBrokerId: deals.brokerId,
        dealStatus: deals.status,
        // Booking
        bookingId: bookings.id,
        bookingReference: bookings.bookingReference,
        lockedVersionId: bookings.lockedVersionId,
        // Filing User
        filedUserName: users.name,
        filedUserRole: users.role,
        filedUserCompanyId: users.companyId,
        // Quotation / Requirement for assignment checks
        quotationBrokerId: quotations.brokerId,
        reqBrokerId: requirements.brokerId,
        // Version
        versionSnapshot: dealVersions.snapshotPayload,
      })
      .from(disputes)
      .innerJoin(deals, eq(disputes.dealId, deals.id))
      .leftJoin(bookings, or(eq(bookings.dealId, deals.id), eq(bookings.dealId, deals.quotationId)))
      .leftJoin(users, eq(disputes.filedBy, users.id))
      .leftJoin(quotations, eq(quotations.id, deals.quotationId))
      .leftJoin(requirements, eq(requirements.id, quotations.requirementId))
      .leftJoin(dealVersions, eq(dealVersions.id, bookings.lockedVersionId))
      .orderBy(desc(disputes.createdAt));

    // 2. Strict Broker Assignment Filter (`broker_id === user.id`)
    const filteredRows = joinedRows.filter((r) => {
      if (isPlatformAdmin) return true;
      const isBrokerAssigned =
        r.dealBrokerId === userId ||
        r.quotationBrokerId === userId ||
        r.reqBrokerId === userId;
      return isBrokerAssigned;
    });

    if (!filteredRows.length) {
      return {
        success: true,
        data: {
          summary: {
            totalDisputes: 0,
            openDisputesCount: 0,
            underReviewCount: 0,
            resolvedDisputesCount: 0,
          },
          disputes: [],
        },
      };
    }

    // Collect IDs for subqueries
    const dealIds = Array.from(new Set(filteredRows.map((r) => r.dealId).filter(Boolean))) as string[];
    const companyIds = Array.from(
      new Set(
        filteredRows
          .flatMap((r) => [r.dealBuyerId, r.dealSellerId, r.filedUserCompanyId])
          .filter(Boolean)
      )
    ) as string[];

    // 3. Batch fetch company names and evidence documents
    const [fetchedCompanies, allDispatches] = await Promise.all([
      companyIds.length > 0
        ? db.query.companies.findMany({
            where: inArray(companies.id, companyIds),
          })
        : Promise.resolve([]),
      dealIds.length > 0
        ? db.query.dispatches.findMany({
            where: inArray(dispatches.dealId, dealIds),
          })
        : Promise.resolve([]),
    ]);

    const companyMap = new Map(fetchedCompanies.map((c) => [c.id, c.name || 'Enterprise']));

    const dispatchIds = allDispatches.map((d) => d.id);
    const docs = dispatchIds.length > 0
      ? await db.query.dispatchDocuments.findMany({
          where: inArray(dispatchDocuments.dispatchId, dispatchIds),
        })
      : [];

    const dealDocsMap = new Map<string, DisputeEvidenceDocument[]>();
    for (const d of allDispatches) {
      const matchDocs = docs.filter((doc) => doc.dispatchId === d.id);
      const existing = dealDocsMap.get(d.dealId) || [];
      for (const m of matchDocs) {
        existing.push({
          id: m.id,
          documentType: m.documentType,
          fileUrl: m.fileUrl,
          createdAt: m.createdAt.toISOString(),
        });
      }
      dealDocsMap.set(d.dealId, existing);
    }

    // 4. Construct payload items
    const now = new Date();
    const disputeItems: BrokerDisputeItem[] = [];

    let openDisputesCount = 0;
    let underReviewCount = 0;
    let resolvedDisputesCount = 0;

    for (const r of filteredRows) {
      const snap = (r.versionSnapshot || {}) as any;
      const createdAt = r.disputeCreatedAt ? new Date(r.disputeCreatedAt) : new Date();

      const diffTime = Math.abs(now.getTime() - createdAt.getTime());
      const daysOpen = Math.max(1, Math.floor(diffTime / (1000 * 60 * 60 * 24)));

      const category = normalizeDisputeCategory(r.reason);

      let status: 'Open' | 'Under Broker Review' | 'Resolved' = 'Open';
      const sLower = (r.disputeStatus || '').toLowerCase();
      if (sLower.includes('resolve') || sLower.includes('closed')) {
        status = 'Resolved';
        resolvedDisputesCount++;
      } else if (sLower.includes('review') || sLower.includes('broker')) {
        status = 'Under Broker Review';
        underReviewCount++;
      } else {
        status = 'Open';
        openDisputesCount++;
      }

      const buyerName = companyMap.get(r.dealBuyerId || '') || 'Verified Buyer Enterprise';
      const sellerName = companyMap.get(r.dealSellerId || '') || 'Verified Seller Enterprise';
      const filedCompany = companyMap.get(r.filedUserCompanyId || '') || 'Counterparty Enterprise';

      const evidenceDocs = dealDocsMap.get(r.dealId) || [];

      disputeItems.push({
        id: r.disputeId,
        dealId: r.dealId,
        bookingId: r.bookingId || undefined,
        bookingReference: r.bookingReference || `BKG-DEAL-${r.dealId.substring(0, 6).toUpperCase()}`,
        category,
        reason: r.reason || 'Operational Exception',
        description: r.description || 'No detailed issue description was submitted by counterparty.',
        resolutionNotes: r.resolutionNotes || null,
        status,
        daysOpen,
        filedByUserId: r.filedBy,
        filedByName: r.filedUserName || 'Enterprise Representative',
        filedByRole: (r.filedUserRole || 'Client').toUpperCase(),
        filedByCompanyName: filedCompany,
        buyerCompanyName: buyerName,
        sellerCompanyName: sellerName,
        commodityName: snap.commodityName || 'Agricultural Commodity',
        lotNumber: snap.lotNumber || 'N/A',
        createdAt: createdAt.toISOString(),
        resolvedAt: r.disputeResolvedAt ? new Date(r.disputeResolvedAt).toISOString() : null,
        evidenceDocuments: evidenceDocs,
      });
    }

    return {
      success: true,
      data: {
        summary: {
          totalDisputes: disputeItems.length,
          openDisputesCount,
          underReviewCount,
          resolvedDisputesCount,
        },
        disputes: disputeItems,
      },
    };
  } catch (err: any) {
    console.error('Error fetching broker active disputes:', err);
    return {
      success: false,
      error: err.message || 'Failed to fetch broker active disputes.',
    };
  }
}

const resolveDisputeInputSchema = z.object({
  disputeId: z.string().uuid('Valid dispute ID is required'),
  resolutionNotes: z.string().min(5, 'Resolution notes must be at least 5 characters'),
  finalDealStatus: z.enum(['Closed', 'Broker Finalized', 'Disputed']).default('Broker Finalized').optional(),
});

export type ResolveDisputeInput = z.infer<typeof resolveDisputeInputSchema>;

/**
 * Server Action: Resolves a dispute record and logs broker mediation steps.
 * (Micro-Sprint 28.4 - Task 1)
 */
export async function resolveDisputeAction(
  input: ResolveDisputeInput
): Promise<{ success: boolean; data?: any; error?: string; message?: string }> {
  try {
    let authUser: any = null;
    try {
      const supabase = await createClient();
      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser();
      if (!authError && user) authUser = user;
    } catch (e) {
      authUser = null;
    }

    if (!authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    const validation = resolveDisputeInputSchema.safeParse(input);
    if (!validation.success) {
      const firstErr = validation.error.errors[0]?.message || 'Invalid dispute resolution input';
      return { success: false, error: firstErr };
    }

    const data = validation.data;

    // Verify broker / admin role
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

    // Execute atomic resolution update
    const updatedDispute = await db.transaction(async (tx) => {
      const existingDisputes = await tx.select().from(disputes).where(eq(disputes.id, data.disputeId));
      if (!existingDisputes.length) throw new Error('Dispute record not found');

      const target = existingDisputes[0];

      // Verify that this dispute's deal belongs to the caller broker
      const dealRecord = await tx.query.deals.findFirst({
        where: eq(deals.id, target.dealId),
      });

      const quotationRecord = dealRecord?.quotationId
        ? await tx.query.quotations.findFirst({
            where: eq(quotations.id, dealRecord.quotationId),
          })
        : null;

      const isAuthorizedBroker =
        role === 'admin' ||
        dealRecord?.brokerId === authUser.id ||
        quotationRecord?.brokerId === authUser.id;

      if (!isAuthorizedBroker) {
        throw new Error('Forbidden: You are not authorized to resolve disputes for this deal.');
      }

      // Update dispute record to Resolved
      const [resolved] = await tx
        .update(disputes)
        .set({
          status: 'Resolved',
          resolutionNotes: data.resolutionNotes.trim(),
          resolvedAt: new Date(),
        })
        .where(eq(disputes.id, data.disputeId))
        .returning();

      // Optionally update parent deal status back to normal / closed
      await tx
        .update(deals)
        .set({
          status: data.finalDealStatus || 'Broker Finalized',
          ...(data.finalDealStatus === 'Closed' ? { closedAt: new Date() } : {}),
        })
        .where(eq(deals.id, target.dealId));

      return resolved;
    });

    revalidatePath('/broker/more/disputes');
    revalidatePath('/broker/orders');

    return {
      success: true,
      data: updatedDispute,
      message: 'Dispute successfully resolved and mediation steps logged.',
    };
  } catch (err: any) {
    console.error('Error resolving dispute:', err);
    return {
      success: false,
      error: err.message || 'Failed to resolve dispute.',
    };
  }
}
