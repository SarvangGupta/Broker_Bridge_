'use client';

import React, { useEffect } from 'react';
import Link from 'next/link';
import { AlertCircle, RefreshCw, Home, ShieldAlert } from 'lucide-react';
import { Button } from '@/components/ui/button';

export default function BrokerError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Log client/server error for debugging
    console.error('Broker Workstation Error Boundary caught an exception:', error);
  }, [error]);

  return (
    <div className="min-h-[70vh] w-full flex items-center justify-center p-4 sm:p-6">
      <div className="w-full max-w-md bg-white border border-border rounded-2xl shadow-xl p-6 sm:p-8 text-center space-y-6">
        {/* Centralized Warning Icon */}
        <div className="mx-auto w-16 h-16 rounded-full bg-teal-50 border-2 border-teal-200/80 flex items-center justify-center shadow-xs">
          <AlertCircle className="w-8 h-8 text-[#0D9488] stroke-[2.25]" />
        </div>

        {/* Title & Description */}
        <div className="space-y-2">
          <h2 className="text-xl font-bold text-slate-900 tracking-tight">
            Workstation Interruption
          </h2>
          <p className="text-xs sm:text-sm text-slate-500 max-w-xs mx-auto">
            {error.message ||
              'A temporary error occurred while loading this workstation view. Please retry or refresh your session.'}
          </p>
          {error.digest && (
            <p className="text-[10px] font-mono text-slate-400">
              Error Digest: {error.digest}
            </p>
          )}
        </div>

        {/* Action Buttons */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-2.5 pt-2">
          <Button
            onClick={() => reset()}
            className="w-full sm:w-auto min-h-[48px] px-5 rounded-xl bg-[#0D9488] hover:bg-[#0F766E] text-white font-semibold shadow-xs flex items-center justify-center gap-2 cursor-pointer transition-all"
          >
            <RefreshCw className="w-4 h-4" />
            <span>Try Again</span>
          </Button>

          <Link
            href="/broker"
            className="w-full sm:w-auto min-h-[48px] px-5 rounded-xl border border-border bg-white text-slate-700 hover:bg-slate-50 font-medium flex items-center justify-center gap-2 cursor-pointer transition-colors shadow-2xs"
          >
            <Home className="w-4 h-4" />
            <span>Back to Home</span>
          </Link>
        </div>

        {/* Bottom Safety Assurance Note */}
        <div className="pt-4 border-t border-slate-100 flex items-center justify-center gap-1.5 text-[11px] text-slate-400">
          <ShieldAlert className="w-3.5 h-3.5 text-teal-600 shrink-0" />
          <span>Your transactions & lot data remain secure</span>
        </div>
      </div>
    </div>
  );
}
