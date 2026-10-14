/**
 * Micro-Sprint 39.4: Buyer Dispute Generation & Tracker Types.
 * 
 * Strict Architectural Guardrails:
 * 1. Disputes NEVER create a direct Buyer-Seller communication channel.
 *    All disputes are routed strictly to the Broker for mediation.
 * 2. Categories strictly restricted to:
 *    'Quality' | 'Quantity' | 'Delivery' | 'Document' | 'Payment' | 'Commercial' | 'Other'.
 * 3. Read-Only Tracker: Zero chat box or unmoderated messaging.
 * 4. Tenant Isolation: Buyer strictly accesses own disputes; zero Seller PII or internal Broker notes exposed.
 */

export const BUYER_DISPUTE_CATEGORIES = [
  'Quality',
  'Quantity',
  'Delivery',
  'Document',
  'Payment',
  'Commercial',
  'Other',
] as const;

export type BuyerDisputeCategory = typeof BUYER_DISPUTE_CATEGORIES[number];

export const BUYER_DISPUTE_STATUSES = [
  'Open',
  'Under Broker Review',
  'Resolved',
] as const;

export type BuyerDisputeStatus = typeof BUYER_DISPUTE_STATUSES[number];

export interface CreateBuyerDisputePayload {
  booking_id: string;
  category: BuyerDisputeCategory;
  description: string;
  evidence_urls?: string[];
}

export interface BuyerDisputeItem {
  id: string;
  bookingId: string;
  dealId?: string;
  dealReference?: string;
  commodityName: string;
  gradeName?: string;
  category: BuyerDisputeCategory;
  description: string;
  status: BuyerDisputeStatus;
  createdAt: string;
  resolvedAt?: string | null;
  evidenceUrls: string[];
  initiator: 'Buyer';
}

export interface BuyerDisputeSummary {
  totalDisputes: number;
  openCount: number;
  underReviewCount: number;
  resolvedCount: number;
}

export interface BuyerDisputesResult {
  success: boolean;
  data?: {
    summary: BuyerDisputeSummary;
    disputes: BuyerDisputeItem[];
  };
  error?: string;
}

export interface CreateBuyerDisputeResult {
  success: boolean;
  disputeId?: string;
  error?: string;
}
