import { z } from 'zod';

/**
 * Zod Schema for Broker-to-Seller Commercial Proposal (Micro-Sprint 25.1)
 * Uses z.coerce.number() for clean react-hook-form type compatibility.
 */
export const sendProposalToSellerSchema = z.object({
  request_id: z.string().min(1, 'Broker Request / Quotation ID is required'),
  offered_price: z.coerce.number().gt(0, 'Offered price per unit must be greater than zero'),
  quantity: z.coerce.number().gt(0, 'Quantity must be greater than zero'),
  delivery_date: z.string().optional().nullable(),
  payment_terms: z.string().optional().nullable(),
  packaging: z.string().optional().nullable(),
  broker_notes: z.string().optional().nullable(),
  expected_version_number: z.coerce.number().optional(),
});

export type SendProposalToSellerPayload = z.infer<typeof sendProposalToSellerSchema>;

export interface SellerNegotiationDetails {
  requestId: string;
  requirementId: string;
  sellerAvailabilityId: string;
  sellerCompanyName: string;
  sellerCompanyVerified: boolean;
  lotNumber: string;
  commodityId: string;
  commodityName: string;
  gradeId: string | null;
  gradeName: string;
  unitId: string | null;
  unitSymbol: string;
  availableQuantity: number;
  askingPrice: number;
  confidentialMinimumPrice: number | null;
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
