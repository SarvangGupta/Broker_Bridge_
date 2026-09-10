"use client";

import React, { useState, useTransition } from "react";
import Link from "next/link";
import { formatDistanceToNow } from "date-fns";
import {
  Bell,
  CheckCheck,
  CheckCircle2,
  AlertCircle,
  AlertTriangle,
  Clock,
  Handshake,
  Sparkles,
  MessageSquare,
  Truck,
  Wallet,
  ShieldCheck,
  FileText,
  FileCheck2,
  ArrowRight,
  ExternalLink,
  Filter,
  RefreshCw,
  Loader2,
  Inbox,
  Flame,
  FileWarning,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";
import type {
  ActionCenterFilter,
  ActionCenterNotificationItem,
} from "@/src/types/notification-schema";
import {
  markNotificationAsReadAction,
  markAllNotificationsAsReadAction,
  getSellerNotificationsAction,
} from "@/src/server/actions/notification-actions";

export interface SellerActionCenterViewProps {
  initialNotifications: ActionCenterNotificationItem[];
  initialCounts: {
    all: number;
    unread: number;
    urgent: number;
    deals: number;
    fulfillment: number;
  };
}

/**
 * Returns appropriate icon, color theme, and category label based on notification eventType.
 */
function getEventMeta(eventType: string) {
  switch (eventType) {
    case "FINAL_CONFIRMATION_REQUIRED":
      return {
        icon: Flame,
        color: "text-red-600 bg-red-50 border-red-200",
        badge: "Urgent Confirmation",
        badgeColor: "bg-red-100 text-red-800 border-red-200",
      };
    case "AVAILABILITY_REJECTED":
    case "AVAILABILITY_EXPIRED":
      return {
        icon: AlertCircle,
        color: "text-red-600 bg-red-50 border-red-200",
        badge: "Lot Inactive",
        badgeColor: "bg-red-100 text-red-800 border-red-200",
      };
    case "DOCUMENT_ISSUE":
      return {
        icon: FileWarning,
        color: "text-red-600 bg-red-50 border-red-200",
        badge: "Document Attention",
        badgeColor: "bg-red-100 text-red-800 border-red-200",
      };
    case "AVAILABILITY_EXPIRING":
      return {
        icon: Clock,
        color: "text-amber-600 bg-amber-50 border-amber-200",
        badge: "Expiring Soon",
        badgeColor: "bg-amber-100 text-amber-800 border-amber-200",
      };
    case "BROKER_COUNTER":
      return {
        icon: MessageSquare,
        color: "text-amber-600 bg-amber-50 border-amber-200",
        badge: "Counter-Proposal",
        badgeColor: "bg-amber-100 text-amber-800 border-amber-200",
      };
    case "LOADING_REMINDER":
    case "DISPATCH_REMINDER":
      return {
        icon: Truck,
        color: "text-amber-600 bg-amber-50 border-amber-200",
        badge: "Logistics Action",
        badgeColor: "bg-amber-100 text-amber-800 border-amber-200",
      };
    case "QUALITY_REVIEW":
    case "LAB_UPDATE":
      return {
        icon: FileCheck2,
        color: "text-amber-600 bg-amber-50 border-amber-200",
        badge: "Quality Review",
        badgeColor: "bg-amber-100 text-amber-800 border-amber-200",
      };
    case "AVAILABILITY_APPROVED":
      return {
        icon: CheckCircle2,
        color: "text-emerald-600 bg-emerald-50 border-emerald-200",
        badge: "Lot Live",
        badgeColor: "bg-emerald-100 text-emerald-800 border-emerald-200",
      };
    case "CONFIRMATION_OUTCOME":
    case "BOOKING_CREATED":
      return {
        icon: Handshake,
        color: "text-emerald-600 bg-emerald-50 border-emerald-200",
        badge: "Trade Booked",
        badgeColor: "bg-emerald-100 text-emerald-800 border-emerald-200",
      };
    case "PAYMENT_UPDATE":
      return {
        icon: Wallet,
        color: "text-emerald-600 bg-emerald-50 border-emerald-200",
        badge: "Payment & Settlement",
        badgeColor: "bg-emerald-100 text-emerald-800 border-emerald-200",
      };
    case "NEW_BROKER_REQUEST":
    case "DEAL_VERSION_UPDATE":
    case "MATCH_CREATED":
    case "MATCH_UPDATED":
      return {
        icon: Sparkles,
        color: "text-blue-600 bg-blue-50 border-blue-200",
        badge: "Commercial Update",
        badgeColor: "bg-blue-100 text-blue-800 border-blue-200",
      };
    default:
      return {
        icon: Bell,
        color: "text-slate-600 bg-slate-50 border-slate-200",
        badge: "System Update",
        badgeColor: "bg-slate-100 text-slate-800 border-slate-200",
      };
  }
}

export function SellerActionCenterView({
  initialNotifications,
  initialCounts,
}: SellerActionCenterViewProps) {
  const [activeTab, setActiveTab] = useState<ActionCenterFilter>("All");
  const [items, setItems] = useState<ActionCenterNotificationItem[]>(initialNotifications);
  const [counts, setCounts] = useState(initialCounts);
  const [isPending, startTransition] = useTransition();

  const handleTabChange = (tab: string) => {
    const filter = tab as ActionCenterFilter;
    setActiveTab(filter);

    startTransition(async () => {
      const res = await getSellerNotificationsAction({ filter });
      if (res.success && res.data) {
        setItems(res.data.notifications);
        setCounts(res.data.counts);
      }
    });
  };

  const handleMarkAsRead = async (id: string) => {
    // Optimistic update
    setItems((prev) =>
      prev.map((item) =>
        item.id === id ? { ...item, isRead: true, readAt: new Date().toISOString() } : item
      )
    );
    setCounts((prev) => ({
      ...prev,
      unread: Math.max(0, prev.unread - 1),
    }));

    try {
      const res = await markNotificationAsReadAction(id);
      if (!res.success) {
        toast.error("Failed to mark notification as read");
      }
    } catch {
      toast.error("Network error marking notification as read");
    }
  };

  const handleMarkAllAsRead = async () => {
    if (counts.unread === 0) return;

    // Optimistic update
    setItems((prev) =>
      prev.map((item) => ({ ...item, isRead: true, readAt: new Date().toISOString() }))
    );
    setCounts((prev) => ({
      ...prev,
      unread: 0,
    }));

    try {
      const res = await markAllNotificationsAsReadAction();
      if (res.success) {
        toast.success("All notifications marked as read");
      } else {
        toast.error(res.error || "Failed to mark all as read");
      }
    } catch {
      toast.error("Network error marking all as read");
    }
  };

  const handleRefresh = () => {
    startTransition(async () => {
      const res = await getSellerNotificationsAction({ filter: activeTab });
      if (res.success && res.data) {
        setItems(res.data.notifications);
        setCounts(res.data.counts);
        toast.success("Action Center refreshed");
      }
    });
  };

  return (
    <div className="space-y-6">
      {/* 1. FILTER TABS & BULK ACTIONS HEADER */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-4 sm:p-5 rounded-2xl border border-slate-200/90 shadow-2xs">
        <Tabs
          value={activeTab}
          onValueChange={handleTabChange}
          className="w-full sm:w-auto"
        >
          <TabsList className="grid grid-cols-2 xs:grid-cols-3 sm:flex sm:flex-wrap h-auto gap-1.5 p-1.5 bg-slate-100/90 rounded-xl">
            <TabsTrigger
              value="All"
              className="rounded-lg text-xs font-bold px-3 py-2 data-[state=active]:bg-white data-[state=active]:text-slate-900 data-[state=active]:shadow-2xs"
            >
              All ({counts.all})
            </TabsTrigger>
            <TabsTrigger
              value="Unread"
              className="rounded-lg text-xs font-bold px-3 py-2 data-[state=active]:bg-white data-[state=active]:text-slate-900 data-[state=active]:shadow-2xs flex items-center gap-1.5"
            >
              <span>Unread</span>
              {counts.unread > 0 && (
                <span className="px-1.5 py-0.5 rounded-full text-[10px] font-black bg-emerald-600 text-white">
                  {counts.unread}
                </span>
              )}
            </TabsTrigger>
            <TabsTrigger
              value="Urgent Action"
              className="rounded-lg text-xs font-bold px-3 py-2 data-[state=active]:bg-white data-[state=active]:text-red-700 data-[state=active]:shadow-2xs flex items-center gap-1.5"
            >
              <Flame className="w-3.5 h-3.5 text-red-500" />
              <span>Urgent</span>
              {counts.urgent > 0 && (
                <span className="px-1.5 py-0.5 rounded-full text-[10px] font-black bg-red-100 text-red-700">
                  {counts.urgent}
                </span>
              )}
            </TabsTrigger>
            <TabsTrigger
              value="Deals & Requests"
              className="rounded-lg text-xs font-bold px-3 py-2 data-[state=active]:bg-white data-[state=active]:text-blue-700 data-[state=active]:shadow-2xs"
            >
              Deals & Requests ({counts.deals})
            </TabsTrigger>
            <TabsTrigger
              value="Fulfillment & Payments"
              className="rounded-lg text-xs font-bold px-3 py-2 data-[state=active]:bg-white data-[state=active]:text-emerald-700 data-[state=active]:shadow-2xs"
            >
              Fulfillment ({counts.fulfillment})
            </TabsTrigger>
          </TabsList>
        </Tabs>

        <div className="flex items-center gap-2 self-end sm:self-auto w-full sm:w-auto justify-end">
          <Button
            variant="outline"
            size="sm"
            onClick={handleRefresh}
            disabled={isPending}
            className="min-h-[44px] h-10 px-3.5 rounded-xl border-slate-200 text-slate-700 font-bold text-xs gap-1.5 cursor-pointer"
          >
            <RefreshCw className={cn("w-3.5 h-3.5", isPending && "animate-spin")} />
            <span className="hidden xs:inline">Refresh</span>
          </Button>

          <Button
            variant="outline"
            size="sm"
            onClick={handleMarkAllAsRead}
            disabled={counts.unread === 0 || isPending}
            className="min-h-[44px] h-10 px-3.5 rounded-xl border-slate-200 text-slate-700 font-bold text-xs gap-1.5 cursor-pointer"
          >
            <CheckCheck className="w-4 h-4 text-slate-600" />
            <span>Mark All Read</span>
          </Button>
        </div>
      </div>

      {/* 2. NOTIFICATIONS LIST CONTAINER */}
      {isPending ? (
        <div className="flex flex-col items-center justify-center py-20 bg-white rounded-3xl border border-slate-200/90 shadow-2xs space-y-3">
          <Loader2 className="w-8 h-8 text-emerald-600 animate-spin" />
          <span className="text-xs text-slate-500 font-semibold tracking-wide">
            Updating Action Center...
          </span>
        </div>
      ) : items.length === 0 ? (
        /* 3. BEAUTIFUL EMPTY STATE */
        <div className="flex flex-col items-center justify-center text-center py-20 px-4 bg-white rounded-3xl border border-slate-200/90 shadow-2xs space-y-4">
          <div className="w-16 h-16 rounded-2xl bg-emerald-50 border border-emerald-100 flex items-center justify-center text-emerald-600 shadow-xs">
            <CheckCircle2 className="w-8 h-8 stroke-[1.75]" />
          </div>
          <div className="space-y-1 max-w-sm">
            <h3 className="text-lg font-extrabold text-slate-900 tracking-tight">
              All caught up!
            </h3>
            <p className="text-xs sm:text-sm text-slate-500 leading-relaxed">
              {activeTab === "Unread"
                ? "No unread operational alerts requiring your attention."
                : activeTab === "Urgent Action"
                ? "No urgent deal confirmations or critical alerts pending."
                : "No operational notifications found in this category."}
            </p>
          </div>
          <Link href="/seller">
            <Button
              variant="outline"
              className="mt-2 h-11 px-5 rounded-xl border-slate-200 text-slate-800 font-bold text-xs"
            >
              Return to Dashboard
            </Button>
          </Link>
        </div>
      ) : (
        /* 4. 3-PART OPERATIONAL NOTIFICATION CARDS */
        <div className="space-y-3.5">
          {items.map((item) => {
            const meta = getEventMeta(item.eventType);
            const Icon = meta.icon;
            const timeAgo = formatDistanceToNow(new Date(item.createdAt), {
              addSuffix: true,
            });

            return (
              <div
                key={item.id}
                className={cn(
                  "group relative bg-white rounded-2xl border transition-all duration-200 p-4 sm:p-5 shadow-2xs hover:shadow-xs",
                  item.isRead
                    ? "border-slate-200/90 bg-white"
                    : "border-emerald-200/90 bg-emerald-50/20 ring-1 ring-emerald-500/10"
                )}
              >
                <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
                  {/* Left: Icon & 3-Part Operational Hierarchy */}
                  <div className="flex items-start gap-3.5">
                    {/* Visual Category Icon */}
                    <div
                      className={cn(
                        "w-10 h-10 sm:w-11 sm:h-11 rounded-xl flex items-center justify-center shrink-0 border mt-0.5",
                        meta.color
                      )}
                    >
                      <Icon className="w-5 h-5 stroke-[2]" />
                    </div>

                    {/* Operational Details */}
                    <div className="space-y-1.5 flex-1 min-w-0">
                      {/* Badge, Category & Time */}
                      <div className="flex flex-wrap items-center gap-2">
                        <Badge
                          variant="outline"
                          className={cn(
                            "text-[10px] font-bold uppercase tracking-wider px-2 py-0.5",
                            meta.badgeColor
                          )}
                        >
                          {meta.badge}
                        </Badge>

                        {!item.isRead && (
                          <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase text-emerald-700 bg-emerald-100/90 px-2 py-0.5 rounded-full">
                            <span className="w-1.5 h-1.5 rounded-full bg-emerald-600 animate-pulse" />
                            New
                          </span>
                        )}

                        <span className="text-[11px] font-medium text-slate-400">
                          {timeAgo}
                        </span>
                      </div>

                      {/* 1. WHAT HAPPENED: Title */}
                      <h4 className="text-sm sm:text-base font-extrabold text-slate-900 tracking-tight leading-snug">
                        {item.title}
                      </h4>

                      {/* 2. WHY IT MATTERS: Context Reason */}
                      <p className="text-xs sm:text-sm text-slate-600 leading-relaxed font-normal">
                        {item.contextReason || item.message}
                      </p>
                    </div>
                  </div>

                  {/* Right / Bottom: 3. WHAT IS THE NEXT ACTION: CTA & Mark Read */}
                  <div className="flex flex-row sm:flex-col items-center sm:items-end justify-between sm:justify-start gap-2.5 pt-3 sm:pt-0 border-t sm:border-t-0 border-slate-100 shrink-0">
                    <Link
                      href={item.actionUrl || "/seller"}
                      onClick={() => !item.isRead && handleMarkAsRead(item.id)}
                      className="w-full sm:w-auto"
                    >
                      <Button
                        size="sm"
                        className="w-full sm:w-auto min-h-[48px] sm:min-h-[40px] px-4 rounded-xl bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs gap-2 shadow-2xs hover:shadow-xs transition-all duration-150"
                      >
                        <span>{item.actionLabel || "View Details"}</span>
                        <ArrowRight className="w-3.5 h-3.5 text-slate-300 group-hover:translate-x-0.5 transition-transform" />
                      </Button>
                    </Link>

                    {!item.isRead && (
                      <button
                        onClick={() => handleMarkAsRead(item.id)}
                        className="text-[11px] font-bold text-slate-500 hover:text-emerald-700 py-1.5 px-2.5 rounded-lg hover:bg-slate-100 transition-colors inline-flex items-center gap-1 shrink-0"
                      >
                        <CheckCheck className="w-3.5 h-3.5" />
                        <span>Mark read</span>
                      </button>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
