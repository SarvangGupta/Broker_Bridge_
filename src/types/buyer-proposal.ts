import { ProposalStatus } from '@/src/utils/proposal-mappers';

/**
 * Retention window for rejected proposals in the active Inbox (48 hours).
 * Proposals rejected longer than this threshold are automatically archived/purged from the inbox to keep the UI clean.
 */
export const REJECTED_PROPOSAL_RETENTION_HOURS = 48;
export const REJECTED_PROPOSAL_RETENTION_MS = REJECTED_PROPOSAL_RETENTION_HOURS * 60 * 60 * 1000;

export interface BuyerProposalItem {
  id: string;
  dealId?: string | null;
  requirementId: string;
  requirementDisplayId: string;
  commodityName: string;
  gradeName: string;
  proposedQuantity: number;
  unitSymbol: string;
  proposedPrice: number; // Landed offered price per unit in INR
  totalEstimatedValue: number; // proposedQuantity * proposedPrice
  status: ProposalStatus;
  rawStatus: string;
  nextAction: string;
  versionNumber: number;
  brokerId: string | null;
  brokerName: string;
  validUntil: string | null;
  isExpired: boolean;
  notes?: string | null;
  deliveryTerms?: string | null;
  deliveryDate?: string | null;
  createdAt: string;
  updatedAt: string;
  autoCleanRemainingHours?: number;
  isArchived?: boolean;
}

export interface BuyerChargeItem {
  name: string;
  amount: number; // in INR
  type: 'fixed' | 'per_unit' | 'percentage';
  rate?: number; // e.g. 1% or 35/MT
  description?: string;
  includedInLandedPrice?: boolean;
}

export interface BuyerQualitySpecItem {
  parameterName: string;
  targetValue: string | number;
  tolerance?: string | null;
  unit?: string | null;
  isMandatory?: boolean;
}

export interface BuyerProposalDetail {
  id: string; // quotation or deal id
  dealId?: string | null;
  requirementId: string;
  requirementDisplayId: string;
  commodityName: string;
  gradeName: string;
  proposedQuantity: number;
  unitSymbol: string;
  basePricePerUnit: number; // Base offered price per unit in INR
  applicableCharges: BuyerChargeItem[];
  totalChargesPerUnit: number;
  netLandedPricePerUnit: number; // Landed price per unit including applicable charges
  totalEstimatedValue: number; // proposedQuantity * netLandedPricePerUnit
  
  status: ProposalStatus;
  rawStatus: string;
  nextAction: string;
  versionNumber: number;
  
  brokerId: string | null;
  brokerName: string;
  brokerAgency?: string;
  brokerNotes?: string | null;
  
  validUntil: string | null;
  isExpired: boolean;
  autoCleanRemainingHours?: number;
  isArchived?: boolean;
  
  // Quality & Inspection
  qualitySpecifications: BuyerQualitySpecItem[];
  inspectionRequirements?: string | null;
  
  // Logistics & Delivery
  deliveryLocation: string;
  deliveryState?: string | null;
  deliveryDistrict?: string | null;
  deliveryCity?: string | null;
  deliveryWindowStart?: string | null;
  deliveryWindowEnd?: string | null;
  freightTerms: string;
  deliveryTerms?: string | null;
  
  // Commercial Terms
  paymentTerms: string;
  packagingType: string;
  specialConditions?: string | null;
  
  createdAt: string;
  updatedAt: string;
}

export interface BuyerProposalDetailResponse {
  success: boolean;
  proposal?: BuyerProposalDetail;
  data?: BuyerProposalDetail;
  error?: string;
}

export interface BuyerProposalsInboxResponse {
  success: boolean;
  data?: BuyerProposalItem[];
  error?: string;
}

export interface BuyerProposalVersionTerms {
  quantity: number;
  unit: string;
  pricePerUnit: number;
  totalChargesPerUnit?: number;
  netLandedPricePerUnit?: number;
  totalEstimatedValue?: number;
  deliveryLocation?: string;
  deliveryWindowStart?: string | null;
  deliveryWindowEnd?: string | null;
  paymentTerms?: string | null;
  packagingType?: string | null;
  freightTerms?: string | null;
  qualityParameters?: Array<{
    name: string;
    value: string | number;
    tolerance?: string | null;
    unit?: string | null;
  }>;
}

export interface BuyerProposalVersionItem {
  id: string;
  versionNumber: number;
  createdAt: string;
  status: string; // 'Proposed', 'Countered', 'Superseded', 'Accepted', 'Rejected'
  terms: BuyerProposalVersionTerms;
  brokerNotes?: string | null;
  originatorRole?: string;
}

export interface BuyerProposalVersionsResponse {
  success: boolean;
  versions?: BuyerProposalVersionItem[];
  data?: BuyerProposalVersionItem[];
  error?: string;
}

export interface AcceptBuyerProposalInput {
  proposalId: string;
  expectedVersionNumber: number;
}

export interface CounterBuyerProposalInput {
  proposalId: string;
  expectedVersionNumber: number;
  counterPrice: number;
  counterQuantity: number;
  deliveryDate?: string;
  buyerNotes?: string;
}

export interface RejectBuyerProposalInput {
  proposalId: string;
  expectedVersionNumber: number;
  reason: string;
  notes?: string;
}

export interface BuyerProposalActionResponse {
  success: boolean;
  newVersion?: number;
  error?: string;
  message?: string;
}



