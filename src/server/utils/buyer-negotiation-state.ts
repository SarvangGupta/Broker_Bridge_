/**
 * Negotiation State Machine Utility (Micro-Sprint 36.5 / PRD Sprint 36).
 * Pure utility functions for the 6-state negotiation lifecycle:
 * - 'Open': Fresh proposal presented, awaiting initial buyer review.
 * - 'Waiting for Broker': Transitioned when Buyer submits a counter-offer.
 * - 'Waiting for Buyer': Transitioned when Broker presents revised terms.
 * - 'Agreed': Mutual agreement reached, locking the snapshot for Sprint 37 deal confirmation.
 * - 'Closed': Rejected or terminated.
 * - 'Expired': Auto-expiry when valid_until has passed and status is not 'Agreed'.
 */

export type NegotiationState = 
  | 'Open'
  | 'Waiting for Broker'
  | 'Waiting for Buyer'
  | 'Agreed'
  | 'Closed'
  | 'Expired';

/**
 * Evaluates current negotiation state based on raw database status, latest event action, and expiry.
 */
export function deriveNegotiationState(
  rawStatus: string,
  latestActionType?: string | null,
  isExpired?: boolean
): NegotiationState {
  // 1. Closed state when rejected, cancelled, or terminated
  if (
    rawStatus === 'Rejected' || 
    rawStatus === 'Closed' || 
    rawStatus === 'Cancelled' ||
    rawStatus === 'Terminated' ||
    latestActionType === 'BUYER_REJECTED' ||
    latestActionType === 'BROKER_REJECTED'
  ) {
    return 'Closed';
  }

  // 2. Agreed state when mutual commercial agreement is reached
  if (
    rawStatus === 'Accepted' || 
    rawStatus === 'Agreed' || 
    rawStatus === 'Confirmed' ||
    rawStatus === 'Dual Confirmed' ||
    rawStatus === 'Broker Finalized' ||
    latestActionType === 'BUYER_ACCEPTED' ||
    latestActionType === 'BROKER_ACCEPTED'
  ) {
    return 'Agreed';
  }

  // 3. Auto-Expiry Check: If valid_until has passed and status is not 'Agreed', evaluate status as 'Expired'
  if (isExpired || rawStatus === 'Expired') {
    return 'Expired';
  }

  // 4. Action-type specific transitions
  if (latestActionType) {
    const act = latestActionType.toUpperCase();
    if (act === 'BUYER_COUNTER' || act === 'BUYER_COUNTERED') {
      return 'Waiting for Broker';
    }
    if (
      act === 'BROKER_REVISED' || 
      act === 'BROKER_COUNTER'
    ) {
      return 'Waiting for Buyer';
    }
    if (act === 'BROKER_PROPOSAL_TO_BUYER' || act === 'BROKER_PROPOSAL') {
      return 'Open';
    }
  }

  // 5. Raw status fallback transitions
  if (rawStatus === 'Waiting for Broker' || rawStatus === 'Countered') {
    return 'Waiting for Broker';
  }

  if (rawStatus === 'Waiting for Buyer') {
    return 'Waiting for Buyer';
  }

  if (rawStatus === 'Open' || rawStatus === 'Sent' || rawStatus === 'Proposed') {
    return 'Open';
  }

  return 'Waiting for Buyer';
}
