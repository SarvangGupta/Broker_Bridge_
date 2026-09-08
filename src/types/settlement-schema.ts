import { z } from "zod";

export const settlementStatusSchema = z.enum([
  "Pending",
  "Part Paid",
  "Paid",
  "Overdue",
  "Disputed",
]);

export type SettlementStatus = z.infer<typeof settlementStatusSchema>;

export const paymentItemSchema = z.object({
  id: z.string(),
  amount: z.number(),
  referenceNumber: z.string(),
  status: z.string(),
  confirmedAt: z.string(),
});

export type PaymentItem = z.infer<typeof paymentItemSchema>;

export const disputeItemSchema = z.object({
  id: z.string(),
  reason: z.string(),
  description: z.string().nullable().optional(),
  status: z.string(),
  createdAt: z.string(),
});

export type DisputeItem = z.infer<typeof disputeItemSchema>;

export const transactionSettlementRecordSchema = z.object({
  bookingId: z.string(),
  bookingReference: z.string(),
  dealId: z.string(),
  quotationId: z.string().optional(),
  commodityName: z.string(),
  gradeName: z.string(),
  lotNumber: z.string(),
  bookedQuantity: z.number(),
  unitSymbol: z.string(),
  lockedRate: z.number(),
  grossSaleValue: z.number(),
  brokerCommissionRate: z.number().default(0),
  brokerCommission: z.number().default(0),
  otherCharges: z.number().default(0),
  netReceivable: z.number(),
  paidAmount: z.number(),
  outstandingAmount: z.number(),
  dueDate: z.string(),
  dueDaysRemaining: z.number().default(0),
  status: settlementStatusSchema,
  dealStatus: z.string(),
  dispute: disputeItemSchema.nullable().optional(),
  paymentsList: z.array(paymentItemSchema),
});

export type TransactionSettlementRecord = z.infer<typeof transactionSettlementRecordSchema>;

export const settlementSummarySchema = z.object({
  totalReceivables: z.number(),
  totalCollected: z.number(),
  totalOutstanding: z.number(),
  totalOverdue: z.number(),
  totalCommission: z.number().default(0),
  totalRecords: z.number().default(0),
  paidCount: z.number().default(0),
  partPaidCount: z.number().default(0),
  pendingCount: z.number().default(0),
  overdueCount: z.number().default(0),
  disputedCount: z.number().default(0),
});

export type SettlementSummary = z.infer<typeof settlementSummarySchema>;

export interface SellerSettlementOverviewResponse {
  success: boolean;
  data?: {
    summary: SettlementSummary;
    records: TransactionSettlementRecord[];
  };
  error?: string;
}
