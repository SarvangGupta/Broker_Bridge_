/**
 * Zero-Buyer-PII Sanitization Utility (Micro-Sprint 20.1 & Security Compliance).
 * Strictly strips or masks Buyer phone numbers, emails, GSTINs, and direct WhatsApp links.
 */

const PHONE_REGEX = /(?:\+91[\-\s]?)?[6-9]\d{9}\b|\b\d{10}\b/g;
const EMAIL_REGEX = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
const GSTIN_REGEX = /\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}\b/gi;
const BUYER_DIRECT_CONTACT_REGEX = /(?:wa\.me\/\S+|whatsapp:\S+|contact\s*buyer:\S+)/gi;

/**
 * Automated text sanitizer that strips or masks any Buyer PII before storing or dispatching notifications.
 */
export function sanitizeNotificationText(text: string | null | undefined): string {
  if (!text || typeof text !== "string") return "";

  return text
    .replace(EMAIL_REGEX, "[PROTECTED_EMAIL]")
    .replace(PHONE_REGEX, "[PROTECTED_CONTACT]")
    .replace(GSTIN_REGEX, "[PROTECTED_GST]")
    .replace(BUYER_DIRECT_CONTACT_REGEX, "[BUYER_SHIELDED]")
    .trim();
}
