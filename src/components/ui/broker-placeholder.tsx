'use client';

import React from 'react';
import Link from 'next/link';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { Card, CardContent } from '@/components/ui/card';
import { Construction, ArrowLeft, ShieldCheck, Layers } from 'lucide-react';

export interface BrokerPlaceholderProps {
  title: string;
  hindiTitle?: string;
  description: string;
  hindiDescription?: string;
  milestone: string;
  badge?: string;
  icon?: React.ElementType;
}

export function BrokerPlaceholder({
  title,
  hindiTitle,
  description,
  hindiDescription,
  milestone,
  badge = 'Planned',
  icon: Icon = Layers,
}: BrokerPlaceholderProps) {
  const { language, t } = useLanguage();

  const displayTitle = language === 'hi' && hindiTitle ? hindiTitle : title;
  const displayDesc = language === 'hi' && hindiDescription ? hindiDescription : description;

  return (
    <div className="w-full max-w-5xl mx-auto p-4 sm:p-6 lg:p-8 space-y-6">
      {/* Back button */}
      <div>
        <Link
          href="/broker"
          className="inline-flex items-center gap-1.5 text-xs sm:text-sm font-semibold text-slate-600 hover:text-[#0D9488] transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>{t('actionBackToDashboard')}</span>
        </Link>
      </div>

      <Card className="border border-slate-200/90 shadow-2xs bg-white rounded-2xl overflow-hidden">
        <CardContent className="p-8 sm:p-12 text-center space-y-6">
          {/* Milestone Badge */}
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-teal-50 border border-teal-200 text-[#0D9488] text-xs font-mono font-bold tracking-wide">
            <ShieldCheck className="w-4 h-4" />
            <span>{milestone}</span>
            <span className="text-teal-400">•</span>
            <span className="uppercase">{badge}</span>
          </div>

          {/* Module Icon */}
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#0D9488]/10 to-[#0F766E]/20 border border-[#0D9488]/20 flex items-center justify-center text-[#0D9488] mx-auto shadow-inner">
            <Icon className="w-8 h-8" />
          </div>

          {/* Text Content */}
          <div className="space-y-2 max-w-lg mx-auto">
            <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">
              {displayTitle}
            </h1>
            <p className="text-sm text-slate-600 leading-relaxed">
              {displayDesc}
            </p>
          </div>

          {/* Compliance & Zero Simulation Assurance */}
          <div className="p-4 rounded-xl bg-slate-50 border border-slate-200/70 max-w-md mx-auto text-left flex items-start gap-3">
            <Construction className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
            <div className="text-xs space-y-1">
              <p className="font-bold text-slate-800">
                {language === 'hi' ? 'वास्तविक एंटरप्राइज आर्किटेक्चर' : 'Authoritative Architecture'}
              </p>
              <p className="text-slate-500">
                {language === 'hi'
                  ? 'शून्य सिम्युलेटेड बिजनेस वर्कफ़्लो। यह मॉड्यूल आगामी स्प्रिंट में लाइव डेटाबेस स्कीमा और ऑथराइजेशन नियमों के साथ सक्रिय होगा।'
                  : 'Zero fabricated workflows. This module will integrate with live PostgreSQL models and verified broker permissions in the scheduled sprint.'}
              </p>
            </div>
          </div>

          {/* Action Link */}
          <div className="pt-2">
            <Link
              href="/broker"
              className="inline-flex items-center justify-center px-6 py-2.5 rounded-xl bg-[#0D9488] hover:bg-[#0F766E] text-white text-sm font-semibold shadow-xs transition-all cursor-pointer"
            >
              {t('actionBackToDashboard')}
            </Link>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
