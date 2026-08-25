'use client'

import { Clock, AlertTriangle, CheckCircle2 } from "lucide-react"
import { useSLA } from "@/src/lib/sla-utils"

interface SlaCountdownProps {
  targetDate: Date | string | null | undefined
  prefix?: string
  className?: string
  compact?: boolean
}

export function SlaCountdown({ targetDate, prefix = "SLA:", className = "", compact = false }: SlaCountdownProps) {
  const { text, isUrgent, isOverdue } = useSLA(targetDate)

  if (!targetDate) return null

  let style = "bg-slate-50 text-slate-600 border-slate-200"
  let Icon = Clock

  if (isOverdue) {
    style = "bg-rose-50 text-rose-700 border-rose-200 font-bold"
    Icon = AlertTriangle
  } else if (isUrgent) {
    style = "bg-amber-50 text-amber-800 border-amber-200 font-semibold"
    Icon = Clock
  }

  return (
    <span
      className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs border ${style} ${className}`}
      title={isOverdue ? "SLA Overdue" : isUrgent ? "Urgent: Less than 24 hours remaining" : "SLA Target"}
    >
      <Icon className={`w-3.5 h-3.5 shrink-0 ${isOverdue ? "text-rose-600 animate-pulse" : isUrgent ? "text-amber-600" : "text-slate-400"}`} />
      <span>{prefix && !compact ? `${prefix} ` : ""}{text}</span>
    </span>
  )
}
