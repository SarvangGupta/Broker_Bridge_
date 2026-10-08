/**
 * Standard industry fulfillment documents for agricultural & bulk trade.
 * Kept in a standalone types module so both Client Components and Server Actions
 * can import without violating Next.js 'use server' boundary rules.
 */
export const STANDARD_DOCUMENT_TYPES = [
  'Certificate of Analysis',
  'Lorry Receipt',
  'Weighbridge Slip',
  'GST Invoice',
  'Phytosanitary Certificate',
] as const;

export type StandardDocumentType = (typeof STANDARD_DOCUMENT_TYPES)[number];

export type BuyerDocumentActionResponse<T = any> = {
  success: boolean;
  data?: T;
  error?: string;
};
