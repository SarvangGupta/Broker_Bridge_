import { z } from 'zod';

/**
 * Zod validation schema for Buyer Counter-Offer submissions (Micro-Sprint 36.3 & PRD 36.3).
 * 
 * Strict Guardrails:
 * 1. Only permitted commercial parameters can be altered.
 * 2. Requires `expected_version_number` for optimistic concurrency locking.
 * 3. Enforces positive numeric bounds on price and quantity.
 */
export const buyerCounterOfferSchema = z.object({
  proposal_id: z.string().min(1, 'Proposal ID is required'),
  expected_version_number: z.number().int().nonnegative('Valid version number required'),
  counter_price: z.coerce.number().positive('Counter price must be greater than 0'),
  counter_quantity: z.coerce.number().positive('Counter quantity must be greater than 0'),
  delivery_date: z.string().min(1, 'Target delivery date is required').or(z.date()),
  payment_terms: z.string().min(1, 'Payment terms required'),
  packaging: z.string().min(1, 'Packaging required'),
  freight: z.string().min(1, 'Freight terms required'),
  inspection: z.string().optional(),
  buyer_notes_to_broker: z.string().max(500, 'Notes cannot exceed 500 characters').optional(),
});

export type BuyerCounterOfferFormValues = z.infer<typeof buyerCounterOfferSchema>;

/**
 * Standard industry preset choices for trade negotiation dropdowns.
 */
export const NEGOTIATION_PAYMENT_TERMS = [
  '100% Against Delivery / CAD',
  '50% Advance, 50% on Delivery',
  '100% Escrow on Dispatch',
  '7 Days Credit after Weighment',
  '15 Days Credit',
  'Letter of Credit (LC)',
] as const;

export const NEGOTIATION_PACKAGING_TYPES = [
  '50kg HDPE Bags',
  '25kg HDPE Bags',
  'Jute / Gunny Bags',
  'Loose in Bulk Tanker / Truck',
  '1000kg Jumbo Bags',
  'Custom Packaging as per Spec',
] as const;

export const NEGOTIATION_FREIGHT_TERMS = [
  'FOR Destination (Freight Paid by Seller)',
  'Ex-Warehouse / Ex-Mill (Freight by Buyer)',
  'FOR Border / Loading Point',
  'Shared Logistics (50/50 Split)',
] as const;

export const NEGOTIATION_INSPECTION_TERMS = [
  'Mandatory NABL Accredited Lab COA at Loading',
  'Joint Sampling & Weighment at Unloading',
  'Buyer Quality Team Inspection at Warehouse',
  'Third-Party Inspection (SGS/Bureau Veritas)',
  'Standard Factory Quality Certificate',
] as const;
