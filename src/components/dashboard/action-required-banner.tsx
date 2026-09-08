'use client'

import React from 'react'
import { useRouter } from 'next/navigation'
import {
  AlertCircle,
  Clock,
  Truck,
  ShieldAlert,
  ArrowRight,
  CheckCircle2,
  AlertTriangle,
  Wallet,
  Building2,
  FileCheck2,
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { ActionRequiredItem } from '@/src/server/actions/analytics-actions'

interface ActionRequiredBannerProps {
  actionItems: ActionRequiredItem[]
  onNavigateTab: (tabId: string) => void
}

export function ActionRequiredBanner({
  actionItems,
  onNavigateTab,
}: ActionRequiredBannerProps) {
  const router = useRouter()

  if (!actionItems || actionItems.length === 0) {
    return (
      <div className="w-full p-4 rounded-2xl bg-white border border-slate-200/80 shadow-xs flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-[#ECFDF5] flex items-center justify-center text-[#047857] shrink-0">
            <CheckCircle2 className="w-4 h-4 stroke-[2.25]" />
          </div>
          <div>
            <div className="text-sm font-bold text-slate-900 leading-tight">
              All Tasks Cleared
            </div>
            <div className="text-xs text-slate-500 mt-0.5">
              No urgent actions pending. Inventory, dispatches, and settlements are up to date.
            </div>
          </div>
        </div>
        <Badge
          variant="outline"
          className="hidden sm:inline-flex bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs"
        >
          Operational Normal
        </Badge>
      </div>
    )
  }

  const getAlertIcon = (type: ActionRequiredItem['type']) => {
    switch (type) {
      case 'PAYMENT_OVERDUE':
        return <Wallet className="w-5 h-5 text-rose-600 shrink-0 stroke-[2]" />
      case 'DISPUTE_FILED':
        return <ShieldAlert className="w-5 h-5 text-rose-600 shrink-0 stroke-[2]" />
      case 'DISPATCH_DELAYED':
        return <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 stroke-[2]" />
      case 'DISPATCH_DUE':
        return <Truck className="w-5 h-5 text-amber-600 shrink-0 stroke-[2]" />
      case 'INVENTORY_EXPIRING':
        return <Clock className="w-5 h-5 text-amber-600 shrink-0 stroke-[2]" />
      case 'KYC_PENDING':
        return <Building2 className="w-5 h-5 text-amber-600 shrink-0 stroke-[2]" />
      default:
        return <AlertCircle className="w-5 h-5 text-rose-600 shrink-0 stroke-[2]" />
    }
  }

  const getCardStyle = (severity: ActionRequiredItem['severity']) => {
    if (severity === 'critical') {
      return 'border-rose-200/90 bg-rose-50/50 hover:bg-rose-50/80'
    }
    return 'border-amber-200/90 bg-amber-50/50 hover:bg-amber-50/80'
  }

  const getBadgeStyle = (severity: ActionRequiredItem['severity']) => {
    if (severity === 'critical') {
      return 'bg-rose-100 text-rose-800 border-rose-200'
    }
    return 'bg-amber-100 text-amber-800 border-amber-200'
  }

  const getButtonStyle = (severity: ActionRequiredItem['severity']) => {
    if (severity === 'critical') {
      return 'bg-rose-600 hover:bg-rose-700 text-white shadow-xs'
    }
    return 'bg-amber-600 hover:bg-amber-700 text-white shadow-xs'
  }

  const handleActionClick = (item: ActionRequiredItem) => {
    if (item.targetUrl) {
      router.push(item.targetUrl)
    } else {
      onNavigateTab(item.targetTab)
    }
  }

  return (
    <section aria-label="Action Required Tasks" className="space-y-3">
      <div className="flex items-center justify-between px-1">
        <div className="flex items-center gap-2">
          <span className="flex h-2.5 w-2.5 rounded-full bg-rose-600 animate-pulse" />
          <h2 className="text-xs sm:text-sm font-bold uppercase tracking-wider text-slate-700">
            Priority Action Required ({actionItems.length})
          </h2>
        </div>
        <span className="text-xs text-slate-400 font-medium">
          Time-Sensitive Operational Tasks
        </span>
      </div>

      <div className="grid grid-cols-1 gap-3">
        {actionItems.map((item) => (
          <div
            key={item.id}
            className={`p-4 sm:p-5 rounded-2xl border transition-all duration-150 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 shadow-xs ${getCardStyle(
              item.severity
            )}`}
          >
            <div className="flex items-start gap-3.5 min-w-0">
              <div className="p-2 rounded-xl bg-white shadow-2xs shrink-0 mt-0.5">
                {getAlertIcon(item.type)}
              </div>
              <div className="min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <h3 className="text-sm sm:text-base font-bold text-slate-900 leading-tight">
                    {item.title}
                  </h3>
                  {item.badgeText && (
                    <span
                      className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider border shrink-0 ${getBadgeStyle(
                        item.severity
                      )}`}
                    >
                      {item.badgeText}
                    </span>
                  )}
                </div>
                <p className="text-xs sm:text-sm text-slate-600 mt-1 leading-relaxed">
                  {item.description}
                </p>
              </div>
            </div>

            <Button
              onClick={() => handleActionClick(item)}
              size="sm"
              className={`w-full sm:w-auto shrink-0 font-bold rounded-xl min-h-[48px] px-5 cursor-pointer gap-1.5 ${getButtonStyle(
                item.severity
              )}`}
            >
              <span>{item.actionLabel}</span>
              <ArrowRight className="w-4 h-4" />
            </Button>
          </div>
        ))}
      </div>
    </section>
  )
}
