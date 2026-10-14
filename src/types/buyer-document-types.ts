/**
 * Buyer Transaction Document Vault Types (Micro-Sprint 39.2)
 * Defined according to Buyer PRD Sprint 39 (Quality, Documents, Payments & Disputes).
 */

export type DocumentComplianceStatus =
  | 'Verified'
  | 'Received'
  | 'Missing'
  | 'Required';

export interface BuyerDocumentComplianceItem {
  id: string;
  documentType: string; // e.g. "Lorry Receipt (LR)", "Commercial Invoice", "Weighment Slip", "Certificate of Analysis", "E-Way Bill"
  displayName: string;
  category: 'Commercial' | 'Logistics' | 'Quality' | 'Statutory' | 'Other';
  isMandatory: boolean;
  status: DocumentComplianceStatus;
  statusDescription: string;
  // Uploaded evidence details (if file exists)
  fileId?: string | null;
  fileName?: string | null;
  fileUrl?: string | null;
  signedUrl?: string | null;
  uploadedAt?: string | null;
  verifiedAt?: string | null;
  dispatchId?: string | null;
  fileSizeBytes?: number | null;
}

export interface BuyerDocumentMatrixData {
  bookingId: string;
  dealId: string;
  dispatchStatus: string;
  dispatchReference?: string | null;
  totalRequired: number;
  totalUploaded: number;
  totalVerified: number;
  totalMissing: number;
  compliancePercentage: number;
  isFullyCompliant: boolean;
  documents: BuyerDocumentComplianceItem[];
  lastUpdated: string;
  disclaimer: string;
}

export type BuyerDocumentMatrixResponse =
  | {
      success: true;
      data: BuyerDocumentMatrixData;
      error?: undefined;
    }
  | {
      success: false;
      error: string;
      data?: undefined;
    };
