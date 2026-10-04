'use client'

import React from 'react'
import Link from 'next/link'
import { 
  Package, 
  Calendar, 
  MapPin, 
  ArrowRight, 
  Layers, 
  DollarSign, 
  Clock, 
  Eye, 
  XCircle, 
  CheckCircle2,
  FileEdit
} from 'lucide-react'
import { format } from 'date-fns'
import { cn } from '@/lib/utils'

import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { formatBuyerRequirementStatus } from '@/src/lib/utils/status-mappers'

interface RequirementCardProps {
  item: {
    requirement: {
      id: string
      companyId: string
      commodityId: string
      gradeId: string
      quantity: number
      unitId: string
      targetPrice: number
      deliveryTermsId: string
      targetDate: Date | string
      visibility: string
      status: string
      fulfilledQuantity?: number
      createdAt: Date | string
    }
    commodityName?: string | null
    gradeName?: string | null
    unitSymbol?: string | null
    unitName?: string | null
  }
  onCancelRequest?: (id: string, title: string) => void
}

export function RequirementCard({ item, onCancelRequest }: RequirementCardProps) {
  const req = item.requirement
  const statusMeta = formatBuyerRequirementStatus(req.status)
  const isCancellable = ['open', 'sourcing', 'draft'].includes((req.status || '').toLowerCase())
  const isDraft = (req.status || '').toLowerCase() === 'draft'
  const isCancelled = (req.status || '').toLowerCase() === 'cancelled'

  // Calculate 48-hour hide countdown for cancelled items
  const getRemainingHours = () => {
    const timestamp = (req as any).updatedAt || (req as any).updated_at || req.createdAt
    if (!timestamp) return 48
    const elapsedMs = Date.now() - new Date(timestamp).getTime()
    const remainingMs = (48 * 60 * 60 * 1000) - elapsedMs
    return Math.max(0, Math.ceil(remainingMs / (1000 * 60 * 60)))
  }
  const remainingHours = isCancelled ? getRemainingHours() : null

  const formattedDate = req.createdAt ? format(new Date(req.createdAt), 'MMM d, yyyy') : 'Recently'
  const shortId = `REQ-${req.id.substring(0, 8).toUpperCase()}`
  const commodityTitle = `${item.commodityName || 'Commodity'} - ${item.gradeName || 'Standard'}`
  const totalBudget = (Number(req.quantity || 0) * Number(req.targetPrice || 0))

  return (
    <Card className="border-slate-200 shadow-xs hover:shadow-md transition-all duration-200 bg-white rounded-2xl overflow-hidden flex flex-col justify-between">
      <div>
        {/* Header Bar */}
        <CardHeader className="p-4 pb-3 border-b border-slate-100 flex flex-row items-center justify-between space-y-0 bg-slate-50/40">
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-mono font-bold text-slate-500 bg-slate-100 px-2 py-0.5 rounded border border-slate-200">
              {shortId}
            </span>
            <span className="text-xs text-slate-400 font-medium">
              {formattedDate}
            </span>
          </div>

          {/* Status Badge */}
          <div className="flex flex-col items-end gap-1">
            <span className={cn(
              "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border stroke-2",
              statusMeta.badgeClass
            )}>
              <span className={cn("w-1.5 h-1.5 rounded-full", statusMeta.dotClass)} />
              {statusMeta.label}
            </span>
            {isCancelled && (
              <span className="text-[10px] text-slate-500 font-medium flex items-center gap-1">
                <Clock className="w-3 h-3 text-slate-400" />
                Hides in {remainingHours}h
              </span>
            )}
          </div>
        </CardHeader>

        {/* Content Body */}
        <CardContent className="p-4 space-y-3">
          {/* Commodity & Grade Title */}
          <div>
            <h3 className="text-base font-bold text-slate-900 leading-snug line-clamp-1">
              {item.commodityName || 'Unspecified Commodity'}
            </h3>
            <p className="text-xs text-[#0284C7] font-semibold mt-0.5">
              Grade: {item.gradeName || 'Standard Specification'}
            </p>
          </div>

          {/* Key Metrics Grid */}
          <div className="grid grid-cols-2 gap-2 pt-1">
            <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-100 space-y-0.5">
              <span className="text-[10px] uppercase font-bold text-slate-400 tracking-wider block">
                Quantity
              </span>
              <span className="text-sm font-extrabold text-slate-900">
                {req.quantity} <span className="text-xs font-medium text-slate-600">{item.unitSymbol || 'Units'}</span>
              </span>
            </div>

            <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-100 space-y-0.5">
              <span className="text-[10px] uppercase font-bold text-slate-400 tracking-wider block">
                Target Price
              </span>
              <span className="text-sm font-extrabold text-slate-900">
                ₹{req.targetPrice} <span className="text-[11px] font-normal text-slate-500">/{item.unitSymbol || 'unit'}</span>
              </span>
            </div>
          </div>

          {/* Budget & Commercial Info */}
          <div className="flex items-center justify-between pt-1 text-xs border-t border-slate-100 text-slate-600">
            <span className="text-slate-500">Indicative Budget:</span>
            <span className="font-extrabold text-[#0284C7]">
              ₹{totalBudget.toLocaleString('en-IN')}
            </span>
          </div>
        </CardContent>
      </div>

      {/* Action Footer */}
      <div className="p-4 pt-0 flex items-center justify-between gap-2 border-t border-slate-50 mt-2">
        {isCancellable && onCancelRequest ? (
          <Button
            type="button"
            variant="ghost"
            onClick={() => onCancelRequest(req.id, commodityTitle)}
            className="min-h-[48px] px-3 text-xs text-rose-600 hover:text-rose-700 hover:bg-rose-50"
          >
            <XCircle className="w-4 h-4 mr-1 stroke-[2]" />
            Cancel
          </Button>
        ) : (
          <span className="text-[11px] text-slate-400 italic px-2">
            {isCancelled ? 'Cancelled' : 'Locked'}
          </span>
        )}

        <Link
          href={isDraft ? `/buyer/requirements/new?id=${req.id}` : `/buyer/requirements/${req.id}`}
          className="min-h-[48px] px-4 rounded-xl border border-slate-300 hover:border-[#0284C7] bg-white hover:bg-sky-50/50 text-[#0284C7] text-xs font-bold inline-flex items-center justify-center transition-all ml-auto min-w-[120px]"
        >
          {isDraft ? (
            <>
              <FileEdit className="w-4 h-4 mr-1.5" />
              Edit Draft
            </>
          ) : (
            <>
              <Eye className="w-4 h-4 mr-1.5" />
              View Details
            </>
          )}
        </Link>
      </div>
    </Card>
  )
}
