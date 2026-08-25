import React from "react"
import { BadgeCheck, ShieldCheck, ShieldAlert, ShieldX } from "lucide-react"

interface VerificationBadgeProps {
  className?: string
  compact?: boolean
}

export function VerificationBadge({ className = "", compact = false }: VerificationBadgeProps) {
  return (
    <span
      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-[#EFF6FF] text-[#1D4ED8] border border-blue-200/90 shrink-0 shadow-2xs ${className}`}
      title="Verified Business by BrokerBridge"
    >
      <BadgeCheck className="w-3.5 h-3.5 text-[#1D4ED8] shrink-0" />
      <span>{compact ? "Verified" : "Verified Business"}</span>
    </span>
  )
}

interface TrustScoreProps {
  score?: number | null
  className?: string
  compact?: boolean
}

export function TrustScore({ score = 100, className = "", compact = false }: TrustScoreProps) {
  const safeScore = typeof score === "number" && !isNaN(score) ? Math.max(0, Math.min(100, score)) : 100

  let badgeColor = "bg-emerald-50 text-emerald-700 border-emerald-200/90"
  let Icon = ShieldCheck

  if (safeScore >= 90) {
    badgeColor = "bg-emerald-50 text-emerald-700 border-emerald-200/90"
    Icon = ShieldCheck
  } else if (safeScore >= 70) {
    badgeColor = "bg-amber-50 text-amber-700 border-amber-200/90"
    Icon = ShieldAlert
  } else {
    badgeColor = "bg-rose-50 text-rose-700 border-rose-200/90"
    Icon = ShieldX
  }

  return (
    <span
      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold border shrink-0 ${badgeColor} ${className}`}
      title={`Trust Score: ${safeScore}%`}
    >
      <Icon className="w-3.5 h-3.5 shrink-0" />
      <span>{compact ? `${safeScore}%` : `${safeScore}% Trust Score`}</span>
    </span>
  )
}
