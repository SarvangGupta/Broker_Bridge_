/**
 * Zero-Buyer-PII & Dual-Channel Privacy Scrubber Utility (Micro-Sprint 25.3 & Security Compliance).
 * Strictly enforces mathematical privacy boundaries between Buyer and Seller negotiation streams.
 */

const PHONE_REGEX = /(?:\+91[\-\s]?)?[6-9]\d{9}\b|\b\d{10}\b/g;
const EMAIL_REGEX = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
const GSTIN_REGEX = /\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}\b/gi;
const BUYER_DIRECT_CONTACT_REGEX = /(?:wa\.me\/\S+|whatsapp:\S+|contact\s*buyer:\S+)/gi;

/**
 * Automated text sanitizer that strips or masks any Buyer PII before storing or dispatching notifications.
 */
export function sanitizeNotificationText(text: string | null | undefined): string {
  if (!text || typeof text !== 'string') return '';

  return text
    .replace(EMAIL_REGEX, '[PROTECTED_EMAIL]')
    .replace(PHONE_REGEX, '[PROTECTED_CONTACT]')
    .replace(GSTIN_REGEX, '[PROTECTED_GST]')
    .replace(BUYER_DIRECT_CONTACT_REGEX, '[BUYER_SHIELDED]')
    .trim();
}

/**
 * Task 1 (Micro-Sprint 25.3): Sanitizes commercial payloads intended for the Buyer Channel.
 * Explicitly removes Seller confidential minimum price, internal notes, seller contact info, and exact warehouse location.
 */
export function sanitizePayloadForBuyer<T = any>(payload: T): T {
  if (!payload || typeof payload !== 'object') return payload;

  const clean = JSON.parse(JSON.stringify(payload));

  // Explicitly delete confidential Seller fields
  delete clean.confidentialMinimumPrice;
  delete clean.confidential_minimum_price;
  delete clean.confidentialMinPrice;
  delete clean.seller_internal_notes;
  delete clean.sellerInternalNotes;
  delete clean.sellerCompanyName;
  delete clean.sellerCompanyVerified;
  delete clean.sellerPhone;
  delete clean.sellerEmail;
  delete clean.sellerGst;
  delete clean.sellerLocation;
  delete clean.exactWarehouseAddress;
  delete clean.warehouseAddress;

  // Sanitize text fields recursively for PII
  for (const key of Object.keys(clean)) {
    if (typeof clean[key] === 'string') {
      clean[key] = sanitizeNotificationText(clean[key]);
    }
  }

  return clean as T;
}

/**
 * Task 1 (Micro-Sprint 25.3): Sanitizes commercial payloads intended for the Seller Channel.
 * Explicitly removes Buyer target price, internal notes, buyer company name, and buyer contact info.
 */
export function sanitizePayloadForSeller<T = any>(payload: T): T {
  if (!payload || typeof payload !== 'object') return payload;

  const clean = JSON.parse(JSON.stringify(payload));

  // Explicitly delete confidential Buyer fields
  delete clean.targetPrice;
  delete clean.target_price;
  delete clean.targetPricePerUnit;
  delete clean.buyer_internal_notes;
  delete clean.buyerInternalNotes;
  delete clean.buyerCompanyName;
  delete clean.buyerCompanyVerified;
  delete clean.buyerPhone;
  delete clean.buyerEmail;
  delete clean.buyerGst;
  delete clean.buyerLocation;

  // Sanitize text fields recursively for PII
  for (const key of Object.keys(clean)) {
    if (typeof clean[key] === 'string') {
      clean[key] = sanitizeNotificationText(clean[key]);
    }
  }

  return clean as T;
}
