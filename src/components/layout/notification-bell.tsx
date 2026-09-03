'use client'

import * as React from 'react'
import { Bell, Handshake, Sparkles, MessageSquare, Info, CheckCheck, Loader2, ExternalLink } from 'lucide-react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { formatDistanceToNow } from 'date-fns'
import { useRouter } from 'next/navigation'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import { Button } from '@/components/ui/button'
import {
  getInAppNotificationsAction,
  markAsReadAction,
  markAllAsReadAction,
} from '@/src/server/actions/notification-actions'
import { cn } from '@/lib/utils'

function getEventIcon(eventType: string) {
  switch (eventType) {
    case 'DEAL_CREATED':
    case 'DEAL_UPDATED':
      return <Handshake className="h-4 w-4 text-emerald-600" />
    case 'MATCH_CREATED':
    case 'MATCH_UPDATED':
      return <Sparkles className="h-4 w-4 text-amber-600" />
    case 'NEGOTIATION_RECEIVED':
    case 'NEGOTIATION_ACCEPTED':
      return <MessageSquare className="h-4 w-4 text-blue-600" />
    default:
      return <Info className="h-4 w-4 text-slate-600" />
  }
}

function getEventBadgeBg(eventType: string) {
  switch (eventType) {
    case 'DEAL_CREATED':
    case 'DEAL_UPDATED':
      return 'bg-emerald-50 border-emerald-100'
    case 'MATCH_CREATED':
    case 'MATCH_UPDATED':
      return 'bg-amber-50 border-amber-100'
    case 'NEGOTIATION_RECEIVED':
    case 'NEGOTIATION_ACCEPTED':
      return 'bg-blue-50 border-blue-100'
    default:
      return 'bg-slate-50 border-slate-200'
  }
}

export function NotificationBell({ className }: { className?: string }) {
  const router = useRouter()
  const queryClient = useQueryClient()
  const [isOpen, setIsOpen] = React.useState(false)

  // 1. TanStack Query for polling in-app notifications
  const { data, isLoading } = useQuery({
    queryKey: ['in-app-notifications'],
    queryFn: async () => {
      const res = await getInAppNotificationsAction()
      return res.success && res.data ? res.data : { notifications: [], unreadCount: 0 }
    },
    refetchInterval: 15000,
    staleTime: 10000,
  })

  const notifications = data?.notifications || []
  const unreadCount = data?.unreadCount || 0

  // 2. Mutation for Mark As Read
  const markReadMutation = useMutation({
    mutationFn: async (id: string) => {
      await markAsReadAction(id)
    },
    onMutate: async (id: string) => {
      await queryClient.cancelQueries({ queryKey: ['in-app-notifications'] })
      const previous = queryClient.getQueryData<any>(['in-app-notifications'])

      if (previous) {
        queryClient.setQueryData(['in-app-notifications'], {
          ...previous,
          notifications: previous.notifications.map((n: any) =>
            n.id === id ? { ...n, readAt: new Date() } : n
          ),
          unreadCount: Math.max(0, previous.unreadCount - 1),
        })
      }
      return { previous }
    },
    onError: (_err, _id, context) => {
      if (context?.previous) {
        queryClient.setQueryData(['in-app-notifications'], context.previous)
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['in-app-notifications'] })
    },
  })

  // 3. Mutation for Mark All As Read
  const markAllMutation = useMutation({
    mutationFn: async () => {
      await markAllAsReadAction()
    },
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey: ['in-app-notifications'] })
      const previous = queryClient.getQueryData<any>(['in-app-notifications'])

      if (previous) {
        queryClient.setQueryData(['in-app-notifications'], {
          ...previous,
          notifications: previous.notifications.map((n: any) => ({
            ...n,
            readAt: new Date(),
          })),
          unreadCount: 0,
        })
      }
      return { previous }
    },
    onError: (_err, _variables, context) => {
      if (context?.previous) {
        queryClient.setQueryData(['in-app-notifications'], context.previous)
      }
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['in-app-notifications'] })
    },
  })

  const handleNotificationClick = (item: any) => {
    if (!item.readAt) {
      markReadMutation.mutate(item.id)
    }

    setIsOpen(false)
    const targetUrl =
      item.actionUrl ||
      item.payload?.action_url ||
      item.payload?.url ||
      (item.payload?.requestId ? `/seller/requests?requestId=${item.payload.requestId}` : null) ||
      (item.payload?.dealId ? '/deals' : null)

    if (targetUrl) {
      router.push(targetUrl)
    }
  }

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
          <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-rose-500 px-1 text-[10px] font-bold text-white shadow-xs animate-in zoom-in-50 duration-200">
            {unreadCount > 9 ? '9+' : unreadCount}
          </span>
        )}
      </PopoverTrigger>

      <PopoverContent
        align="end"
        sideOffset={8}
        className="w-80 sm:w-96 p-0 shadow-lg border border-slate-200/90 rounded-xl overflow-hidden bg-white"
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-100 bg-slate-50/50">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-slate-900">Notifications</span>
            {unreadCount > 0 && (
              <span className="px-1.5 py-0.5 text-[11px] font-medium bg-rose-50 text-rose-600 rounded-full border border-rose-200/60">
                {unreadCount} new
              </span>
            )}
          </div>
          {unreadCount > 0 && (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => markAllMutation.mutate()}
              disabled={markAllMutation.isPending}
              className="h-7 px-2 text-xs text-slate-500 hover:text-slate-900 hover:bg-slate-100 font-medium"
            >
              <CheckCheck className="h-3.5 w-3.5 mr-1" />
              Mark all as read
            </Button>
          )}
        </div>

        {/* Content List */}
        <div className="max-h-[380px] overflow-y-auto divide-y divide-slate-100 scrollbar-thin">
          {isLoading ? (
            <div className="flex flex-col items-center justify-center py-8 text-slate-400 gap-2">
              <Loader2 className="h-5 w-5 animate-spin text-slate-400" />
              <span className="text-xs">Loading notifications...</span>
            </div>
          ) : notifications.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-10 px-4 text-center">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-slate-100 text-slate-400 mb-2">
                <Bell className="h-5 w-5" />
              </div>
              <p className="text-sm font-medium text-slate-800">All caught up!</p>
              <p className="text-xs text-slate-400 mt-0.5">No new notifications right now.</p>
            </div>
          ) : (
            notifications.map((item: any) => {
              const isUnread = !item.readAt
              return (
                <div
                  key={item.id}
                  onClick={() => handleNotificationClick(item)}
                  className={cn(
                    "flex items-start gap-3 p-3.5 transition-colors cursor-pointer text-left hover:bg-slate-50/80 relative",
                    isUnread ? "bg-blue-50/25" : "bg-white"
                  )}
                >
                  {/* Event Type Icon Badge */}
                  <div
                    className={cn(
                      "flex h-8 w-8 shrink-0 items-center justify-center rounded-lg border",
                      getEventBadgeBg(item.eventType)
                    )}
                  >
                    {getEventIcon(item.eventType)}
                  </div>

                  {/* Body Text */}
                  <div className="flex-1 min-w-0 pr-2">
                    <div className="flex items-baseline justify-between gap-1">
                      <p className={cn("text-xs font-semibold truncate", isUnread ? "text-slate-900" : "text-slate-700")}>
                        {item.title}
                      </p>
                      <span className="text-[10px] text-slate-400 shrink-0">
                        {item.createdAt ? formatDistanceToNow(new Date(item.createdAt), { addSuffix: true }) : ''}
                      </span>
                    </div>
                    <p className="text-xs text-slate-500 mt-0.5 line-clamp-2 leading-relaxed">
                      {item.message}
                    </p>
                  </div>

                  {/* Unread indicator dot */}
                  {isUnread && (
                    <span className="absolute top-4 right-3 h-2 w-2 rounded-full bg-blue-600" />
                  )}
                </div>
              )
            })
          )}
        </div>
      </PopoverContent>
    </Popover>
  )
}
