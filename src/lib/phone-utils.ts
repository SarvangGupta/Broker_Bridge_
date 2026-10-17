/**
 * Phone Number Validation and Normalization Utilities for RMBroker
 * Micro-Sprint RB-06
 */

export interface PhoneValidationResult {
  isValid: boolean;
  normalized: string; // E.164-like e.g. +919876543210
  formatted: string;  // e.g. +91 98765 43210
  rawDigits: string;  // e.g. 9876543210
  error?: string;
}

/**
 * Validates and normalizes Indian mobile numbers (+91 standard).
 * Accepts formats:
 * - 9876543210
 * - 09876543210
 * - +91 98765 43210
 * - 919876543210
 * - +91-98765-43210
 */
export function validateAndNormalizePhone(rawPhone: string | null | undefined): PhoneValidationResult {
  if (!rawPhone || typeof rawPhone !== 'string') {
    return {
      isValid: false,
      normalized: '',
      formatted: '',
      rawDigits: '',
      error: 'Phone number is required',
    };
  }

  // Strip all whitespace, hyphens, parentheses, and dots
  const cleaned = rawPhone.replace(/[\s\-\(\)\.]/g, '').trim();

  let digits = cleaned;

  // Handle leading +91
  if (digits.startsWith('+91')) {
    digits = digits.slice(3);
  } else if (digits.startsWith('91') && digits.length === 12) {
    digits = digits.slice(2);
  } else if (digits.startsWith('0') && digits.length === 11) {
    digits = digits.slice(1);
  }

  // Check if exactly 10 digits
  if (!/^\d{10}$/.test(digits)) {
    return {
      isValid: false,
      normalized: '',
      formatted: '',
      rawDigits: digits,
      error: 'Please enter a valid 10-digit mobile number',
    };
  }

  // Indian mobile numbers must start with 6, 7, 8, or 9
  if (!/^[6-9]/.test(digits)) {
    return {
      isValid: false,
      normalized: '',
      formatted: '',
      rawDigits: digits,
      error: 'Mobile number must start with 6, 7, 8, or 9',
    };
  }

  const normalized = `+91${digits}`;
  const formatted = `+91 ${digits.slice(0, 5)} ${digits.slice(5)}`;

  return {
    isValid: true,
    normalized,
    formatted,
    rawDigits: digits,
  };
}

/**
 * Returns safe tel: URI for device dialler
 */
export function getSafeTelUri(phone: string | null | undefined): string | null {
  const res = validateAndNormalizePhone(phone);
  if (!res.isValid) return null;
  return `tel:${res.normalized}`;
}

/**
 * Returns safe wa.me URL for WhatsApp conversation
 */
export function getSafeWhatsAppUri(phone: string | null | undefined, initialMessage?: string): string | null {
  const res = validateAndNormalizePhone(phone);
  if (!res.isValid) return null;
  const base = `https://wa.me/91${res.rawDigits}`;
  if (initialMessage && initialMessage.trim()) {
    return `${base}?text=${encodeURIComponent(initialMessage.trim())}`;
  }
  return base;
}
