'use client'

import React, { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { RotateCw, CheckCircle2 } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

interface DataFreshnessProps {
  timestamp?: Date | number | string
  className?: string
  onRefresh?: () => void
}

export function DataFreshness({
  timestamp = new Date(),
  className,
  onRefresh,
}: DataFreshnessProps) {
  const router = useRouter()
  const [isPending, startTransition] = useTransition()
  const [lastRefreshedTime, setLastRefreshedTime] = useState<Date>(
    timestamp instanceof Date ? timestamp : new Date(timestamp)
  )

  const handleRefresh = () => {
    startTransition(() => {
      setLastRefreshedTime(new Date())
      if (onRefresh) {
        onRefresh()
      } else {
        router.refresh()
      }
    })
  }

  // Format time in "HH:MM AM/PM" format
  const formatTime = (date: Date) => {
    try {
      return date.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
      })
    } catch {
      return 'Just now'
    }
  }

  return (
    <div
      className={cn(
        "inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-100/80 border border-slate-200/80 text-xs text-slate-500 select-none shadow-2xs",
        className
      )}
    >
      <div className="flex items-center gap-1.5 font-medium">
        <span className="flex h-2 w-2 rounded-full bg-emerald-500 shrink-0" />
        <span className="text-slate-600">Updated:</span>
        <span className="font-semibold text-slate-800">{formatTime(lastRefreshedTime)}</span>
      </div>

      <button
        type="button"
        onClick={handleRefresh}
        disabled={isPending}
        title="Refresh live data"
        className="p-1 rounded-full text-slate-400 hover:text-slate-700 hover:bg-slate-200/70 transition-colors disabled:opacity-50 cursor-pointer outline-none focus-visible:ring-1 focus-visible:ring-emerald-600"
        aria-label="Refresh workspace data"
      >
        <RotateCw
          className={cn(
            "w-3.5 h-3.5 transition-transform duration-500",
            isPending && "animate-spin text-[#059669]"
          )}
        />
      </button>
    </div>
  )
}
