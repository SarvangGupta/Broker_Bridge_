/**
 * Zero-Buyer-PII & Channel Privacy Isolation Utility (Micro-Sprint 36.1 & PRD 36.1).
 * Strictly isolates Buyer ↔ Broker negotiation from Seller-side interactions.
 * 
 * Strict Guardrails:
 * 1. Mathematically scrubs Seller confidential notes, minimum floor price, and direct contact details.
 * 2. Explicitly filters out all Seller-originated negotiation events (e.g. SELLER_COUNTER, SELLER_PROPOSED).
 * 3. Guarantees Buyer only communicates with and receives updates from the Broker desk.
 */

const PHONE_REGEX = /(?:\+91[\-\s]?)?[6-9]\d{9}\b|\b\d{10}\b/g;
const EMAIL_REGEX = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
const GSTIN_REGEX = /\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}\b/gi;
const SELLER_DIRECT_CONTACT_REGEX = /(?:wa\.me\/\S+|whatsapp:\S+|contact\s*seller:\S+|call\s*seller:\S+)/gi;

/**
 * Strips phone numbers, emails, GSTIN, and direct contact hooks from text.
 */
export function sanitizeBuyerChannelText(text: string | null | undefined): string {
  if (!text || typeof text !== 'string') return '';

  return text
    .replace(EMAIL_REGEX, '[PROTECTED_EMAIL]')
    .replace(PHONE_REGEX, '[PROTECTED_CONTACT]')
    .replace(GSTIN_REGEX, '[PROTECTED_GST]')
    .replace(SELLER_DIRECT_CONTACT_REGEX, '[SELLER_SHIELDED]')
    .trim();
}

/**
 * Blacklisted action types that belong strictly to the Seller side of negotiation.
 * Must NEVER be exposed to the Buyer under any circumstance.
 */
export const SELLER_ACTION_TYPES_BLACKLIST = new Set([
  'SELLER_COUNTER',
  'SELLER_PROPOSED',
  'SELLER_ACCEPTED',
  'SELLER_REJECTED',
  'SELLER_NOTE',
  'SELLER_UPDATE',
  'SELLER_REQUEST',
  'SELLER_SUBMISSION',
  'SELLER_DISPATCH',
  'SELLER_CONFIRMATION',
]);

/**
 * Permitted action types for the Buyer ↔ Broker negotiation channel.
 */
export const BUYER_PERMITTED_ACTION_TYPES = new Set([
  'BROKER_PROPOSAL_TO_BUYER',
  'BROKER_PROPOSAL',
  'BROKER_REVISED',
  'BROKER_COUNTER',
  'BROKER_MESSAGE',
  'BUYER_COUNTER',
  'BUYER_COUNTERED',
  'BUYER_ACCEPTED',
  'BUYER_REJECTED',
  'BUYER_MESSAGE',
  'BUYER_CONFIRMATION',
  'DEAL_VERSION',
]);

/**
 * Determines whether a negotiation event is permitted in the Buyer channel.
 * Strictly blocks any Seller-originated event.
 */
export function isBuyerPermittedNegotiationEvent(
  actionType: string,
  actorRole?: string | null
): boolean {
  if (!actionType) return false;

  const normalizedAction = actionType.toUpperCase().trim();
  const normalizedRole = (actorRole || '').toLowerCase().trim();

  // 1. Explicitly reject if role is seller
  if (normalizedRole.includes('seller')) {
    return false;
  }

  // 2. Explicitly reject if actionType is in the seller blacklist
  if (SELLER_ACTION_TYPES_BLACKLIST.has(normalizedAction)) {
    return false;
  }

  // 3. Reject any action starting with SELLER_
  if (normalizedAction.startsWith('SELLER_') || normalizedAction.startsWith('SELLER-')) {
    return false;
  }

  return true;
}

/**
 * Mathematically scrubs all confidential Seller fields from a commercial payload.
 * Removes seller minimum floor price, seller internal notes, seller contact info, and warehouse location.
 */
export function sanitizeBuyerNegotiationPayload<T = any>(payload: T): T {
  if (!payload || typeof payload !== 'object') return payload;

  const clean = JSON.parse(JSON.stringify(payload));

  // Explicitly delete confidential Seller fields
  delete clean.confidentialMinimumPrice;
  delete clean.confidential_minimum_price;
  delete clean.confidentialMinPrice;
  delete clean.sellerFloorPrice;
  delete clean.seller_floor_price;
  delete clean.seller_notes;
  delete clean.sellerNotes;
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
  delete clean.sellerCommission;
  delete clean.sellerMargin;
  delete clean.brokerMarginSpread;
  delete clean.sellerId;
  delete clean.sellerAvailabilityId;

  // Recursively sanitize text fields for PII
  for (const key of Object.keys(clean)) {
    if (typeof clean[key] === 'string') {
      clean[key] = sanitizeBuyerChannelText(clean[key]);
    } else if (clean[key] && typeof clean[key] === 'object') {
      clean[key] = sanitizeBuyerNegotiationPayload(clean[key]);
    }
  }

  return clean as T;
}

export interface RawNegotiationEvent {
  id?: string;
  requestId?: string;
  actionType: string;
  actorId?: string;
  actorName?: string | null;
  actorRole?: string | null;
  payload?: any;
  createdAt?: string | Date;
  [key: string]: any;
}

/**
 * Filters and sanitizes negotiation events for the Buyer view.
 * 1. Omit all Seller-originated events.
 * 2. Scrub Seller confidential attributes from payload.
 * 3. Normalize actor display to "Broker Desk" or "Buyer Admin".
 */
export function filterBuyerNegotiationEvents<E extends RawNegotiationEvent>(
  events: E[]
): E[] {
  if (!Array.isArray(events)) return [];

  return events
    .filter((event) => isBuyerPermittedNegotiationEvent(event.actionType, event.actorRole))
    .map((event) => {
      const sanitizedPayload = sanitizeBuyerNegotiationPayload(event.payload);

      const isBuyer = 
        (event.actorRole && event.actorRole.toLowerCase().includes('buyer')) ||
        event.actionType.toUpperCase().startsWith('BUYER');

      const normalizedActorRole = isBuyer ? 'buyer' : 'broker';
      const normalizedActorName = isBuyer ? 'Buyer Admin' : (event.actorName || 'Broker Desk');

      return {
        ...event,
        actorRole: normalizedActorRole,
        actorName: normalizedActorName,
        payload: sanitizedPayload,
      };
    });
}
