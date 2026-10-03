'use client';

import React, { useTransition } from 'react';
import { AlertCircle, RotateCcw, Home } from 'lucide-react';
import Link from 'next/link';

export default function BuyerDashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const [isPending, startTransition] = useTransition();

  const handleRetry = () => {
    startTransition(() => {
      reset();
    });
  };

  return (
    <div className="min-h-[70vh] w-full max-w-full overflow-hidden flex items-center justify-center p-4 sm:p-6 select-none">
      <div className="max-w-md w-full bg-white border border-slate-200/80 rounded-2xl p-6 sm:p-8 text-center shadow-sm space-y-5">
        {/* Error Icon */}
        <div className="w-14 h-14 rounded-full bg-rose-50 text-rose-600 mx-auto flex items-center justify-center border border-rose-100">
          <AlertCircle className="w-7 h-7" />
        </div>

        {/* Messaging */}
        <div className="space-y-1.5 min-w-0">
          <h2 className="text-lg sm:text-xl font-bold text-slate-900 tracking-tight">
            Connection Lost or System Error
          </h2>
          <p className="text-xs sm:text-sm text-slate-500 leading-relaxed break-words">
            {error?.message ||
              'Unable to load the Buyer Procurement Command Center. Please check your network connection and try again.'}
          </p>
          {error?.digest && (
            <p className="text-[10px] font-mono text-slate-400 truncate pt-1">
              Error Ref: {error.digest}
            </p>
          )}
        </div>

        {/* Actions */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-2">
          <button
            onClick={handleRetry}
            disabled={isPending}
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-3 text-xs sm:text-sm font-bold text-white bg-[#0284C7] hover:bg-[#0369A1] active:bg-[#0369A1] disabled:opacity-60 rounded-xl transition-all shadow-xs min-h-[48px] cursor-pointer"
          >
            <RotateCcw className={`w-4 h-4 ${isPending ? 'animate-spin' : ''}`} />
            <span>{isPending ? 'Retrying...' : 'Try Again'}</span>
          </button>

          <Link
            href="/buyer"
            className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-5 py-3 text-xs sm:text-sm font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-all min-h-[48px]"
          >
            <Home className="w-4 h-4 text-slate-500" />
            <span>Buyer Home</span>
          </Link>
        </div>
      </div>
    </div>
  );
}
