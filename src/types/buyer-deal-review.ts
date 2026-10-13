import { z } from 'zod';

export type DealConfirmationStatus =
  | 'Awaiting Buyer Confirmation'
  | 'Buyer Confirmed'
  | 'Awaiting Seller Confirmation'
  | 'Confirmed'
  | 'Amendment Required';

export interface BuyerSideCharge {
  name: string;
  rate: number;
  amount: number;
  type: string;
  description: string;
  includedInLandedPrice: boolean;
}

export interface BuyerQualitySpec {
  parameterName: string;
  targetValue: string | number;
  tolerance?: string;
  unit?: string | null;
  isMandatory?: boolean;
}

export interface FinalDealCommercialTerms {
  commodityName: string;
  gradeName: string;
  quantity: number;
  unitSymbol: string;
  basePricePerUnit: number;
  netLandedPricePerUnit: number;
  totalEstimatedValue: number;
  applicableCharges: BuyerSideCharge[];
  totalChargesPerUnit: number;
  deliveryLocation: string;
  deliveryState?: string | null;
  deliveryDistrict?: string | null;
  deliveryCity?: string | null;
  deliveryWindowStart: string | null;
  deliveryWindowEnd: string | null;
  deliveryDate: string | null;
  paymentTerms: string;
  packagingType: string;
  freightTerms: string;
  inspectionRequirements: string;
  specialConditions?: string | null;
  remarks?: string | null;
  qualityParameters: BuyerQualitySpec[];
}

export interface FinalDealReviewData {
  dealId: string;
  requestId: string;
  requirementDisplayId: string;
  status: DealConfirmationStatus;
  rawStatus: string;
  versionNumber: number;
  hasPreviousVersion: boolean;
  previousVersionNumber?: number | null;
  currentTerms: FinalDealCommercialTerms;
  previousTerms?: FinalDealCommercialTerms | null;
  brokerName: string;
  brokerAgency: string;
  brokerNotes?: string | null;
  snapshotTimestamp: string;
  createdAt: string;
  updatedAt: string;
}

export interface FinalDealReviewResponse {
  success: boolean;
  data?: FinalDealReviewData;
  error?: string;
}
