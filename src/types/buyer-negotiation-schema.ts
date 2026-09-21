import { z } from 'zod';

/**
 * Zod Schema for Broker-to-Buyer Commercial Proposal (Micro-Sprint 25.2)
 * Uses z.coerce.number() for clean react-hook-form type compatibility.
 */
export const sendProposalToBuyerSchema = z.object({
  requirement_id: z.string().min(1, 'Buyer Requirement ID is required'),
  request_id: z.string().optional().nullable(),
  offered_price: z.coerce.number().gt(0, 'Offered price (landed price) must be greater than zero'),
  quantity: z.coerce.number().gt(0, 'Quantity must be greater than zero'),
  delivery_date: z.string().optional().nullable(),
  payment_terms: z.string().optional().nullable(),
  packaging: z.string().optional().nullable(),
  broker_notes: z.string().optional().nullable(),
  expected_version_number: z.coerce.number().optional(),
});

export type SendProposalToBuyerPayload = z.infer<typeof sendProposalToBuyerSchema>;

export interface BuyerNegotiationDetails {
  requirementId: string;
  requestId: string | null;
  buyerCompanyName: string;
  buyerCompanyVerified: boolean;
  commodityId: string;
  commodityName: string;
  gradeId: string | null;
  gradeName: string;
  unitId: string | null;
  unitSymbol: string;
  targetQuantity: number;
  targetPrice: number;
  offeredPrice: number;
  proposedQuantity: number;
  deliveryTerms: string;
  deliveryDate: string | null;
  paymentTerms: string;
  packagingType: string;
  currentStatus: string;
  currentVersionNumber: number;
  expectedVersionNumber: number;
  updatedAt: string;
}
