'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import {
  Building2,
  CheckCircle2,
  Calendar,
  Truck,
  Sparkles,
  MessageSquare,
  AlertTriangle,
  Clock,
  Layers,
  ShieldCheck,
  Search,
  ExternalLink,
  ChevronRight,
  Info,
  Loader2,
} from 'lucide-react';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Textarea } from '@/components/ui/textarea';
import { formatIndianCurrency } from '@/lib/utils';
import type { BrokerAssignedRequirement, BrokerOperationalStatus } from '@/src/server/actions/broker-work-actions';
import { toast } from 'sonner';

interface RequirementCardProps {
  requirement: BrokerAssignedRequirement;
  onFindSeller?: (requirement: BrokerAssignedRequirement) => void;
}

export function RequirementCard({ requirement, onFindSeller }: RequirementCardProps) {
  const [isClarifyOpen, setIsClarifyOpen] = useState(false);
  const [clarifyNotes, setClarifyNotes] = useState('');
  const [isSubmittingClarify, setIsSubmittingClarify] = useState(false);

  const getStatusBadge = (status: BrokerOperationalStatus, isUrgent: boolean) => {
    switch (status) {
      case 'Action Required':
        return (
          <Badge className="bg-amber-50 text-amber-700 border-amber-200/80 hover:bg-amber-50 text-[11px] font-semibold flex items-center gap-1 shrink-0">
            <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse" />
            <span>Action Required</span>
          </Badge>
        );
      case 'New Demand':
        return (
          <Badge className="bg-[#CCFBF1] text-[#0D9488] border-teal-200/80 hover:bg-[#CCFBF1] text-[11px] font-semibold flex items-center gap-1 shrink-0">
            <Sparkles className="w-3 h-3 text-[#0D9488]" />
            <span>New Demand</span>
          </Badge>
        );
      case 'Sourcing':
        return (
          <Badge className="bg-blue-50 text-blue-700 border-blue-200/80 hover:bg-blue-50 text-[11px] font-semibold flex items-center gap-1 shrink-0">
            <Search className="w-3 h-3" />
            <span>Sourcing</span>
          </Badge>
        );
      case 'Matched':
        return (
          <Badge className="bg-purple-50 text-purple-700 border-purple-200/80 hover:bg-purple-50 text-[11px] font-semibold flex items-center gap-1 shrink-0">
            <CheckCircle2 className="w-3 h-3" />
            <span>Matched</span>
          </Badge>
        );
      case 'Partially Fulfilled':
        return (
          <Badge className="bg-indigo-50 text-indigo-700 border-indigo-200/80 hover:bg-indigo-50 text-[11px] font-semibold flex items-center gap-1 shrink-0">
            <Layers className="w-3 h-3" />
            <span>Partially Fulfilled</span>
          </Badge>
        );
      case 'Fulfilled':
        return (
          <Badge className="bg-emerald-50 text-emerald-700 border-emerald-200/80 hover:bg-emerald-50 text-[11px] font-semibold">
            Fulfilled
          </Badge>
        );
      case 'Closed':
      default:
        return (
          <Badge className="bg-slate-100 text-slate-600 border-slate-200 hover:bg-slate-100 text-[11px] font-medium">
            Closed
          </Badge>
        );
    }
  };

  const handleSendClarification = () => {
    if (!clarifyNotes.trim()) {
      toast.error('Please enter a clarification question or note for the buyer.');
      return;
    }

    setIsSubmittingClarify(true);
    // Simulate instantaneous local response and acknowledgement
    setTimeout(() => {
      setIsSubmittingClarify(false);
      setIsClarifyOpen(false);
      setClarifyNotes('');
      toast.success(`Clarification request sent to ${requirement.buyerCompanyName}`);
    }, 600);
  };

  const formattedTargetPrice = formatIndianCurrency(requirement.targetPrice);
  const formattedUnit = requirement.unitSymbol || requirement.unitName || 'MT';

  return (
    <>
      <Card className="w-full bg-white border border-slate-200/80 shadow-2xs hover:shadow-md transition-all duration-200 rounded-xl overflow-hidden flex flex-col justify-between">
        <div className="p-4 sm:p-5 space-y-3.5">
          {/* Top Header: Buyer Company & Operational Status Badge */}
          <div className="flex items-start justify-between gap-2.5">
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-1.5 flex-wrap">
                <span className="font-bold text-slate-900 text-sm sm:text-base truncate tracking-tight">
                  {requirement.buyerCompanyName}
                </span>
                {requirement.buyerCompanyVerified && (
                  <span
                    title="Verified Buyer Profile"
                    className="inline-flex items-center text-[#0D9488] shrink-0"
                  >
                    <ShieldCheck className="w-4 h-4 fill-teal-50" />
                  </span>
                )}
              </div>
              <div className="flex items-center gap-2 mt-0.5 text-xs text-slate-400 font-mono">
                <span>{requirement.requirementRef}</span>
                <span>•</span>
                <span className="text-slate-500 font-sans font-medium text-[11px]">
                  Assigned to You
                </span>
              </div>
            </div>

            {/* Operational Status Badge */}
            {getStatusBadge(requirement.operationalStatus, requirement.isUrgent)}
          </div>

          {/* Commodity & Grade Strip */}
          <div className="bg-slate-50/90 rounded-lg p-2.5 border border-slate-100/90 space-y-1">
            <div className="flex items-center gap-1.5 text-[11px] font-medium text-slate-500 truncate">
              {requirement.industryName && <span>{requirement.industryName}</span>}
              {requirement.categoryName && (
                <>
                  <span>•</span>
                  <span>{requirement.categoryName}</span>
                </>
              )}
            </div>
            <div className="flex items-center justify-between gap-2 flex-wrap">
              <span className="font-bold text-slate-800 text-sm sm:text-base">
                {requirement.commodityName}{' '}
                <span className="text-[#0D9488] font-semibold text-xs sm:text-sm">
                  • {requirement.gradeName}
                </span>
              </span>
              {requirement.commodityCode && (
                <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-white text-slate-500 border border-slate-200/60">
                  {requirement.commodityCode}
                </span>
              )}
            </div>
          </div>

          {/* Key Commercial Metrics Grid */}
          <div className="grid grid-cols-2 gap-2.5 pt-1">
            {/* Quantity */}
            <div className="p-2.5 rounded-lg bg-slate-50/60 border border-slate-100">
              <span className="text-[11px] font-medium text-slate-400 uppercase tracking-wider block">
                Required Volume
              </span>
              <div className="mt-0.5 flex items-baseline gap-1">
                <span className="text-base sm:text-lg font-extrabold text-slate-900 tracking-tight">
                  {requirement.quantity.toLocaleString('en-IN')}
                </span>
                <span className="text-xs font-semibold text-slate-600">
                  {formattedUnit}
                </span>
              </div>
              {requirement.fulfilledQuantity > 0 && (
                <div className="mt-1">
                  <div className="w-full bg-slate-200 h-1.5 rounded-full overflow-hidden">
                    <div
                      className="bg-[#0D9488] h-full rounded-full transition-all"
                      style={{ width: `${requirement.fulfillmentPercentage}%` }}
                    />
                  </div>
                  <span className="text-[10px] text-slate-500 font-medium mt-0.5 block">
                    {requirement.fulfilledQuantity} {formattedUnit} fulfilled ({requirement.fulfillmentPercentage}%)
                  </span>
                </div>
              )}
            </div>

            {/* Target Price */}
            <div className="p-2.5 rounded-lg bg-teal-50/40 border border-teal-100/60">
              <span className="text-[11px] font-medium text-teal-700/80 uppercase tracking-wider block">
                Target Price
              </span>
              <div className="mt-0.5 flex items-baseline gap-1">
                <span className="text-base sm:text-lg font-extrabold text-[#0D9488] tracking-tight">
                  {formattedTargetPrice}
                </span>
                <span className="text-[11px] font-medium text-teal-800/70">
                  / {formattedUnit}
                </span>
              </div>
              <span className="text-[10px] text-teal-700/70 block mt-0.5 truncate">
                Estimated Mandate Price
              </span>
            </div>
          </div>

          {/* Operational Details: Delivery Terms & Target Timeline */}
          <div className="space-y-1.5 pt-1 text-xs text-slate-600">
            <div className="flex items-center gap-2">
              <Truck className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <span className="font-medium text-slate-700">Terms:</span>
              <span className="truncate text-slate-600">{requirement.deliveryTerms}</span>
            </div>
            <div className="flex items-center gap-2">
              <Calendar className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <span className="font-medium text-slate-700">Target Delivery:</span>
              <span className="text-slate-900 font-semibold">{requirement.targetDateFormatted}</span>
              {requirement.isUrgent && (
                <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-100 text-amber-800 shrink-0">
                  Urgent (≤48h)
                </span>
              )}
            </div>
          </div>

          {/* Quality Parameters Preview (if available) */}
          {requirement.qualityParameters && Object.keys(requirement.qualityParameters).length > 0 && (
            <div className="pt-1">
              <div className="flex items-center gap-1.5 text-[11px] font-medium text-slate-500 mb-1">
                <Info className="w-3 h-3 text-slate-400" />
                <span>Quality Specs:</span>
              </div>
              <div className="flex flex-wrap gap-1.5">
                {Object.entries(requirement.qualityParameters).slice(0, 3).map(([key, val]) => (
                  <span
                    key={key}
                    className="text-[10px] px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 font-mono border border-slate-200/60"
                  >
                    {key}: {String(val)}
                  </span>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Task 3: Primary Actions (The Triad) */}
        {/* TOUCH TARGET RULE: Both buttons MUST possess min-h-[48px] */}
        <div className="p-3 sm:p-4 bg-slate-50/60 border-t border-slate-100 flex flex-col sm:flex-row gap-2.5">
          {/* Action 1 (Primary CTA): Prominent "Find Seller" with Electric Teal Accent */}
          <Link
            href={`/broker/work/supply?requirementId=${requirement.id}&commodity=${requirement.commodityId}`}
            onClick={() => {
              if (onFindSeller) onFindSeller(requirement);
            }}
            className="flex-1 min-h-[48px] h-12 bg-[#0D9488] hover:bg-teal-700 text-white font-bold text-sm shadow-xs rounded-lg transition-all flex items-center justify-center gap-2 px-4"
          >
            <Search className="w-4 h-4 shrink-0" />
            <span>Find Seller</span>
            <ChevronRight className="w-4 h-4 ml-auto sm:ml-0 opacity-70 shrink-0" />
          </Link>

          {/* Action 2 (Secondary CTA): Outline "Ask Buyer" */}
          <Button
            type="button"
            variant="outline"
            onClick={() => setIsClarifyOpen(true)}
            className="min-h-[48px] h-12 border-slate-200 hover:bg-slate-100 text-slate-700 font-semibold text-sm rounded-lg transition-all flex items-center justify-center gap-2 px-4 shrink-0"
          >
            <MessageSquare className="w-4 h-4 text-slate-500 shrink-0" />
            <span>Ask Buyer</span>
          </Button>
        </div>
      </Card>

      {/* Ask Buyer / Clarification Dialog */}
      <Dialog open={isClarifyOpen} onOpenChange={setIsClarifyOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <MessageSquare className="w-5 h-5 text-[#0D9488]" />
              <span>Ask Buyer for Clarification</span>
            </DialogTitle>
            <DialogDescription className="text-xs sm:text-sm text-slate-500">
              Send an operational inquiry to <span className="font-semibold text-slate-700">{requirement.buyerCompanyName}</span> regarding requirement <span className="font-mono font-medium text-slate-700">{requirement.requirementRef}</span> ({requirement.commodityName}).
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 py-2">
            <div className="bg-slate-50 p-3 rounded-lg border border-slate-200/80 text-xs space-y-1">
              <div className="font-medium text-slate-700">Requirement Summary:</div>
              <div className="text-slate-600">
                {requirement.quantity} {formattedUnit} • Target Price: {formattedTargetPrice} • Terms: {requirement.deliveryTerms}
              </div>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-slate-700">
                Inquiry / Question for Buyer
              </label>
              <Textarea
                placeholder="e.g. Can you accept delivery 2 days earlier? Are you open to ±5% moisture variance?"
                value={clarifyNotes}
                onChange={(e) => setClarifyNotes(e.target.value)}
                rows={4}
                className="text-sm resize-none focus-visible:ring-[#0D9488]"
              />
            </div>
          </div>

          <DialogFooter className="flex flex-col sm:flex-row gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsClarifyOpen(false)}
              className="min-h-[48px] h-12"
              disabled={isSubmittingClarify}
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleSendClarification}
              disabled={isSubmittingClarify || !clarifyNotes.trim()}
              className="min-h-[48px] h-12 bg-[#0D9488] hover:bg-teal-700 text-white font-semibold flex items-center gap-2"
            >
              {isSubmittingClarify ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Sending...</span>
                </>
              ) : (
                <>
                  <MessageSquare className="w-4 h-4" />
                  <span>Send Inquiry</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
