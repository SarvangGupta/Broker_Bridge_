/**
 * RMBroker Localization Foundation - Languages & Formatters
 * Micro-Sprint RB-04
 */

export type SupportedLanguage = 'en' | 'hi';

export interface LanguageOption {
  code: SupportedLanguage;
  label: string;
  nativeLabel: string;
  flag: string;
}

export const SUPPORTED_LANGUAGES: LanguageOption[] = [
  {
    code: 'en',
    label: 'English',
    nativeLabel: 'English',
    flag: '🇮🇳',
  },
  {
    code: 'hi',
    label: 'Hindi',
    nativeLabel: 'हिन्दी',
    flag: '🇮🇳',
  },
];

export const DEFAULT_LANGUAGE: SupportedLanguage = 'en';
export const LANGUAGE_COOKIE_KEY = 'broker_language';
export const LANGUAGE_STORAGE_KEY = 'broker_preferred_language';

/**
 * Currency Formatter: Formats Indian Rupees with proper Lakh/Crore grouping.
 */
export function formatCurrencyINR(amount: number | string, language: SupportedLanguage = 'en'): string {
  const num = typeof amount === 'string' ? parseFloat(amount.replace(/[^0-9.-]+/g, '')) || 0 : amount;
  const locale = language === 'hi' ? 'hi-IN' : 'en-IN';
  
  try {
    return new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 0,
    }).format(num);
  } catch (_e) {
    return `₹${Math.round(num).toLocaleString('en-IN')}`;
  }
}

/**
 * Number Formatter: Formats quantities and counts according to locale.
 */
export function formatQuantityNumber(value: number | string, language: SupportedLanguage = 'en'): string {
  const num = typeof value === 'string' ? parseFloat(value) || 0 : value;
  const locale = language === 'hi' ? 'hi-IN' : 'en-IN';
  
  try {
    return new Intl.NumberFormat(locale, {
      maximumFractionDigits: 2,
    }).format(num);
  } catch (_e) {
    return num.toLocaleString('en-IN');
  }
}

/**
 * Date Formatter: Formats timestamps with Indian date conventions.
 */
export function formatLocalizedDate(
  dateInput: Date | string | number,
  language: SupportedLanguage = 'en',
  options: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short', year: 'numeric' }
): string {
  try {
    const d = typeof dateInput === 'string' || typeof dateInput === 'number' ? new Date(dateInput) : dateInput;
    if (isNaN(d.getTime())) return '';
    const locale = language === 'hi' ? 'hi-IN' : 'en-IN';
    return new Intl.DateTimeFormat(locale, options).format(d);
  } catch (_e) {
    return String(dateInput);
  }
}
