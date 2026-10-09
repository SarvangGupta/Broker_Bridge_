/**
 * Proposal State & Next Action Mappers (Micro-Sprint 35.1)
 * Maps backend negotiation and quote states to Buyer PRD Sprint 35 specifications:
 * States: 'New', 'Pending Response', 'Accepted', 'Rejected', 'Countered', 'Expired'
 */

export type ProposalStatus =
  | 'New'
  | 'Pending Response'
  | 'Accepted'
  | 'Rejected'
  | 'Countered'
  | 'Expired';

export interface ProposalStatusMeta {
  status: ProposalStatus;
  label: string;
  badgeClass: string;
  dotClass: string;
  nextAction: string;
}

/**
 * Maps arbitrary raw backend status and expiration timestamp to one of the 6 canonical PRD states.
 */
export function mapToProposalStatus(
  rawStatus?: string | null,
  validUntil?: string | Date | null
): ProposalStatus {
  const normalized = (rawStatus || '').toLowerCase().trim();

  // If validity date is in the past and status is not already accepted, mark as Expired
  if (validUntil) {
    const expiryTime = new Date(validUntil).getTime();
    if (!isNaN(expiryTime) && expiryTime < Date.now()) {
      if (
        normalized !== 'accepted' &&
        normalized !== 'accepted (booked)' &&
        normalized !== 'confirmed' &&
        normalized !== 'buyer confirmed' &&
        normalized !== 'broker finalized' &&
        normalized !== 'booked'
      ) {
        return 'Expired';
      }
    }
  }

  // Canonical mapping based on database and version engine states
  switch (normalized) {
    case 'new':
    case 'draft':
    case 'proposed':
      return 'New';

    case 'sent':
    case 'pending':
    case 'pending response':
    case 'under review':
    case 'pending confirmation':
      return 'Pending Response';

    case 'countered':
    case 'revised sent':
    case 'counter':
    case 'counter offer':
    case 'buyer countered':
    case 'seller countered':
    case 'broker countered':
      return 'Countered';

    case 'accepted':
    case 'accepted (booked)':
    case 'buyer confirmed':
    case 'seller confirmed':
    case 'broker finalized':
    case 'confirmed':
    case 'booked':
    case 'dispatch pending':
    case 'dispatched':
    case 'fulfilled':
    case 'closed':
      return 'Accepted';

    case 'rejected':
    case 'seller rejected':
    case 'buyer rejected':
    case 'declined':
    case 'cancelled':
      return 'Rejected';

    case 'expired':
      return 'Expired';

    default:
      return 'New';
  }
}

/**
 * Derives the "Clear Next Action" requirement instruction for the Buyer UI.
 */
export function getProposalNextAction(status: ProposalStatus): string {
  switch (status) {
    case 'New':
      return 'Review & Respond';
    case 'Pending Response':
      return 'Review & Respond';
    case 'Countered':
      return 'Review Counter Terms';
    case 'Accepted':
      return 'Awaiting Order Finalization';
    case 'Rejected':
      return 'Archived - Offer Closed';
    case 'Expired':
      return 'Request Fresh Quote';
    default:
      return 'Review Proposal';
  }
}

/**
 * Returns complete presentation metadata including badge colors and dot classes.
 * Adheres strictly to the PRD color rules:
 * - Green for Accepted
 * - Ocean Blue (#0284C7) for New / Countered
 * - Amber for Pending Response
 * - Red for Rejected
 * - Gray for Expired
 */
export function getProposalStatusMeta(status: ProposalStatus): ProposalStatusMeta {
  switch (status) {
    case 'Accepted':
      return {
        status,
        label: 'Accepted',
        badgeClass: 'bg-emerald-50 text-emerald-800 border-emerald-200/90 shadow-2xs',
        dotClass: 'bg-emerald-600',
        nextAction: getProposalNextAction(status),
      };

    case 'New':
      return {
        status,
        label: 'New Offer',
        badgeClass: 'bg-sky-50 text-[#0284C7] border-sky-200/90 shadow-2xs',
        dotClass: 'bg-[#0284C7] animate-pulse',
        nextAction: getProposalNextAction(status),
      };

    case 'Countered':
      return {
        status,
        label: 'Countered',
        badgeClass: 'bg-blue-50 text-[#0284C7] border-blue-200/90 shadow-2xs',
        dotClass: 'bg-[#0284C7]',
        nextAction: getProposalNextAction(status),
      };

    case 'Pending Response':
      return {
        status,
        label: 'Pending Response',
        badgeClass: 'bg-amber-50 text-amber-800 border-amber-200/90 shadow-2xs',
        dotClass: 'bg-amber-500',
        nextAction: getProposalNextAction(status),
      };

    case 'Rejected':
      return {
        status,
        label: 'Rejected',
        badgeClass: 'bg-rose-50 text-rose-800 border-rose-200/90 shadow-2xs',
        dotClass: 'bg-rose-500',
        nextAction: getProposalNextAction(status),
      };

    case 'Expired':
      return {
        status,
        label: 'Expired',
        badgeClass: 'bg-slate-100 text-slate-700 border-slate-200/90 shadow-2xs',
        dotClass: 'bg-slate-400',
        nextAction: getProposalNextAction(status),
      };

    default:
      return {
        status: 'New',
        label: 'New Offer',
        badgeClass: 'bg-sky-50 text-[#0284C7] border-sky-200/90 shadow-2xs',
        dotClass: 'bg-[#0284C7]',
        nextAction: 'Review & Respond',
      };
  }
}
