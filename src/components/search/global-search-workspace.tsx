'use client';

import React, { useState, useEffect, useTransition, useCallback } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import {
  Search,
  X,
  Phone,
  MessageCircle,
  Building2,
  Users2,
  Package,
  Layers,
  Handshake,
  ExternalLink,
  Clock,
  MapPin,
  Tag,
  History,
  Trash2,
  AlertCircle,
  CheckCircle2,
  Sparkles,
  ArrowRight,
  RefreshCw,
  Info,
} from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { useLanguage } from '@/src/lib/i18n/language-context';
import {
  searchGlobalAction,
  SearchEntityType,
  GlobalSearchResults,
  SearchContactResult,
  SearchMaterialResult,
  SearchRequirementResult,
  SearchOfferResult,
  SearchDealResult,
} from '@/src/server/actions/broker-search-actions';
import { VoiceSearchButton } from '@/src/components/search/voice-search-button';

const RECENT_SEARCHES_KEY = 'rmbroker_recent_searches';
const MAX_RECENT_SEARCHES = 6;

export interface GlobalSearchWorkspaceProps {
  initialQuery?: string;
  initialFilter?: SearchEntityType;
  isModalView?: boolean;
  onNavigate?: () => void;
}

export function GlobalSearchWorkspace({
  initialQuery = '',
  initialFilter = 'all',
  isModalView = false,
  onNavigate,
}: GlobalSearchWorkspaceProps) {
  const { t, formatCurrency, formatNumber, language } = useLanguage();
  const router = useRouter();
  const searchParams = useSearchParams();

  const [searchQuery, setSearchQuery] = useState(initialQuery);
  const [activeFilter, setActiveFilter] = useState<SearchEntityType>(initialFilter);
  const [isPending, startTransition] = useTransition();

  const [results, setResults] = useState<GlobalSearchResults>({
    contacts: [],
    materials: [],
    requirements: [],
    offers: [],
    deals: [],
    totalCount: 0,
  });

  const [counts, setCounts] = useState<Record<SearchEntityType, number>>({
    all: 0,
    contacts: 0,
    materials: 0,
    requirements: 0,
    offers: 0,
    deals: 0,
  });

  const [hasSearched, setHasSearched] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [recentSearches, setRecentSearches] = useState<string[]>([]);
  const [showRecent, setShowRecent] = useState(false);

  // Load recent searches from localStorage
  useEffect(() => {
    try {
      const stored = localStorage.getItem(RECENT_SEARCHES_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        if (Array.isArray(parsed)) {
          setRecentSearches(parsed.slice(0, MAX_RECENT_SEARCHES));
        }
      }
    } catch (_e) {
      // LocalStorage access fail-safe
    }
  }, []);

  const saveRecentSearch = (query: string) => {
    const trimmed = query.trim();
    if (!trimmed || trimmed.length < 2) return;

    try {
      const updated = [trimmed, ...recentSearches.filter((q) => q.toLowerCase() !== trimmed.toLowerCase())].slice(
        0,
        MAX_RECENT_SEARCHES
      );
      setRecentSearches(updated);
      localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(updated));
    } catch (_e) {}
  };

  const removeRecentSearch = (e: React.MouseEvent, queryToRemove: string) => {
    e.stopPropagation();
    const updated = recentSearches.filter((q) => q !== queryToRemove);
    setRecentSearches(updated);
    try {
      localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(updated));
    } catch (_e) {}
  };

  const clearAllRecentSearches = () => {
    setRecentSearches([]);
    try {
      localStorage.removeItem(RECENT_SEARCHES_KEY);
    } catch (_e) {}
  };

  // Perform Server Search
  const executeSearch = useCallback(
    (queryText: string, filter: SearchEntityType) => {
      const clean = queryText.trim();
      if (clean.length < 2) {
        setResults({
          contacts: [],
          materials: [],
          requirements: [],
          offers: [],
          deals: [],
          totalCount: 0,
        });
        setCounts({
          all: 0,
          contacts: 0,
          materials: 0,
          requirements: 0,
          offers: 0,
          deals: 0,
        });
        setHasSearched(false);
        setErrorMessage(null);
        return;
      }

      setErrorMessage(null);
      saveRecentSearch(clean);

      startTransition(async () => {
        const res = await searchGlobalAction(clean, filter);
        if (res.success && res.data) {
          setResults(res.data.results);
          setCounts(res.data.counts);
          setHasSearched(true);
        } else {
          setErrorMessage(res.error || t('errorDesc'));
          setHasSearched(true);
        }
      });
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t]
  );

  // Debounced live typing search (300ms)
  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchQuery.trim().length >= 2) {
        executeSearch(searchQuery, activeFilter);
      } else if (searchQuery.trim().length === 0) {
        setResults({
          contacts: [],
          materials: [],
          requirements: [],
          offers: [],
          deals: [],
          totalCount: 0,
        });
        setCounts({
          all: 0,
          contacts: 0,
          materials: 0,
          requirements: 0,
          offers: 0,
          deals: 0,
        });
        setHasSearched(false);
      }
    }, 300);

    return () => clearTimeout(timer);
  }, [searchQuery, activeFilter, executeSearch]);

  const handleManualSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setShowRecent(false);
    if (searchQuery.trim().length >= 2) {
      executeSearch(searchQuery, activeFilter);
    }
  };

  const handleVoiceTranscript = (transcript: string) => {
    setSearchQuery(transcript);
    setShowRecent(false);
    executeSearch(transcript, activeFilter);
  };

  const handleFilterClick = (filter: SearchEntityType) => {
    setActiveFilter(filter);
    if (searchQuery.trim().length >= 2) {
      executeSearch(searchQuery, filter);
    }
  };

  const handleRecentClick = (query: string) => {
    setSearchQuery(query);
    setShowRecent(false);
    executeSearch(query, activeFilter);
  };

  const ENTITY_TABS: Array<{ id: SearchEntityType; label: string; icon: React.ElementType }> = [
    { id: 'all', label: t('searchTabAll'), icon: Sparkles },
    { id: 'contacts', label: t('searchTabContacts'), icon: Users2 },
    { id: 'materials', label: t('searchTabMaterials'), icon: Package },
    { id: 'requirements', label: t('searchTabRequirements'), icon: Layers },
    { id: 'offers', label: t('searchTabOffers'), icon: Tag },
    { id: 'deals', label: t('searchTabDeals'), icon: Handshake },
  ];

  return (
    <div className={`space-y-4 ${isModalView ? 'p-1' : 'w-full max-w-screen-xl mx-auto p-4 sm:p-6'}`}>
      {/* 1. Header & Title (if not modal) */}
      {!isModalView && (
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <div className="flex items-center gap-2.5">
              <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">
                {t('navGlobalSearch')}
              </h1>
              <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200/70 shrink-0">
                RB-07
              </span>
            </div>
            <p className="text-xs sm:text-sm text-slate-500 mt-1">
              {t('searchGlobalPlaceholder')}
            </p>
          </div>
        </div>
      )}

      {/* 2. Unified Search Input Bar */}
      <div className="relative">
        <form onSubmit={handleManualSubmit} className="relative flex items-center">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />

          <input
            type="text"
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value);
              if (!showRecent && e.target.value.length === 0) {
                setShowRecent(true);
              }
            }}
            onFocus={() => {
              if (searchQuery.trim().length === 0 && recentSearches.length > 0) {
                setShowRecent(true);
              }
            }}
            placeholder={t('searchGlobalPlaceholder')}
            className="w-full pl-10 pr-24 py-3 text-sm text-slate-900 placeholder:text-slate-400 bg-white rounded-xl border border-slate-200/90 shadow-xs focus:outline-none focus:border-[#0D9488] focus:ring-2 focus:ring-[#0D9488]/20 transition-all"
            autoComplete="off"
          />

          <div className="absolute right-2.5 top-1/2 -translate-y-1/2 flex items-center gap-1.5">
            {/* Clear button */}
            {searchQuery && (
              <button
                type="button"
                onClick={() => {
                  setSearchQuery('');
                  setResults({
                    contacts: [],
                    materials: [],
                    requirements: [],
                    offers: [],
                    deals: [],
                    totalCount: 0,
                  });
                  setHasSearched(false);
                }}
                className="p-1 rounded-md text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition-colors"
                title={t('searchClearInput')}
                aria-label={t('searchClearInput')}
              >
                <X className="w-4 h-4" />
              </button>
            )}

            {/* Voice Search Button */}
            <VoiceSearchButton
              onTranscript={handleVoiceTranscript}
              isSearching={isPending}
            />

            {/* Submit Action Button */}
            <button
              type="submit"
              disabled={isPending || searchQuery.trim().length < 2}
              className="hidden sm:inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-[#0D9488] hover:bg-[#0F766E] disabled:bg-slate-200 disabled:text-slate-400 text-white text-xs font-semibold shadow-2xs transition-all focus:outline-none"
            >
              {isPending ? (
                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
              ) : (
                <Search className="w-3.5 h-3.5" />
              )}
              <span>{language === 'hi' ? 'खोजें' : 'Search'}</span>
            </button>
          </div>
        </form>

        {/* Recent Searches Dropdown Panel */}
        {showRecent && recentSearches.length > 0 && searchQuery.trim().length === 0 && (
          <div className="absolute left-0 right-0 top-full mt-1.5 z-40 bg-white rounded-xl border border-slate-200 shadow-md p-3 animate-in fade-in slide-in-from-top-1">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100 text-xs">
              <div className="flex items-center gap-1.5 text-slate-500 font-semibold">
                <History className="w-3.5 h-3.5 text-[#0D9488]" />
                <span>{t('searchRecentTitle')}</span>
              </div>
              <button
                type="button"
                onClick={clearAllRecentSearches}
                className="text-[11px] text-slate-400 hover:text-rose-600 font-medium transition-colors"
              >
                {t('searchRecentClearAll')}
              </button>
            </div>

            <div className="flex flex-wrap gap-2 mt-2.5">
              {recentSearches.map((term, i) => (
                <div
                  key={i}
                  onClick={() => handleRecentClick(term)}
                  className="group inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-50 hover:bg-[#CCFBF1] text-xs font-medium text-slate-700 hover:text-[#0D9488] border border-slate-200/80 hover:border-[#0D9488]/40 transition-all cursor-pointer"
                >
                  <span>{term}</span>
                  <button
                    type="button"
                    onClick={(e) => removeRecentSearch(e, term)}
                    className="text-slate-400 group-hover:text-slate-600 hover:text-rose-600"
                    title="Remove item"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* 3. Hindi Transliteration & Mandi Guidance Note */}
      <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-teal-50/60 border border-teal-200/50 text-[11px] text-teal-900">
        <Info className="w-3.5 h-3.5 text-[#0D9488] shrink-0" />
        <span className="leading-tight">{t('searchHindiTransliterationNote')}</span>
      </div>

      {/* 4. Entity Filter Category Tabs */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none select-none">
        {ENTITY_TABS.map((tab) => {
          const isSelected = activeFilter === tab.id;
          const Icon = tab.icon;
          const count = counts[tab.id] || 0;

          return (
            <button
              key={tab.id}
              type="button"
              onClick={() => handleFilterClick(tab.id)}
              className={`flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold border whitespace-nowrap transition-all ${
                isSelected
                  ? 'bg-[#0D9488] text-white border-[#0D9488] shadow-xs'
                  : 'bg-white text-slate-600 border-slate-200/80 hover:bg-slate-50 hover:text-slate-900'
              }`}
            >
              <Icon className="w-3.5 h-3.5" />
              <span>{tab.label}</span>
              {hasSearched && count > 0 && (
                <span
                  className={`px-1.5 py-0.2 rounded-full text-[10px] font-mono font-bold ${
                    isSelected ? 'bg-white/20 text-white' : 'bg-slate-100 text-slate-600'
                  }`}
                >
                  {count}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* 5. Error Banner */}
      {errorMessage && (
        <div className="p-4 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 flex items-center justify-between gap-3 text-xs">
          <div className="flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
            <span>{errorMessage}</span>
          </div>
          <button
            type="button"
            onClick={() => executeSearch(searchQuery, activeFilter)}
            className="px-2.5 py-1 rounded-md bg-white border border-rose-300 text-rose-700 font-bold hover:bg-rose-100 text-[11px]"
          >
            {t('retryAction')}
          </button>
        </div>
      )}

      {/* 6. Loading Skeleton */}
      {isPending && (
        <div className="space-y-3 py-2">
          {[1, 2, 3].map((n) => (
            <Card key={n} className="p-4 bg-white border border-slate-200/80 animate-pulse rounded-xl">
              <div className="flex items-start justify-between">
                <div className="space-y-2 flex-1">
                  <div className="h-4 w-1/3 bg-slate-200 rounded" />
                  <div className="h-3 w-1/2 bg-slate-100 rounded" />
                </div>
                <div className="h-6 w-16 bg-slate-100 rounded" />
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* 7. Empty State */}
      {!isPending && hasSearched && results.totalCount === 0 && !errorMessage && (
        <Card className="p-8 text-center bg-white border border-slate-200/80 rounded-xl space-y-3">
          <div className="w-12 h-12 mx-auto rounded-full bg-slate-100 flex items-center justify-center text-slate-400">
            <Search className="w-6 h-6" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-slate-900">{t('searchNoResultsTitle')}</h3>
            <p className="text-xs text-slate-500 mt-1 max-w-md mx-auto">
              {t('searchNoResultsDesc')}
            </p>
          </div>
        </Card>
      )}

      {/* 8. Initial Hint State (before search) */}
      {!isPending && !hasSearched && (
        <div className="py-8 text-center text-slate-400 space-y-2">
          <Search className="w-8 h-8 mx-auto text-slate-300 stroke-[1.5]" />
          <p className="text-xs text-slate-500">{t('searchMinLengthHint')}</p>
          <p className="text-[11px] text-slate-400 font-mono">{t('searchShortcutsHint')}</p>
        </div>
      )}

      {/* 9. Search Results Grouped by Entity */}
      {!isPending && hasSearched && results.totalCount > 0 && (
        <div className="space-y-6">
          {/* Group A: Buyers & Sellers */}
          {(activeFilter === 'all' || activeFilter === 'contacts') && results.contacts.length > 0 && (
            <section className="space-y-2.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Users2 className="w-4 h-4 text-[#0D9488]" />
                  <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    {t('searchTabContacts')} ({results.contacts.length})
                  </h2>
                </div>
                <Link
                  href="/broker/directory"
                  onClick={onNavigate}
                  className="text-[11px] font-semibold text-[#0D9488] hover:underline inline-flex items-center gap-1"
                >
                  <span>{language === 'hi' ? 'डायरेक्टरी खोलें' : 'View Directory'}</span>
                  <ExternalLink className="w-3 h-3" />
                </Link>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5">
                {results.contacts.map((contact) => (
                  <Card
                    key={contact.id}
                    className="p-3.5 bg-white border border-slate-200/80 hover:border-[#0D9488]/40 hover:shadow-xs transition-all rounded-xl flex flex-col justify-between gap-3"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="font-bold text-slate-900 text-sm truncate">
                            {contact.name}
                          </span>
                          <Badge
                            variant="secondary"
                            className={`text-[9px] font-mono uppercase px-1.5 py-0.2 ${
                              contact.role === 'Buyer'
                                ? 'bg-sky-50 text-sky-700 border-sky-200'
                                : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                            }`}
                          >
                            {contact.role}
                          </Badge>
                        </div>
                        <div className="flex items-center gap-1 text-xs text-slate-600 mt-0.5 truncate">
                          <Building2 className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                          <span className="truncate">{contact.companyName}</span>
                        </div>
                        {contact.city && (
                          <div className="flex items-center gap-1 text-[11px] text-slate-400 mt-0.5">
                            <MapPin className="w-3 h-3 text-slate-400 shrink-0" />
                            <span>{contact.city}</span>
                          </div>
                        )}
                      </div>

                      {/* Verified Number or Status */}
                      <span
                        className={`px-1.5 py-0.5 rounded text-[9px] font-mono font-bold ${
                          contact.status
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : 'bg-slate-100 text-slate-500'
                        }`}
                      >
                        {contact.status ? t('statusActive') : t('statusInactive')}
                      </span>
                    </div>

                    {/* Quick Call & WhatsApp Action Row */}
                    <div className="flex items-center gap-2 pt-2 border-t border-slate-100">
                      {contact.telUri ? (
                        <a
                          href={contact.telUri}
                          className="flex-1 inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-lg bg-teal-50 hover:bg-teal-100 text-[#0D9488] font-bold text-xs transition-colors min-h-[36px]"
                          title={`${t('searchCallAction')}: ${contact.formattedMobile}`}
                        >
                          <Phone className="w-3.5 h-3.5" />
                          <span>{t('searchCallAction')}</span>
                        </a>
                      ) : (
                        <span className="flex-1 text-center text-[10px] text-slate-400 py-1 bg-slate-50 rounded-lg">
                          {t('phoneMissing')}
                        </span>
                      )}

                      {contact.whatsappUri ? (
                        <a
                          href={contact.whatsappUri}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex-1 inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 font-bold text-xs transition-colors min-h-[36px]"
                          title={`${t('searchWhatsAppAction')}: ${contact.formattedMobile}`}
                        >
                          <MessageCircle className="w-3.5 h-3.5" />
                          <span>{t('searchWhatsAppAction')}</span>
                        </a>
                      ) : null}

                      <Link
                        href={contact.url}
                        onClick={onNavigate}
                        className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition-colors"
                        title={t('searchViewRecord')}
                      >
                        <ExternalLink className="w-4 h-4" />
                      </Link>
                    </div>
                  </Card>
                ))}
              </div>
            </section>
          )}

          {/* Group B: Materials & Grades */}
          {(activeFilter === 'all' || activeFilter === 'materials') && results.materials.length > 0 && (
            <section className="space-y-2.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Package className="w-4 h-4 text-indigo-600" />
                  <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    {t('searchTabMaterials')} ({results.materials.length})
                  </h2>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5">
                {results.materials.map((mat) => (
                  <Card
                    key={mat.id}
                    className="p-3.5 bg-white border border-slate-200/80 hover:border-indigo-300 hover:shadow-xs transition-all rounded-xl flex flex-col justify-between gap-3"
                  >
                    <div>
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <h3 className="font-bold text-slate-900 text-sm">{mat.name}</h3>
                          <span className="text-[11px] text-slate-500">
                            {mat.categoryName ? `${mat.categoryName} • ` : ''}
                            {mat.industryName || 'Commodity'}
                          </span>
                        </div>
                        {mat.code && (
                          <Badge variant="outline" className="font-mono text-[9px] uppercase">
                            {mat.code}
                          </Badge>
                        )}
                      </div>

                      {/* Grades / Quality specs chips */}
                      {mat.grades.length > 0 && (
                        <div className="flex flex-wrap gap-1 mt-2.5">
                          {mat.grades.slice(0, 4).map((g, idx) => (
                            <span
                              key={idx}
                              className="px-2 py-0.5 rounded-md bg-indigo-50 text-indigo-700 text-[10px] font-medium"
                            >
                              {g}
                            </span>
                          ))}
                          {mat.grades.length > 4 && (
                            <span className="text-[10px] text-slate-400 self-center">
                              +{mat.grades.length - 4} more
                            </span>
                          )}
                        </div>
                      )}
                    </div>

                    <div className="flex items-center justify-between pt-2 border-t border-slate-100">
                      <Link
                        href={mat.url}
                        onClick={onNavigate}
                        className="inline-flex items-center gap-1.5 text-xs font-bold text-indigo-600 hover:text-indigo-800"
                      >
                        <span>{t('searchFindSupply')}</span>
                        <ArrowRight className="w-3.5 h-3.5" />
                      </Link>
                    </div>
                  </Card>
                ))}
              </div>
            </section>
          )}

          {/* Group C: Buyer Requirements */}
          {(activeFilter === 'all' || activeFilter === 'requirements') &&
            results.requirements.length > 0 && (
              <section className="space-y-2.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Layers className="w-4 h-4 text-blue-600" />
                    <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                      {t('searchTabRequirements')} ({results.requirements.length})
                    </h2>
                  </div>
                  <Link
                    href="/broker/work"
                    onClick={onNavigate}
                    className="text-[11px] font-semibold text-blue-600 hover:underline inline-flex items-center gap-1"
                  >
                    <span>{language === 'hi' ? 'वर्क डेस्क खोलें' : 'View Work Desk'}</span>
                    <ExternalLink className="w-3 h-3" />
                  </Link>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5">
                  {results.requirements.map((req) => (
                    <Card
                      key={req.id}
                      className="p-3.5 bg-white border border-slate-200/80 hover:border-blue-300 hover:shadow-xs transition-all rounded-xl flex flex-col justify-between gap-3"
                    >
                      <div>
                        <div className="flex items-start justify-between gap-2">
                          <div>
                            <span className="font-bold text-slate-900 text-sm">
                              {req.commodityName}
                            </span>
                            {req.gradeName && (
                              <span className="text-xs text-slate-500 ml-1.5 font-medium">
                                ({req.gradeName})
                              </span>
                            )}
                            <div className="text-xs text-slate-600 mt-0.5 truncate">
                              {req.buyerCompanyName}
                            </div>
                          </div>
                          <Badge
                            variant="secondary"
                            className="bg-blue-50 text-blue-700 border-blue-200 text-[9px] uppercase font-mono"
                          >
                            {req.status}
                          </Badge>
                        </div>

                        <div className="grid grid-cols-2 gap-2 mt-2.5 text-xs bg-slate-50 p-2 rounded-lg">
                          <div>
                            <span className="text-[10px] text-slate-400 block font-medium">
                              Volume
                            </span>
                            <span className="font-black text-slate-800">
                              {formatNumber(req.quantity)} {req.unitSymbol}
                            </span>
                          </div>
                          <div>
                            <span className="text-[10px] text-slate-400 block font-medium">
                              Target Price
                            </span>
                            <span className="font-black text-slate-800">
                              {formatCurrency(req.targetPrice)}/{req.unitSymbol}
                            </span>
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center justify-between pt-2 border-t border-slate-100">
                        <span className="text-[10px] text-slate-400 font-mono">
                          ID: {req.id.slice(0, 8)}
                        </span>
                        <Link
                          href={req.url}
                          onClick={onNavigate}
                          className="inline-flex items-center gap-1 text-xs font-bold text-blue-600 hover:text-blue-800"
                        >
                          <span>{t('searchViewRecord')}</span>
                          <ExternalLink className="w-3.5 h-3.5" />
                        </Link>
                      </div>
                    </Card>
                  ))}
                </div>
              </section>
            )}

          {/* Group D: Seller Offers */}
          {(activeFilter === 'all' || activeFilter === 'offers') && results.offers.length > 0 && (
            <section className="space-y-2.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Tag className="w-4 h-4 text-emerald-600" />
                  <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    {t('searchTabOffers')} ({results.offers.length})
                  </h2>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5">
                {results.offers.map((offer) => (
                  <Card
                    key={offer.id}
                    className="p-3.5 bg-white border border-slate-200/80 hover:border-emerald-300 hover:shadow-xs transition-all rounded-xl flex flex-col justify-between gap-3"
                  >
                    <div>
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <div className="flex items-center gap-1.5">
                            <span className="font-bold text-slate-900 text-sm">
                              {offer.commodityName}
                            </span>
                            {offer.lotNumber && (
                              <Badge
                                variant="outline"
                                className="font-mono text-[9px] uppercase px-1.5"
                              >
                                {offer.lotNumber}
                              </Badge>
                            )}
                          </div>
                          <div className="text-xs text-slate-600 mt-0.5 truncate">
                            {offer.sellerCompanyName}
                            {offer.stateName ? ` • ${offer.stateName}` : ''}
                          </div>
                        </div>

                        <Badge
                          variant="secondary"
                          className="bg-emerald-50 text-emerald-700 border-emerald-200 text-[9px] uppercase font-mono"
                        >
                          {offer.loadingStatus}
                        </Badge>
                      </div>

                      <div className="grid grid-cols-2 gap-2 mt-2.5 text-xs bg-slate-50 p-2 rounded-lg">
                        <div>
                          <span className="text-[10px] text-slate-400 block font-medium">
                            Available Lot
                          </span>
                          <span className="font-black text-slate-800">
                            {formatNumber(offer.availableQuantity)} {offer.unitSymbol}
                          </span>
                        </div>
                        <div>
                          <span className="text-[10px] text-slate-400 block font-medium">
                            Asking Price
                          </span>
                          <span className="font-black text-slate-800">
                            {formatCurrency(offer.askingPrice)}/{offer.unitSymbol}
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center justify-between pt-2 border-t border-slate-100">
                      <span className="text-[10px] text-slate-400 font-mono">
                        ID: {offer.id.slice(0, 8)}
                      </span>
                      <Link
                        href={offer.url}
                        onClick={onNavigate}
                        className="inline-flex items-center gap-1 text-xs font-bold text-emerald-600 hover:text-emerald-800"
                      >
                        <span>{t('searchViewRecord')}</span>
                        <ExternalLink className="w-3.5 h-3.5" />
                      </Link>
                    </div>
                  </Card>
                ))}
              </div>
            </section>
          )}

          {/* Group E: Deals */}
          {(activeFilter === 'all' || activeFilter === 'deals') && results.deals.length > 0 && (
            <section className="space-y-2.5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Handshake className="w-4 h-4 text-[#0D9488]" />
                  <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    {t('searchTabDeals')} ({results.deals.length})
                  </h2>
                </div>
                <Link
                  href="/broker/deals"
                  onClick={onNavigate}
                  className="text-[11px] font-semibold text-[#0D9488] hover:underline inline-flex items-center gap-1"
                >
                  <span>{language === 'hi' ? 'सौदे देखें' : 'View Deals'}</span>
                  <ExternalLink className="w-3 h-3" />
                </Link>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5">
                {results.deals.map((deal) => (
                  <Card
                    key={deal.id}
                    className="p-3.5 bg-white border border-slate-200/80 hover:border-[#0D9488]/40 hover:shadow-xs transition-all rounded-xl flex flex-col justify-between gap-3"
                  >
                    <div>
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-slate-900 text-sm">
                              {deal.dealRef}
                            </span>
                            <span className="text-xs text-slate-500 font-medium">
                              {deal.commodityName}
                            </span>
                          </div>
                          <div className="text-xs text-slate-600 mt-0.5">
                            <span className="text-sky-700 font-semibold">{deal.buyerName}</span>
                            <span className="text-slate-400 mx-1.5">↔</span>
                            <span className="text-emerald-700 font-semibold">
                              {deal.sellerName}
                            </span>
                          </div>
                        </div>

                        <Badge
                          variant="secondary"
                          className="bg-teal-50 text-[#0D9488] border-teal-200 text-[9px] uppercase font-mono"
                        >
                          {deal.status}
                        </Badge>
                      </div>

                      <div className="grid grid-cols-2 gap-2 mt-2.5 text-xs bg-slate-50 p-2 rounded-lg">
                        <div>
                          <span className="text-[10px] text-slate-400 block font-medium">
                            Agreed Volume
                          </span>
                          <span className="font-black text-slate-800">
                            {formatNumber(deal.agreedQuantity)} MT
                          </span>
                        </div>
                        <div>
                          <span className="text-[10px] text-slate-400 block font-medium">
                            Agreed Price
                          </span>
                          <span className="font-black text-slate-800">
                            {formatCurrency(deal.agreedPrice)}/MT
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center justify-between pt-2 border-t border-slate-100">
                      <span className="text-[10px] text-slate-400">
                        {new Date(deal.createdAt).toLocaleDateString(
                          language === 'hi' ? 'hi-IN' : 'en-IN',
                          { day: 'numeric', month: 'short' }
                        )}
                      </span>
                      <Link
                        href={deal.url}
                        onClick={onNavigate}
                        className="inline-flex items-center gap-1 text-xs font-bold text-[#0D9488] hover:text-[#0F766E]"
                      >
                        <span>{t('searchViewRecord')}</span>
                        <ExternalLink className="w-3.5 h-3.5" />
                      </Link>
                    </div>
                  </Card>
                ))}
              </div>
            </section>
          )}
        </div>
      )}
    </div>
  );
}
