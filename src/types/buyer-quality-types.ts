/**
 * Buyer Transaction Quality & Weighment Types (Micro-Sprint 39.1)
 * Defined according to Buyer PRD Sprint 39 (Quality, Documents, Payments & Disputes).
 */

export type LabVerificationStatus =
  | 'Verified'
  | 'Under Review'
  | 'Pending Broker Review'
  | 'Sample Pending'
  | 'Testing In Progress'
  | 'Report Uploaded'
  | 'Correction Required'
  | 'Rejected'
  | 'Expired'
  | 'Missing';

export type WeighmentStatus =
  | 'Verified'
  | 'Recorded'
  | 'Pending Weighment'
  | 'Discrepancy Detected'
  | 'Missing';

export interface BuyerQualityParameterComparison {
  parameterId: string;
  parameterName: string;
  unit: string;
  type: string; // 'numeric' | 'boolean' | 'text'
  buyerTargetFormatted: string; // e.g. "12.0% Max" or "10.0 - 12.0%"
  targetValue: number | null;
  minValue: number | null;
  maxValue: number | null;
  isRequired: boolean;
  actualValueFormatted: string; // e.g. "10.8%"
  actualNumericValue: number | null;
  isWithinBounds: boolean;
  varianceLabel?: string | null; // e.g. "-0.4% (Optimal)"
}

export interface BuyerLabReportDetails {
  id: string;
  reportNumber: string;
  laboratoryName: string;
  laboratoryLocation?: string | null;
  sampleId?: string | null;
  testDate?: string | null; // ISO date string
  reportDate?: string | null; // ISO date string
  validUntil?: string | null; // ISO date string
  status: LabVerificationStatus;
  verifiedAt?: string | null; // ISO date string
  verificationNotes?: string | null; // Sanitized broker notes
  hasCertificate: boolean;
  fileUrl?: string | null;
  signedUrl?: string | null;
}

export interface BuyerWeighmentDetails {
  dispatchId: string;
  dispatchReference?: string | null;
  vehicleNumber: string;
  grossWeight: number | null; // MT
  tareWeight: number | null; // MT
  netWeight: number | null; // MT = Gross - Tare
  unitSymbol: string;
  weighmentDate?: string | null;
  weighbridgeLocation?: string | null;
  slipDocumentId?: string | null;
  hasWeighbridgeSlip: boolean;
  slipFilePath?: string | null;
  status: WeighmentStatus;
}

export interface BuyerTransactionQualityData {
  bookingId: string;
  dealId: string;
  commodityName: string;
  gradeName: string;
  overallQualityStatus: 'Verified' | 'Under Review' | 'Pending Review' | 'Missing';
  labReport: BuyerLabReportDetails | null;
  parameters: BuyerQualityParameterComparison[];
  weighment: BuyerWeighmentDetails | null;
  verifiedAt?: string | null;
  disclaimer: string;
}

export type BuyerTransactionQualityResponse =
  | {
      success: true;
      data: BuyerTransactionQualityData;
      error?: undefined;
    }
  | {
      success: false;
      error: string;
      data?: undefined;
    };
