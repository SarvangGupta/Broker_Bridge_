'use client';

import React, { useEffect } from 'react';
import Link from 'next/link';
import {
  AlertTriangle,
  RefreshCw,
  LayoutDashboard,
  WifiOff,
  ShieldAlert,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';

interface ErrorProps {
  error: Error & { digest?: string };
  reset: () => void;
}

export default function SellerRootError({ error, reset }: ErrorProps) {
  useEffect(() => {
    // Log error for client observability
    console.error('Seller Workspace Global Error Boundary caught:', error);
  }, [error]);

  return (
    <div className="min-h-[85vh] w-full flex items-center justify-center p-4 sm:p-6 lg:p-8 font-sans antialiased">
      <div className="max-w-md w-full bg-white rounded-3xl border border-slate-200/90 shadow-lg p-6 sm:p-8 text-center space-y-6 animate-in fade-in-50 zoom-in-95 duration-200">
        
        {/* ICON BANNER */}
        <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-3xl bg-rose-50 text-rose-600 mx-auto flex items-center justify-center shadow-xs border border-rose-100">
          <ShieldAlert className="w-8 h-8 sm:w-10 sm:h-10 stroke-[2]" />
        </div>

        {/* TITLE & DESCRIPTION */}
        <div className="space-y-2">
          <Badge
            variant="outline"
            className="bg-amber-50 text-amber-800 border-amber-200 font-bold text-xs px-2.5 py-0.5"
          >
            Tier-2 Network Resilience Safeguard
          </Badge>
          <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
            Connection Interrupted or Temporary Delay
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 font-medium leading-relaxed">
            The workspace encountered a network timeout or connection reset. Your data is protected and no unsaved transactions were compromised.
          </p>
        </div>

        {/* DIGEST CODE (IF PRESENT) */}
        {error.digest && (
          <div className="p-2.5 bg-slate-50 rounded-xl border border-slate-200/80 text-[11px] font-mono text-slate-500 truncate">
            Error Reference: <span className="font-bold text-slate-700">{error.digest}</span>
          </div>
        )}

        {/* RECOVERY ACTION BUTTONS (48px Touch Targets) */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-center gap-3 pt-2">
          <Button
            onClick={() => reset()}
            className="min-h-[48px] h-12 px-6 bg-[#047857] hover:bg-[#065f46] text-white font-bold rounded-xl shadow-sm flex items-center justify-center gap-2 cursor-pointer transition-all active:scale-[0.98]"
          >
            <RefreshCw className="w-4 h-4" />
            <span>Try Again</span>
          </Button>

          <Link href="/seller" className="w-full sm:w-auto">
            <Button
              variant="outline"
              className="w-full min-h-[48px] h-12 px-6 border-slate-300 text-slate-700 hover:bg-slate-50 font-bold rounded-xl cursor-pointer flex items-center justify-center gap-2"
            >
              <LayoutDashboard className="w-4 h-4 text-slate-600" />
              <span>Command Center</span>
            </Button>
          </Link>
        </div>

        {/* LOW-BANDWIDTH ADVISORY */}
        <div className="pt-4 border-t border-slate-100 text-[11px] text-slate-400 flex items-center justify-center gap-1.5">
          <WifiOff className="w-3.5 h-3.5 text-slate-400 shrink-0" />
          <span>If on 2G/3G connectivity, reconnecting your network will restore live sync.</span>
        </div>
      </div>
    </div>
  );
}
