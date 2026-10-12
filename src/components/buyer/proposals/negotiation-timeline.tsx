'use client';

import React, { useEffect, useState, useTransition } from 'react';
import { 
  History, 
  ArrowUpRight, 
  ArrowDownLeft, 
  Clock, 
  CheckCircle2, 
  XCircle, 
  FileText, 
  RefreshCw,
  Calendar,
  Layers,
  Sparkles,
  DollarSign,
  Package,
  ShieldCheck,
  User,
  Handshake,
  Loader2
} from 'lucide-react';
import { Skeleton } from '@/components/ui/skeleton';
import { 
  getBuyerNegotiationTimelineAction, 
  BuyerNegotiationTimelineEvent 
} from '@/src/server/actions/buyer-negotiation-actions';
import { cn } from '@/lib/utils';
import { toast } from 'sonner';

export interface NegotiationTimelineProps {
  proposalId: string;
  initialEvents?: BuyerNegotiationTimelineEvent[];
  className?: string;
}

export function NegotiationTimeline({
  proposalId,
  initialEvents,
  className,
}: NegotiationTimelineProps) {
  const [events, setEvents] = useState<BuyerNegotiationTimelineEvent[]>(initialEvents || []);
  const [isLoading, setIsLoading] = useState<boolean>(!initialEvents || initialEvents.length === 0);
  const [isRefreshing, startRefreshTransition] = useTransition();

  const loadTimeline = async (showToast = false) => {
    try {
      const res = await getBuyerNegotiationTimelineAction(proposalId);
      if (res.success && res.data) {
        setEvents(res.data);
        if (showToast) {
          toast.success('Timeline history refreshed.');
        }
      } else if (res.error) {
        if (showToast) {
          toast.error(res.error);
        }
      }
    } catch (err: any) {
      if (showToast) {
        toast.error(err.message || 'Failed to load timeline.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!initialEvents || initialEvents.length === 0) {
      loadTimeline();
    }
  }, [proposalId]);

  const handleManualRefresh = () => {
    startRefreshTransition(async () => {
      await loadTimeline(true);
    });
  };

  // 1. Loading State with Skeletons
  if (isLoading) {
    return (
      <div className={cn('space-y-4 p-4 rounded-xl border border-slate-200 bg-white', className)}>
        <div className="flex items-center justify-between pb-2 border-b border-slate-100">
          <Skeleton className="h-4 w-40 rounded" />
          <Skeleton className="h-4 w-16 rounded" />
        </div>
        <div className="space-y-3 pl-4 border-l-2 border-slate-100 ml-2">
          <Skeleton className="h-24 w-full rounded-xl" />
          <Skeleton className="h-24 w-full rounded-xl" />
        </div>
      </div>
    );
  }

  // 2. Empty State
  if (events.length === 0) {
    return (
      <div className={cn('p-6 text-center rounded-xl bg-slate-50 border border-slate-200 space-y-2', className)}>
        <History className="w-8 h-8 text-slate-300 mx-auto" />
        <h4 className="text-xs font-bold text-slate-800">No Negotiation Events Yet</h4>
        <p className="text-[11px] text-slate-500 max-w-sm mx-auto">
          Chronological proposals, counter-offers, and revisions exchanged with the Broker Desk will appear in this immutable timeline.
        </p>
        <button
          type="button"
          onClick={handleManualRefresh}
          disabled={isRefreshing}
          className="mt-2 text-xs font-bold text-[#0284C7] hover:underline inline-flex items-center gap-1 cursor-pointer"
        >
          <RefreshCw className={cn('w-3 h-3', isRefreshing && 'animate-spin')} />
          <span>Check for Updates</span>
        </button>
      </div>
    );
  }

  return (
    <div className={cn('w-full max-w-full overflow-x-hidden space-y-4', className)}>
      {/* Timeline Header Bar */}
      <div className="flex items-center justify-between pb-2 border-b border-slate-200/80">
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-lg bg-[#E0F2FE] flex items-center justify-center text-[#0284C7]">
            <History className="w-4 h-4" />
          </div>
          <div>
            <h4 className="text-xs sm:text-sm font-bold text-slate-900 leading-tight">
              Chronological Negotiation Stream
            </h4>
            <span className="text-[11px] text-slate-500">
              {events.length} immutable event{events.length === 1 ? '' : 's'} recorded • Strictly Broker-mediated
            </span>
          </div>
        </div>

        <button
          type="button"
          onClick={handleManualRefresh}
          disabled={isRefreshing}
          title="Refresh event stream"
          className="min-h-[36px] px-2.5 py-1.5 rounded-lg border border-slate-200 text-slate-600 hover:text-slate-900 hover:bg-slate-50 text-xs font-semibold flex items-center gap-1.5 transition-colors cursor-pointer"
        >
          <RefreshCw className={cn('w-3.5 h-3.5', isRefreshing && 'animate-spin text-[#0284C7]')} />
          <span className="hidden xs:inline">Refresh</span>
        </button>
      </div>

      {/* Vertical Timeline List (Read-Only & Immutable) */}
      <div className="relative border-l-2 border-slate-200 ml-3 sm:ml-4 pl-4 sm:pl-6 space-y-5 py-1">
        {events.map((evt, idx) => {
          const isBuyer = evt.actorRole === 'buyer';
          const isLatest = idx === events.length - 1;

          return (
            <div key={evt.id || idx} className="relative group">
              {/* Circular Node / Dot */}
              <div
                className={cn(
                  'absolute -left-[23px] sm:-left-[31px] top-1.5 w-6 h-6 rounded-full flex items-center justify-center border-2 border-white shadow-2xs transition-transform',
                  isBuyer
                    ? 'bg-[#0284C7] text-white'
                    : 'bg-slate-800 text-white'
                )}
              >
                {isBuyer ? (
                  <ArrowUpRight className="w-3.5 h-3.5 stroke-[2.5]" />
                ) : (
                  <ArrowDownLeft className="w-3.5 h-3.5 stroke-[2.5]" />
                )}
              </div>

              {/* Event Content Card (Read-Only) */}
              <div
                className={cn(
                  'rounded-xl p-3.5 sm:p-4 border text-xs space-y-2.5 transition-all max-w-full overflow-hidden break-words',
                  isBuyer
                    ? 'bg-sky-50/50 border-sky-200/80 shadow-2xs'
                    : 'bg-white border-slate-200 shadow-2xs',
                  isLatest && 'ring-1 ring-sky-300/50'
                )}
              >
                {/* Event Card Header */}
                <div className="flex flex-col xs:flex-row xs:items-center justify-between gap-1.5 border-b pb-2 border-slate-200/60">
                  <div className="flex items-center gap-2 flex-wrap">
                    {/* Actor Pill */}
                    <span
                      className={cn(
                        'px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider',
                        isBuyer
                          ? 'bg-[#0284C7] text-white'
                          : 'bg-slate-800 text-white'
                      )}
                    >
                      {evt.actorName || (isBuyer ? 'You' : 'Broker')}
                    </span>

                    {/* Action Name */}
                    <span className="font-bold text-slate-900 text-xs sm:text-sm">
                      {evt.actionLabel}
                    </span>

                    {/* Version Badge (if present) */}
                    {evt.versionNumber && (
                      <span className="px-1.5 py-0.2 rounded text-[10px] font-bold bg-slate-100 text-slate-700 border border-slate-200">
                        v{evt.versionNumber}
                      </span>
                    )}
                  </div>

                  {/* Timestamp */}
                  <div className="flex items-center gap-1 text-[11px] text-slate-500 shrink-0">
                    <Clock className="w-3 h-3 text-slate-400" />
                    <span>{evt.formattedTime}</span>
                  </div>
                </div>

                {/* Summary Badge / Diff */}
                {evt.summary && (
                  <div className="flex items-center gap-2 flex-wrap">
                    <div
                      className={cn(
                        'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold border shadow-2xs',
                        isBuyer
                          ? 'bg-white border-sky-200 text-[#0369A1]'
                          : 'bg-slate-50 border-slate-200 text-slate-900'
                      )}
                    >
                      <DollarSign className="w-3.5 h-3.5 text-[#0284C7] shrink-0" />
                      <span>{evt.summary}</span>
                    </div>

                    {evt.termsDiff?.deliveryDate && (
                      <div className="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg text-[11px] font-medium bg-slate-100 text-slate-700 border border-slate-200/60">
                        <Calendar className="w-3 h-3 text-slate-500 shrink-0" />
                        <span>Delivery: {evt.termsDiff.deliveryDate}</span>
                      </div>
                    )}
                  </div>
                )}

                {/* Notes or Justification Body (if present) */}
                {evt.termsDiff?.notes && (
                  <div className="p-2.5 rounded-lg bg-white/80 border border-slate-200/80 text-xs text-slate-700 space-y-1">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400 block">
                      {isBuyer ? 'Notes to Broker Desk' : 'Message from Broker Desk'}
                    </span>
                    <p className="italic text-slate-700">
                      "{evt.termsDiff.notes}"
                    </p>
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
