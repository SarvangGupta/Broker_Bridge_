/**
 * Buyer Payable Ledger & Financial Types (Micro-Sprint 39.3)
 * Defined according to Buyer PRD Sprint 39 (Quality, Documents, Payments & Disputes).
 */

export type BuyerPaymentStatus =
  | 'Pending'
  | 'Part Paid'
  | 'Paid'
  | 'Overdue'
  | 'Disputed';

export interface BuyerPaymentRecord {
  id: string;
  referenceNumber: string;
  amount: number;
  formattedAmount: string; // e.g. "₹5,00,000"
  status: 'Confirmed' | 'Processing' | 'Pending Verification';
  paymentDate: string; // ISO date string
  paymentMethod?: string; // e.g. "NEFT / RTGS Escrow"
  receiptUrl?: string | null;
}

export interface BuyerPayableItem {
  bookingId: string;
  dealId: string;
  dealReference?: string | null;
  commodityName: string;
  gradeName: string;
  finalQuantity: number;
  unitSymbol: string;
  lockedBaseRate: number; // e.g. ₹28,500 / MT
  formattedLockedBaseRate: string;
  baseAmount: number; // Final Quantity * Locked Base Rate
  formattedBaseAmount: string;
  chargesAndTaxes: number; // Mandi tax, platform brokerage, GST
  formattedChargesAndTaxes: string;
  grossPayable: number; // Base Amount + Charges & Taxes
  formattedGrossPayable: string;
  totalPaid: number;
  formattedTotalPaid: string;
  outstandingBalance: number; // Gross Payable - Total Paid
  formattedOutstandingBalance: string;
  paymentStatus: BuyerPaymentStatus;
  dueDate?: string | null;
  isOverdue: boolean;
  paymentRecords: BuyerPaymentRecord[];
  nodalAccountName: string; // "BrokerBridge Nodal Trade Escrow"
  escrowReference: string; // Unique virtual account / escrow reference
  disclaimer: string;
}

export interface BuyerPayablesOverview {
  totalActiveOrders: number;
  totalGrossPayable: number;
  formattedTotalGrossPayable: string;
  totalAmountPaid: number;
  formattedTotalAmountPaid: string;
  totalOutstandingBalance: number;
  formattedTotalOutstandingBalance: string;
  overdueCount: number;
}

export interface BuyerPayableLedgerData {
  singlePayable?: BuyerPayableItem | null;
  overview: BuyerPayablesOverview;
  payables: BuyerPayableItem[];
  lastUpdated: string;
}

export type BuyerPayableLedgerResponse =
  | {
      success: true;
      data: BuyerPayableLedgerData;
      error?: undefined;
    }
  | {
      success: false;
      error: string;
      data?: undefined;
    };
