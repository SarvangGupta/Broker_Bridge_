'use client';

import React from 'react';
import {
  FileCheck2,
  Calendar,
  PackageCheck,
  Truck,
  MapPin,
  CheckCircle2,
  ShieldCheck,
  Clock,
  AlertTriangle,
  XCircle,
  AlertOctagon,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

export interface LogisticsTimelineProps {
  status?: string | null;
  bookingId?: string | null;
  className?: string;
}

interface TimelineStage {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
}

/**
 * Micro-Sprint 38.4: Live 6-State Progression
 * Booked → Dispatch Planned → Dispatched → In Transit → Delivered → Completed
 */
const LIVE_STAGES: TimelineStage[] = [
  {
    id: 'booked',
    title: 'Booked',
    subtitle: 'Broker generated ID',
    description: 'Commercial deal finalized and physical Booking ID minted by the Broker desk.',
    icon: FileCheck2,
  },
  {
    id: 'dispatch_planned',
    title: 'Dispatch Planned',
    subtitle: 'Vehicle assigned',
    description: 'Transporter nominated, lorry vehicle assigned, and loading slot scheduled.',
    icon: Calendar,
  },
  {
    id: 'dispatched',
    title: 'Dispatched',
    subtitle: 'Lorry loaded & gate pass',
    description: 'Vehicle loaded, weighbridge verified, and invoice issued at origin facility.',
    icon: PackageCheck,
  },
  {
    id: 'in_transit',
    title: 'In Transit',
    subtitle: 'On-route live tracking',
    description: 'Consignment in transit with verified e-way bill and transporter monitoring.',
    icon: Truck,
  },
  {
    id: 'delivered',
    title: 'Delivered',
    subtitle: 'Unloaded at warehouse',
    description: 'Goods safely reached destination warehouse and unloading commenced.',
    icon: MapPin,
  },
  {
    id: 'completed',
    title: 'Completed',
    subtitle: 'Fulfillment closed',
    description: 'Quality verification finalized and final delivery receipt signed.',
    icon: CheckCircle2,
  },
];

/**
 * Resolves active stage index (0 to 5) based on status string.
 */
function resolveLiveStageIndex(status?: string | null): number {
  if (!status) return 0;
  const s = status.toLowerCase().trim();

  if (s === 'completed' || s.includes('closed') || s.includes('finalized')) return 5;
  if (s === 'delivered') return 4;
  if (s === 'in transit' || s.includes('transit')) return 3;
  if (s === 'dispatched') return 2;
  if (s.includes('dispatch planned') || s.includes('planned')) return 1;
  if (s.includes('booked') || s.includes('confirmed')) return 0;
  if (s.includes('awaiting') || s.includes('pending')) return -1;

  return 0;
}

/**
 * Evaluates exception states (Delayed, Cancelled, Disputed).
 */
function getExceptionState(status?: string | null) {
  if (!status) return null;
  const s = status.toLowerCase().trim();

  if (s.includes('delayed') || s.includes('delay')) {
    return {
      type: 'delayed',
      label: 'Shipment Delayed',
      detail: 'Transporter reported en-route transit delay. Revised ETA in effect.',
      badgeClass: 'bg-amber-100 text-amber-800 border-amber-300',
      icon: AlertTriangle,
    };
  }

  if (s.includes('cancelled') || s.includes('canceled')) {
    return {
      type: 'cancelled',
      label: 'Dispatch Cancelled',
      detail: 'Dispatch booking has been cancelled by the administrative desk.',
      badgeClass: 'bg-red-100 text-red-800 border-red-300',
      icon: XCircle,
    };
  }

  if (s.includes('disputed') || s.includes('dispute')) {
    return {
      type: 'disputed',
      label: 'Consignment Disputed',
      detail: 'An operational discrepancy has been logged. Under broker mediation.',
      badgeClass: 'bg-red-100 text-red-800 border-red-300',
      icon: AlertOctagon,
    };
  }

  return null;
}

/**
 * Task 2 (Micro-Sprint 38.4): Live State Machine Timeline.
 * Renders Booked → Dispatch Planned → Dispatched → In Transit → Delivered → Completed
 * Highlights current and past steps in Ocean Blue (#0284C7).
 * Renders prominent exception badges for Delayed, Cancelled, or Disputed states.
 */
export function LogisticsTimeline({
  status,
  bookingId,
  className,
}: LogisticsTimelineProps) {
  const activeIndex = resolveLiveStageIndex(status);
  const exception = getExceptionState(status);

  return (
    <Card
      className={cn(
        'w-full max-w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xs',
        className
      )}
    >
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 pb-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-sky-50 text-[#0284C7] flex items-center justify-center shrink-0 border border-sky-100">
              <Truck className="w-4 h-4" />
            </div>
            <div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                Physical Fulfillment
              </span>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                Logistics Dispatch Timeline
              </CardTitle>
            </div>
          </div>

          {/* Exception Badge or Normal Status Badge */}
          <div className="flex items-center gap-2">
            {exception ? (
              <Badge
                variant="outline"
                className={cn('text-xs px-2.5 py-0.5 font-bold flex items-center gap-1', exception.badgeClass)}
              >
                <exception.icon className="w-3.5 h-3.5 shrink-0" />
                <span>{exception.label}</span>
              </Badge>
            ) : (
              <Badge
                variant="outline"
                className="w-fit text-xs px-2.5 py-0.5 bg-sky-50 text-[#0284C7] border-sky-200 font-bold"
              >
                {status || 'Booked'}
              </Badge>
            )}
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-6 space-y-6">
        {/* Exception Alert Banner if active */}
        {exception && (
          <div
            className={cn(
              'p-3.5 rounded-xl border flex items-start gap-2.5 text-xs',
              exception.type === 'delayed'
                ? 'bg-amber-50/80 border-amber-200 text-amber-900'
                : 'bg-red-50/80 border-red-200 text-red-900'
            )}
          >
            <exception.icon className="w-4 h-4 shrink-0 mt-0.5" />
            <div>
              <strong className="block font-bold">{exception.label} Exception Logged</strong>
              <p className="text-[11px] leading-relaxed mt-0.5">{exception.detail}</p>
            </div>
          </div>
        )}

        {/* Awaiting Broker Notice if not minted yet */}
        {activeIndex === -1 && !exception && (
          <div className="p-3.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-900 text-xs flex items-center gap-2.5">
            <Clock className="w-4 h-4 text-amber-600 shrink-0" />
            <p className="font-medium">
              Awaiting Broker Finalization: The physical Booking ID will unlock the dispatch workflow upon minting.
            </p>
          </div>
        )}

        {/* Vertical Timeline Stages */}
        <div className="relative pl-2 sm:pl-4 space-y-6">
          {LIVE_STAGES.map((stage, idx) => {
            const isCompleted = activeIndex > idx;
            const isActive = activeIndex === idx;
            const isFuture = activeIndex < idx;
            const isLast = idx === LIVE_STAGES.length - 1;
            const StageIcon = stage.icon;

            return (
              <div key={stage.id} className="relative flex items-start gap-3.5 group">
                {/* Vertical Connector Line */}
                {!isLast && (
                  <div
                    className={cn(
                      'absolute left-[15px] top-[32px] w-0.5 h-[calc(100%+8px)] -translate-x-1/2 transition-colors',
                      isCompleted ? 'bg-[#0284C7]' : 'bg-slate-200'
                    )}
                  />
                )}

                {/* Node Indicator (Past & Current in Ocean Blue #0284C7, Future in Gray) */}
                <div
                  className={cn(
                    'relative z-10 w-8 h-8 rounded-full flex items-center justify-center shrink-0 transition-all shadow-2xs',
                    isCompleted && 'bg-[#0284C7] text-white',
                    isActive &&
                      'bg-[#0284C7] text-white ring-4 ring-sky-100 shadow-sm animate-pulse',
                    isFuture && 'bg-slate-100 text-slate-300 border border-slate-200'
                  )}
                >
                  {isCompleted ? (
                    <CheckCircle2 className="w-4 h-4 text-white" />
                  ) : (
                    <StageIcon className="w-4 h-4" />
                  )}
                </div>

                {/* Stage Content */}
                <div className="flex-1 min-w-0 pt-0.5 pb-2">
                  <div className="flex flex-wrap items-center justify-between gap-1.5 mb-0.5">
                    <div className="flex items-center gap-2">
                      <h4
                        className={cn(
                          'text-xs sm:text-sm font-bold tracking-tight',
                          isActive && 'text-[#0284C7] font-black',
                          isCompleted && 'text-slate-900',
                          isFuture && 'text-slate-400 font-medium'
                        )}
                      >
                        {stage.title}
                      </h4>
                      <span
                        className={cn(
                          'text-[10px] font-semibold px-1.5 py-0.2 rounded',
                          isActive && 'bg-sky-50 text-[#0284C7] border border-sky-200',
                          isCompleted && 'bg-sky-50 text-[#0284C7]',
                          isFuture && 'text-slate-400'
                        )}
                      >
                        ({stage.subtitle})
                      </span>
                    </div>

                    {isActive && (
                      <Badge className="bg-[#0284C7] text-white text-[10px] px-2 py-0 h-5 font-bold">
                        Active Stage
                      </Badge>
                    )}
                    {isCompleted && (
                      <span className="text-[10px] font-bold text-[#0284C7]">
                        Completed
                      </span>
                    )}
                  </div>

                  <p
                    className={cn(
                      'text-xs leading-relaxed',
                      isActive
                        ? 'text-slate-700 font-medium'
                        : isFuture
                        ? 'text-slate-400'
                        : 'text-slate-500'
                    )}
                  >
                    {stage.description}
                  </p>
                </div>
              </div>
            );
          })}
        </div>

        {/* Read-Only Dispatch Transparency Notice */}
        <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/60 flex items-center gap-2.5 text-[11px] text-slate-500">
          <ShieldCheck className="w-4 h-4 text-[#0284C7] shrink-0" />
          <p className="leading-tight">
            Strictly Read-Only Tracking: Physical dispatches and transporter checkpoints are certified by the Broker Desk.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
