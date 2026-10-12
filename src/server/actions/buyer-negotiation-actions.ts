'use server';

import { revalidatePath } from 'next/cache';
import { db } from '@/src/server/db';
import { 
  quotations, 
  deals, 
  dealVersions, 
  negotiationEvents,
  requirements,
  users 
} from '@/src/server/db/schema';
import { eq, desc, asc, inArray, and, or } from 'drizzle-orm';
import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';
import { 
  filterBuyerNegotiationEvents, 
  sanitizeBuyerNegotiationPayload,
  isBuyerPermittedNegotiationEvent 
} from '@/src/server/utils/buyer-privacy-scrubber';

import { 
  type NegotiationState, 
  deriveNegotiationState 
} from '@/src/server/utils/buyer-negotiation-state';

export type { NegotiationState };

export interface SubmitBuyerCounterOfferInput {
  proposal_id?: string;
  proposalId?: string;
  counter_price?: number;
  counterPrice?: number;
  counter_quantity?: number;
  counterQuantity?: number;
  delivery_date?: string | null;
  deliveryDate?: string | null;
  payment_terms?: string | null;
  paymentTerms?: string | null;
  packaging?: string | null;
  freight?: string | null;
  inspection?: string | null;
  buyer_notes_to_broker?: string | null;
  buyerNotesToBroker?: string | null;
  expected_version_number?: number;
  expectedVersionNumber?: number;
}

export interface SubmitBuyerCounterOfferResponse {
  success: boolean;
  newVersion?: number;
  negotiationState?: NegotiationState;
  error?: string;
  message?: string;
}

export interface BuyerNegotiationChannelState {
  proposalId: string;
  targetRequestId: string;
  negotiationState: NegotiationState;
  currentVersion: number;
  activeTerms: {
    price: number;
    quantity: number;
    unitSymbol?: string;
    deliveryDate?: string | null;
    paymentTerms?: string | null;
    packaging?: string | null;
    freight?: string | null;
    inspection?: string | null;
    buyerNotes?: string | null;
    brokerNotes?: string | null;
  };
  events: Array<{
    id: string;
    actionType: string;
    actorRole: 'buyer' | 'broker';
    actorName: string;
    payload: any;
    createdAt: string;
  }>;
}

export interface GetBuyerNegotiationChannelResponse {
  success: boolean;
  data?: BuyerNegotiationChannelState;
  error?: string;
}

function parseSnapshot(raw: any): Record<string, any> {
  if (!raw) return {};
  if (typeof raw === 'object') return raw;
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch {
      return {};
    }
  }
  return {};
}

/**
 * Task 1 (Micro-Sprint 36.1): Submit Buyer Counter-Offer Action.
 * 
 * Strict Guardrails (PRD 36.1 & 36.3):
 * 1. Authenticate session via @supabase/ssr ensuring caller is BUYER_ADMIN.
 * 2. Tenant isolation: Verify proposal belongs to caller's company_id.
 * 3. Atomic transaction:
 *    - Query latest deal_versions to calculate next version_number.
 *    - Insert new immutable record into deal_versions with updated commercial snapshot.
 *    - Insert tracking event into negotiation_events (action_type: 'BUYER_COUNTER').
 *    - Update parent deals / quotations to 'Waiting for Broker'.
 * 4. Optimistic locking: abort if latest version > expected_version_number.
 */
export async function submitBuyerCounterOfferAction(
  payload: SubmitBuyerCounterOfferInput
): Promise<SubmitBuyerCounterOfferResponse> {
  try {
    // 1. Authenticate caller as BUYER_ADMIN
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized: Active Buyer session required' };
    }

    const { user, companyId: buyerCompanyId } = sessionRes.data;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    // Normalize input keys
    const proposalId = payload.proposal_id || payload.proposalId;
    const counterPrice = Number(payload.counter_price ?? payload.counterPrice);
    const counterQuantity = Number(payload.counter_quantity ?? payload.counterQuantity);
    const deliveryDate = payload.delivery_date ?? payload.deliveryDate ?? null;
    const paymentTerms = payload.payment_terms ?? payload.paymentTerms ?? null;
    const packaging = payload.packaging ?? null;
    const freight = payload.freight ?? null;
    const inspection = payload.inspection ?? null;
    const buyerNotesToBroker = payload.buyer_notes_to_broker ?? payload.buyerNotesToBroker ?? null;
    const expectedVersionNumber = payload.expected_version_number ?? payload.expectedVersionNumber;

    if (!proposalId) {
      return { success: false, error: 'Proposal ID is required.' };
    }

    if (isNaN(counterPrice) || counterPrice <= 0) {
      return { success: false, error: 'Counter price must be greater than zero.' };
    }

    if (isNaN(counterQuantity) || counterQuantity <= 0) {
      return { success: false, error: 'Counter quantity must be greater than zero.' };
    }

    // Demo/Mock ID fallback for development environments
    if (
      proposalId.startsWith('demo-') ||
      proposalId.startsWith('sample-') ||
      proposalId.startsWith('mock-') ||
      proposalId === 'demo'
    ) {
      return { 
        success: true, 
        newVersion: (expectedVersionNumber || 1) + 1,
        negotiationState: 'Waiting for Broker',
        message: 'Counter offer submitted to Broker Desk (Simulated).'
      };
    }

    // 2. Resolve target proposal / deal under strict tenant isolation
    let targetRequestId = proposalId;

    // Check quotations matching buyer company requirements
    const quoteRow = await db
      .select({
        quotation: quotations,
        requirement: requirements,
      })
      .from(quotations)
      .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
      .where(
        and(
          eq(quotations.id, proposalId),
          eq(requirements.companyId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);

    // Check deals explicitly assigned to this buyer
    let dealRow = null;
    if (!quoteRow) {
      dealRow = await db
        .select({
          deal: deals,
          requirement: requirements,
        })
        .from(deals)
        .leftJoin(requirements, eq(deals.requirementId, requirements.id))
        .where(
          and(
            or(
              eq(deals.id, proposalId),
              eq(deals.quotationId, proposalId)
            ),
            eq(deals.buyerId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);
    }

    // If still not matched, check if proposalId is a deal_versions requestId
    let directVersion = null;
    if (!quoteRow && !dealRow) {
      const vMatch = await db
        .select()
        .from(dealVersions)
        .where(or(eq(dealVersions.id, proposalId), eq(dealVersions.requestId, proposalId)))
        .limit(1)
        .then((rows) => rows[0] || null);

      if (vMatch) {
        directVersion = vMatch;
        targetRequestId = vMatch.requestId;

        // Verify company owns the parent quotation / deal
        const vQuote = await db
          .select({ quotation: quotations, requirement: requirements })
          .from(quotations)
          .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
          .where(
            and(
              eq(quotations.id, vMatch.requestId),
              eq(requirements.companyId, buyerCompanyId)
            )
          )
          .limit(1)
          .then((rows) => rows[0] || null);

        if (!vQuote) {
          const vDeal = await db
            .select({ deal: deals, requirement: requirements })
            .from(deals)
            .leftJoin(requirements, eq(deals.requirementId, requirements.id))
            .where(
              and(
                eq(deals.id, vMatch.requestId),
                eq(deals.buyerId, buyerCompanyId)
              )
            )
            .limit(1)
            .then((rows) => rows[0] || null);

          if (!vDeal) {
            return {
              success: false,
              error: 'Unauthorized: Proposal does not belong to your organization.',
            };
          }
        }
      } else {
        return {
          success: false,
          error: 'Proposal not found or access denied under organization isolation rules.',
        };
      }
    } else {
      targetRequestId = quoteRow ? quoteRow.quotation.id : dealRow!.deal.id;
    }

    const candidateRequestIds = Array.from(
      new Set(
        [
          proposalId,
          targetRequestId,
          quoteRow?.quotation.id,
          dealRow?.deal.id,
          dealRow?.deal.quotationId,
          directVersion?.requestId,
        ].filter(Boolean) as string[]
      )
    );

    // 3. Atomic Drizzle Transaction with Optimistic Concurrency & Immutability Enforcement
    let nextVersionNumber = 1;

    await db.transaction(async (tx) => {
      // Step A: Mutation Guard (Micro-Sprint 36.5 / PRD 36.5):
      // Evaluate current state and strictly reject if NOT 'Open' or 'Waiting for Buyer'
      const rawStatus = quoteRow?.quotation.status || dealRow?.deal.status || directVersion?.status || 'Open';
      const validUntil = quoteRow?.quotation.validUntil;
      const isExpired = validUntil ? new Date(validUntil) < new Date() : false;

      const latestEvents = await tx
        .select()
        .from(negotiationEvents)
        .where(inArray(negotiationEvents.requestId, candidateRequestIds))
        .orderBy(desc(negotiationEvents.createdAt))
        .limit(1);

      const latestEventRow = latestEvents[0] || null;
      const currentState = deriveNegotiationState(
        rawStatus,
        latestEventRow?.actionType || null,
        isExpired
      );

      if (currentState !== 'Open' && currentState !== 'Waiting for Buyer') {
        const stateError = new Error('INVALID_NEGOTIATION_STATE');
        (stateError as any).currentState = currentState;
        throw stateError;
      }

      // Step B: Stale Version Guard within transaction
      const existingVersions = await tx
        .select()
        .from(dealVersions)
        .where(inArray(dealVersions.requestId, candidateRequestIds))
        .orderBy(desc(dealVersions.versionNumber), desc(dealVersions.createdAt));

      const latestVersionRecord = existingVersions[0] || null;
      const currentVersion = latestVersionRecord ? latestVersionRecord.versionNumber : 1;

      if (
        typeof expectedVersionNumber === 'number' &&
        currentVersion > expectedVersionNumber
      ) {
        const staleError = new Error('STALE_VERSION_DETECTED');
        (staleError as any).currentVersion = currentVersion;
        throw staleError;
      }

      nextVersionNumber = currentVersion + 1;

      // Step C: Base snapshot resolution
      const baseSnapshot = parseSnapshot(latestVersionRecord?.snapshotPayload);

      // Construct new snapshot with sanitized buyer counter-terms
      const updatedSnapshot = {
        ...baseSnapshot,
        rate: counterPrice,
        price: counterPrice,
        quantity: counterQuantity,
        deliveryDate: deliveryDate || baseSnapshot.deliveryDate || null,
        deliveryWindowStart: deliveryDate || baseSnapshot.deliveryWindowStart || null,
        deliveryWindowEnd: deliveryDate || baseSnapshot.deliveryWindowEnd || null,
        paymentTerms: paymentTerms || baseSnapshot.paymentTerms || null,
        packagingType: packaging || baseSnapshot.packagingType || null,
        freightTerms: freight || baseSnapshot.freightTerms || null,
        inspectionRequirements: inspection || baseSnapshot.inspectionRequirements || null,
        buyerNotes: buyerNotesToBroker || null,
        remarks: buyerNotesToBroker || baseSnapshot.remarks || null,
        originatorRole: 'buyer',
        timestamp: new Date().toISOString(),
      };

      // Ensure no seller confidential info accidentally leaks inside snapshot
      const sanitizedSnapshot = sanitizeBuyerNegotiationPayload(updatedSnapshot);

      // Step D: Atomically mark prior active deal_versions as 'Superseded'
      // STRICT IMMUTABILITY GUARDRAIL: Only the 'status' column is modified to comply with
      // the prevent_deal_version_snapshot_tampering() database trigger.
      await tx
        .update(dealVersions)
        .set({ status: 'Superseded' })
        .where(inArray(dealVersions.requestId, candidateRequestIds));

      // Step E: Insert NEW immutable record into deal_versions (Append-Only)
      await tx.insert(dealVersions).values({
        requestId: targetRequestId,
        versionNumber: nextVersionNumber,
        actorId: user.id,
        status: 'Countered',
        snapshotPayload: sanitizedSnapshot,
      });

      // Step F: Insert tracking event into negotiation_events (PRD 36.1 & 36.4 Append-Only)
      await tx.insert(negotiationEvents).values({
        requestId: targetRequestId,
        companyId: buyerCompanyId,
        actorId: user.id,
        actionType: 'BUYER_COUNTER',
        payload: {
          actor_role: 'buyer',
          version_number: nextVersionNumber,
          counterPrice,
          counterQuantity,
          deliveryDate,
          paymentTerms,
          packaging,
          freight,
          inspection,
          buyerNotesToBroker,
          timestamp: new Date().toISOString(),
        },
      });

      // Step G: Update parent deals or quotations to 'Waiting for Broker'
      if (quoteRow) {
        await tx
          .update(quotations)
          .set({
            status: 'Waiting for Broker',
            counterPrice: String(counterPrice),
            counterNotes: buyerNotesToBroker || null,
          })
          .where(eq(quotations.id, quoteRow.quotation.id));
      }

      if (dealRow) {
        await tx
          .update(deals)
          .set({ status: 'Waiting for Broker' })
          .where(eq(deals.id, dealRow.deal.id));
      }

      const reqId = quoteRow?.requirement.id || dealRow?.requirement?.id;
      if (reqId) {
        await tx
          .update(requirements)
          .set({ status: 'Negotiating' })
          .where(eq(requirements.id, reqId));
      }
    });

    // 4. Revalidate cache
    revalidatePath('/buyer/proposals');
    revalidatePath(`/buyer/proposals/${proposalId}`);
    revalidatePath('/buyer/negotiations');
    revalidatePath(`/buyer/negotiations/${proposalId}`);

    return {
      success: true,
      newVersion: nextVersionNumber,
      negotiationState: 'Waiting for Broker',
      message: 'Your counter-offer has been sent to the Broker Desk.',
    };
  } catch (error: any) {
    if (error.message === 'INVALID_NEGOTIATION_STATE' || error.message?.includes('INVALID_NEGOTIATION_STATE')) {
      const state = error.currentState || 'terminal';
      let message = `Counter offers cannot be submitted because this negotiation is currently in '${state}' state.`;
      if (state === 'Waiting for Broker') {
        message = 'You have already submitted counter-terms. The Broker is reviewing them. Editing is paused until Broker response.';
      } else if (state === 'Agreed') {
        message = 'Terms agreed. Proceed to Final Deal & Confirmation.';
      } else if (state === 'Closed') {
        message = 'Negotiation Closed. This commercial thread has concluded.';
      } else if (state === 'Expired') {
        message = 'Terms Expired. The proposal validity window has ended.';
      }
      return {
        success: false,
        error: 'INVALID_NEGOTIATION_STATE',
        message,
      };
    }

    if (error.message === 'STALE_VERSION_DETECTED' || error.message?.includes('STALE_VERSION_DETECTED')) {
      const currentVer = error.currentVersion;
      return {
        success: false,
        error: 'STALE_VERSION_DETECTED',
        message: currentVer
          ? `The Broker has updated this proposal to Version ${currentVer}. Please refresh to review the latest terms before countering.`
          : 'A newer version of this proposal exists. Please refresh to review the latest terms before countering.',
      };
    }

    console.error('submitBuyerCounterOfferAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to submit counter offer',
    };
  }
}

/**
 * Task 2 & 3: Retrieves the sanitized negotiation state and event history for the Buyer Channel.
 * Guarantees 100% mathematical scrubbing of Seller fields and exclusion of Seller events.
 */
export async function getBuyerNegotiationChannelAction(
  proposalId: string
): Promise<GetBuyerNegotiationChannelResponse> {
  try {
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const { companyId: buyerCompanyId } = sessionRes.data;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    if (!proposalId) {
      return { success: false, error: 'Proposal ID is required.' };
    }

    // Demo/Mock fallback
    if (
      proposalId.startsWith('demo-') ||
      proposalId.startsWith('sample-') ||
      proposalId.startsWith('mock-') ||
      proposalId === 'demo'
    ) {
      return {
        success: true,
        data: {
          proposalId,
          targetRequestId: proposalId,
          negotiationState: 'Waiting for Buyer',
          currentVersion: 2,
          activeTerms: {
            price: 52500,
            quantity: 25,
            unitSymbol: 'MT',
            deliveryDate: '2026-10-25',
            paymentTerms: 'CAD (Cash Against Documents)',
            packaging: '50kg HDPE Bags',
            freight: 'FOR Destination',
            inspection: 'Mandatory Third-Party Lab COA',
            brokerNotes: 'Broker desk offers optimal lot with verified moisture under 12%.',
          },
          events: [
            {
              id: 'evt-1',
              actionType: 'BROKER_PROPOSAL_TO_BUYER',
              actorRole: 'broker',
              actorName: 'Broker Desk',
              payload: {
                rate: 53000,
                quantity: 25,
                remarks: 'Initial offer based on requirement match.',
              },
              createdAt: new Date(Date.now() - 86400000).toISOString(),
            },
            {
              id: 'evt-2',
              actionType: 'BUYER_COUNTER',
              actorRole: 'buyer',
              actorName: 'Buyer Admin',
              payload: {
                counterPrice: 52000,
                counterQuantity: 25,
                buyerNotesToBroker: 'Target budget limit is 52k/MT.',
              },
              createdAt: new Date(Date.now() - 43200000).toISOString(),
            },
            {
              id: 'evt-3',
              actionType: 'BROKER_REVISED',
              actorRole: 'broker',
              actorName: 'Broker Desk',
              payload: {
                rate: 52500,
                quantity: 25,
                remarks: 'Revised down to 52,500/MT with freight covered.',
              },
              createdAt: new Date(Date.now() - 7200000).toISOString(),
            },
          ],
        },
      };
    }

    // Resolve target request ID
    let targetRequestId = proposalId;

    const quoteRow = await db
      .select({ quotation: quotations, requirement: requirements })
      .from(quotations)
      .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
      .where(
        and(
          eq(quotations.id, proposalId),
          eq(requirements.companyId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);

    let dealRow = null;
    if (!quoteRow) {
      dealRow = await db
        .select({ deal: deals, requirement: requirements })
        .from(deals)
        .leftJoin(requirements, eq(deals.requirementId, requirements.id))
        .where(
          and(
            or(eq(deals.id, proposalId), eq(deals.quotationId, proposalId)),
            eq(deals.buyerId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);
    }

    if (!quoteRow && !dealRow) {
      return { success: false, error: 'Proposal not found or access denied.' };
    }

    targetRequestId = quoteRow ? quoteRow.quotation.id : dealRow!.deal.id;

    const candidateRequestIds = Array.from(
      new Set(
        [
          proposalId,
          targetRequestId,
          quoteRow?.quotation.id,
          dealRow?.deal.id,
          dealRow?.deal.quotationId,
        ].filter(Boolean) as string[]
      )
    );

    // Query versions
    const versions = await db
      .select()
      .from(dealVersions)
      .where(inArray(dealVersions.requestId, candidateRequestIds))
      .orderBy(desc(dealVersions.versionNumber));

    const latestVersion = versions[0] || null;
    const currentVersion = latestVersion ? latestVersion.versionNumber : 1;
    const latestSnapshot = sanitizeBuyerNegotiationPayload(parseSnapshot(latestVersion?.snapshotPayload));

    // Query negotiation events
    const rawEvents = await db
      .select({
        id: negotiationEvents.id,
        requestId: negotiationEvents.requestId,
        actionType: negotiationEvents.actionType,
        actorId: negotiationEvents.actorId,
        actorName: users.name,
        actorRole: users.role,
        payload: negotiationEvents.payload,
        createdAt: negotiationEvents.createdAt,
      })
      .from(negotiationEvents)
      .leftJoin(users, eq(negotiationEvents.actorId, users.id))
      .where(inArray(negotiationEvents.requestId, candidateRequestIds))
      .orderBy(asc(negotiationEvents.createdAt));

    // Filter events through Channel Privacy Enforcer (PRD 36.1)
    const sanitizedEvents = filterBuyerNegotiationEvents(
      rawEvents.map((e) => ({
        ...e,
        createdAt: e.createdAt ? new Date(e.createdAt).toISOString() : new Date().toISOString(),
      }))
    );

    const latestEvent = sanitizedEvents[sanitizedEvents.length - 1] || null;
    const rawStatus = quoteRow?.quotation.status || dealRow?.deal.status || 'Sent';
    const isExpired = quoteRow?.quotation.validUntil ? new Date(quoteRow.quotation.validUntil) < new Date() : false;

    const negotiationState = deriveNegotiationState(
      rawStatus,
      latestEvent?.actionType || null,
      isExpired
    );

    return {
      success: true,
      data: {
        proposalId,
        targetRequestId,
        negotiationState,
        currentVersion,
        activeTerms: {
          price: Number(latestSnapshot.rate || latestSnapshot.price || quoteRow?.quotation.offeredPrice || 0),
          quantity: Number(latestSnapshot.quantity || quoteRow?.requirement.quantity || 0),
          unitSymbol: latestSnapshot.unitSymbol || 'MT',
          deliveryDate: latestSnapshot.deliveryDate || null,
          paymentTerms: latestSnapshot.paymentTerms || null,
          packaging: latestSnapshot.packagingType || null,
          freight: latestSnapshot.freightTerms || null,
          inspection: latestSnapshot.inspectionRequirements || null,
          buyerNotes: latestSnapshot.buyerNotes || null,
          brokerNotes: latestSnapshot.brokerNotes || latestSnapshot.remarks || null,
        },
        events: sanitizedEvents.map((e) => ({
          id: e.id || `evt-${Math.random()}`,
          actionType: e.actionType,
          actorRole: e.actorRole as 'buyer' | 'broker',
          actorName: e.actorName || (e.actorRole === 'buyer' ? 'Buyer Admin' : 'Broker Desk'),
          payload: e.payload,
          createdAt: typeof e.createdAt === 'string' ? e.createdAt : new Date().toISOString(),
        })),
      },
    };
  } catch (error: any) {
    console.error('getBuyerNegotiationChannelAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to retrieve negotiation channel state',
    };
  }
}

/**
 * Timeline Event interface for Buyer-Broker negotiation history.
 */
export interface BuyerNegotiationTimelineEvent {
  id: string;
  actionType: string;
  actionLabel: string;
  actorRole: 'buyer' | 'broker';
  actorName: string;
  createdAt: string;
  formattedTime: string;
  summary: string;
  versionNumber?: number;
  termsDiff?: {
    price?: number;
    quantity?: number;
    deliveryDate?: string | null;
    paymentTerms?: string | null;
    packaging?: string | null;
    freight?: string | null;
    inspection?: string | null;
    notes?: string | null;
  };
  payload?: any;
}

export interface GetBuyerNegotiationTimelineResponse {
  success: boolean;
  data?: BuyerNegotiationTimelineEvent[];
  error?: string;
}

/**
 * Format timestamp to user-friendly local representation, e.g., "Oct 24, 2:30 PM".
 */
function formatTimelineDate(date: Date): string {
  try {
    return new Intl.DateTimeFormat('en-IN', {
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    }).format(date);
  } catch {
    return date.toISOString();
  }
}

/**
 * Formats event action label and summary badge/diff text.
 */
function formatTimelineEventMetadata(actionType: string, isBuyer: boolean, payload: any) {
  const norm = (actionType || '').toUpperCase();
  const rate = payload?.counterPrice ?? payload?.rate ?? payload?.price;
  const qty = payload?.counterQuantity ?? payload?.quantity;
  const unit = payload?.unitSymbol || 'MT';
  const notes = payload?.buyerNotesToBroker ?? payload?.buyerNotes ?? payload?.remarks ?? payload?.notes;

  let actionLabel = 'Negotiation Event';
  let summary = '';

  if (norm === 'BUYER_COUNTER' || norm === 'BUYER_COUNTERED') {
    actionLabel = 'Counter Offer Submitted';
    summary = rate ? `Price updated to ₹${Number(rate).toLocaleString('en-IN')}/${unit}` : 'Counter terms submitted';
    if (qty) summary += ` • Volume: ${qty} ${unit}`;
  } else if (norm === 'BROKER_PROPOSAL_TO_BUYER' || norm === 'BROKER_PROPOSAL') {
    actionLabel = 'Proposal Presented';
    summary = rate ? `Offered at ₹${Number(rate).toLocaleString('en-IN')}/${unit}` : 'Initial proposal presented';
    if (qty) summary += ` • Volume: ${qty} ${unit}`;
  } else if (norm === 'BROKER_REVISED' || norm === 'BROKER_COUNTER') {
    actionLabel = 'Revision Proposed';
    summary = rate ? `Price updated to ₹${Number(rate).toLocaleString('en-IN')}/${unit}` : 'Revised terms offered';
    if (qty) summary += ` • Volume: ${qty} ${unit}`;
  } else if (norm === 'BUYER_ACCEPTED') {
    actionLabel = 'Proposal Accepted';
    summary = 'Buyer aligned with offered commercial terms';
  } else if (norm === 'BUYER_REJECTED') {
    actionLabel = 'Proposal Declined';
    summary = payload?.reason ? `Reason: ${payload.reason}` : 'Proposal declined by Buyer';
  } else if (norm === 'BUYER_CLARIFICATION' || norm === 'BUYER_MESSAGE') {
    actionLabel = 'Clarification Requested';
    summary = notes ? `Note: "${notes}"` : 'Clarification note sent to Broker Desk';
  } else if (norm === 'BROKER_MESSAGE') {
    actionLabel = 'Broker Note';
    summary = notes ? `Note: "${notes}"` : 'Note from Broker Desk';
  } else {
    actionLabel = isBuyer ? 'Counter Offer Submitted' : 'Revision Proposed';
    summary = rate ? `Price updated to ₹${Number(rate).toLocaleString('en-IN')}/${unit}` : 'Commercial terms update';
  }

  return { actionLabel, summary };
}

/**
 * Task 1 (Micro-Sprint 36.2): Retrieves the chronological Buyer ↔ Broker negotiation timeline.
 * 
 * Strict Guardrails (PRD 36.2):
 * 1. Authenticate caller as BUYER_ADMIN and enforce tenant company ownership.
 * 2. Fetch negotiation_events for the deal/proposal.
 * 3. STRICT FILTER: Only return events where actor_role is 'buyer' or 'broker'.
 *    Mathematically excludes any events, revisions, notes, or timestamps from the Seller.
 * 4. Order strictly by created_at ASC to construct an immutable chronological audit stream.
 */
export async function getBuyerNegotiationTimelineAction(
  proposalId: string
): Promise<GetBuyerNegotiationTimelineResponse> {
  try {
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data) {
      return { success: false, error: sessionRes.error || 'Unauthorized' };
    }

    const { companyId: buyerCompanyId } = sessionRes.data;
    if (!buyerCompanyId) {
      return { success: false, error: 'Buyer organization profile not found.' };
    }

    if (!proposalId) {
      return { success: false, error: 'Proposal ID is required.' };
    }

    // Demo/Mock ID fallback
    if (
      proposalId.startsWith('demo-') ||
      proposalId.startsWith('sample-') ||
      proposalId.startsWith('mock-') ||
      proposalId === 'demo'
    ) {
      const now = Date.now();
      const mockEvents: BuyerNegotiationTimelineEvent[] = [
        {
          id: 'mock-evt-1',
          actionType: 'BROKER_PROPOSAL_TO_BUYER',
          actionLabel: 'Proposal Presented',
          actorRole: 'broker',
          actorName: 'Broker',
          createdAt: new Date(now - 86400000).toISOString(),
          formattedTime: formatTimelineDate(new Date(now - 86400000)),
          summary: 'Offered at ₹53,000/MT • Volume: 25 MT',
          versionNumber: 1,
          termsDiff: {
            price: 53000,
            quantity: 25,
            deliveryDate: '2026-10-25',
            paymentTerms: 'CAD (Cash Against Documents)',
            packaging: '50kg Bags',
            freight: 'FOR Destination',
            notes: 'Initial lot offer from Broker Desk.',
          },
          payload: { rate: 53000, quantity: 25 },
        },
        {
          id: 'mock-evt-2',
          actionType: 'BUYER_COUNTER',
          actionLabel: 'Counter Offer Submitted',
          actorRole: 'buyer',
          actorName: 'You',
          createdAt: new Date(now - 43200000).toISOString(),
          formattedTime: formatTimelineDate(new Date(now - 43200000)),
          summary: 'Price updated to ₹52,000/MT • Volume: 25 MT',
          versionNumber: 2,
          termsDiff: {
            price: 52000,
            quantity: 25,
            deliveryDate: '2026-10-25',
            notes: 'Target budget limit is 52k/MT.',
          },
          payload: { counterPrice: 52000, counterQuantity: 25 },
        },
        {
          id: 'mock-evt-3',
          actionType: 'BROKER_REVISED',
          actionLabel: 'Revision Proposed',
          actorRole: 'broker',
          actorName: 'Broker',
          createdAt: new Date(now - 7200000).toISOString(),
          formattedTime: formatTimelineDate(new Date(now - 7200000)),
          summary: 'Price updated to ₹52,500/MT • Volume: 25 MT',
          versionNumber: 3,
          termsDiff: {
            price: 52500,
            quantity: 25,
            notes: 'Broker negotiated optimal landing rate with freight covered.',
          },
          payload: { rate: 52500, quantity: 25 },
        },
      ];
      return { success: true, data: mockEvents };
    }

    // 1. Resolve parent quotation or deal under tenant isolation
    let targetRequestId = proposalId;

    const quoteRow = await db
      .select({ quotation: quotations, requirement: requirements })
      .from(quotations)
      .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
      .where(
        and(
          eq(quotations.id, proposalId),
          eq(requirements.companyId, buyerCompanyId)
        )
      )
      .limit(1)
      .then((rows) => rows[0] || null);

    let dealRow = null;
    if (!quoteRow) {
      dealRow = await db
        .select({ deal: deals, requirement: requirements })
        .from(deals)
        .leftJoin(requirements, eq(deals.requirementId, requirements.id))
        .where(
          and(
            or(eq(deals.id, proposalId), eq(deals.quotationId, proposalId)),
            eq(deals.buyerId, buyerCompanyId)
          )
        )
        .limit(1)
        .then((rows) => rows[0] || null);
    }

    if (!quoteRow && !dealRow) {
      return { success: false, error: 'Proposal not found or access denied.' };
    }

    targetRequestId = quoteRow ? quoteRow.quotation.id : dealRow!.deal.id;

    const candidateRequestIds = Array.from(
      new Set(
        [
          proposalId,
          targetRequestId,
          quoteRow?.quotation.id,
          dealRow?.deal.id,
          dealRow?.deal.quotationId,
        ].filter(Boolean) as string[]
      )
    );

    // 2. Fetch raw negotiation events for this request
    const rawEvents = await db
      .select({
        id: negotiationEvents.id,
        requestId: negotiationEvents.requestId,
        actionType: negotiationEvents.actionType,
        actorId: negotiationEvents.actorId,
        actorName: users.name,
        actorRole: users.role,
        payload: negotiationEvents.payload,
        createdAt: negotiationEvents.createdAt,
      })
      .from(negotiationEvents)
      .leftJoin(users, eq(negotiationEvents.actorId, users.id))
      .where(inArray(negotiationEvents.requestId, candidateRequestIds))
      .orderBy(asc(negotiationEvents.createdAt));

    // 3. Strict Seller Filter & Mathematical Privacy Scrubber (PRD 36.1 & 36.2)
    const sanitizedEvents = filterBuyerNegotiationEvents(
      rawEvents.map((e) => ({
        ...e,
        createdAt: e.createdAt ? new Date(e.createdAt).toISOString() : new Date().toISOString(),
      }))
    );

    // 4. Also fetch deal versions to ensure initial proposal or intermediate versions are represented
    const versions = await db
      .select()
      .from(dealVersions)
      .where(inArray(dealVersions.requestId, candidateRequestIds))
      .orderBy(asc(dealVersions.versionNumber));

    const timelineEvents: BuyerNegotiationTimelineEvent[] = [];

    // If no negotiation_events exist yet, but deal_versions exist, synthesize version records
    if (sanitizedEvents.length === 0 && versions.length > 0) {
      for (const v of versions) {
        const snap = sanitizeBuyerNegotiationPayload(parseSnapshot(v.snapshotPayload));
        const isBuyer = (snap.originatorRole || '').toLowerCase() === 'buyer';
        const d = new Date(v.createdAt);
        const { actionLabel, summary } = formatTimelineEventMetadata(
          isBuyer ? 'BUYER_COUNTER' : 'BROKER_PROPOSAL_TO_BUYER',
          isBuyer,
          snap
        );

        timelineEvents.push({
          id: `v-synth-${v.id}`,
          actionType: isBuyer ? 'BUYER_COUNTER' : 'BROKER_PROPOSAL_TO_BUYER',
          actionLabel,
          actorRole: isBuyer ? 'buyer' : 'broker',
          actorName: isBuyer ? 'You' : 'Broker',
          createdAt: d.toISOString(),
          formattedTime: formatTimelineDate(d),
          summary,
          versionNumber: v.versionNumber,
          termsDiff: {
            price: Number(snap.rate || snap.price || 0),
            quantity: Number(snap.quantity || 0),
            deliveryDate: snap.deliveryDate || null,
            paymentTerms: snap.paymentTerms || null,
            packaging: snap.packagingType || null,
            freight: snap.freightTerms || null,
            inspection: snap.inspectionRequirements || null,
            notes: snap.buyerNotes || snap.remarks || null,
          },
          payload: snap,
        });
      }
    } else {
      // Map sanitized negotiation events
      for (const evt of sanitizedEvents) {
        const payload: any = evt.payload || {};
        const isBuyer = evt.actorRole === 'buyer';
        const d = new Date(evt.createdAt);
        const { actionLabel, summary } = formatTimelineEventMetadata(
          evt.actionType,
          isBuyer,
          payload
        );

        timelineEvents.push({
          id: evt.id,
          actionType: evt.actionType,
          actionLabel,
          actorRole: evt.actorRole as 'buyer' | 'broker',
          actorName: isBuyer ? 'You' : 'Broker',
          createdAt: d.toISOString(),
          formattedTime: formatTimelineDate(d),
          summary,
          versionNumber: payload.version_number || payload.versionNumber || undefined,
          termsDiff: {
            price: Number(payload.counterPrice ?? payload.rate ?? payload.price ?? 0) || undefined,
            quantity: Number(payload.counterQuantity ?? payload.quantity ?? 0) || undefined,
            deliveryDate: payload.deliveryDate || payload.delivery_date || null,
            paymentTerms: payload.paymentTerms || payload.payment_terms || null,
            packaging: payload.packaging || null,
            freight: payload.freight || null,
            inspection: payload.inspection || null,
            notes: payload.buyerNotesToBroker || payload.buyerNotes || payload.remarks || payload.notes || null,
          },
          payload,
        });
      }
    }

    // Sort strictly by createdAt ASC
    timelineEvents.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

    return {
      success: true,
      data: timelineEvents,
    };
  } catch (error: any) {
    console.error('getBuyerNegotiationTimelineAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to retrieve negotiation timeline',
    };
  }
}
