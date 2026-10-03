'use client';

import React, { useTransition, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ArrowRight, Clock, AlertTriangle, CheckCircle2, Truck, Loader2 } from 'lucide-react';
import { BuyerActionItem } from '@/src/server/actions/buyer-dashboard-actions';

interface BuyerActionFeedProps {
  actionItems: BuyerActionItem[];
}

export function BuyerActionFeed({ actionItems }: BuyerActionFeedProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [loadingItemId, setLoadingItemId] = useState<string | null>(null);

  // Task 3: Action Required Empty State
  if (!actionItems || actionItems.length === 0) {
    return (
      <div className="bg-white border border-slate-200/80 rounded-2xl p-6 text-center shadow-2xs select-none space-y-2">
        <div className="w-12 h-12 rounded-full bg-emerald-50 text-emerald-600 mx-auto flex items-center justify-center border border-emerald-100">
          <CheckCircle2 className="w-6 h-6 text-emerald-600" />
        </div>
        <h3 className="text-sm font-bold text-slate-900">
          All clear! You have no pending proposals or urgent alerts.
        </h3>
        <p className="text-xs text-slate-500">
          New broker proposals and vehicle dispatch updates will appear here automatically.
        </p>
      </div>
    );
  }

  const getAlertStyles = (type: BuyerActionItem['type']) => {
    switch (type) {
      case 'PROPOSAL_PENDING':
        return {
          container: 'border-l-4 border-l-amber-500 bg-amber-50/30 border-t border-r border-b border-amber-200/60',
          chip: 'bg-amber-100 text-amber-800 border-amber-200',
          icon: Clock,
          iconColor: 'text-amber-600 bg-amber-100',
        };
      case 'DISPATCH_IN_TRANSIT':
        return {
          container: 'border-l-4 border-l-[#0284C7] bg-sky-50/30 border-t border-r border-b border-sky-200/60',
          chip: 'bg-[#E0F2FE] text-[#0284C7] border-sky-200',
          icon: Truck,
          iconColor: 'text-[#0284C7] bg-[#E0F2FE]',
        };
      case 'ACTION_EXPIRED':
        return {
          container: 'border-l-4 border-l-rose-500 bg-rose-50/30 border-t border-r border-b border-rose-200/60',
          chip: 'bg-rose-100 text-rose-800 border-rose-200',
          icon: AlertTriangle,
          iconColor: 'text-rose-600 bg-rose-100',
        };
      default:
        return {
          container: 'border-l-4 border-l-slate-400 bg-slate-50 border-t border-r border-b border-slate-200',
          chip: 'bg-slate-100 text-slate-700 border-slate-200',
          icon: Clock,
          iconColor: 'text-slate-600 bg-slate-100',
        };
    }
  };

  const handleCtaClick = (url: string, itemId: string) => {
    setLoadingItemId(itemId);
    startTransition(() => {
      router.push(url);
    });
  };

  return (
    <section className="space-y-3 select-none" aria-label="P0 Action Required Section">
      <div className="flex items-center justify-between">
        <h2 className="text-base sm:text-lg font-bold text-slate-900 tracking-tight flex items-center gap-2">
          <span className="w-2 h-2 rounded-full bg-amber-500 animate-pulse inline-block"></span>
          <span>P0 Action Required</span>
        </h2>
        <span className="text-xs font-semibold text-slate-500 bg-slate-100 px-2 py-0.5 rounded-md">
          {actionItems.length} Urgent Items
        </span>
      </div>

      <div className="space-y-3">
        {actionItems.map((item) => {
          const styles = getAlertStyles(item.type);
          const Icon = styles.icon;
          const isLoadingThis = isPending && loadingItemId === item.id;

          return (
            <div
              key={item.id}
              className={`rounded-2xl p-4 sm:p-5 transition-all duration-150 shadow-2xs ${styles.container}`}
            >
              <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                <div className="flex items-start gap-3.5 min-w-0">
                  <div className={`p-2.5 rounded-xl shrink-0 ${styles.iconColor}`}>
                    <Icon className="w-5 h-5" />
                  </div>
                  <div className="space-y-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="text-sm font-bold text-slate-900 tracking-tight">
                        {item.title}
                      </h3>
                      {item.timeRemaining && (
                        <span
                          className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${styles.chip}`}
                        >
                          {item.timeRemaining}
                        </span>
                      )}
                    </div>
                    <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
                      {item.description}
                    </p>
                  </div>
                </div>

                {/* Task 4: Optimistic Disabled Button with Spinner */}
                <button
                  onClick={() => handleCtaClick(item.ctaUrl, item.id)}
                  disabled={isLoadingThis}
                  className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-5 py-2.5 text-xs sm:text-sm font-bold text-white bg-[#0284C7] hover:bg-[#0369A1] active:bg-[#0369A1] disabled:opacity-60 rounded-xl transition-all shadow-xs min-h-[48px] shrink-0 cursor-pointer"
                >
                  {isLoadingThis ? (
                    <Loader2 className="w-4 h-4 animate-spin text-white" />
                  ) : (
                    <>
                      <span>{item.ctaLabel}</span>
                      <ArrowRight className="w-4 h-4" />
                    </>
                  )}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}
