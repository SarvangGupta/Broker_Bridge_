'use client';

import React, { useState } from 'react';
import { 
  History, 
  Layers, 
  Sparkles, 
  Clock, 
  CheckCircle2, 
  ArrowRight, 
  TrendingDown, 
  TrendingUp,
  Minus,
  AlertCircle,
  Lock,
  GitCommit,
  GitFork,
  X
} from 'lucide-react';
import { BuyerProposalVersionItem } from '@/src/types/buyer-proposal';
import { VersionComparisonCard } from '@/src/components/buyer/proposals/version-comparison-card';
import { cn } from '@/lib/utils';

interface ProposalVersionTimelineProps {
  versions: BuyerProposalVersionItem[];
  className?: string;
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-IN', {
    maximumFractionDigits: 0,
  }).format(amount);
}

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function ProposalVersionTimeline({
  versions,
  className,
}: ProposalVersionTimelineProps) {
  // Guard: if no versions or only 1 version exists
  const totalRounds = versions.length;
  const latestVersion = versions[totalRounds - 1] || versions[0];
  const [selectedVersionId, setSelectedVersionId] = useState<string>(
    latestVersion ? latestVersion.id : ''
  );

  const selectedVersion =
    versions.find((v) => v.id === selectedVersionId) || latestVersion;

  if (!versions || versions.length === 0) {
    return (
      <div className="p-6 rounded-2xl bg-white border border-slate-200 text-center space-y-2">
        <Layers className="w-8 h-8 text-slate-300 mx-auto" />
        <h4 className="text-sm font-bold text-slate-800">No Version History Available</h4>
        <p className="text-xs text-slate-500">
          This proposal has no recorded versions yet.
        </p>
      </div>
    );
  }

  // Single Version (Initial Proposal)
  if (versions.length === 1) {
    const v1 = versions[0];
    const isRejected = v1.status === 'Rejected';
    const isAccepted = v1.status === 'Accepted';

    return (
      <div className="p-6 rounded-2xl bg-white border border-slate-200 shadow-xs space-y-4">
        <div className="flex items-center gap-2.5 pb-3 border-b border-slate-100">
          <div className={cn(
            "w-8 h-8 rounded-lg flex items-center justify-center border",
            isRejected
              ? "bg-rose-50 text-rose-600 border-rose-100"
              : isAccepted
              ? "bg-emerald-50 text-emerald-600 border-emerald-100"
              : "bg-sky-50 text-[#0284C7] border-sky-100"
          )}>
            <History className="w-4 h-4" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-slate-900 leading-tight">
              Proposal Negotiation Ledger
            </h3>
            <span className="text-[11px] text-slate-500">
              Iteration audit trail
            </span>
          </div>
        </div>

        <div className={cn(
          "p-4 rounded-xl border flex items-start gap-3",
          isRejected
            ? "bg-rose-50/60 border-rose-200/80 text-rose-950"
            : isAccepted
            ? "bg-emerald-50/60 border-emerald-200/80 text-emerald-950"
            : "bg-slate-50 border-slate-200/80 text-slate-900"
        )}>
          {isRejected ? (
            <X className="w-4 h-4 text-rose-600 shrink-0 mt-0.5" />
          ) : isAccepted ? (
            <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
          ) : (
            <AlertCircle className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
          )}
          <div className="space-y-1 text-xs">
            <div className="flex items-center gap-2">
              <p className="font-semibold text-slate-900">
                {isRejected
                  ? `Proposal Round ${v1.versionNumber} — Declined`
                  : isAccepted
                  ? `Proposal Round ${v1.versionNumber} — Accepted`
                  : `Initial Proposal (Round ${v1.versionNumber})`}
              </p>
              <span className={cn(
                "px-2 py-0.5 rounded text-[10px] font-bold uppercase",
                isRejected
                  ? "bg-rose-100 text-rose-700"
                  : isAccepted
                  ? "bg-emerald-100 text-emerald-800"
                  : "bg-sky-100 text-[#0284C7]"
              )}>
                {v1.status}
              </span>
            </div>
            <p className="text-slate-600 leading-relaxed">
              {isRejected
                ? 'This commercial proposal iteration was declined by your organization.'
                : isAccepted
                ? 'This commercial proposal was accepted. Agreement confirmation is active.'
                : 'This is the opening proposal mediated by your broker. No prior counter-offers or revised negotiation rounds have been recorded for this demand yet.'}
            </p>
            <div className="pt-2 flex items-center gap-2 text-[11px] text-slate-400">
              <Clock className="w-3 h-3" />
              <span>Logged on {formatDate(v1.createdAt)}</span>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div
      className={cn(
        'w-full max-w-full overflow-x-hidden bg-white rounded-2xl border border-slate-200 shadow-xs p-4 sm:p-6 space-y-6',
        className
      )}
    >
      {/* 1. Module Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 pb-4 border-b border-slate-100">
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl bg-sky-50 text-[#0284C7] flex items-center justify-center border border-sky-100 shadow-2xs">
            <History className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
              Proposal Negotiation Ledger
            </h3>
            <p className="text-xs text-slate-500">
              Review commercial terms across all {totalRounds} negotiation rounds
            </p>
          </div>
        </div>

        {/* Round Meta Badges */}
        <div className="flex items-center gap-2">
          <span
            className={cn(
              'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border',
              latestVersion.status === 'Rejected'
                ? 'bg-rose-50 text-rose-700 border-rose-200'
                : latestVersion.status === 'Accepted'
                ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                : 'bg-sky-50 text-[#0284C7] border border-sky-200'
            )}
          >
            <GitCommit className="w-3.5 h-3.5" />
            <span>
              {latestVersion.status === 'Rejected'
                ? `Declined: Round ${latestVersion.versionNumber}`
                : latestVersion.status === 'Accepted'
                ? `Accepted: Round ${latestVersion.versionNumber}`
                : `Active: Round ${latestVersion.versionNumber}`}
            </span>
          </span>

          <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-600 border border-slate-200">
            {totalRounds} Rounds Logged
          </span>
        </div>
      </div>

      {/* 2. Version Selector Tabs (Horizontal segmented control with min-h-[48px] touch targets) */}
      <div className="space-y-2">
        <div className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
          Select Negotiation Round
        </div>

        <div className="flex items-center gap-2 overflow-x-auto pb-1.5 no-scrollbar">
          {versions.map((ver, idx) => {
            const isSelected = ver.id === selectedVersion.id;
            const isLatest = idx === totalRounds - 1;

            return (
              <button
                key={ver.id}
                type="button"
                onClick={() => setSelectedVersionId(ver.id)}
                className={cn(
                  'flex items-center gap-2 min-h-[48px] px-4 py-2 rounded-xl text-xs sm:text-sm font-semibold transition-all shrink-0 cursor-pointer border',
                  isSelected
                    ? 'bg-[#0284C7] text-white border-[#0284C7] shadow-xs'
                    : 'bg-slate-50 hover:bg-slate-100 text-slate-700 border-slate-200'
                )}
              >
                <span>Round {ver.versionNumber}</span>
                <span
                  className={cn(
                    'px-1.5 py-0.5 rounded text-[10px] font-bold uppercase',
                    isSelected
                      ? 'bg-white/20 text-white'
                      : ver.status === 'Rejected'
                      ? 'bg-rose-100 text-rose-700'
                      : ver.status === 'Accepted'
                      ? 'bg-emerald-100 text-emerald-800'
                      : isLatest
                      ? 'bg-sky-100 text-[#0284C7]'
                      : 'bg-slate-200 text-slate-600'
                  )}
                >
                  {ver.status === 'Rejected'
                    ? 'Rejected'
                    : ver.status === 'Accepted'
                    ? 'Accepted'
                    : isLatest
                    ? 'Latest'
                    : 'Superseded'}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* 3. Diff Chips (Change Indicators against predecessor) */}
      {selectedVersion && (
        <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200/90 space-y-2 text-xs">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <span className="font-semibold text-slate-800">
              Round {selectedVersion.versionNumber} Snapshot Details
            </span>
            <span className="text-slate-400 text-[11px]">
              Logged on {formatDate(selectedVersion.createdAt)}
            </span>
          </div>

          {/* Change Delta against V1 or previous version */}
          {selectedVersion.versionNumber > 1 && (
            <div className="flex flex-wrap items-center gap-2 pt-1 border-t border-slate-200/60">
              <span className="text-slate-500 text-[11px]">Round Deltas:</span>

              {/* Price Diff */}
              {(() => {
                const prevVer = versions.find(
                  (v) => v.versionNumber === selectedVersion.versionNumber - 1
                );
                if (!prevVer) return null;

                const diff =
                  selectedVersion.terms.pricePerUnit - prevVer.terms.pricePerUnit;
                if (diff === 0) return null;

                const isDrop = diff < 0;
                return (
                  <span
                    className={cn(
                      'inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-semibold border',
                      isDrop
                        ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                        : 'bg-amber-50 text-amber-800 border-amber-200'
                    )}
                  >
                    {isDrop ? (
                      <TrendingDown className="w-3 h-3 text-emerald-600" />
                    ) : (
                      <TrendingUp className="w-3 h-3 text-amber-600" />
                    )}
                    <span>
                      Rate adjusted: ₹{formatCurrency(prevVer.terms.pricePerUnit)} ➔ ₹{formatCurrency(selectedVersion.terms.pricePerUnit)} / {selectedVersion.terms.unit}
                    </span>
                  </span>
                );
              })()}

              {/* Volume Diff */}
              {(() => {
                const prevVer = versions.find(
                  (v) => v.versionNumber === selectedVersion.versionNumber - 1
                );
                if (!prevVer) return null;

                const qtyDiff =
                  selectedVersion.terms.quantity - prevVer.terms.quantity;
                if (qtyDiff === 0) return null;

                return (
                  <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-sky-50 text-[#0284C7] border border-sky-200">
                    <span>
                      Volume: {prevVer.terms.quantity} ➔ {selectedVersion.terms.quantity} {selectedVersion.terms.unit}
                    </span>
                  </span>
                );
              })()}
            </div>
          )}
        </div>
      )}

      {/* 4. Comparison Component: Contrast Selected Version vs Active Version */}
      <VersionComparisonCard
        selectedVersion={selectedVersion}
        latestVersion={latestVersion}
      />
    </div>
  );
}
