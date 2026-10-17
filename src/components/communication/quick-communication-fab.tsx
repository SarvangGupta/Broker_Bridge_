'use client';

import React, { useState, useEffect, useTransition } from 'react';
import {
  PhoneCall,
  X,
  Phone,
  MessageCircle,
  Search,
  Building2,
  Users2,
  ShieldCheck,
  AlertCircle,
  Loader2,
  RefreshCw,
} from 'lucide-react';
import { useLanguage } from '@/src/lib/i18n/language-context';
import {
  getQuickDialContactsAction,
  QuickDialContactItem,
} from '@/src/server/actions/broker-search-actions';
import { Badge } from '@/components/ui/badge';

export function QuickCommunicationFAB() {
  const { t, language } = useLanguage();
  const [isOpen, setIsOpen] = useState(false);
  const [contacts, setContacts] = useState<QuickDialContactItem[]>([]);
  const [searchFilter, setSearchFilter] = useState('');
  const [isPending, startTransition] = useTransition();
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Fetch quick dial contacts when modal opens
  useEffect(() => {
    if (isOpen) {
      startTransition(async () => {
        setErrorMessage(null);
        const res = await getQuickDialContactsAction();
        if (res.success && res.data) {
          setContacts(res.data);
        } else {
          setErrorMessage(res.error || t('errorDesc'));
        }
      });
    }
  }, [isOpen, t]);

  // Filter contacts by name, company, or mobile
  const filteredContacts = contacts.filter((c) => {
    const q = searchFilter.toLowerCase().trim();
    if (!q) return true;
    return (
      c.name.toLowerCase().includes(q) ||
      c.companyName.toLowerCase().includes(q) ||
      c.mobile.includes(q)
    );
  });

  const getWhatsAppMessage = (contactName: string) => {
    return t('quickCommPrefilledWhatsApp').replace('{name}', contactName);
  };

  return (
    <>
      {/* 1. Floating Action Button (FAB) */}
      <div className="fixed bottom-20 md:bottom-6 right-4 md:right-6 z-40 select-none">
        <button
          type="button"
          onClick={() => setIsOpen(true)}
          className="group relative flex items-center justify-center w-14 h-14 rounded-full bg-gradient-to-tr from-[#0D9488] to-[#0F766E] text-white shadow-lg hover:shadow-xl hover:scale-105 active:scale-95 transition-all focus:outline-none focus:ring-4 focus:ring-teal-200 min-h-[48px] min-w-[48px]"
          title={t('quickCommFloatingTooltip')}
          aria-label={t('quickCommFloatingTooltip')}
        >
          <PhoneCall className="w-6 h-6 transition-transform group-hover:rotate-12" />
          <span className="absolute -top-1 -right-1 flex h-3.5 w-3.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-teal-400 opacity-75" />
            <span className="relative inline-flex rounded-full h-3.5 w-3.5 bg-emerald-500 border-2 border-white" />
          </span>
        </button>
      </div>

      {/* 2. Quick Communication Modal Dialog */}
      {isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-xs animate-in fade-in">
          <div
            className="w-full max-w-lg bg-white rounded-2xl shadow-2xl border border-slate-200 overflow-hidden flex flex-col max-h-[85vh] animate-in zoom-in-95"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="px-5 py-4 border-b border-slate-100 flex items-center justify-between bg-slate-50/70">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-teal-500/10 text-[#0D9488] flex items-center justify-center">
                  <PhoneCall className="w-5 h-5" />
                </div>
                <div>
                  <h3 className="text-sm font-bold text-slate-900">{t('quickCommTitle')}</h3>
                  <p className="text-[11px] text-slate-500">{t('quickCommSub')}</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setIsOpen(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-200/60 transition-colors"
                aria-label={t('actionClose')}
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Fiduciary Mediation Notice */}
            <div className="px-4 py-2 bg-amber-50/80 border-b border-amber-200/60 flex items-center gap-2 text-[11px] text-amber-900">
              <ShieldCheck className="w-4 h-4 text-amber-600 shrink-0" />
              <span className="leading-tight font-medium">{t('quickCommDisclaimer')}</span>
            </div>

            {/* Search Input Bar */}
            <div className="p-3 border-b border-slate-100 bg-white">
              <div className="relative">
                <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  value={searchFilter}
                  onChange={(e) => setSearchFilter(e.target.value)}
                  placeholder={t('quickCommSearchPlaceholder')}
                  className="w-full pl-9 pr-8 py-2 text-xs text-slate-800 placeholder:text-slate-400 rounded-lg border border-slate-200 focus:outline-none focus:border-[#0D9488] focus:ring-1 focus:ring-[#0D9488]"
                  autoFocus
                />
                {searchFilter && (
                  <button
                    type="button"
                    onClick={() => setSearchFilter('')}
                    className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
            </div>

            {/* Contacts Scrollable List */}
            <div className="flex-1 overflow-y-auto p-3 space-y-2 divide-y divide-slate-100">
              {isPending && (
                <div className="py-8 text-center text-slate-400 flex flex-col items-center gap-2">
                  <Loader2 className="w-6 h-6 animate-spin text-[#0D9488]" />
                  <span className="text-xs">{t('loadingText')}</span>
                </div>
              )}

              {errorMessage && (
                <div className="p-3 rounded-lg bg-rose-50 text-rose-800 text-xs flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
                  <span>{errorMessage}</span>
                </div>
              )}

              {!isPending && filteredContacts.length === 0 && (
                <div className="py-8 text-center text-slate-400 space-y-1">
                  <Users2 className="w-8 h-8 mx-auto text-slate-300 stroke-[1.5]" />
                  <p className="text-xs text-slate-500 font-medium">{t('quickCommNoContacts')}</p>
                </div>
              )}

              {!isPending &&
                filteredContacts.map((contact) => (
                  <div
                    key={contact.id}
                    className="pt-2 first:pt-0 flex items-center justify-between gap-3 hover:bg-slate-50/80 p-2 rounded-xl transition-colors"
                  >
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-slate-900 text-xs sm:text-sm truncate">
                          {contact.name}
                        </span>
                        <Badge
                          variant="secondary"
                          className={`text-[9px] font-mono uppercase px-1.5 py-0 ${
                            contact.role === 'Buyer'
                              ? 'bg-sky-50 text-sky-700 border-sky-200'
                              : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                          }`}
                        >
                          {contact.role}
                        </Badge>
                      </div>

                      <div className="flex items-center gap-1.5 text-xs text-slate-500 mt-0.5 truncate">
                        <Building2 className="w-3 h-3 text-slate-400 shrink-0" />
                        <span className="truncate">{contact.companyName}</span>
                      </div>

                      <div className="text-[11px] text-slate-400 font-mono mt-0.5">
                        {contact.formattedMobile}
                      </div>
                    </div>

                    {/* 1-Tap Action Buttons (min 48px touch targets) */}
                    <div className="flex items-center gap-1.5 shrink-0">
                      {contact.telUri ? (
                        <a
                          href={contact.telUri}
                          className="flex items-center justify-center w-10 h-10 rounded-xl bg-teal-50 hover:bg-teal-100 text-[#0D9488] active:scale-95 transition-all min-h-[40px] min-w-[40px]"
                          title={`${t('searchCallAction')}: ${contact.formattedMobile}`}
                          aria-label={`${t('searchCallAction')}: ${contact.formattedMobile}`}
                        >
                          <Phone className="w-4 h-4" />
                        </a>
                      ) : (
                        <span
                          className="flex items-center justify-center w-10 h-10 rounded-xl bg-slate-100 text-slate-300 cursor-not-allowed"
                          title={t('phoneMissing')}
                        >
                          <Phone className="w-4 h-4" />
                        </span>
                      )}

                      {contact.whatsappUri ? (
                        <a
                          href={`${contact.whatsappUri}?text=${encodeURIComponent(
                            getWhatsAppMessage(contact.name)
                          )}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center justify-center w-10 h-10 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-700 active:scale-95 transition-all min-h-[40px] min-w-[40px]"
                          title={`${t('searchWhatsAppAction')}: ${contact.formattedMobile}`}
                          aria-label={`${t('searchWhatsAppAction')}: ${contact.formattedMobile}`}
                        >
                          <MessageCircle className="w-4 h-4" />
                        </a>
                      ) : (
                        <span
                          className="flex items-center justify-center w-10 h-10 rounded-xl bg-slate-100 text-slate-300 cursor-not-allowed"
                          title={t('phoneMissing')}
                        >
                          <MessageCircle className="w-4 h-4" />
                        </span>
                      )}
                    </div>
                  </div>
                ))}
            </div>

            {/* Footer */}
            <div className="px-4 py-3 border-t border-slate-100 bg-slate-50 flex items-center justify-between text-[11px] text-slate-400">
              <span>
                {filteredContacts.length} {t('searchResultsCount')}
              </span>
              <button
                type="button"
                onClick={() => setIsOpen(false)}
                className="font-bold text-slate-600 hover:text-slate-900"
              >
                {t('actionClose')}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
