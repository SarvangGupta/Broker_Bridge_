"use client";

import { useEffect, useState } from "react";
import { format, formatDistanceToNowStrict } from "date-fns";
import {
  History,
  Clock,
  ArrowRight,
  ShieldCheck,
  CheckCircle2,
  XCircle,
  RefreshCw,
  AlertCircle,
  FileText,
  Sparkles,
  ArrowUpDown,
  Building2,
  Calendar,
  Layers,
  Lock,
} from "lucide-react";
import { cn, formatIndianCurrency } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { NegotiationTimelineItem } from "@/src/types/deal-version-schema";
import { getNegotiationTimelineAction } from "@/src/server/actions/version-actions";

interface NegotiationTimelineProps {
  requestId: string;
  className?: string;
  initialEvents?: NegotiationTimelineItem[];
  onRefresh?: () => void;
}

export function NegotiationTimeline({
  requestId,
  className,
  initialEvents,
  onRefresh,
}: NegotiationTimelineProps) {
  const [events, setEvents] = useState<NegotiationTimelineItem[]>(initialEvents || []);
  const [isLoading, setIsLoading] = useState(!initialEvents);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function loadTimeline() {
    if (!requestId) return;
    setIsLoading(true);
    setError(null);
    try {
      const res = await getNegotiationTimelineAction(requestId);
      if (res.success && res.data) {
        setEvents(res.data);
      } else {
        setError(res.error || "Failed to load negotiation timeline.");
      }
    } catch (err: any) {
      setError(err.message || "An unexpected error occurred loading timeline.");
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  }

  useEffect(() => {
    if (!initialEvents) {
      loadTimeline();
    }
  }, [requestId]);

  const handleManualRefresh = () => {
    setIsRefreshing(true);
    loadTimeline();
    if (onRefresh) onRefresh();
  };

  if (isLoading) {
    return (
      <div className={cn("space-y-4 p-4", className)}>
        <div className="flex items-center justify-between mb-2">
          <Skeleton className="h-5 w-40" />
          <Skeleton className="h-4 w-16" />
        </div>
        <div className="space-y-4 pl-4 border-l-2 border-slate-200">
          {[1, 2, 3].map((i) => (
            <div key={i} className="space-y-2 relative">
              <Skeleton className="h-4 w-32" />
              <Skeleton className="h-16 w-full rounded-xl" />
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className={cn("p-4 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs flex items-start gap-2", className)}>
        <AlertCircle className="h-4 w-4 shrink-0 text-rose-600 mt-0.5" />
        <div className="flex-1">
          <p className="font-semibold">Unable to load negotiation history</p>
          <p className="text-rose-600 mt-0.5">{error}</p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={handleManualRefresh}
          className="h-7 text-xs bg-white text-rose-700 border-rose-200 hover:bg-rose-50"
        >
          Retry
        </Button>
      </div>
    );
  }

  if (events.length === 0) {
    return (
      <div className={cn("p-6 text-center rounded-xl bg-slate-50 border border-slate-200/80 text-slate-500", className)}>
        <History className="h-8 w-8 mx-auto mb-2 text-slate-400 stroke-[1.5]" />
        <p className="text-xs font-semibold text-slate-700">No Negotiation Events Yet</p>
        <p className="text-[11px] text-slate-500 mt-0.5">
          Commercial version revisions and counter-offers will appear here in chronological order.
        </p>
      </div>
    );
  }

  return (
    <div className={cn("flex flex-col space-y-4", className)}>
      {/* HEADER & REFRESH BUTTON */}
      <div className="flex items-center justify-between pb-2 border-b border-slate-100">
        <div className="flex items-center gap-2">
          <div className="h-7 w-7 rounded-lg bg-emerald-50 text-emerald-700 flex items-center justify-center">
            <History className="h-4 w-4" />
          </div>
          <div>
            <h4 className="text-xs sm:text-sm font-bold text-slate-900 leading-none">
              Commercial Version History
            </h4>
            <p className="text-[10px] text-slate-500 mt-0.5">
              {events.length} chronological audit {events.length === 1 ? "record" : "records"} (Read-Only)
            </p>
          </div>
        </div>

        <Button
          variant="ghost"
          size="sm"
          onClick={handleManualRefresh}
          disabled={isRefreshing}
          className="h-7 px-2 text-slate-500 hover:text-slate-800 text-[11px] gap-1"
        >
          <RefreshCw className={cn("h-3 w-3", isRefreshing && "animate-spin text-emerald-600")} />
          <span className="hidden sm:inline">Refresh</span>
        </Button>
      </div>

      {/* VERTICAL TIMELINE CONTAINER */}
      <div className="relative pl-6 sm:pl-7 space-y-6 before:absolute before:left-2.5 sm:before:left-3 before:top-2 before:bottom-2 before:w-0.5 before:bg-slate-200">
        {events.map((evt, idx) => {
          const isLast = idx === events.length - 1;
          const isSeller = evt.isSeller;

          // Node Icon & Colors
          let nodeBg = "bg-slate-100 border-slate-300 text-slate-600";
          let badgeVariant = "bg-slate-100 text-slate-700 border-slate-200";

          if (evt.type === "DEAL_VERSION") {
            if (evt.status === "Superseded") {
              nodeBg = "bg-slate-100 border-slate-300 text-slate-400";
              badgeVariant = "bg-slate-100 text-slate-500 border-slate-200 line-through opacity-80";
            } else if (evt.status === "Seller Confirmed" || evt.status === "Accepted") {
              nodeBg = "bg-emerald-500 border-emerald-600 text-white";
              badgeVariant = "bg-emerald-50 text-emerald-800 border-emerald-300 font-bold";
            } else if (evt.status === "Countered") {
              nodeBg = "bg-sky-500 border-sky-600 text-white";
              badgeVariant = "bg-sky-50 text-sky-800 border-sky-300 font-bold";
            } else {
              nodeBg = "bg-indigo-500 border-indigo-600 text-white";
              badgeVariant = "bg-indigo-50 text-indigo-800 border-indigo-300 font-bold";
            }
          } else if (evt.type === "NEGOTIATION_ACTION") {
            if (evt.status === "ACCEPT") {
              nodeBg = "bg-emerald-500 border-emerald-600 text-white";
              badgeVariant = "bg-emerald-50 text-emerald-700 border-emerald-200";
            } else if (evt.status === "REJECT") {
              nodeBg = "bg-rose-500 border-rose-600 text-white";
              badgeVariant = "bg-rose-50 text-rose-700 border-rose-200";
            } else if (evt.status === "COUNTER") {
              nodeBg = "bg-sky-500 border-sky-600 text-white";
              badgeVariant = "bg-sky-50 text-sky-700 border-sky-200";
            }
          }

          return (
            <div key={evt.id} className="relative group">
              {/* TIMELINE CIRCULAR NODE */}
              <div
                className={cn(
                  "absolute -left-6 sm:-left-7 top-1 h-5 w-5 sm:h-6 sm:w-6 rounded-full border-2 flex items-center justify-center text-[10px] font-bold shadow-xs transition-transform duration-200 group-hover:scale-110",
                  nodeBg
                )}
              >
                {evt.versionNumber ? (
                  <span>v{evt.versionNumber}</span>
                ) : evt.status === "ACCEPT" ? (
                  <CheckCircle2 className="h-3 w-3" />
                ) : evt.status === "REJECT" ? (
                  <XCircle className="h-3 w-3" />
                ) : (
                  <ArrowUpDown className="h-3 w-3" />
                )}
              </div>

              {/* TIMELINE CONTENT CARD */}
              <div
                className={cn(
                  "p-3.5 sm:p-4 rounded-xl border text-left transition-all duration-200 shadow-2xs",
                  isLast && evt.status !== "Superseded"
                    ? "bg-emerald-50/20 border-emerald-200 hover:border-emerald-300 hover:shadow-xs"
                    : evt.status === "Superseded"
                    ? "bg-slate-50/60 border-slate-200/60 opacity-80"
                    : "bg-white border-slate-200/90 hover:border-slate-300 hover:shadow-xs"
                )}
              >
                {/* TOP HEADER: Title, Badge, Timestamp */}
                <div className="flex items-start justify-between gap-2 flex-wrap mb-1.5">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <span className="text-xs sm:text-sm font-bold text-slate-900">
                      {evt.title}
                    </span>
                    <Badge variant="outline" className={cn("text-[10px] px-1.5 py-0 rounded", badgeVariant)}>
                      {evt.status}
                    </Badge>
                    {isLast && evt.status !== "Superseded" && (
                      <Badge className="bg-emerald-600 text-white text-[9px] px-1.5 py-0 font-bold">
                        Current Terms
                      </Badge>
                    )}
                  </div>

                  <div className="flex items-center gap-1 text-[11px] text-slate-400 font-medium shrink-0">
                    <Clock className="h-3 w-3" />
                    <span title={format(new Date(evt.createdAt), "PPpp")}>
                      {format(new Date(evt.createdAt), "MMM d, h:mm a")}
                    </span>
                  </div>
                </div>

                {/* ACTOR ATTRIBUTION */}
                <div className="flex items-center gap-1.5 text-[11px] text-slate-500 mb-2">
                  <span
                    className={cn(
                      "font-semibold px-1.5 py-0.2 rounded text-[10px]",
                      isSeller
                        ? "bg-emerald-100/70 text-emerald-800"
                        : "bg-indigo-100/70 text-indigo-800"
                    )}
                  >
                    {evt.actorRole}
                  </span>
                  <span>by</span>
                  <span className="font-semibold text-slate-700">{evt.actorName}</span>
                </div>

                {/* SUMMARY TEXT */}
                <div className="text-xs text-slate-700 bg-white/80 rounded-lg p-2.5 border border-slate-100 font-medium">
                  {evt.summary}
                </div>

                {/* SPECIAL DETAILS (If rejection or counter remarks exist) */}
                {evt.details?.rejectionReason && (
                  <div className="mt-2 text-[11px] bg-rose-50 text-rose-800 border border-rose-100 rounded-md p-2">
                    <span className="font-bold">Rejection Note:</span> {evt.details.rejectionReason}
                  </div>
                )}

                {evt.details?.remarks && evt.details.remarks !== evt.summary && (
                  <div className="mt-2 text-[11px] text-slate-600 bg-slate-50 border border-slate-100 rounded-md p-2">
                    <span className="font-bold">Commercial Note:</span> {evt.details.remarks}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* FOOTER PRIVACY NOTICE */}
      <div className="pt-2 text-[10px] text-slate-400 flex items-center justify-between border-t border-slate-100">
        <span className="flex items-center gap-1">
          <ShieldCheck className="h-3 w-3 text-emerald-600" />
          <span>Broker-Mediated Audit Trail • Zero Buyer Contact Exposure</span>
        </span>
        <span className="flex items-center gap-1 font-mono text-[9px] text-slate-400">
          <Lock className="h-2.5 w-2.5" /> Immutable
        </span>
      </div>
    </div>
  );
}
