'use client';

import React from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  FileCheck2,
  PackageCheck,
  Truck,
  MapPin,
  CheckCircle2,
  Clock,
  AlertTriangle,
  ShieldAlert,
  XCircle,
  Sparkles,
  ArrowRight,
  ChevronRight,
} from 'lucide-react';
import {
  FulfillmentStage,
  ExceptionFlag,
} from '@/src/server/actions/broker-order-actions';

interface LogisticsTrackerProps {
  bookingReference: string;
  fulfillmentStage: FulfillmentStage;
  exceptionFlag?: ExceptionFlag;
  agreedQuantity?: number;
  dispatchedQuantity?: number;
  unitSymbol?: string;
  lastUpdated?: string;
}

export interface StageStep {
  key: FulfillmentStage;
  label: string;
  description: string;
  icon: React.ElementType;
}

const STAGES: StageStep[] = [
  {
    key: 'Booked',
    label: 'Booked',
    description: 'Booking ID generated & contract locked',
    icon: FileCheck2,
  },
  {
    key: 'Dispatch Planned',
    label: 'Dispatch Planned',
    description: 'Seller preparing lot & vehicle loading',
    icon: PackageCheck,
  },
  {
    key: 'Dispatched',
    label: 'Dispatched',
    description: 'Truck loaded & LR document issued',
    icon: Truck,
  },
  {
    key: 'In Transit',
    label: 'In Transit',
    description: 'Shipment moving to destination',
    icon: MapPin,
  },
  {
    key: 'Delivered',
    label: 'Delivered',
    description: 'Buyer received & verified shipment',
    icon: CheckCircle2,
  },
  {
    key: 'Completed',
    label: 'Completed',
    description: 'Transaction settled & closed',
    icon: Sparkles,
  },
];

export function LogisticsTracker({
  bookingReference,
  fulfillmentStage,
  exceptionFlag,
  agreedQuantity = 0,
  dispatchedQuantity = 0,
  unitSymbol = 'MT',
  lastUpdated,
}: LogisticsTrackerProps) {
  // Determine current active step index (0 to 5)
  const activeStepIndex = Math.max(
    0,
    STAGES.findIndex((s) => s.key === fulfillmentStage)
  );

  // Partial fulfillment calculation
  const isPartialFulfillment = dispatchedQuantity > 0 && agreedQuantity > 0 && dispatchedQuantity < agreedQuantity;
  const dispatchPercent = agreedQuantity > 0 ? Math.min(100, Math.round((dispatchedQuantity / agreedQuantity) * 100)) : 0;

  return (
    <Card className="border-slate-200/80 bg-white shadow-xs text-slate-900 w-full overflow-hidden">
      {/* HEADER */}
      <CardHeader className="bg-slate-900 text-white pb-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <Badge className="bg-[#0D9488] text-white text-[10px] font-bold uppercase tracking-wider px-2 py-0.5">
                Logistics State Engine
              </Badge>
              <span className="text-xs font-mono text-teal-400 font-bold">{bookingReference}</span>
            </div>
            <CardTitle className="text-base sm:text-lg font-bold flex items-center gap-2 text-white">
              <Truck className="w-5 h-5 text-teal-400" />
              Physical Fulfillment & Dispatch Tracker
            </CardTitle>
            <CardDescription className="text-xs text-slate-400">
              PRD v2.2 real-time order lifecycle tracking from booking to settlement.
            </CardDescription>
          </div>

          {/* EXCEPTION FLAG BADGES */}
          <div className="flex flex-wrap items-center gap-2 self-start sm:self-auto">
            {exceptionFlag === 'Disputed' && (
              <Badge className="bg-rose-500/20 text-rose-300 border-rose-400/40 text-xs font-bold px-3 py-1 flex items-center gap-1.5 animate-pulse">
                <ShieldAlert className="w-3.5 h-3.5 text-rose-400" />
                Active Dispute
              </Badge>
            )}

            {exceptionFlag === 'Delayed' && (
              <Badge className="bg-amber-500/20 text-amber-300 border-amber-400/40 text-xs font-bold px-3 py-1 flex items-center gap-1.5">
                <Clock className="w-3.5 h-3.5 text-amber-400" />
                Transit Delay
              </Badge>
            )}

            {exceptionFlag === 'Cancelled' && (
              <Badge className="bg-red-500/20 text-red-300 border-red-400/40 text-xs font-bold px-3 py-1 flex items-center gap-1.5">
                <XCircle className="w-3.5 h-3.5 text-red-400" />
                Order Cancelled
              </Badge>
            )}

            {(exceptionFlag === 'Partially Fulfilled' || isPartialFulfillment) && (
              <Badge className="bg-teal-500/20 text-teal-300 border-teal-400/40 text-xs font-mono font-bold px-3 py-1 flex items-center gap-1.5">
                <PackageCheck className="w-3.5 h-3.5 text-teal-400" />
                Partial: {dispatchedQuantity} / {agreedQuantity} {unitSymbol} ({dispatchPercent}%)
              </Badge>
            )}

            {!exceptionFlag && !isPartialFulfillment && (
              <Badge className="bg-emerald-500/20 text-emerald-300 border-emerald-400/40 text-xs font-mono font-bold px-3 py-1">
                Stage {activeStepIndex + 1}/6: {fulfillmentStage}
              </Badge>
            )}
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-6 space-y-6">
        {/* PARTIAL FULFILLMENT PROGRESS BAR (IF APPLICABLE) */}
        {agreedQuantity > 0 && (
          <div className="bg-slate-50 border border-slate-200/80 rounded-xl p-3.5 sm:p-4 space-y-2">
            <div className="flex items-center justify-between text-xs">
              <span className="font-bold text-slate-800 flex items-center gap-1.5">
                <PackageCheck className="w-4 h-4 text-[#0D9488]" />
                Dispatch Fulfillment Quantity Progress
              </span>
              <span className="font-mono font-bold text-teal-800">
                {dispatchedQuantity} {unitSymbol} of {agreedQuantity} {unitSymbol} ({dispatchPercent}%)
              </span>
            </div>
            <div className="w-full bg-slate-200 rounded-full h-2.5 overflow-hidden">
              <div
                className="bg-[#0D9488] h-2.5 rounded-full transition-all duration-500"
                style={{ width: `${dispatchPercent}%` }}
              ></div>
            </div>
            <p className="text-[11px] text-slate-500">
              {dispatchPercent === 100
                ? '100% full quantity has been dispatched by seller.'
                : isPartialFulfillment
                ? `${agreedQuantity - dispatchedQuantity} ${unitSymbol} remaining to be dispatched.`
                : 'Awaiting initial seller vehicle dispatch.'}
            </p>
          </div>
        )}

        {/* DESKTOP HORIZONTAL STEPPER (HIDDEN ON MOBILE) */}
        <div className="hidden lg:block pt-2">
          <div className="relative flex items-center justify-between w-full">
            {/* Background connecting bar */}
            <div className="absolute top-1/2 left-0 right-0 h-1 bg-slate-200 -translate-y-1/2 z-0"></div>

            {/* Active connecting bar */}
            <div
              className="absolute top-1/2 left-0 h-1 bg-[#0D9488] -translate-y-1/2 z-0 transition-all duration-500"
              style={{
                width: `${(activeStepIndex / (STAGES.length - 1)) * 100}%`,
              }}
            ></div>

            {STAGES.map((stage, index) => {
              const IconComponent = stage.icon;
              const isPassed = index < activeStepIndex;
              const isActive = index === activeStepIndex;
              const isFuture = index > activeStepIndex;

              return (
                <div
                  key={stage.key}
                  className="relative z-10 flex flex-col items-center group text-center max-w-[140px]"
                >
                  <div
                    className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm transition-all shadow-xs ${
                      isPassed
                        ? 'bg-[#0D9488] text-white'
                        : isActive
                        ? 'bg-[#0D9488] text-white ring-4 ring-teal-100 shadow-md scale-110'
                        : 'bg-white text-slate-400 border-2 border-slate-300'
                    }`}
                  >
                    {isPassed ? (
                      <CheckCircle2 className="w-5 h-5 text-white" />
                    ) : (
                      <IconComponent className="w-5 h-5" />
                    )}
                  </div>

                  <span
                    className={`text-xs font-bold mt-2 ${
                      isActive
                        ? 'text-[#0D9488]'
                        : isPassed
                        ? 'text-slate-800'
                        : 'text-slate-400'
                    }`}
                  >
                    {stage.label}
                  </span>

                  <span className="text-[10px] text-slate-500 mt-0.5 line-clamp-2 leading-tight">
                    {stage.description}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* MOBILE VERTICAL STEPPER (360px VIEWPORT COMPLIANT) */}
        <div className="block lg:hidden space-y-3">
          <h4 className="text-xs font-bold uppercase tracking-wider text-slate-700 mb-2">
            Fulfillment Lifecycle Stages
          </h4>

          <div className="space-y-2.5 relative pl-2">
            {STAGES.map((stage, index) => {
              const IconComponent = stage.icon;
              const isPassed = index < activeStepIndex;
              const isActive = index === activeStepIndex;

              return (
                <div
                  key={stage.key}
                  className={`p-3 rounded-xl border flex items-start gap-3 transition-all ${
                    isActive
                      ? 'bg-teal-50/80 border-[#0D9488] shadow-xs'
                      : isPassed
                      ? 'bg-slate-50/80 border-slate-200'
                      : 'bg-white border-slate-200/60 opacity-60'
                  }`}
                >
                  <div
                    className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 mt-0.5 font-bold ${
                      isActive
                        ? 'bg-[#0D9488] text-white'
                        : isPassed
                        ? 'bg-teal-100 text-teal-800'
                        : 'bg-slate-100 text-slate-400'
                    }`}
                  >
                    {isPassed ? (
                      <CheckCircle2 className="w-4 h-4" />
                    ) : (
                      <IconComponent className="w-4 h-4" />
                    )}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-2">
                      <span
                        className={`text-xs font-bold ${
                          isActive
                            ? 'text-[#0D9488]'
                            : isPassed
                            ? 'text-slate-900'
                            : 'text-slate-500'
                        }`}
                      >
                        {stage.label}
                      </span>
                      {isActive && (
                        <Badge className="bg-[#0D9488] text-white text-[9px] font-bold px-2 py-0">
                          Active Stage
                        </Badge>
                      )}
                    </div>
                    <p className="text-[11px] text-slate-600 mt-0.5 leading-snug">
                      {stage.description}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
