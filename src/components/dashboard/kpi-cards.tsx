import * as React from "react"
import { LucideIcon, TrendingUp, TrendingDown } from "lucide-react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { cn, formatIndianCurrency, formatNumber } from "@/lib/utils"

export { formatIndianCurrency, formatNumber }

export interface KpiCardProps {
  title: string
  value: string | number
  icon: LucideIcon
  description?: string
  trend?: string
  trendDirection?: 'up' | 'down' | 'neutral'
  badgeColor?: 'blue' | 'emerald' | 'teal' | 'indigo' | 'amber' | 'slate'
  className?: string
}

const badgeColorStyles: Record<string, { bg: string; text: string; border: string }> = {
  blue: {
    bg: "bg-blue-50/80",
    text: "text-blue-600",
    border: "border-blue-100",
  },
  emerald: {
    bg: "bg-emerald-50/80",
    text: "text-emerald-600",
    border: "border-emerald-100",
  },
  teal: {
    bg: "bg-teal-50/80",
    text: "text-teal-600",
    border: "border-teal-100",
  },
  indigo: {
    bg: "bg-indigo-50/80",
    text: "text-indigo-600",
    border: "border-indigo-100",
  },
  amber: {
    bg: "bg-amber-50/80",
    text: "text-amber-600",
    border: "border-amber-100",
  },
  slate: {
    bg: "bg-slate-100/80",
    text: "text-slate-600",
    border: "border-slate-200/80",
  },
}

export function KpiCard({
  title,
  value,
  icon: Icon,
  description,
  trend,
  trendDirection = 'neutral',
  badgeColor = 'slate',
  className,
}: KpiCardProps) {
  const colorStyle = badgeColorStyles[badgeColor] || badgeColorStyles.slate

  return (
    <Card className={cn(
      "relative overflow-hidden rounded-xl border border-slate-200/80 bg-white/90 shadow-xs hover:shadow-md transition-all duration-200",
      className
    )}>
      <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
        <CardTitle className="text-xs font-semibold uppercase tracking-wider text-slate-500">
          {title}
        </CardTitle>
        <div className={cn(
          "flex h-9 w-9 items-center justify-center rounded-lg border",
          colorStyle.bg,
          colorStyle.text,
          colorStyle.border
        )}>
          <Icon className="h-4 w-4" />
        </div>
      </CardHeader>
      <CardContent className="pt-0">
        <div className="text-2xl font-bold tracking-tight text-slate-900">
          {typeof value === 'number' ? formatNumber(value) : value}
        </div>
        {(description || trend) && (
          <div className="flex items-center gap-1.5 mt-1 text-xs text-slate-500">
            {trend && (
              <span className={cn(
                "inline-flex items-center font-medium gap-0.5",
                trendDirection === 'up' && "text-emerald-600",
                trendDirection === 'down' && "text-rose-600",
                trendDirection === 'neutral' && "text-slate-500"
              )}>
                {trendDirection === 'up' && <TrendingUp className="h-3 w-3" />}
                {trendDirection === 'down' && <TrendingDown className="h-3 w-3" />}
                {trend}
              </span>
            )}
            {description && <span>{description}</span>}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

export function KpiGrid({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={cn("grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-6", className)}>
      {children}
    </div>
  )
}

export function KpiCardSkeleton() {
  return (
    <Card className="rounded-xl border border-slate-200/80 bg-white p-6 shadow-xs animate-pulse">
      <div className="flex items-center justify-between">
        <div className="h-3.5 w-24 bg-slate-200 rounded-md" />
        <div className="h-9 w-9 bg-slate-100 rounded-lg" />
      </div>
      <div className="h-7 w-32 bg-slate-200 rounded-md mt-4" />
      <div className="h-3 w-20 bg-slate-100 rounded-md mt-2" />
    </Card>
  )
}

export function KpiGridSkeleton({ count = 3 }: { count?: number }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-6">
      {Array.from({ length: count }).map((_, idx) => (
        <KpiCardSkeleton key={idx} />
      ))}
    </div>
  )
}
