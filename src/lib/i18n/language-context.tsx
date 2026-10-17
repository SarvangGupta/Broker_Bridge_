'use client';

import React, { createContext, useContext, useState, useEffect, useMemo, useCallback } from 'react';
import {
  SupportedLanguage,
  SUPPORTED_LANGUAGES,
  DEFAULT_LANGUAGE,
  LANGUAGE_COOKIE_KEY,
  LANGUAGE_STORAGE_KEY,
  formatCurrencyINR,
  formatQuantityNumber,
  formatLocalizedDate,
} from './languages';
import { TRANSLATIONS, TranslationKey } from './translations';

export interface LanguageContextValue {
  language: SupportedLanguage;
  setLanguage: (lang: SupportedLanguage) => void;
  t: (key: TranslationKey, fallback?: string) => string;
  formatCurrency: (amount: number | string) => string;
  formatNumber: (val: number | string) => string;
  formatDate: (date: Date | string | number, options?: Intl.DateTimeFormatOptions) => string;
  supportedLanguages: typeof SUPPORTED_LANGUAGES;
}

const LanguageContext = createContext<LanguageContextValue | null>(null);

export interface LanguageProviderProps {
  children: React.ReactNode;
  initialLanguage?: SupportedLanguage;
}

export function LanguageProvider({ children, initialLanguage }: LanguageProviderProps) {
  const [language, setLanguageState] = useState<SupportedLanguage>(() => {
    if (initialLanguage && (initialLanguage === 'en' || initialLanguage === 'hi')) {
      return initialLanguage;
    }
    return DEFAULT_LANGUAGE;
  });

  // Client-side restoration from localStorage or cookie
  useEffect(() => {
    try {
      if (typeof window !== 'undefined') {
        const stored = localStorage.getItem(LANGUAGE_STORAGE_KEY) as SupportedLanguage | null;
        if (stored === 'en' || stored === 'hi') {
          setLanguageState(stored);
          return;
        }

        // Check document.cookie
        const match = document.cookie.match(new RegExp(`(^|;\\s*)${LANGUAGE_COOKIE_KEY}=([^;]*)`));
        if (match) {
          const cookieVal = decodeURIComponent(match[2]) as SupportedLanguage;
          if (cookieVal === 'en' || cookieVal === 'hi') {
            setLanguageState(cookieVal);
          }
        }
      }
    } catch (_e) {
      // Ignore storage access errors in restricted iframe/incognito
    }
  }, []);

  const setLanguage = useCallback((newLang: SupportedLanguage) => {
    setLanguageState(newLang);
    try {
      if (typeof window !== 'undefined') {
        localStorage.setItem(LANGUAGE_STORAGE_KEY, newLang);
        document.cookie = `${LANGUAGE_COOKIE_KEY}=${newLang}; path=/; max-age=31536000; SameSite=Lax`;
        document.documentElement.lang = newLang;
      }
    } catch (_e) {
      // Storage unavailable fallback
    }
  }, []);

  const t = useCallback((key: TranslationKey, fallback?: string): string => {
    const dict = TRANSLATIONS[language] || TRANSLATIONS.en;
    const value = dict[key];
    if (value) return value;
    const fallbackDict = TRANSLATIONS.en;
    return fallbackDict[key] || fallback || String(key);
  }, [language]);

  const formatCurrency = useCallback((amount: number | string): string => {
    return formatCurrencyINR(amount, language);
  }, [language]);

  const formatNumber = useCallback((val: number | string): string => {
    return formatQuantityNumber(val, language);
  }, [language]);

  const formatDate = useCallback((date: Date | string | number, options?: Intl.DateTimeFormatOptions): string => {
    return formatLocalizedDate(date, language, options);
  }, [language]);

  const contextValue = useMemo<LanguageContextValue>(() => ({
    language,
    setLanguage,
    t,
    formatCurrency,
    formatNumber,
    formatDate,
    supportedLanguages: SUPPORTED_LANGUAGES,
  }), [language, setLanguage, t, formatCurrency, formatNumber, formatDate]);

  return (
    <LanguageContext.Provider value={contextValue}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage(): LanguageContextValue {
  const context = useContext(LanguageContext);
  if (!context) {
    // Graceful fallback if called outside provider (e.g. testing)
    return {
      language: DEFAULT_LANGUAGE,
      setLanguage: () => {},
      t: (key: TranslationKey, fallback?: string) => TRANSLATIONS.en[key] || fallback || String(key),
      formatCurrency: (amt: number | string) => formatCurrencyINR(amt, 'en'),
      formatNumber: (val: number | string) => formatQuantityNumber(val, 'en'),
      formatDate: (d: Date | string | number, opt?: Intl.DateTimeFormatOptions) => formatLocalizedDate(d, 'en', opt),
      supportedLanguages: SUPPORTED_LANGUAGES,
    };
  }
  return context;
}
