'use client';

import React from 'react';
import { useRouter } from 'next/navigation';
import {
  FlaskConical,
  ShieldCheck,
  FileText,
  SlidersHorizontal,
  CheckCircle2,
  AlertTriangle,
  ArrowRight,
  Sparkles,
  Building2,
  Layers,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import type { BrokerAssignedRequirement } from '@/src/server/actions/broker-work-actions';
import { formatIndianCurrency } from '@/lib/utils';

interface BrokerQualityHubProps {
  requirements: BrokerAssignedRequirement[];
  onNavigateToMatches?: (reqId: string) => void;
}

export function BrokerQualityHub({
  requirements = [],
  onNavigateToMatches,
}: BrokerQualityHubProps) {
  const router = useRouter();
  if (requirements.length === 0) {
    return (
      <Card className="border-dashed border-2 border-slate-200 bg-white/70">
        <CardContent className="p-8 sm:p-12 text-center space-y-4">
          <div className="mx-auto w-12 h-12 rounded-full bg-slate-100 border border-slate-200 flex items-center justify-center text-slate-400">
            <FlaskConical className="w-6 h-6" />
          </div>
          <div className="space-y-1 max-w-sm mx-auto">
            <h3 className="font-bold text-slate-800 text-base">No Open Quality Mandates</h3>
            <p className="text-xs sm:text-sm text-slate-500">
              Assigned buyer requirements with quality parameter specifications will appear here for COA verification.
            </p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto">
      {/* Top Banner */}
      <Card className="bg-gradient-to-r from-teal-950 via-slate-900 to-slate-900 text-white border-0 shadow-sm rounded-2xl p-5 sm:p-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="space-y-1.5 max-w-xl">
            <div className="flex items-center gap-2">
              <span className="px-2.5 py-0.5 rounded-md text-[10px] font-mono font-bold uppercase tracking-wider bg-[#0D9488] text-white">
                COA & LAB VERIFICATION DESK
              </span>
            </div>
            <h2 className="text-xl sm:text-2xl font-bold tracking-tight text-white">
              Quality Assurance & Certificate Audit
            </h2>
            <p className="text-xs sm:text-sm text-slate-300">
              Audit laboratory certificates, inspect parameter tolerances, and enforce commercial quality compliance before finalizing match proposals.
            </p>
          </div>

          <div className="grid grid-cols-2 gap-2 sm:gap-3 bg-white/10 rounded-xl p-3 border border-white/10 text-center shrink-0">
            <div>
              <div className="text-[10px] text-teal-300 uppercase font-bold">Assigned Mandates</div>
              <div className="text-xl font-bold text-white mt-0.5">{requirements.length}</div>
            </div>
            <div>
              <div className="text-[10px] text-slate-300 uppercase font-bold">Protocol</div>
              <div className="text-xs font-semibold text-teal-200 mt-1">NABL / Lab EAV</div>
            </div>
          </div>
        </div>
      </Card>

      {/* Requirement Quality Cards */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-bold text-slate-800 flex items-center gap-2">
            <SlidersHorizontal className="w-4 h-4 text-[#0D9488]" />
            <span>Active Buyer Mandates Requiring Quality Review ({requirements.length})</span>
          </h3>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {requirements.map((req) => (
            <Card
              key={req.id}
              className="bg-white border border-slate-200/90 shadow-2xs hover:shadow-md transition-all duration-200 rounded-xl overflow-hidden flex flex-col justify-between"
            >
              <div className="p-4 sm:p-5 space-y-3">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <div className="flex items-center gap-1.5">
                      <span className="font-bold text-slate-900 text-sm sm:text-base">
                        {req.buyerCompanyName}
                      </span>
                      {req.buyerCompanyVerified && (
                        <ShieldCheck className="w-4 h-4 text-[#0D9488] shrink-0" />
                      )}
                    </div>
                    <div className="text-xs text-slate-400 font-mono mt-0.5">
                      {req.requirementRef}
                    </div>
                  </div>

                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-teal-50 text-teal-800 border border-teal-200 uppercase tracking-wider">
                    {req.operationalStatus}
                  </span>
                </div>

                {/* Commodity & Grade */}
                <div className="bg-slate-50 p-2.5 rounded-lg border border-slate-100 text-xs">
                  <div className="font-bold text-slate-800">
                    {req.commodityName}{' '}
                    <span className="text-[#0D9488] font-semibold">• {req.gradeName}</span>
                  </div>
                  <div className="text-slate-500 mt-0.5">
                    {req.quantity} {req.unitSymbol || 'MT'} needed • Target:{' '}
                    {formatIndianCurrency(req.targetPrice)}
                  </div>
                </div>

                {/* Quality Specs Preview */}
                {req.qualityParameters && Object.keys(req.qualityParameters).length > 0 ? (
                  <div className="space-y-1 text-xs">
                    <div className="text-[11px] font-semibold text-slate-600">
                      Standard Quality Tolerances:
                    </div>
                    <div className="flex flex-wrap gap-1 text-[11px] font-mono">
                      {Object.entries(req.qualityParameters).slice(0, 3).map(([k, v]) => (
                        <span key={k} className="px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                          {k}: {String(v)}
                        </span>
                      ))}
                    </div>
                  </div>
                ) : (
                  <div className="text-xs text-slate-500 italic">
                    Standard Grade Quality Specifications active.
                  </div>
                )}
              </div>

              <div className="p-4 pt-0">
                <Button
                  type="button"
                  onClick={() => {
                    if (onNavigateToMatches) {
                      onNavigateToMatches(req.id);
                    } else {
                      router.push(`/broker/work?tab=matches&reqId=${req.id}`);
                    }
                  }}
                  className="w-full min-h-[48px] h-12 bg-teal-50 hover:bg-teal-100 text-[#0D9488] font-bold text-xs sm:text-sm rounded-lg transition-all flex items-center justify-center gap-2 border border-teal-200 shadow-2xs cursor-pointer"
                >
                  <FlaskConical className="w-4 h-4 text-[#0D9488] shrink-0" />
                  <span>Audit Quality & Match Supply</span>
                  <ArrowRight className="w-4 h-4 text-[#0D9488] shrink-0" />
                </Button>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}
