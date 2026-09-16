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
import {
  getRankedMatchesForRequirementAction,
  logMatchOverrideAction,
  type MatchedRequirementDetail,
  type RankedBrokerSupplyMatch,
} from '@/src/server/actions/broker-match-actions';
import type { BrokerAssignedRequirement } from '@/src/server/actions/broker-work-actions';
import { SendRequestDialog } from './send-request-dialog';
import { QualityComparisonPanel } from './quality-comparison-panel';
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
  const urlReqId = searchParams.get('reqId') || initialRequirementId;

  // Active requirement selection
  const [selectedReqId, setSelectedReqId] = useState<string>(
    urlReqId || (availableRequirements.length > 0 ? availableRequirements[0].id : '')
  );

  const [isLoadingMatches, startMatchTransition] = useTransition();
  const [requirementDetail, setRequirementDetail] = useState<MatchedRequirementDetail | null>(null);
  const [rankedMatches, setRankedMatches] = useState<RankedBrokerSupplyMatch[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Filters & State
  const [scoreFilter, setScoreFilter] = useState<'all' | 'strong' | 'good' | 'partial'>('all');
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

  // Load matches when selectedReqId changes
  useEffect(() => {
    if (!selectedReqId) return;

    startMatchTransition(async () => {
      setErrorMessage(null);
      const res = await getRankedMatchesForRequirementAction(selectedReqId);
      if (res.success && res.requirement && res.matches) {
        setRequirementDetail(res.requirement);
        setRankedMatches(res.matches);
        // Expand top 2 matches by default for quick explainability
        const initialExpanded: Record<string, boolean> = {};
        res.matches.slice(0, 2).forEach((m) => {
          initialExpanded[m.id] = true;
        });
        setExpandedCards(initialExpanded);
      } else {
        setErrorMessage(res.error || 'Failed to load matching supply lots.');
      }
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

  // Filter and search matches
  const filteredMatches = rankedMatches.filter((lot) => {
    // Score tier filter
    if (scoreFilter === 'strong' && lot.match.totalScore < 85) return false;
    if (scoreFilter === 'good' && (lot.match.totalScore < 70 || lot.match.totalScore >= 85)) return false;
    if (scoreFilter === 'partial' && (lot.match.totalScore < 50 || lot.match.totalScore >= 70)) return false;

    // Search filter
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const sellerMatch = lot.sellerCompanyName.toLowerCase().includes(q);
      const lotNumMatch = (lot.lotNumber || '').toLowerCase().includes(q);
      const stateMatch = (lot.stateName || '').toLowerCase().includes(q);
      const districtMatch = (lot.districtName || '').toLowerCase().includes(q);
      return sellerMatch || lotNumMatch || stateMatch || districtMatch;
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
            <h3 className="font-bold text-slate-800 text-base">No Assigned Requirements</h3>
            <p className="text-xs sm:text-sm text-slate-500">
              You do not have any open Buyer Requirements assigned to your broker desk. Check the Requirements tab when new demand arrives.
            </p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto">
      {/* 1. REQUIREMENT CONTEXT HEADER (Sticky & Selectable) */}
      <Card className="bg-gradient-to-br from-slate-900 via-slate-800 to-teal-950 text-white border-0 shadow-md rounded-2xl overflow-hidden">
        <div className="p-4 sm:p-6 space-y-4">
          {/* Top Bar: Selector & Status */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-white/10">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="px-2.5 py-0.5 rounded-md text-[11px] font-mono font-bold tracking-wider bg-[#0D9488] text-white uppercase shadow-xs">
                ACTIVE BUYER REQUIREMENT
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
                  Switch Mandate:
                </span>
                <Select
                  value={selectedReqId}
                  onValueChange={(val) => {
                    if (val) handleSelectRequirement(val);
                  }}
                >
                  <SelectTrigger className="w-full sm:w-[260px] h-9 text-xs bg-white/10 border-white/20 text-white font-medium focus:ring-teal-400">
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

              {/* Right Column: Key Commercial Targets */}
              <div className="lg:col-span-5 grid grid-cols-3 gap-2 bg-white/5 rounded-xl p-3 border border-white/10 text-center">
                <div>
                  <div className="text-[10px] text-slate-400 uppercase font-semibold">Volume Needed</div>
                  <div className="text-sm sm:text-base font-bold text-white mt-0.5">
                    {requirementDetail.quantity}{' '}
                    <span className="text-xs font-normal text-teal-300">
                      {requirementDetail.unitSymbol || 'MT'}
                    </span>
                  </div>
                </div>

                <div>
                  <div className="text-[10px] text-slate-400 uppercase font-semibold">Target Price</div>
                  <div className="text-sm sm:text-base font-bold text-teal-300 mt-0.5">
                    {formatIndianCurrency(requirementDetail.targetPrice)}
                  </div>
                </div>

                <div>
                  <div className="text-[10px] text-slate-400 uppercase font-semibold">Target Date</div>
                  <div className="text-xs sm:text-sm font-bold text-slate-200 mt-0.5 truncate">
                    {requirementDetail.targetDateFormatted}
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div className="h-16 flex items-center justify-center text-xs text-slate-400">
              Loading requirement metadata...
            </div>
          )}
        </div>
      </Card>

      {/* 2. MATCH FILTER & SORT BAR */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-white p-3 sm:p-4 rounded-xl border border-slate-200/80 shadow-2xs">
        {/* Score Tier Filter Tabs */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 scrollbar-none">
          <Button
            type="button"
            size="sm"
            variant={scoreFilter === 'all' ? 'default' : 'ghost'}
            onClick={() => setScoreFilter('all')}
            className={`h-9 px-3 text-xs font-semibold rounded-lg ${
              scoreFilter === 'all'
                ? 'bg-[#0D9488] text-white'
                : 'text-slate-600 hover:bg-slate-100'
            }`}
          >
            All Matches ({rankedMatches.length})
          </Button>

          <Button
            type="button"
            size="sm"
            variant={scoreFilter === 'strong' ? 'default' : 'ghost'}
            onClick={() => setScoreFilter('strong')}
            className={`h-9 px-3 text-xs font-semibold rounded-lg ${
              scoreFilter === 'strong'
                ? 'bg-emerald-600 text-white'
                : 'text-emerald-700 hover:bg-emerald-50'
            }`}
          >
            Strong &ge;85 ({rankedMatches.filter((m) => m.match.totalScore >= 85).length})
          </Button>

          <Button
            type="button"
            size="sm"
            variant={scoreFilter === 'good' ? 'default' : 'ghost'}
            onClick={() => setScoreFilter('good')}
            className={`h-9 px-3 text-xs font-semibold rounded-lg ${
              scoreFilter === 'good'
                ? 'bg-teal-600 text-white'
                : 'text-teal-700 hover:bg-teal-50'
            }`}
          >
            Good 70–84 ({rankedMatches.filter((m) => m.match.totalScore >= 70 && m.match.totalScore < 85).length})
          </Button>

          <Button
            type="button"
            size="sm"
            variant={scoreFilter === 'partial' ? 'default' : 'ghost'}
            onClick={() => setScoreFilter('partial')}
            className={`h-9 px-3 text-xs font-semibold rounded-lg ${
              scoreFilter === 'partial'
                ? 'bg-amber-600 text-white'
                : 'text-amber-700 hover:bg-amber-50'
            }`}
          >
            Partial 50–69 ({rankedMatches.filter((m) => m.match.totalScore >= 50 && m.match.totalScore < 70).length})
          </Button>
        </div>

        {/* Search within matches */}
        <div className="relative w-full sm:w-64 shrink-0">
          <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <Input
            placeholder="Search seller, lot #, state..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="h-9 pl-8 text-xs bg-slate-50 border-slate-200/80 focus-visible:ring-[#0D9488]"
          />
        </div>
      </div>

      {/* 3. RANKED SUPPLY FEED */}
      {isLoadingMatches ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <Card key={i} className="animate-pulse bg-white border border-slate-200 rounded-xl p-6">
              <div className="h-6 bg-slate-200 rounded w-1/3 mb-4"></div>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-4">
                <div className="h-12 bg-slate-100 rounded"></div>
                <div className="h-12 bg-slate-100 rounded"></div>
                <div className="h-12 bg-slate-100 rounded"></div>
                <div className="h-12 bg-slate-100 rounded"></div>
              </div>
              <div className="h-10 bg-slate-100 rounded"></div>
            </Card>
          ))}
        </div>
      ) : errorMessage ? (
        <Card className="border-rose-200 bg-rose-50/50">
          <CardContent className="p-6 text-center text-rose-700 text-sm">
            {errorMessage}
          </CardContent>
        </Card>
      ) : filteredMatches.length === 0 ? (
        <Card className="border-dashed border-2 border-slate-200 bg-white/70">
          <CardContent className="p-8 sm:p-12 text-center space-y-3">
            <div className="mx-auto w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center text-slate-400">
              <Filter className="w-6 h-6" />
            </div>
            <h3 className="font-bold text-slate-800 text-base">No Matching Seller Supply Found</h3>
            <p className="text-xs sm:text-sm text-slate-500 max-w-sm mx-auto">
              No active seller inventory lots currently match the selected criteria for this commodity.
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {filteredMatches.map((lot, idx) => {
            const isExpanded = expandedCards[lot.id] ?? false;
            const hasOverride = overriddenMatches[lot.id];
            const priceDiff = lot.askingPrice - (requirementDetail?.targetPrice || 0);
            const isPriceFavorable = priceDiff <= 0;

            return (
              <Card
                key={lot.id}
                className={`bg-white border transition-all duration-200 rounded-xl overflow-hidden shadow-2xs hover:shadow-md ${
                  lot.match.totalScore >= 85
                    ? 'border-emerald-200/90'
                    : lot.match.totalScore >= 70
                    ? 'border-teal-200/90'
                    : 'border-slate-200/90'
                }`}
              >
                <div className="p-4 sm:p-5 space-y-4">
                  {/* Top Row: Rank & Score Badge + Seller info */}
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div className="flex items-center gap-3">
                      {/* Rank Index */}
                      <div className="w-7 h-7 rounded-full bg-slate-100 border border-slate-200 text-slate-600 font-bold text-xs flex items-center justify-center shrink-0">
                        #{idx + 1}
                      </div>

                      {/* Score Ring Badge */}
                      <div
                        className={`px-3 py-1.5 rounded-lg font-mono font-bold text-sm border ring-2 flex items-center gap-1.5 shadow-2xs ${getScoreBadgeStyles(
                          lot.match.totalScore
                        )}`}
                      >
                        <Sparkles className="w-4 h-4 shrink-0" />
                        <span>{lot.match.totalScore}%</span>
                        <span className="text-[11px] font-sans font-medium opacity-80">Match</span>
                      </div>

                      {/* Classification Badge */}
                      {getClassificationBadge(lot.match.classification, lot.match.totalScore)}

                      {/* Broker Override Badge */}
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
                      <span className="font-mono text-slate-500 bg-slate-50 px-2 py-0.5 rounded border border-slate-200/60">
                        {lot.lotNumber}
                      </span>
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 text-slate-700 border border-slate-200">
                        {lot.loadingStatus}
                      </span>
                    </div>
                  </div>

                  {/* Seller Name & Location Strip */}
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pt-1 border-t border-slate-100">
                    <div className="flex items-center gap-1.5">
                      <Building2 className="w-4 h-4 text-slate-400 shrink-0" />
                      <span className="font-bold text-slate-900 text-sm sm:text-base">
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
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 bg-slate-50/80 p-3 rounded-xl border border-slate-100">
                    {/* Available Volume */}
                    <div>
                      <div className="text-[10px] font-semibold text-slate-400 uppercase">
                        Available Qty
                      </div>
                      <div className="text-sm font-bold text-slate-800 mt-0.5">
                        {lot.availableQuantity} {lot.unitSymbol || 'MT'}
                      </div>
                      <div className="text-[10px] text-slate-500">
                        {requirementDetail?.quantity
                          ? `${Math.min(
                              100,
                              Math.round((lot.availableQuantity / requirementDetail.quantity) * 100)
                            )}% of buyer need`
                          : 'Full lot'}
                      </div>
                    </div>

                    {/* Asking Price */}
                    <div>
                      <div className="text-[10px] font-semibold text-slate-400 uppercase">
                        Seller Asking
                      </div>
                      <div className="text-sm font-bold text-slate-900 mt-0.5">
                        {formatIndianCurrency(lot.askingPrice)}
                      </div>
                      <div
                        className={`text-[10px] font-medium ${
                          isPriceFavorable ? 'text-emerald-600' : 'text-amber-600'
                        }`}
                      >
                        {isPriceFavorable
                          ? `₹${Math.abs(priceDiff)} below target`
                          : `+₹${priceDiff} above target`}
                      </div>
                    </div>

                    {/* Confidential Floor Price (Authorized to Broker) */}
                    <div>
                      <div className="text-[10px] font-semibold text-teal-700 uppercase flex items-center gap-1">
                        <Lock className="w-2.5 h-2.5" />
                        <span>Broker Floor</span>
                      </div>
                      <div className="text-sm font-bold text-teal-900 mt-0.5">
                        {lot.confidentialMinimumPrice
                          ? formatIndianCurrency(lot.confidentialMinimumPrice)
                          : formatIndianCurrency(lot.askingPrice)}
                      </div>
                      <div className="text-[10px] text-teal-600 font-medium">
                        Confidential limit
                      </div>
                    </div>

                    {/* Stock Readiness */}
                    <div>
                      <div className="text-[10px] font-semibold text-slate-400 uppercase">
                        Validity / Stock
                      </div>
                      <div className="text-xs font-semibold text-slate-700 mt-0.5 truncate">
                        Valid: {lot.validUntilFormatted}
                      </div>
                      <div className="text-[10px] text-slate-500">
                        {lot.gradeName}
                      </div>
                    </div>
                  </div>

                  {/* Explainability Accordion ("Why this match?") */}
                  <div className="border border-slate-100 rounded-lg overflow-hidden">
                    <button
                      type="button"
                      onClick={() => toggleCardExpand(lot.id)}
                      className="w-full px-3 py-2 bg-slate-50/50 hover:bg-slate-100/70 text-left flex items-center justify-between text-xs font-semibold text-slate-700 transition-colors"
                    >
                      <div className="flex items-center gap-2">
                        <Sparkles className="w-3.5 h-3.5 text-[#0D9488]" />
                        <span>
                          Score Breakdown & Factors ({lot.match.reasons.length} advantages,{' '}
                          {lot.match.risks.length} considerations)
                        </span>
                      </div>
                      {isExpanded ? (
                        <ChevronUp className="w-4 h-4 text-slate-400" />
                      ) : (
                        <ChevronDown className="w-4 h-4 text-slate-400" />
                      )}
                    </button>

                    {isExpanded && (
                      <div className="p-3 bg-white space-y-3 border-t border-slate-100 text-xs">
                        {/* Score weights chip list */}
                        <div className="flex flex-wrap gap-1.5 pb-2 border-b border-slate-100 text-[11px] font-mono">
                          <span className="px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                            Commodity: {lot.match.breakdown.commodity}/35
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                            Grade: {lot.match.breakdown.grade}/25
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                            Price: {lot.match.breakdown.price}/20
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                            Location: {lot.match.breakdown.location}/10
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                            Volume: {lot.match.breakdown.quantity}/7
                          </span>
                          <span className="px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                            Date: {lot.match.breakdown.deliveryDate}/3
                          </span>
                        </div>

                        {/* Reasons */}
                        {lot.match.reasons.length > 0 && (
                          <div className="space-y-1">
                            <div className="font-semibold text-emerald-800 text-[11px]">
                              Match Drivers:
                            </div>
                            <ul className="space-y-1 pl-1">
                              {lot.match.reasons.map((r, i) => (
                                <li key={i} className="text-slate-600 flex items-start gap-1.5">
                                  <span>{r}</span>
                                </li>
                              ))}
                            </ul>
                          </div>
                        )}

                        {/* Risks */}
                        {lot.match.risks.length > 0 && (
                          <div className="space-y-1 pt-1">
                            <div className="font-semibold text-amber-800 text-[11px]">
                              Points of Attention:
                            </div>
                            <ul className="space-y-1 pl-1">
                              {lot.match.risks.map((risk, i) => (
                                <li key={i} className="text-slate-600 flex items-start gap-1.5">
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
                    {/* Primary CTA: Select Lot & Structure Request */}
                    <Button
                      type="button"
                      onClick={() => {
                        setRequestDialogLot(lot);
                        setIsRequestDialogOpen(true);
                      }}
                      className="w-full sm:flex-1 min-h-[48px] h-12 bg-[#0D9488] hover:bg-teal-700 text-white font-bold text-sm shadow-xs rounded-lg transition-all flex items-center justify-center gap-2 px-4"
                    >
                      <Send className="w-4 h-4 shrink-0" />
                      <span>Select Lot & Structure Request</span>
                      <ChevronRight className="w-4 h-4 ml-auto sm:ml-0 opacity-80 shrink-0" />
                    </Button>

                    {/* Quality CTA: Check Quality (Sprint 24.2) */}
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => setQualityCheckLot(lot)}
                      className="w-full sm:w-auto min-h-[48px] h-12 border-teal-200 hover:bg-teal-50 text-teal-800 font-semibold text-xs rounded-lg transition-all flex items-center justify-center gap-2 px-3.5 shrink-0"
                    >
                      <FlaskConical className="w-4 h-4 text-[#0D9488] shrink-0" />
                      <span>Check Quality</span>
                    </Button>

                    {/* Secondary CTA: Manual Match Override */}
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => handleOpenOverrideDialog(lot)}
                      className="w-full sm:w-auto min-h-[48px] h-12 border-slate-200 hover:bg-slate-50 text-slate-700 font-semibold text-xs rounded-lg transition-all flex items-center justify-center gap-2 px-3 shrink-0"
                    >
                      <SlidersHorizontal className="w-4 h-4 text-slate-500 shrink-0" />
                      <span>Manual Override</span>
                    </Button>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* 4. MANUAL OVERRIDE MODAL */}
      <Dialog open={!!overrideModalLot} onOpenChange={(open) => !open && setOverrideModalLot(null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold text-slate-900 flex items-center gap-2">
              <SlidersHorizontal className="w-4 h-4 text-[#0D9488]" />
              <span>Record Manual Match Override</span>
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              PRD v2.2 Human Decision Gate: Override algorithmic match ranking for lot{' '}
              <span className="font-mono font-medium text-slate-700">{overrideModalLot?.lotNumber}</span>.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <div className="bg-slate-50 p-3 rounded-lg border border-slate-200/80 text-xs space-y-1">
              <div className="font-medium text-slate-700">Lot: {overrideModalLot?.sellerCompanyName}</div>
              <div className="text-slate-500">
                Score: {overrideModalLot?.match.totalScore}% • Asking:{' '}
                {overrideModalLot ? formatIndianCurrency(overrideModalLot.askingPrice) : ''}
              </div>
            </div>

            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">Reason for Override *</Label>
              <Select
                value={overrideReason}
                onValueChange={(val) => {
                  if (val) setOverrideReason(val);
                }}
              >
                <SelectTrigger className="h-10 text-xs bg-white">
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
              <Label className="text-xs font-semibold text-slate-700">Broker Operational Notes (Optional)</Label>
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

      {/* 5. SEND REQUEST DIALOG (from Sprint 23.4) */}
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

      {/* 6. QUALITY COMPARISON PANEL (Micro-Sprint 24.2) */}
      {qualityCheckLot && requirementDetail && (
        <QualityComparisonPanel
          open={!!qualityCheckLot}
          onOpenChange={(open) => !open && setQualityCheckLot(null)}
          requirementId={requirementDetail.id}
          availabilityId={qualityCheckLot.id}
          onVerificationComplete={() => {
            // Refresh matches
            if (selectedReqId) {
              startMatchTransition(async () => {
                const res = await getRankedMatchesForRequirementAction(selectedReqId);
                if (res.success && res.matches) {
                  setRankedMatches(res.matches);
                }
              });
            }
          }}
        />
      )}
    </div>
  );
}
