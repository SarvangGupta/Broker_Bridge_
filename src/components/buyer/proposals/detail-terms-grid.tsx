'use client';

import React from 'react';
import { 
  CheckCircle, 
  Clock, 
  FileCheck2, 
  MapPin, 
  Package, 
  Scale, 
  ShieldCheck, 
  Truck, 
  CreditCard,
  FileText,
  AlertTriangle,
  BadgeCheck
} from 'lucide-react';
import { BuyerProposalDetail } from '@/src/types/buyer-proposal';
import { cn } from '@/lib/utils';

interface DetailTermsGridProps {
  proposal: BuyerProposalDetail;
  className?: string;
}

function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return 'Immediate / Flexible';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

export function DetailTermsGrid({ proposal, className }: DetailTermsGridProps) {
  return (
    <div className={cn('w-full max-w-full overflow-x-hidden space-y-4', className)}>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {/* CARD 1: Quality & Inspection Terms */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-4 sm:p-5 flex flex-col justify-between space-y-4">
          <div className="space-y-3">
            {/* Header */}
            <div className="flex items-center gap-2.5 pb-2.5 border-b border-slate-100">
              <div className="w-8 h-8 rounded-lg bg-teal-50 text-teal-700 flex items-center justify-center border border-teal-100">
                <Scale className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-sm font-bold text-slate-900 leading-tight">
                  Quality & Lab Specs
                </h3>
                <span className="text-[11px] text-slate-500">
                  Agreed chemical & physical limits
                </span>
              </div>
            </div>

            {/* Quality Parameters Table / Chips */}
            <div className="space-y-2">
              <div className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">
                Parameter Limits
              </div>

              <div className="divide-y divide-slate-100 rounded-xl border border-slate-100 overflow-hidden bg-slate-50/60">
                {proposal.qualitySpecifications.map((spec, idx) => (
                  <div
                    key={idx}
                    className="flex items-center justify-between p-2.5 text-xs gap-2"
                  >
                    <div className="flex items-center gap-1.5 min-w-0">
                      <CheckCircle className="w-3.5 h-3.5 text-teal-600 shrink-0" />
                      <span className="font-medium text-slate-700 truncate">
                        {spec.parameterName}
                      </span>
                    </div>

                    <div className="text-right shrink-0">
                      <span className="font-bold text-slate-900">
                        {spec.targetValue}
                      </span>
                      {spec.unit && (
                        <span className="text-slate-500 text-[11px] ml-1">
                          {spec.unit}
                        </span>
                      )}
                      {spec.tolerance && (
                        <span className="block text-[10px] text-slate-400">
                          {spec.tolerance}
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Inspection Requirements */}
            {proposal.inspectionRequirements && (
              <div className="space-y-1 pt-1">
                <div className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">
                  Verification & Inspection
                </div>
                <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-200/80 text-xs text-slate-700 flex items-start gap-2">
                  <BadgeCheck className="w-4 h-4 text-teal-600 shrink-0 mt-0.5" />
                  <p className="leading-relaxed">
                    {proposal.inspectionRequirements}
                  </p>
                </div>
              </div>
            )}
          </div>

          <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-400">
            <span>Mandatory COA Required</span>
            <span className="text-teal-700 font-semibold">Strict NABL Gate</span>
          </div>
        </div>

        {/* CARD 2: Logistics & Delivery Window */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-4 sm:p-5 flex flex-col justify-between space-y-4">
          <div className="space-y-3">
            {/* Header */}
            <div className="flex items-center gap-2.5 pb-2.5 border-b border-slate-100">
              <div className="w-8 h-8 rounded-lg bg-sky-50 text-[#0284C7] flex items-center justify-center border border-sky-100">
                <Truck className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-sm font-bold text-slate-900 leading-tight">
                  Logistics & Delivery
                </h3>
                <span className="text-[11px] text-slate-500">
                  Freight, location and window
                </span>
              </div>
            </div>

            {/* Destination Location */}
            <div className="space-y-1">
              <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider block">
                Designated Destination
              </span>
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/80 flex items-start gap-2 text-xs">
                <MapPin className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
                <div>
                  <span className="font-bold text-slate-900 block">
                    {proposal.deliveryLocation}
                  </span>
                  {(proposal.deliveryDistrict || proposal.deliveryState) && (
                    <span className="text-slate-500 text-[11px]">
                      {[proposal.deliveryDistrict, proposal.deliveryState].filter(Boolean).join(', ')}
                    </span>
                  )}
                </div>
              </div>
            </div>

            {/* Delivery Window */}
            <div className="space-y-1">
              <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider block">
                Delivery Window
              </span>
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/80 flex items-center gap-3 text-xs">
                <Clock className="w-4 h-4 text-[#0284C7] shrink-0" />
                <div className="min-w-0">
                  <div className="font-bold text-slate-900">
                    {formatDate(proposal.deliveryWindowStart)} — {formatDate(proposal.deliveryWindowEnd)}
                  </div>
                  <span className="text-[11px] text-slate-400">
                    Expected transit timeline
                  </span>
                </div>
              </div>
            </div>

            {/* Freight Terms */}
            <div className="space-y-1">
              <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider block">
                Freight & Transit Responsibilities
              </span>
              <div className="p-2.5 rounded-xl bg-sky-50/70 border border-sky-200 text-xs text-[#0284C7] font-semibold">
                {proposal.freightTerms}
              </div>
            </div>
          </div>

          <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-400">
            <span>E-Way Bill & LR Handover</span>
            <span className="text-sky-700 font-semibold">Trackable GPS Dispatch</span>
          </div>
        </div>

        {/* CARD 3: Commercial & Payment Terms */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-4 sm:p-5 flex flex-col justify-between space-y-4 md:col-span-2 lg:col-span-1">
          <div className="space-y-3">
            {/* Header */}
            <div className="flex items-center gap-2.5 pb-2.5 border-b border-slate-100">
              <div className="w-8 h-8 rounded-lg bg-emerald-50 text-emerald-700 flex items-center justify-center border border-emerald-100">
                <CreditCard className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-sm font-bold text-slate-900 leading-tight">
                  Commercial Terms
                </h3>
                <span className="text-[11px] text-slate-500">
                  Payment schedule & packaging
                </span>
              </div>
            </div>

            {/* Payment Schedule */}
            <div className="space-y-1">
              <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider block">
                Payment Terms & Settlement
              </span>
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/80 text-xs">
                <div className="flex items-start gap-2">
                  <ShieldCheck className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
                  <p className="font-semibold text-slate-900 leading-snug">
                    {proposal.paymentTerms}
                  </p>
                </div>
              </div>
            </div>

            {/* Packaging Specification */}
            <div className="space-y-1">
              <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider block">
                Packaging Specifications
              </span>
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/80 flex items-center gap-2 text-xs">
                <Package className="w-4 h-4 text-slate-500 shrink-0" />
                <span className="font-semibold text-slate-800">
                  {proposal.packagingType}
                </span>
              </div>
            </div>

            {/* Special Conditions */}
            {proposal.specialConditions && (
              <div className="space-y-1">
                <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider block">
                  Special Trade Conditions
                </span>
                <div className="p-2.5 rounded-xl bg-amber-50/70 border border-amber-200 text-xs text-amber-900 leading-relaxed">
                  {proposal.specialConditions}
                </div>
              </div>
            )}
          </div>

          <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-400">
            <span>Escrow Protected</span>
            <span className="text-emerald-700 font-semibold">100% Guaranteed</span>
          </div>
        </div>
      </div>
    </div>
  );
}
