'use client';

import React, { useState, useEffect, useTransition } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import {
  Sparkles,
  ShieldCheck,
  Building2,
  Tag,
  Layers,
  MapPin,
  Calendar,
  AlertTriangle,
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  SlidersHorizontal,
  Send,
  HelpCircle,
  Clock,
  ArrowRight,
  TrendingUp,
  RefreshCw,
  Search,
  Lock,
  ChevronRight,
  Filter,
  FlaskConical,
  Scale,
  ShieldAlert,
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { formatIndianCurrency } from '@/lib/utils';
import { useLanguage } from '@/src/lib/i18n/language-context';
import {
  getRankedMatchesForRequirementAction,
  logMatchOverrideAction,
  type MatchedRequirementDetail,
  type RankedBrokerSupplyMatch,
} from '@/src/server/actions/broker-match-actions';
import {
  getRequirementAllocationsAction,
  type BrokerAllocationDetail,
  type AllocationSummary,
} from '@/src/server/actions/broker-allocation-actions';
import type { BrokerAssignedRequirement } from '@/src/server/actions/broker-work-actions';
import { SendRequestDialog } from './send-request-dialog';
import { QualityComparisonPanel } from './quality-comparison-panel';
import { AllocationDialog } from './allocation-dialog';
import { AllocationsList } from './allocations-list';
import { toast } from 'sonner';

interface MatchesViewProps {
  availableRequirements: BrokerAssignedRequirement[];
  initialRequirementId?: string | null;
}

const OVERRIDE_REASONS = [
  { id: 'trusted_supplier', label: 'Trusted supplier relationship' },
  { id: 'offline_negotiation', label: 'Negotiating terms offline' },
  { id: 'spec_deviation_approved', label: 'Buyer approved specification deviation' },
  { id: 'logistics_advantage', label: 'Logistics proximity advantage' },
  { id: 'other', label: 'Other operational reason' },
];

export function MatchesView({
  availableRequirements = [],
  initialRequirementId,
}: MatchesViewProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { t, formatCurrency, formatNumber, language } = useLanguage();
  const urlReqId = searchParams.get('reqId') || initialRequirementId;

  // Active requirement selection
  const [selectedReqId, setSelectedReqId] = useState<string>(
    urlReqId || (availableRequirements.length > 0 ? availableRequirements[0].id : '')
  );

  const [isLoadingMatches, startMatchTransition] = useTransition();
  const [requirementDetail, setRequirementDetail] = useState<MatchedRequirementDetail | null>(null);
  const [rankedMatches, setRankedMatches] = useState<RankedBrokerSupplyMatch[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Allocations State (RB-09)
  const [allocations, setAllocations] = useState<BrokerAllocationDetail[]>([]);
  const [allocationSummary, setAllocationSummary] = useState<AllocationSummary | null>(null);
  const [allocationModalLot, setAllocationModalLot] = useState<RankedBrokerSupplyMatch | null>(null);
  const [isAllocationModalOpen, setIsAllocationModalOpen] = useState<boolean>(false);

  // Filters & State
  const [scoreFilter, setScoreFilter] = useState<'all' | 'strong' | 'good' | 'partial'>('all');
  const [locationFilter, setLocationFilter] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [expandedCards, setExpandedCards] = useState<Record<string, boolean>>({});
  const [overriddenMatches, setOverriddenMatches] = useState<Record<string, string>>({});

  // Dialog states
  const [overrideModalLot, setOverrideModalLot] = useState<RankedBrokerSupplyMatch | null>(null);
  const [overrideReason, setOverrideReason] = useState<string>('trusted_supplier');
  const [overrideNotes, setOverrideNotes] = useState<string>('');
  const [isSubmittingOverride, setIsSubmittingOverride] = useState<boolean>(false);

  // Send request dialog state
  const [requestDialogLot, setRequestDialogLot] = useState<RankedBrokerSupplyMatch | null>(null);
  const [isRequestDialogOpen, setIsRequestDialogOpen] = useState<boolean>(false);

  // Quality check panel state (Sprint 24.2)
  const [qualityCheckLot, setQualityCheckLot] = useState<RankedBrokerSupplyMatch | null>(null);

  // Central loader for requirement, matches, and allocations
  const loadRequirementData = async (reqId: string) => {
    if (!reqId) return;
    setErrorMessage(null);
    const [matchRes, allocRes] = await Promise.all([
      getRankedMatchesForRequirementAction(reqId),
      getRequirementAllocationsAction(reqId),
    ]);

    if (matchRes.success && matchRes.requirement && matchRes.matches) {
      setRequirementDetail(matchRes.requirement);
      setRankedMatches(matchRes.matches);
      // Expand top 2 matches by default for quick explainability
      const initialExpanded: Record<string, boolean> = {};
      matchRes.matches.slice(0, 2).forEach((m) => {
        initialExpanded[m.id] = true;
      });
      setExpandedCards(initialExpanded);
    } else {
      setErrorMessage(matchRes.error || 'Failed to load matching supply lots.');
    }

    if (allocRes.success && allocRes.allocations) {
      setAllocations(allocRes.allocations);
      setAllocationSummary(allocRes.summary || null);
    }
  };

  // Load matches & allocations when selectedReqId changes
  useEffect(() => {
    if (!selectedReqId) return;

    startMatchTransition(() => {
      loadRequirementData(selectedReqId);
    });
  }, [selectedReqId]);

  // Sync selectedReqId when url or initialRequirementId changes
  useEffect(() => {
    const currentUrlReqId = searchParams.get('reqId') || initialRequirementId;
    if (currentUrlReqId && currentUrlReqId !== selectedReqId) {
      setSelectedReqId(currentUrlReqId);
    }
  }, [searchParams, initialRequirementId, selectedReqId]);

  const handleSelectRequirement = (reqId: string) => {
    setSelectedReqId(reqId);
    router.replace(`/broker/work?tab=matches&reqId=${reqId}`, { scroll: false });
  };

  const toggleCardExpand = (id: string) => {
    setExpandedCards((prev) => ({
      ...prev,
      [id]: !prev[id],
    }));
  };

  const handleOpenOverrideDialog = (lot: RankedBrokerSupplyMatch) => {
    setOverrideModalLot(lot);
    setOverrideReason('trusted_supplier');
    setOverrideNotes('');
  };

  const handleSubmitOverride = async () => {
    if (!overrideModalLot || !requirementDetail) return;

    setIsSubmittingOverride(true);
    try {
      const selectedReasonObj = OVERRIDE_REASONS.find((r) => r.id === overrideReason);
      const reasonLabel = selectedReasonObj ? selectedReasonObj.label : overrideReason;

      const res = await logMatchOverrideAction({
        requirementId: requirementDetail.id,
        availabilityId: overrideModalLot.id,
        reasonCode: overrideReason,
        notes: overrideNotes ? `${reasonLabel} — ${overrideNotes}` : reasonLabel,
      });

      if (res.success) {
        setOverriddenMatches((prev) => ({
          ...prev,
          [overrideModalLot.id]: reasonLabel,
        }));
        toast.success('Broker Match Override recorded for compliance audit.');
        setOverrideModalLot(null);
      } else {
        toast.error(res.error || 'Failed to record override');
      }
    } catch (err: any) {
      toast.error(err.message || 'Error recording override');
    } finally {
      setIsSubmittingOverride(false);
    }
  };

  // Extract unique locations for filtering
  const availableLocations = Array.from(
    new Set(rankedMatches.map((m) => m.stateName).filter(Boolean))
  ) as string[];

  // Filter and search matches
  const filteredMatches = rankedMatches.filter((lot) => {
    // Score tier filter
    if (scoreFilter === 'strong' && lot.match.totalScore < 85) return false;
    if (scoreFilter === 'good' && (lot.match.totalScore < 70 || lot.match.totalScore >= 85)) return false;
    if (scoreFilter === 'partial' && (lot.match.totalScore < 50 || lot.match.totalScore >= 70)) return false;

    // Location filter
    if (locationFilter !== 'all' && lot.stateName !== locationFilter) return false;

    // Search filter
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const sellerMatch = lot.sellerCompanyName.toLowerCase().includes(q);
      const lotNumMatch = (lot.lotNumber || '').toLowerCase().includes(q);
      const stateMatch = (lot.stateName || '').toLowerCase().includes(q);
      const districtMatch = (lot.districtName || '').toLowerCase().includes(q);
      const gradeMatch = (lot.gradeName || '').toLowerCase().includes(q);
      return sellerMatch || lotNumMatch || stateMatch || districtMatch || gradeMatch;
    }

    return true;
  });

  const getScoreBadgeStyles = (score: number) => {
    if (score >= 85) {
      return 'bg-emerald-50 text-emerald-800 border-emerald-300 ring-emerald-500/20';
    }
    if (score >= 70) {
      return 'bg-teal-50 text-teal-800 border-teal-300 ring-teal-500/20';
    }
    if (score >= 50) {
      return 'bg-amber-50 text-amber-800 border-amber-300 ring-amber-500/20';
    }
    return 'bg-slate-100 text-slate-700 border-slate-300 ring-slate-400/20';
  };

  const getClassificationBadge = (classification: string, score: number) => {
    if (score >= 85) {
      return (
        <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-emerald-100 text-emerald-800 border border-emerald-200">
          Strong Match
        </span>
      );
    }
    if (score >= 70) {
      return (
        <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-teal-100 text-teal-800 border border-teal-200">
          Good Match
        </span>
      );
    }
    if (score >= 50) {
      return (
        <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-amber-100 text-amber-800 border border-amber-200">
          Partial Match
        </span>
      );
    }
    return (
      <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-slate-100 text-slate-600 border border-slate-200">
        Low / Alternative
      </span>
    );
  };

  // If no requirements assigned to broker at all
  if (availableRequirements.length === 0) {
    return (
      <Card className="border-dashed border-2 border-slate-200 bg-white/70">
        <CardContent className="p-8 sm:p-12 text-center space-y-4">
          <div className="mx-auto w-12 h-12 rounded-full bg-slate-100 border border-slate-200 flex items-center justify-center text-slate-400">
            <Sparkles className="w-6 h-6" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="font-bold text-slate-800 text-base">{t('emptyRequirementsTitle')}</h3>
            <p className="text-xs sm:text-sm text-slate-500">
              {t('emptyRequirementsDesc')}
            </p>
          </div>
        </CardContent>
      </Card>
    );
  }

  const requestedQty = requirementDetail?.quantity ?? 0;
  const fulfilledQty = requirementDetail?.fulfilledQuantity ?? 0;
  const remainingQty = requirementDetail?.remainingQuantity ?? 0;
  const unitSymbol = requirementDetail?.unitSymbol || requirementDetail?.unitName || 'MT';
  const allocationPercent = requestedQty > 0 ? Math.min(100, Math.round((fulfilledQty / requestedQty) * 100)) : 0;

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto">
      {/* 1. MANDATORY FIDUCIARY & NON-RESERVATION DISCLAIMER */}
      <div className="p-3.5 bg-amber-50/90 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800 rounded-xl flex items-start gap-3 shadow-xs">
        <ShieldAlert className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
        <div className="text-xs text-amber-900 dark:text-amber-200 leading-relaxed">
          <strong className="font-semibold block mb-0.5">
            {language === 'hi' ? 'ब्रोकर प्रकटीकरण एवं परिचालन नियम:' : 'Broker Fiduciary Notice:'}
          </strong>
          {t('brokerDisclaimerMatching')}
        </div>
      </div>

      {/* 2. REQUIREMENT CONTEXT HEADER & VISUAL ALLOCATION PROGRESS */}
      <Card className="bg-gradient-to-br from-slate-900 via-slate-800 to-teal-950 text-white border-0 shadow-md rounded-2xl overflow-hidden">
        <div className="p-4 sm:p-6 space-y-5">
          {/* Top Bar: Selector & Status */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-white/10">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="px-2.5 py-0.5 rounded-md text-[11px] font-mono font-bold tracking-wider bg-[#0D9488] text-white uppercase shadow-xs">
                {language === 'hi' ? 'सक्रिय खरीदार मांग' : 'ACTIVE BUYER REQUIREMENT'}
              </span>
              {requirementDetail?.isUrgent && (
                <span className="px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-rose-500/90 text-white animate-pulse">
                  URGENT (&le; 48H)
                </span>
              )}
            </div>

            {/* Switch Requirement Dropdown */}
            {availableRequirements.length > 1 && (
              <div className="flex items-center gap-2">
                <span className="text-xs text-slate-300 font-medium hidden sm:inline">
                  {language === 'hi' ? 'मांग बदलें:' : 'Switch Mandate:'}
                </span>
                <Select
                  value={selectedReqId}
                  onValueChange={(val) => {
                    if (val) handleSelectRequirement(val);
                  }}
                >
                  <SelectTrigger className="w-full sm:w-[280px] h-9 text-xs bg-white/10 border-white/20 text-white font-medium focus:ring-teal-400">
                    <SelectValue placeholder="Select requirement...">
                      {(() => {
                        const active = availableRequirements.find((r) => r.id === selectedReqId);
                        return active
                          ? `${active.buyerCompanyName} • ${active.commodityName}`
                          : 'Select requirement...';
                      })()}
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent className="bg-slate-900 border-slate-800 text-white">
                    {availableRequirements.map((req) => (
                      <SelectItem
                        key={req.id}
                        value={req.id}
                        className="text-xs focus:bg-teal-900 focus:text-white"
                      >
                        {req.buyerCompanyName} • {req.commodityName} ({req.quantity} {req.unitSymbol || 'MT'})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
          </div>

          {/* Main Context Details */}
          {requirementDetail ? (
            <div className="space-y-4">
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-center">
                {/* Left Column: Buyer & Commodity */}
                <div className="lg:col-span-7 space-y-2">
                  <div className="flex items-center gap-2">
                    <h2 className="text-lg sm:text-xl font-bold text-white tracking-tight flex items-center gap-2">
                      <span>{requirementDetail.buyerCompanyName}</span>
                      {requirementDetail.buyerCompanyVerified && (
                        <ShieldCheck className="w-4 h-4 text-teal-400 inline shrink-0" />
                      )}
                    </h2>
                    <span className="text-xs text-slate-400 font-mono">
                      ({requirementDetail.requirementRef})
                    </span>
                  </div>

                  <div className="text-xs text-teal-200/80 font-medium flex items-center gap-1.5 flex-wrap">
                    {requirementDetail.industryName && <span>{requirementDetail.industryName}</span>}
                    {requirementDetail.categoryName && (
                      <>
                        <span>•</span>
                        <span>{requirementDetail.categoryName}</span>
                      </>
                    )}
                    <span>•</span>
                    <span className="text-white font-bold text-sm">
                      {requirementDetail.commodityName} ({requirementDetail.gradeName})
                    </span>
                  </div>
                </div>

                {/* Right Column: Commercial Targets */}
                <div className="lg:col-span-5 grid grid-cols-3 gap-2 bg-white/5 rounded-xl p-3 border border-white/10 text-center">
                  <div>
                    <div className="text-[10px] text-slate-400 uppercase font-semibold">{t('qtyRequested')}</div>
                    <div className="text-sm sm:text-base font-bold text-white mt-0.5">
                      {formatNumber(requirementDetail.quantity)}{' '}
                      <span className="text-xs font-normal text-teal-300">
                        {unitSymbol}
                      </span>
                    </div>
                  </div>

                  <div>
                    <div className="text-[10px] text-slate-400 uppercase font-semibold">{t('fieldTargetPrice')}</div>
                    <div className="text-sm sm:text-base font-bold text-teal-300 mt-0.5">
                      {formatCurrency(requirementDetail.targetPrice)}
                    </div>
                  </div>

                  <div>
                    <div className="text-[10px] text-slate-400 uppercase font-semibold">{t('fieldDeliveryDate')}</div>
                    <div className="text-xs sm:text-sm font-bold text-slate-200 mt-0.5 truncate">
                      {requirementDetail.targetDateFormatted}
                    </div>
                  </div>
                </div>
              </div>

              {/* Visual Allocation Summary Progress Bar */}
              <div className="bg-white/10 rounded-xl p-3.5 border border-white/15 space-y-2">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between text-xs gap-2">
                  <div className="flex items-center gap-2">
                    <Scale className="w-4 h-4 text-teal-300" />
                    <span className="font-bold text-white">{t('allocationSummary')}</span>
                    <Badge variant="outline" className="text-[10px] border-white/20 text-teal-200 font-mono">
                      {allocationPercent}% {language === 'hi' ? 'पूर्ण' : 'Fulfilled'}
                    </Badge>
                  </div>
                  <div className="flex items-center gap-4 text-xs font-mono">
                    <div>
                      <span className="text-slate-300 mr-1.5">{t('qtyRequested')}:</span>
                      <strong className="text-white">{formatNumber(requestedQty)} {unitSymbol}</strong>
                    </div>
                    <div>
                      <span className="text-teal-300 mr-1.5">{t('qtyAllocated')}:</span>
                      <strong className="text-teal-300">{formatNumber(fulfilledQty)} {unitSymbol}</strong>
                    </div>
                    <div>
                      <span className="text-amber-300 mr-1.5">{t('remainingQty')}:</span>
                      <strong className="text-amber-300">{formatNumber(remainingQty)} {unitSymbol}</strong>
                    </div>
                  </div>
                </div>

                {/* Multi-seller Allocation Bar */}
                <div className="w-full bg-black/40 rounded-full h-3 overflow-hidden p-0.5 border border-white/10">
                  <div
                    className="bg-gradient-to-r from-teal-400 to-emerald-400 h-full rounded-full transition-all duration-500 ease-out"
                    style={{ width: `${allocationPercent}%` }}
                  />
                </div>
              </div>
            </div>
          ) : (
            <div className="h-16 flex items-center justify-center text-xs text-slate-400">
              {t('loadingText')}
            </div>
          )}
        </div>
      </Card>

      {/* 3. ACTIVE ALLOCATIONS LIST (Multi-seller breakdown) */}
      <AllocationsList
        allocations={allocations}
        summary={allocationSummary}
        onRefresh={() => selectedReqId && loadRequirementData(selectedReqId)}
      />

      {/* 4. MATCH FILTER & SEARCH BAR */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 bg-white dark:bg-slate-900 p-3 sm:p-4 rounded-xl border border-slate-200/80 dark:border-slate-800 shadow-2xs">
        {/* Score Tier Filter Tabs */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0 scrollbar-none">
          <Button
            type="button"
            size="sm"
            variant={scoreFilter === 'all' ? 'default' : 'ghost'}
            onClick={() => setScoreFilter('all')}
            className={`h-9 px-3 text-xs font-semibold rounded-lg ${
              scoreFilter === 'all'
                ? 'bg-[#0D9488] text-white'
                : 'text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
          >
            {language === 'hi' ? 'सभी मिलान' : 'All Matches'} ({rankedMatches.length})
          </Button>

          <Button
            type="button"
            size="sm"
            variant={scoreFilter === 'strong' ? 'default' : 'ghost'}
            onClick={() => setScoreFilter('strong')}
            className={`h-9 px-3 text-xs font-semibold rounded-lg ${
              scoreFilter === 'strong'
                ? 'bg-emerald-600 text-white'
                : 'text-emerald-700 dark:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-950/40'
            }`}
          >
            {language === 'hi' ? 'उत्कृष्ट' : 'Strong'} &ge;85 ({rankedMatches.filter((m) => m.match.totalScore >= 85).length})
          </Button>

          <Button
            type="button"
            size="sm"
            variant={scoreFilter === 'good' ? 'default' : 'ghost'}
            onClick={() => setScoreFilter('good')}
            className={`h-9 px-3 text-xs font-semibold rounded-lg ${
              scoreFilter === 'good'
                ? 'bg-teal-600 text-white'
                : 'text-teal-700 dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/40'
            }`}
          >
            {language === 'hi' ? 'अच्छा' : 'Good'} 70–84 ({rankedMatches.filter((m) => m.match.totalScore >= 70 && m.match.totalScore < 85).length})
          </Button>

          <Button
            type="button"
            size="sm"
            variant={scoreFilter === 'partial' ? 'default' : 'ghost'}
            onClick={() => setScoreFilter('partial')}
            className={`h-9 px-3 text-xs font-semibold rounded-lg ${
              scoreFilter === 'partial'
                ? 'bg-amber-600 text-white'
                : 'text-amber-700 dark:text-amber-400 hover:bg-amber-50 dark:hover:bg-amber-950/40'
            }`}
          >
            {language === 'hi' ? 'आंशिक' : 'Partial'} 50–69 ({rankedMatches.filter((m) => m.match.totalScore >= 50 && m.match.totalScore < 70).length})
          </Button>
        </div>

        {/* Location Dropdown and Search Input */}
        <div className="flex items-center gap-2">
          {availableLocations.length > 0 && (
            <Select value={locationFilter} onValueChange={(val) => { if (val) setLocationFilter(val); }}>
              <SelectTrigger className="w-[150px] h-9 text-xs">
                <SelectValue placeholder="Location" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{language === 'hi' ? 'सभी राज्य' : 'All States'}</SelectItem>
                {availableLocations.map((loc) => (
                  <SelectItem key={loc} value={loc} className="text-xs">
                    {loc}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}

          <div className="relative w-full sm:w-56 shrink-0">
            <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <Input
              type="text"
              placeholder={language === 'hi' ? 'खोजें (विक्रेता, लॉट, मंडी)...' : 'Search seller, lot, mandi...'}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-8 text-xs h-9 bg-slate-50 dark:bg-slate-900 border-slate-200 dark:border-slate-800"
            />
          </div>
        </div>
      </div>

      {/* 5. MATCH RESULTS LIST */}
      {isLoadingMatches ? (
        <div className="p-12 text-center text-slate-500">
          <RefreshCw className="w-8 h-8 mx-auto mb-3 animate-spin text-[#0D9488]" />
          <p className="font-semibold text-sm">{t('loadingText')}</p>
        </div>
      ) : errorMessage ? (
        <Card className="border-red-200 bg-red-50/50">
          <CardContent className="p-6 text-center text-red-700 text-sm">
            <AlertTriangle className="w-8 h-8 mx-auto mb-2 text-red-500" />
            <p className="font-bold">{t('errorTitle')}</p>
            <p className="text-xs mt-1 text-red-600">{errorMessage}</p>
          </CardContent>
        </Card>
      ) : filteredMatches.length === 0 ? (
        <Card className="border-dashed border-2 border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900">
          <CardContent className="p-8 sm:p-12 text-center space-y-3">
            <div className="mx-auto w-12 h-12 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-400">
              <Search className="w-6 h-6" />
            </div>
            <div className="space-y-1">
              <h3 className="font-bold text-slate-800 dark:text-slate-200 text-sm">
                {t('emptyMatchesTitle')}
              </h3>
              <p className="text-xs text-slate-500 max-w-sm mx-auto">
                {t('emptyMatchesDesc')}
              </p>
            </div>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {filteredMatches.map((lot, idx) => {
            const isExpanded = !!expandedCards[lot.id];
            const hasOverride = overriddenMatches[lot.id];
            const priceDiff = requirementDetail
              ? lot.askingPrice - requirementDetail.targetPrice
              : 0;
            const isPriceFavorable = priceDiff <= 0;

            return (
              <Card
                key={lot.id}
                className="border-slate-200 dark:border-slate-800 shadow-xs hover:shadow-md transition-shadow overflow-hidden bg-white dark:bg-slate-900"
              >
                <div className="p-4 sm:p-5 space-y-4">
                  {/* Top Header: Score & Match Tier */}
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <div
                        className={`px-3 py-1 rounded-lg border font-mono font-bold text-sm sm:text-base flex items-center gap-1.5 ring-1 ${getScoreBadgeStyles(
                          lot.match.totalScore
                        )}`}
                      >
                        <Sparkles className="w-4 h-4 text-[#0D9488]" />
                        <span>{lot.match.totalScore}%</span>
                      </div>
                      {getClassificationBadge(lot.match.classification, lot.match.totalScore)}

                      {hasOverride && (
                        <Badge
                          variant="outline"
                          className="bg-purple-50 text-purple-700 border-purple-200 text-[10px] font-semibold"
                        >
                          Overridden: {hasOverride}
                        </Badge>
                      )}
                    </div>

                    {/* Lot Number & Loading Status */}
                    <div className="flex items-center gap-2 text-xs">
                      <span className="font-mono text-slate-500 bg-slate-50 dark:bg-slate-800 px-2 py-0.5 rounded border border-slate-200/60 dark:border-slate-700">
                        {lot.lotNumber}
                      </span>
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border border-slate-200 dark:border-slate-700">
                        {lot.loadingStatus}
                      </span>
                    </div>
                  </div>

                  {/* Seller Name & Location Strip */}
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pt-1 border-t border-slate-100 dark:border-slate-800">
                    <div className="flex items-center gap-1.5">
                      <Building2 className="w-4 h-4 text-slate-400 shrink-0" />
                      <span className="font-bold text-slate-900 dark:text-white text-sm sm:text-base">
                        {lot.sellerCompanyName}
                      </span>
                      {lot.sellerCompanyVerified && (
                        <ShieldCheck className="w-4 h-4 text-[#0D9488] shrink-0" />
                      )}
                    </div>

                    <div className="flex items-center gap-1.5 text-xs text-slate-500">
                      <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                      <span>
                        {lot.districtName ? `${lot.districtName}, ` : ''}
                        {lot.stateName || 'Location on file'}
                      </span>
                    </div>
                  </div>

                  {/* Commercial Comparison Grid */}
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 bg-slate-50/80 dark:bg-slate-800/50 p-3 rounded-xl border border-slate-100 dark:border-slate-800">
                    {/* Available Volume */}
                    <div>
                      <div className="text-[10px] font-semibold text-slate-400 uppercase">
                        {t('qtyAvailable')}
                      </div>
                      <div className="text-sm font-bold text-slate-800 dark:text-slate-200 mt-0.5">
                        {formatNumber(lot.availableQuantity)} {lot.unitSymbol || 'MT'}
                      </div>
                      <div className="text-[10px] text-slate-500">
                        {requirementDetail?.quantity
                          ? `${Math.min(
                              100,
                              Math.round((lot.availableQuantity / requirementDetail.quantity) * 100)
                            )}% ${language === 'hi' ? 'मांग का' : 'of buyer need'}`
                          : 'Full lot'}
                      </div>
                    </div>

                    {/* Asking Price */}
                    <div>
                      <div className="text-[10px] font-semibold text-slate-400 uppercase">
                        {t('fieldAskingPrice')}
                      </div>
                      <div className="text-sm font-bold text-slate-900 dark:text-white mt-0.5">
                        {formatCurrency(lot.askingPrice)}
                      </div>
                      <div
                        className={`text-[10px] font-medium ${
                          isPriceFavorable ? 'text-emerald-600' : 'text-amber-600'
                        }`}
                      >
                        {isPriceFavorable
                          ? `₹${Math.abs(priceDiff)} ${language === 'hi' ? 'लक्षित से कम' : 'below target'}`
                          : `+₹${priceDiff} ${language === 'hi' ? 'लक्षित से अधिक' : 'above target'}`}
                      </div>
                    </div>

                    {/* Confidential Floor Price (Authorized to Broker) */}
                    <div>
                      <div className="text-[10px] font-semibold text-teal-700 uppercase flex items-center gap-1">
                        <Lock className="w-2.5 h-2.5" />
                        <span>{t('fieldFloorPrice')}</span>
                      </div>
                      <div className="text-sm font-bold text-teal-900 dark:text-teal-300 mt-0.5">
                        {lot.confidentialMinimumPrice
                          ? formatCurrency(lot.confidentialMinimumPrice)
                          : formatCurrency(lot.askingPrice)}
                      </div>
                      <div className="text-[10px] text-teal-600 font-medium">
                        {language === 'hi' ? 'गोपनीय सीमा' : 'Confidential limit'}
                      </div>
                    </div>

                    {/* Stock Readiness */}
                    <div>
                      <div className="text-[10px] font-semibold text-slate-400 uppercase">
                        {t('fieldValidUntil')}
                      </div>
                      <div className="text-xs font-semibold text-slate-700 dark:text-slate-300 mt-0.5 truncate">
                        {lot.validUntilFormatted}
                      </div>
                      <div className="text-[10px] text-slate-500">
                        {lot.gradeName}
                      </div>
                    </div>
                  </div>

                  {/* Explainability Accordion ("Why this match?") */}
                  <div className="border border-slate-100 dark:border-slate-800 rounded-lg overflow-hidden">
                    <button
                      type="button"
                      onClick={() => toggleCardExpand(lot.id)}
                      className="w-full px-3 py-2 bg-slate-50/50 dark:bg-slate-800/40 hover:bg-slate-100/70 dark:hover:bg-slate-800/80 text-left flex items-center justify-between text-xs font-semibold text-slate-700 dark:text-slate-300 transition-colors"
                    >
                      <div className="flex items-center gap-2">
                        <Sparkles className="w-3.5 h-3.5 text-[#0D9488]" />
                        <span>
                          {t('matchExplanation')} ({lot.match.reasons.length} {language === 'hi' ? 'अनुकूल' : 'advantages'},{' '}
                          {lot.match.risks.length} {language === 'hi' ? 'ध्यानार्थ' : 'considerations'})
                        </span>
                      </div>
                      {isExpanded ? (
                        <ChevronUp className="w-4 h-4 text-slate-400" />
                      ) : (
                        <ChevronDown className="w-4 h-4 text-slate-400" />
                      )}
                    </button>

                    {isExpanded && (
                      <div className="p-3 bg-white dark:bg-slate-900 space-y-3 border-t border-slate-100 dark:border-slate-800 text-xs">
                        {/* Score weights chip list */}
                        <div className="flex flex-wrap gap-1.5 pb-2 border-b border-slate-100 dark:border-slate-800 text-[11px] font-mono">
                          <span className="px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                            Commodity: {lot.match.breakdown.commodity}/35
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                            Grade: {lot.match.breakdown.grade}/25
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                            Price: {lot.match.breakdown.price}/20
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                            Location: {lot.match.breakdown.location}/10
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                            Volume: {lot.match.breakdown.quantity}/7
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
                            Date: {lot.match.breakdown.deliveryDate}/3
                          </span>
                        </div>

                        {/* Reasons */}
                        {lot.match.reasons.length > 0 && (
                          <div className="space-y-1">
                            <div className="font-semibold text-emerald-800 dark:text-emerald-400 text-[11px]">
                              {t('matchReasons')}:
                            </div>
                            <ul className="space-y-1 pl-1">
                              {lot.match.reasons.map((r, i) => (
                                <li key={i} className="text-slate-600 dark:text-slate-400 flex items-start gap-1.5">
                                  <span>{r}</span>
                                </li>
                              ))}
                            </ul>
                          </div>
                        )}

                        {/* Risks */}
                        {lot.match.risks.length > 0 && (
                          <div className="space-y-1 pt-1">
                            <div className="font-semibold text-amber-800 dark:text-amber-400 text-[11px]">
                              {t('matchRisks')}:
                            </div>
                            <ul className="space-y-1 pl-1">
                              {lot.match.risks.map((risk, i) => (
                                <li key={i} className="text-slate-600 dark:text-slate-400 flex items-start gap-1.5">
                                  <span>{risk}</span>
                                </li>
                              ))}
                            </ul>
                          </div>
                        )}
                      </div>
                    )}
                  </div>

                  {/* ACTION ROW (Min 48px touch targets) */}
                  <div className="flex flex-col sm:flex-row items-center gap-2 pt-2">
                    {/* Primary CTA: Controlled Allocation (RB-09) */}
                    <Button
                      type="button"
                      onClick={() => {
                        setAllocationModalLot(lot);
                        setIsAllocationModalOpen(true);
                      }}
                      className="w-full sm:flex-1 min-h-[48px] h-12 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-sm shadow-xs rounded-lg transition-all flex items-center justify-center gap-2 px-4"
                    >
                      <Scale className="w-4 h-4 shrink-0" />
                      <span>{t('allocateOffer')}</span>
                      <ChevronRight className="w-4 h-4 ml-auto sm:ml-0 opacity-80 shrink-0" />
                    </Button>

                    {/* Secondary CTA: Send Request / Structure */}
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => {
                        setRequestDialogLot(lot);
                        setIsRequestDialogOpen(true);
                      }}
                      className="w-full sm:w-auto min-h-[48px] h-12 border-teal-200 dark:border-teal-800 hover:bg-teal-50 dark:hover:bg-teal-950/40 text-teal-800 dark:text-teal-300 font-semibold text-xs rounded-lg transition-all flex items-center justify-center gap-2 px-3.5 shrink-0"
                    >
                      <Send className="w-4 h-4 shrink-0" />
                      <span>{language === 'hi' ? 'अनुरोध भेजें' : 'Send Request'}</span>
                    </Button>

                    {/* Quality CTA: Check Quality (Sprint 24.2) */}
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => setQualityCheckLot(lot)}
                      className="w-full sm:w-auto min-h-[48px] h-12 border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300 font-semibold text-xs rounded-lg transition-all flex items-center justify-center gap-2 px-3.5 shrink-0"
                    >
                      <FlaskConical className="w-4 h-4 text-[#0D9488] shrink-0" />
                      <span>{language === 'hi' ? 'गुणवत्ता जांच' : 'Check Quality'}</span>
                    </Button>

                    {/* Decision Gate: Manual Override */}
                    <Button
                      type="button"
                      variant="ghost"
                      onClick={() => handleOpenOverrideDialog(lot)}
                      className="w-full sm:w-auto min-h-[48px] h-12 text-slate-500 hover:text-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-xs rounded-lg transition-all flex items-center justify-center gap-1.5 px-3 shrink-0"
                    >
                      <SlidersHorizontal className="w-3.5 h-3.5 shrink-0" />
                      <span>{language === 'hi' ? 'ओवरराइड' : 'Override'}</span>
                    </Button>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* 6. CONTROLLED ALLOCATION MODAL (RB-09) */}
      {allocationModalLot && requirementDetail && (
        <AllocationDialog
          open={isAllocationModalOpen}
          onOpenChange={setIsAllocationModalOpen}
          requirement={requirementDetail}
          offer={allocationModalLot}
          onAllocationSuccess={() => {
            if (selectedReqId) loadRequirementData(selectedReqId);
          }}
        />
      )}

      {/* 7. MANUAL OVERRIDE MODAL */}
      <Dialog open={!!overrideModalLot} onOpenChange={(open) => !open && setOverrideModalLot(null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <SlidersHorizontal className="w-4 h-4 text-[#0D9488]" />
              <span>Record Manual Match Override</span>
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              PRD v2.2 Human Decision Gate: Override algorithmic match ranking for lot{' '}
              <span className="font-mono font-medium text-slate-700 dark:text-slate-300">{overrideModalLot?.lotNumber}</span>.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <div className="bg-slate-50 dark:bg-slate-800 p-3 rounded-lg border border-slate-200/80 dark:border-slate-700 text-xs space-y-1">
              <div className="font-medium text-slate-700 dark:text-slate-200">Lot: {overrideModalLot?.sellerCompanyName}</div>
              <div className="text-slate-500">
                Score: {overrideModalLot?.match.totalScore}% • Asking:{' '}
                {overrideModalLot ? formatIndianCurrency(overrideModalLot.askingPrice) : ''}
              </div>
            </div>

            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700 dark:text-slate-300">Reason for Override *</Label>
              <Select
                value={overrideReason}
                onValueChange={(val) => {
                  if (val) setOverrideReason(val);
                }}
              >
                <SelectTrigger className="h-10 text-xs bg-white dark:bg-slate-900">
                  <SelectValue placeholder="Select reason...">
                    {OVERRIDE_REASONS.find((r) => r.id === overrideReason)?.label || 'Select reason...'}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {OVERRIDE_REASONS.map((r) => (
                    <SelectItem key={r.id} value={r.id} className="text-xs">
                      {r.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700 dark:text-slate-300">Broker Operational Notes (Optional)</Label>
              <Textarea
                placeholder="Add contextual justification for this pairing..."
                value={overrideNotes}
                onChange={(e) => setOverrideNotes(e.target.value)}
                rows={3}
                className="text-xs resize-none focus-visible:ring-[#0D9488]"
              />
            </div>
          </div>

          <DialogFooter className="flex flex-col sm:flex-row gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => setOverrideModalLot(null)}
              className="min-h-[44px] h-11"
              disabled={isSubmittingOverride}
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleSubmitOverride}
              className="min-h-[44px] h-11 bg-[#0D9488] hover:bg-teal-700 text-white font-bold"
              disabled={isSubmittingOverride}
            >
              {isSubmittingOverride ? 'Recording...' : 'Confirm Override'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* 8. SEND REQUEST DIALOG (from Sprint 23.4) */}
      {requestDialogLot && (
        <SendRequestDialog
          open={isRequestDialogOpen}
          onOpenChange={setIsRequestDialogOpen}
          lot={requestDialogLot as any}
          requirementContext={
            requirementDetail
              ? {
                  id: requirementDetail.id,
                  ref: requirementDetail.requirementRef,
                  commodityName: requirementDetail.commodityName,
                  quantity: requirementDetail.remainingQuantity > 0 ? requirementDetail.remainingQuantity : requirementDetail.quantity,
                  unit: requirementDetail.unitSymbol || requirementDetail.unitName,
                }
              : null
          }
          onSuccess={() => {
            toast.success('Commercial request successfully dispatched to Seller inbox!');
            setIsRequestDialogOpen(false);
          }}
        />
      )}

      {/* 9. QUALITY COMPARISON PANEL (Micro-Sprint 24.2) */}
      {qualityCheckLot && requirementDetail && (
        <QualityComparisonPanel
          open={!!qualityCheckLot}
          onOpenChange={(open) => !open && setQualityCheckLot(null)}
          requirementId={requirementDetail.id}
          availabilityId={qualityCheckLot.id}
          onVerificationComplete={() => {
            if (selectedReqId) loadRequirementData(selectedReqId);
          }}
        />
      )}
    </div>
  );
}
