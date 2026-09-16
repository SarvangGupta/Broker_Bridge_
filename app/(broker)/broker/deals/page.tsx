'use client';

import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Handshake, FileCheck2, ArrowRight } from 'lucide-react';

export default function BrokerDealsPage() {
  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">
          Deals & Contracts
        </h1>
        <p className="text-xs sm:text-sm text-slate-500 mt-1">
          Manage finalized terms and confirmed agreements.
        </p>
      </div>

      {/* Standard Empty State Card */}
      <Card className="border-dashed border-2 border-slate-200 bg-white/60">
        <CardContent className="p-8 sm:p-12 text-center space-y-4">
          <div className="mx-auto w-12 h-12 rounded-full bg-teal-50 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
            <Handshake className="w-6 h-6" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="font-bold text-slate-800 text-base">No Finalized Deals Yet</h3>
            <p className="text-xs sm:text-sm text-slate-500">
              When negotiations reach mutual agreement and pass the Pre-Flight Finalization Gate, confirmed contracts will appear here.
            </p>
          </div>
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-mono font-medium text-teal-700 bg-teal-50/80 border border-teal-200/60">
            <span>Module ready for Sprint 27 wiring</span>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
