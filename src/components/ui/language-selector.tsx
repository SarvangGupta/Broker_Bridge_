'use client';

import React from 'react';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { SupportedLanguage } from '@/src/lib/i18n/languages';
import { Languages } from 'lucide-react';

export interface LanguageSelectorProps {
  variant?: 'pill' | 'dropdown' | 'compact';
  className?: string;
}

export function LanguageSelector({ variant = 'pill', className = '' }: LanguageSelectorProps) {
  const { language, setLanguage, supportedLanguages } = useLanguage();

  if (variant === 'compact') {
    return (
      <button
        type="button"
        onClick={() => setLanguage(language === 'en' ? 'hi' : 'en')}
        className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg border border-slate-200/80 bg-white hover:bg-slate-50 text-slate-700 text-xs font-semibold shadow-2xs transition-all cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#0D9488] ${className}`}
        title="Toggle English / हिन्दी"
        aria-label="Toggle language between English and Hindi"
      >
        <Languages className="w-3.5 h-3.5 text-[#0D9488] shrink-0" />
        <span className="font-mono tracking-tight font-bold">
          {language === 'en' ? 'हिन्दी' : 'EN'}
        </span>
      </button>
    );
  }

  // Default 'pill' variant: Two-way segment control
  return (
    <div
      role="group"
      aria-label="Language selection"
      className={`inline-flex items-center p-0.5 rounded-lg border border-slate-200 bg-slate-100/80 shadow-2xs ${className}`}
    >
      {supportedLanguages.map((lang) => {
        const isSelected = language === lang.code;

        return (
          <button
            key={lang.code}
            type="button"
            onClick={() => setLanguage(lang.code)}
            aria-pressed={isSelected}
            className={`flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-semibold transition-all cursor-pointer select-none focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#0D9488] ${
              isSelected
                ? 'bg-white text-slate-900 shadow-xs font-bold'
                : 'text-slate-600 hover:text-slate-900 hover:bg-white/50'
            }`}
          >
            <span>{lang.nativeLabel}</span>
          </button>
        );
      })}
    </div>
  );
}
