import { z } from "zod";

export const BROKER_RESPONSE_ACTIONS = ['accept', 'reject', 'counter'] as const;
export type BrokerResponseAction = typeof BROKER_RESPONSE_ACTIONS[number];

/**
 * Zod validation schema for Seller responding to a broker-originated commercial proposal.
 * Strictly checks required rejection reasons and counter terms.
 */
export const brokerResponseSchema = z
  .object({
    requestId: z.string().uuid("Valid quotation/request ID is required"),
    action: z.enum(BROKER_RESPONSE_ACTIONS, {
      required_error: "Action type is required",
    }),
    rejectionReason: z.preprocess(
      (val) => (val === "" || val === null || val === undefined ? undefined : String(val).trim()),
      z.string().optional()
    ),
    counterPrice: z.preprocess(
      (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
      z.number({ invalid_type_error: "Counter price must be a valid number" })
        .positive("Counter price must be positive")
        .optional()
    ),
    counterQuantity: z.preprocess(
      (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
      z.number({ invalid_type_error: "Counter quantity must be a valid number" })
        .positive("Counter quantity must be positive")
        .optional()
    ),
    counterDeliveryDate: z.preprocess(
      (val) => (val === "" || val === null || val === undefined ? undefined : String(val)),
      z.string().optional()
    ),
    counterRemarks: z.preprocess(
      (val) => (val === "" || val === null || val === undefined ? undefined : String(val).trim()),
      z.string().max(500, "Remarks cannot exceed 500 characters").optional()
    ),
  })
  .superRefine((data, ctx) => {
    // Refinement 1: If rejecting, a clear reason is mandatory
    if (data.action === "reject") {
      if (!data.rejectionReason || data.rejectionReason.trim().length < 5) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Please provide a brief reason for rejection (at least 5 characters)",
          path: ["rejectionReason"],
        });
      }
    }

    // Refinement 2: If countering, at least one parameter must change
    if (data.action === "counter") {
      const hasPrice = data.counterPrice !== undefined && data.counterPrice !== null && data.counterPrice > 0;
      const hasQuantity = data.counterQuantity !== undefined && data.counterQuantity !== null && data.counterQuantity > 0;
      const hasRemarks = data.counterRemarks !== undefined && data.counterRemarks !== null && data.counterRemarks.trim().length > 0;
      const hasDate = data.counterDeliveryDate !== undefined && data.counterDeliveryDate !== null && data.counterDeliveryDate.trim().length > 0;

      if (!hasPrice && !hasQuantity && !hasRemarks && !hasDate) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "At least one counter proposal field (price, quantity, delivery date, or remarks) must be specified",
          path: ["counterPrice"],
        });
      }
    }
  });

export type BrokerResponseInput = z.infer<typeof brokerResponseSchema>;
export type BrokerResponsePayload = BrokerResponseInput;

/**
 * Anonymized, Seller-Safe Broker Request Model.
 * HARD PRIVACY ENFORCEMENT: Never exposes Buyer name, email, phone, or direct WhatsApp.
 */
export interface SellerBrokerRequestItem {
  id: string;
  requirementId: string;
  sellerAvailabilityId: string;
  commodityName: string;
  categoryName?: string | null;
  industryName?: string | null;
  gradeName?: string | null;
  lotNumber?: string | null;
  requestedQuantity: number;
  unitSymbol: string;
  proposedRate: number;
  askingPrice?: number | null;
  deliveryState?: string | null;
  deliveryDistrict?: string | null;
  deliveryTerms?: string | null;
  paymentTerms?: string | null;
  targetDate?: Date | string | null;
  loadingWindow?: string | null;
  brokerNotes?: string | null;
  brokerName?: string | null;
  brokerCompany?: string | null;
  isBrokerVerified?: boolean;
  status:
    | 'Pending'
    | 'Sent'
    | 'Seller Accepted'
    | 'Seller Rejected'
    | 'Seller Countered'
    | 'Expired'
    | 'Accepted'
    | 'Rejected'
    | 'Countered';
  expiresAt: Date | string;
  createdAt: Date | string;
  counterPrice?: number | null;
  counterNotes?: string | null;
  rejectionReason?: string | null;
}
