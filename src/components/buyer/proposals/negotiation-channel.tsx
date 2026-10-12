'use client';

import React, { useState } from 'react';
import { 
  Handshake, 
  ShieldCheck, 
  Clock, 
  ArrowLeftRight, 
  CheckCircle2, 
  Lock, 
  AlertTriangle,
  History,
  Scale,
  Sparkles
} from 'lucide-react';
import { Card } from '@/components/ui/card';
import { BuyerProposalDetail, BuyerProposalVersionItem } from '@/src/types/buyer-proposal';
import { NegotiationState } from '@/src/server/actions/buyer-negotiation-actions';
import { NegotiationTimeline } from '@/src/components/buyer/proposals/negotiation-timeline';
import { CounterOfferForm } from '@/src/components/buyer/proposals/counter-offer-form';
import { cn } from '@/lib/utils';
import { useRouter } from 'next/navigation';

interface NegotiationChannelProps {
  proposal: BuyerProposalDetail;
  versions?: BuyerProposalVersionItem[];
  className?: string;
}

export function NegotiationChannel({
  proposal,
  versions = [],
  className,
}: NegotiationChannelProps) {
  const router = useRouter();

  // Derive initial negotiation state from proposal
  const deriveInitialState = (): NegotiationState => {
    if (proposal.isExpired || proposal.rawStatus === 'Expired') return 'Expired';
    if (proposal.status === 'Accepted' || proposal.rawStatus === 'Accepted') return 'Agreed';
    if (proposal.status === 'Rejected' || proposal.rawStatus === 'Rejected') return 'Closed';
    if (proposal.status === 'Countered' || proposal.rawStatus === 'Countered' || proposal.rawStatus === 'Waiting for Broker') {
      return 'Waiting for Broker';
    }
    return 'Waiting for Buyer';
  };

  const [currentNegotiationState, setCurrentNegotiationState] = useState<NegotiationState>(deriveInitialState);
  const [currentVersion, setCurrentVersion] = useState<number>(proposal.versionNumber);

  // State Badge Config according to Task 2 specifications
  const getStateBadge = (state: NegotiationState) => {
    switch (state) {
      case 'Open':
      case 'Waiting for Buyer':
        return {
          label: 'Your Action Required',
          icon: ArrowLeftRight,
          className: 'bg-[#E0F2FE] text-[#0284C7] border-sky-200',
          dotColor: 'bg-[#0284C7] animate-pulse',
        };
      case 'Waiting for Broker':
        return {
          label: 'Awaiting Broker Response',
          icon: Clock,
          className: 'bg-amber-50 text-[#D97706] border-amber-200',
          dotColor: 'bg-[#D97706] animate-pulse',
        };
      case 'Agreed':
        return {
          label: 'Commercial Terms Agreed',
          icon: CheckCircle2,
          className: 'bg-emerald-50 text-[#059669] border-emerald-200',
          dotColor: 'bg-[#059669]',
        };
      case 'Closed':
        return {
          label: 'Negotiation Closed',
          icon: Lock,
          className: 'bg-red-50 text-[#DC2626] border-red-200',
          dotColor: 'bg-[#DC2626]',
        };
      case 'Expired':
        return {
          label: 'Terms Expired',
          icon: AlertTriangle,
          className: 'bg-slate-100 text-[#64748B] border-slate-200',
          dotColor: 'bg-[#64748B]',
        };
      default:
        return {
          label: 'Your Action Required',
          icon: ArrowLeftRight,
          className: 'bg-[#E0F2FE] text-[#0284C7] border-sky-200',
          dotColor: 'bg-[#0284C7]',
        };
    }
  };

  const stateInfo = getStateBadge(currentNegotiationState);
  const StateIcon = stateInfo.icon;
  const isTerminal = currentNegotiationState === 'Closed' || currentNegotiationState === 'Expired';
  const isWaitingBroker = currentNegotiationState === 'Waiting for Broker';
  const isAgreed = currentNegotiationState === 'Agreed';

  return (
    <Card className={cn('w-full max-w-full overflow-hidden border border-slate-200 bg-white rounded-2xl shadow-xs', className)}>
      {/* 1. Sticky Negotiation Header */}
      <div className="sticky top-0 z-20 bg-white/95 backdrop-blur-md border-b border-slate-200 px-4 py-3 sm:px-6 sm:py-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-xs font-bold text-slate-900 tracking-tight flex items-center gap-1.5">
                <Handshake className="w-4 h-4 text-[#0284C7]" />
                <span>Buyer ↔ Broker Negotiation Channel</span>
              </span>
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-sky-50 text-[#0284C7] border border-sky-200">
                v{currentVersion}
              </span>
            </div>
            <p className="text-[11px] text-slate-500 mt-0.5 flex items-center gap-1.5">
              <ShieldCheck className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
              <span className="truncate">
                Isolated Channel • Mediated via {proposal.brokerName || 'Broker Desk'} • Zero Seller PII
              </span>
            </p>
          </div>

          {/* Current State Pill */}
          <div className="flex items-center gap-2 self-start sm:self-auto">
            <div className={cn('inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-colors', stateInfo.className)}>
              <span className={cn('w-2 h-2 rounded-full shrink-0', stateInfo.dotColor)} />
              <StateIcon className="w-3.5 h-3.5 shrink-0" />
              <span>{stateInfo.label}</span>
            </div>
          </div>
        </div>

        {/* Turn-based Action Alert Bar */}
        <div className="mt-3">
          {isWaitingBroker ? (
            <div className="p-2.5 rounded-xl bg-amber-50/90 border border-amber-200 flex items-start gap-2.5 text-xs text-amber-900">
              <Clock className="w-4 h-4 text-[#D97706] shrink-0 mt-0.5" />
              <div className="min-w-0 flex-1 leading-relaxed">
                <span className="font-bold">Awaiting Broker Response:</span> You have submitted counter-terms. The Broker is reviewing them. Editing is paused until Broker response.
              </div>
            </div>
          ) : (currentNegotiationState === 'Waiting for Buyer' || currentNegotiationState === 'Open') ? (
            <div className="p-2.5 rounded-xl bg-[#E0F2FE]/90 border border-sky-200 flex items-start gap-2.5 text-xs text-[#0369A1]">
              <Sparkles className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
              <div className="min-w-0 flex-1 leading-relaxed">
                <span className="font-bold">Your Action Required:</span> The Broker Desk has provided commercial terms for {proposal.commodityName}. Review active terms below or submit counter-terms.
              </div>
            </div>
          ) : isAgreed ? (
            <div className="p-2.5 rounded-xl bg-emerald-50/90 border border-emerald-200 flex items-start gap-2.5 text-xs text-emerald-900">
              <CheckCircle2 className="w-4 h-4 text-[#059669] shrink-0 mt-0.5" />
              <div className="min-w-0 flex-1 leading-relaxed">
                <span className="font-bold">Commercial Terms Agreed:</span> Terms agreed. Proceed to Final Deal & Confirmation.
              </div>
            </div>
          ) : currentNegotiationState === 'Closed' ? (
            <div className="p-2.5 rounded-xl bg-red-50/90 border border-red-200 flex items-start gap-2.5 text-xs text-red-900">
              <Lock className="w-4 h-4 text-[#DC2626] shrink-0 mt-0.5" />
              <div className="min-w-0 flex-1 leading-relaxed">
                <span className="font-bold">Negotiation Closed:</span> This commercial negotiation has concluded. No further counter-offers can be made.
              </div>
            </div>
          ) : currentNegotiationState === 'Expired' ? (
            <div className="p-2.5 rounded-xl bg-slate-100 border border-slate-200 flex items-start gap-2.5 text-xs text-slate-800">
              <AlertTriangle className="w-4 h-4 text-[#64748B] shrink-0 mt-0.5" />
              <div className="min-w-0 flex-1 leading-relaxed">
                <span className="font-bold">Terms Expired:</span> Proposal validity period has ended. Request a refreshed proposal from the Broker Desk to resume.
              </div>
            </div>
          ) : null}
        </div>
      </div>

      <div className="p-4 sm:p-6 space-y-6">
        {/* 2. Active Commercial Position Card */}
        <div className="rounded-xl border border-slate-200 bg-slate-50/60 p-4 space-y-3">
          <div className="flex items-center justify-between border-b border-slate-200/80 pb-2">
            <span className="text-xs font-bold text-slate-800 uppercase tracking-wider">
              Active Proposed Terms (v{currentVersion})
            </span>
            <span className="text-[11px] font-semibold text-slate-500">
              Broker: {proposal.brokerName || 'Assigned Broker'}
            </span>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
            <div className="bg-white p-2.5 rounded-lg border border-slate-200/70 shadow-2xs">
              <span className="text-[10px] text-slate-400 font-bold uppercase block">Landed Price</span>
              <span className="text-sm font-extrabold text-slate-900 mt-0.5 block">
                ₹{proposal.netLandedPricePerUnit.toLocaleString('en-IN')}/{proposal.unitSymbol}
              </span>
            </div>

            <div className="bg-white p-2.5 rounded-lg border border-slate-200/70 shadow-2xs">
              <span className="text-[10px] text-slate-400 font-bold uppercase block">Quantity</span>
              <span className="text-sm font-extrabold text-slate-900 mt-0.5 block">
                {proposal.proposedQuantity} {proposal.unitSymbol}
              </span>
            </div>

            <div className="bg-white p-2.5 rounded-lg border border-slate-200/70 shadow-2xs">
              <span className="text-[10px] text-slate-400 font-bold uppercase block">Delivery Window</span>
              <span className="text-xs font-bold text-slate-800 mt-0.5 block truncate">
                {proposal.deliveryWindowStart ? proposal.deliveryWindowStart : 'Immediate Dispatch'}
              </span>
            </div>

            <div className="bg-white p-2.5 rounded-lg border border-slate-200/70 shadow-2xs">
              <span className="text-[10px] text-slate-400 font-bold uppercase block">Payment Terms</span>
              <span className="text-xs font-bold text-slate-800 mt-0.5 block truncate">
                {proposal.paymentTerms || 'Standard Escrow'}
              </span>
            </div>
          </div>
        </div>

        {/* 3. Chronological Negotiation Timeline (Micro-Sprint 36.2) */}
        <div className="rounded-xl border border-slate-200 bg-white p-4">
          <NegotiationTimeline proposalId={proposal.id} />
        </div>

        {/* 4. Counter-Offer Engine & Dynamic UI Lock (Micro-Sprint 36.3 & 36.5) */}
        {isWaitingBroker ? (
          <div className="rounded-xl border border-amber-200 bg-amber-50/70 p-4 sm:p-5 text-xs text-amber-950 space-y-3">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-amber-100 flex items-center justify-center shrink-0">
                <Clock className="w-4 h-4 text-[#D97706]" />
              </div>
              <div>
                <h4 className="font-bold text-xs sm:text-sm text-amber-950 leading-tight">
                  Awaiting Broker Response (Terms Locked at v{currentVersion})
                </h4>
                <p className="text-[11px] text-amber-700 mt-0.5">
                  Your counter-offer is currently in active mediation with {proposal.brokerName || 'the Broker Desk'}.
                </p>
              </div>
            </div>

            <p className="text-amber-900 leading-relaxed bg-white/80 p-3 rounded-lg border border-amber-200/80">
              You have submitted counter-terms. The Broker is reviewing them. Editing is paused until Broker response.
            </p>
          </div>
        ) : isAgreed ? (
          <div className="rounded-xl border border-emerald-200 bg-emerald-50/70 p-4 sm:p-5 text-xs text-emerald-950 space-y-3">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-lg bg-emerald-100 flex items-center justify-center shrink-0">
                <CheckCircle2 className="w-4 h-4 text-[#059669]" />
              </div>
              <div>
                <h4 className="font-bold text-xs sm:text-sm text-emerald-950 leading-tight">
                  Commercial Terms Agreed (Locked at v{currentVersion})
                </h4>
                <p className="text-[11px] text-emerald-700 mt-0.5">
                  Both parties have reached mutual commercial alignment.
                </p>
              </div>
            </div>

            <div className="bg-white/80 p-3.5 rounded-lg border border-emerald-200/80 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <span className="text-emerald-900 font-medium">
                Terms agreed. Proceed to Final Deal & Confirmation.
              </span>
              <button
                type="button"
                onClick={() => router.push(`/buyer/proposals/${proposal.id}?tab=confirmation`)}
                className="inline-flex items-center justify-center gap-2 min-h-[48px] px-5 py-2.5 rounded-xl bg-[#059669] hover:bg-emerald-700 text-white font-bold text-xs transition-colors shadow-xs"
              >
                <span>Proceed to Confirmation</span>
                <CheckCircle2 className="w-4 h-4" />
              </button>
            </div>
          </div>
        ) : isTerminal ? (
          <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 sm:p-5 text-xs text-slate-700 space-y-2">
            <div className="flex items-center gap-2">
              <Lock className="w-4 h-4 text-slate-500" />
              <h4 className="font-bold text-slate-900">
                {currentNegotiationState === 'Closed' ? 'Negotiation Closed' : 'Terms Expired'}
              </h4>
            </div>
            <p className="text-[11px] text-slate-600 leading-relaxed bg-white p-3 rounded-lg border border-slate-200">
              {currentNegotiationState === 'Closed'
                ? 'Negotiation closed. This commercial thread has concluded. No active inputs permitted.'
                : 'Terms expired. The proposal validity window has ended. Request a refreshed proposal from the Broker Desk to resume negotiations.'}
            </p>
          </div>
        ) : (currentNegotiationState === 'Waiting for Buyer' || currentNegotiationState === 'Open') ? (
          <div className="rounded-xl border border-sky-200/80 bg-white p-4 sm:p-5 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2">
                <div className="w-7 h-7 rounded-lg bg-[#0284C7] flex items-center justify-center text-white">
                  <Scale className="w-4 h-4" />
                </div>
                <div>
                  <h4 className="text-xs sm:text-sm font-bold text-slate-900">
                    Submit Commercial Counter-Offer
                  </h4>
                  <p className="text-[11px] text-slate-500">
                    Negotiate rate, quantity, delivery window, and terms with the Broker Desk
                  </p>
                </div>
              </div>

              <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-sky-50 text-[#0284C7] border border-sky-200">
                Your Action Required
              </span>
            </div>

            <CounterOfferForm
              proposalId={proposal.id}
              currentVersionNumber={currentVersion}
              unitSymbol={proposal.unitSymbol}
              initialData={{
                price: proposal.netLandedPricePerUnit || proposal.basePricePerUnit,
                quantity: proposal.proposedQuantity,
                deliveryDate: proposal.deliveryWindowStart,
                paymentTerms: proposal.paymentTerms,
                packaging: proposal.packagingType,
                freight: proposal.freightTerms,
                inspection: proposal.inspectionRequirements,
              }}
              onSuccess={(newVer) => {
                setCurrentVersion(newVer);
                setCurrentNegotiationState('Waiting for Broker');
              }}
            />
          </div>
        ) : null}
      </div>
    </Card>
  );
}
