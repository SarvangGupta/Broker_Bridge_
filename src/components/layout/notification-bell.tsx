"use client";

import * as React from "react";
import Link from "next/link";
import {
  Bell,
  Handshake,
  Sparkles,
  MessageSquare,
  Info,
  CheckCheck,
  Loader2,
  ExternalLink,
  Flame,
  AlertCircle,
  Clock,
  Truck,
  Wallet,
  FileCheck2,
  FileWarning,
  ArrowRight,
  ShieldCheck,
} from "lucide-react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { formatDistanceToNow } from "date-fns";
import { useRouter } from "next/navigation";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Button } from "@/components/ui/button";
import {
  getInAppNotificationsAction,
  markAsReadAction,
  markAllAsReadAction,
} from "@/src/server/actions/notification-actions";
import { cn } from "@/lib/utils";

function getEventMeta(eventType: string) {
  switch (eventType) {
    case "FINAL_CONFIRMATION_REQUIRED":
      return {
        icon: Flame,
        color: "text-red-600 bg-red-50 border-red-200",
      };
    case "AVAILABILITY_REJECTED":
    case "AVAILABILITY_EXPIRED":
      return {
        icon: AlertCircle,
        color: "text-red-600 bg-red-50 border-red-200",
      };
    case "DOCUMENT_ISSUE":
      return {
        icon: FileWarning,
        color: "text-red-600 bg-red-50 border-red-200",
      };
    case "AVAILABILITY_EXPIRING":
      return {
        icon: Clock,
        color: "text-amber-600 bg-amber-50 border-amber-200",
      };
    case "BROKER_COUNTER":
      return {
        icon: MessageSquare,
        color: "text-amber-600 bg-amber-50 border-amber-200",
      };
    case "LOADING_REMINDER":
    case "DISPATCH_REMINDER":
      return {
        icon: Truck,
        color: "text-amber-600 bg-amber-50 border-amber-200",
      };
    case "QUALITY_REVIEW":
    case "LAB_UPDATE":
      return {
        icon: FileCheck2,
        color: "text-amber-600 bg-amber-50 border-amber-200",
      };
    case "AVAILABILITY_APPROVED":
    case "CONFIRMATION_OUTCOME":
    case "BOOKING_CREATED":
      return {
        icon: Handshake,
        color: "text-emerald-600 bg-emerald-50 border-emerald-200",
      };
    case "PAYMENT_UPDATE":
      return {
        icon: Wallet,
        color: "text-emerald-600 bg-emerald-50 border-emerald-200",
      };
    case "NEW_BROKER_REQUEST":
    case "DEAL_VERSION_UPDATE":
    case "MATCH_CREATED":
    case "MATCH_UPDATED":
      return {
        icon: Sparkles,
        color: "text-blue-600 bg-blue-50 border-blue-200",
      };
    default:
      return {
        icon: Bell,
        color: "text-slate-600 bg-slate-50 border-slate-200",
      };
  }
}

export function NotificationBell({ className }: { className?: string }) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [isOpen, setIsOpen] = React.useState(false);

  // 1. TanStack Query for polling in-app notifications
  const { data, isLoading } = useQuery({
    queryKey: ["in-app-notifications"],
    queryFn: async () => {
      const res = await getInAppNotificationsAction();
      return res.success && res.data
        ? res.data
        : { notifications: [], unreadCount: 0 };
    },
    refetchInterval: 15000,
    staleTime: 10000,
  });

  const notifications = data?.notifications || [];
  const unreadCount = data?.unreadCount || 0;

  // 2. Mutation for Mark As Read
  const markReadMutation = useMutation({
    mutationFn: async (id: string) => {
      await markAsReadAction(id);
    },
    onMutate: async (id: string) => {
      await queryClient.cancelQueries({ queryKey: ["in-app-notifications"] });
      const previous = queryClient.getQueryData<any>(["in-app-notifications"]);

      if (previous) {
        queryClient.setQueryData(["in-app-notifications"], {
          ...previous,
          notifications: previous.notifications.map((n: any) =>
            n.id === id ? { ...n, isRead: true, readAt: new Date() } : n
          ),
          unreadCount: Math.max(0, previous.unreadCount - 1),
        });
      }
      return { previous };
    },
    onError: (_err, _id, context) => {
      if (context?.previous) {
        queryClient.setQueryData(["in-app-notifications"], context.previous);
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["in-app-notifications"] });
    },
  });

  // 3. Mutation for Mark All As Read
  const markAllMutation = useMutation({
    mutationFn: async () => {
      await markAllAsReadAction();
    },
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey: ["in-app-notifications"] });
      const previous = queryClient.getQueryData<any>(["in-app-notifications"]);

      if (previous) {
        queryClient.setQueryData(["in-app-notifications"], {
          ...previous,
          notifications: previous.notifications.map((n: any) => ({
            ...n,
            isRead: true,
            readAt: new Date(),
          })),
          unreadCount: 0,
        });
      }
      return { previous };
    },
    onError: (_err, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(["in-app-notifications"], context.previous);
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["in-app-notifications"] });
    },
  });

  const handleNotificationClick = (item: any) => {
    if (!item.isRead && !item.readAt) {
      markReadMutation.mutate(item.id);
    }

    setIsOpen(false);
    const targetUrl = item.actionUrl || item.payload?.action_url || "/seller";
    router.push(targetUrl);
  };

  return (
    <Popover open={isOpen} onOpenChange={setIsOpen}>
      <PopoverTrigger
        render={
          <Button
            variant="ghost"
            size="icon"
            className={cn(
              "relative h-9 w-9 rounded-full text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors focus-visible:ring-1 focus-visible:ring-slate-400",
              className
            )}
            aria-label="Notifications"
          />
        }
      >
        <Bell className="h-4 w-4" />
        {unreadCount > 0 && (
          <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-emerald-600 px-1 text-[10px] font-black text-white shadow-xs animate-in zoom-in-50 duration-200">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        )}
      </PopoverTrigger>

      <PopoverContent
        align="end"
        sideOffset={8}
        className="w-80 sm:w-96 p-0 shadow-xl border border-slate-200/90 rounded-2xl overflow-hidden bg-white z-50"
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-100 bg-slate-50/70">
          <div className="flex items-center gap-2">
            <span className="text-sm font-extrabold text-slate-900 tracking-tight">
              Action Alerts
            </span>
            {unreadCount > 0 && (
              <span className="px-2 py-0.5 text-[10px] font-black bg-emerald-100 text-emerald-800 rounded-full">
                {unreadCount} unread
              </span>
            )}
          </div>
          {unreadCount > 0 && (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => markAllMutation.mutate()}
              disabled={markAllMutation.isPending}
              className="h-7 px-2 text-xs text-slate-500 hover:text-slate-900 hover:bg-slate-200/50 font-bold"
            >
              <CheckCheck className="h-3.5 w-3.5 mr-1" />
              Mark all read
            </Button>
          )}
        </div>

        {/* Content List (Top 5 items) */}
        <div className="max-h-[360px] overflow-y-auto divide-y divide-slate-100 scrollbar-thin">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center py-10 text-slate-400 gap-2">
              <Loader2 className="h-5 w-5 animate-spin text-emerald-600" />
              <span className="text-xs font-semibold">Loading action alerts...</span>
            </div>
          ) : notifications.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-10 px-4 text-center space-y-2">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600">
                <Bell className="h-5 w-5 stroke-[1.75]" />
              </div>
              <p className="text-sm font-bold text-slate-800">All caught up!</p>
              <p className="text-xs text-slate-400 max-w-xs">
                No pending operational alerts requiring your action.
              </p>
            </div>
          ) : (
            notifications.slice(0, 5).map((item: any) => {
              const meta = getEventMeta(item.eventType);
              const Icon = meta.icon;
              const isUnread = !item.isRead && !item.readAt;

              return (
                <div
                  key={item.id}
                  onClick={() => handleNotificationClick(item)}
                  className={cn(
                    "flex items-start gap-3 p-3.5 transition-colors cursor-pointer text-left hover:bg-slate-50 relative group",
                    isUnread ? "bg-emerald-50/20" : "bg-white"
                  )}
                >
                  {/* Category Icon */}
                  <div
                    className={cn(
                      "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border mt-0.5",
                      meta.color
                    )}
                  >
                    <Icon className="h-4 w-4 stroke-[2]" />
                  </div>

                  {/* Operational Summary */}
                  <div className="flex-1 min-w-0 pr-1 space-y-0.5">
                    <div className="flex items-center justify-between gap-1">
                      <p
                        className={cn(
                          "text-xs font-bold truncate leading-tight",
                          isUnread ? "text-slate-900" : "text-slate-700"
                        )}
                      >
                        {item.title}
                      </p>
                      <span className="text-[10px] text-slate-400 shrink-0 font-medium">
                        {item.createdAt
                          ? formatDistanceToNow(new Date(item.createdAt), {
                              addSuffix: false,
                            })
                          : ""}
                      </span>
                    </div>

                    <p className="text-[11px] text-slate-500 line-clamp-2 leading-relaxed">
                      {item.contextReason || item.message}
                    </p>

                    <div className="pt-1 flex items-center gap-1 text-[11px] font-bold text-emerald-700 group-hover:text-emerald-800">
                      <span>{item.actionLabel || "View Details"}</span>
                      <ArrowRight className="w-3 h-3 group-hover:translate-x-0.5 transition-transform" />
                    </div>
                  </div>

                  {/* Unread indicator dot */}
                  {isUnread && (
                    <span className="h-2 w-2 rounded-full bg-emerald-600 shrink-0 self-center" />
                  )}
                </div>
              );
            })
          )}
        </div>

        {/* Footer Link to Action Center */}
        <div className="p-2.5 border-t border-slate-100 bg-slate-50/80">
          <Link
            href="/seller/notifications"
            onClick={() => setIsOpen(false)}
            className="block"
          >
            <Button
              variant="outline"
              size="sm"
              className="w-full h-9 rounded-xl border-slate-200 text-slate-800 hover:text-slate-900 font-bold text-xs justify-center gap-1.5 shadow-2xs"
            >
              <span>View All in Action Center</span>
              <ArrowRight className="w-3.5 h-3.5 text-slate-400" />
            </Button>
          </Link>
        </div>
      </PopoverContent>
    </Popover>
  );
}
