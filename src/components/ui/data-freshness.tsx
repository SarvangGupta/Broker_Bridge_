'use client'

import React, { useState, useEffect, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { RotateCw } from 'lucide-react'
import { cn } from '@/lib/utils'

interface DataFreshnessProps {
  timestamp?: Date | number | string
  className?: string
  onRefresh?: () => void
}

export function DataFreshness({
  timestamp,
  className,
  onRefresh,
}: DataFreshnessProps) {
  const router = useRouter()
  const [isPending, startTransition] = useTransition()
  const [mounted, setMounted] = useState(false)

  const [initialTime] = useState<Date>(() => {
    if (!timestamp) return new Date()
    return timestamp instanceof Date ? timestamp : new Date(timestamp)
  })

  const [lastRefreshedTime, setLastRefreshedTime] = useState<Date>(initialTime)

  useEffect(() => {
    setMounted(true)
  }, [])

  const handleRefresh = () => {
    startTransition(() => {
      const now = new Date()
      setLastRefreshedTime(now)
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

  const timeToDisplay = mounted ? lastRefreshedTime : initialTime

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
        <span className="font-semibold text-slate-800" suppressHydrationWarning>
          {formatTime(timeToDisplay)}
        </span>
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
