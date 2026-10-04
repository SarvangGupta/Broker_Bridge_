'use client'

import React from 'react'
import { format } from 'date-fns'
import { Package, Layers, Calendar, CheckCircle2, Clock, PieChart, ArrowUpRight } from 'lucide-react'
import { cn } from '@/lib/utils'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { formatBuyerRequirementStatus } from '@/src/lib/utils/status-mappers'

interface DetailFulfillmentCardProps {
  data: {
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
    fulfillment: {
      originalQuantity: number
      bookedQuantity: number
      remainingQuantity: number
      progressPercentage: number
    }
  }
}

export function DetailFulfillmentCard({ data }: DetailFulfillmentCardProps) {
  const req = data.requirement
  const statusMeta = formatBuyerRequirementStatus(req.status)
  const ful = data.fulfillment
  const shortId = `REQ-${req.id.substring(0, 8).toUpperCase()}`
  const unitLabel = data.unitSymbol || 'Units'
  const formattedDate = req.createdAt ? format(new Date(req.createdAt), 'PPP') : 'Recently'

  return (
    <Card className="border-slate-200 shadow-sm bg-white rounded-2xl overflow-hidden">
      {/* Header Banner */}
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50 space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <span className="text-xs font-mono font-bold text-slate-600 bg-white px-2.5 py-1 rounded-md border border-slate-200 shadow-2xs">
              {shortId}
            </span>
            <span className="text-xs text-slate-500 font-medium flex items-center gap-1">
              <Calendar className="w-3.5 h-3.5 opacity-60" />
              {formattedDate}
            </span>
          </div>

          {/* Status Badge */}
          <span className={cn(
            "inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border stroke-2",
            statusMeta.badgeClass
          )}>
            <span className={cn("w-1.5 h-1.5 rounded-full", statusMeta.dotClass)} />
            {statusMeta.label}
          </span>
        </div>

        {/* Commodity Title */}
        <div>
          <h1 className="text-xl sm:text-2xl font-extrabold text-slate-900 tracking-tight leading-tight">
            {data.commodityName || 'Unspecified Commodity'}
          </h1>
          <p className="text-xs sm:text-sm text-[#0284C7] font-semibold mt-0.5 flex items-center gap-1.5">
            <Package className="w-4 h-4 inline stroke-[2]" />
            Grade Specification: {data.gradeName || 'Standard Grade'}
          </p>
        </div>
      </CardHeader>

      {/* Fulfillment Visualizer Body */}
      <CardContent className="p-4 sm:p-5 space-y-5">
        {/* Progress Bar Container */}
        <div className="space-y-2 bg-sky-50/40 p-4 rounded-xl border border-sky-100">
          <div className="flex items-center justify-between text-xs font-bold text-slate-900">
            <span className="flex items-center gap-1.5 text-[#0284C7]">
              <PieChart className="w-4 h-4" />
              Requirement Fulfillment Progress
            </span>
            <span className="text-[#0284C7] font-extrabold">
              {ful.progressPercentage}% Complete
            </span>
          </div>

          <div className="w-full bg-slate-200 rounded-full h-3 overflow-hidden">
            <div 
              className="bg-[#0284C7] h-3 rounded-full transition-all duration-500 ease-out"
              style={{ width: `${ful.progressPercentage}%` }}
            />
          </div>

          <div className="flex justify-between items-center text-[11px] text-slate-500">
            <span>0 {unitLabel}</span>
            <span>{ful.originalQuantity} {unitLabel} Target</span>
          </div>
        </div>

        {/* Explicit 3-Column Math Grid */}
        <div className="overflow-x-auto touch-pan-x">
          <div className="grid grid-cols-3 gap-3 min-w-[320px]">
            {/* 1. Original Quantity */}
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200/80 space-y-1 text-left">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                1. Original Qty
              </span>
              <span className="text-base sm:text-lg font-extrabold text-slate-900 block truncate">
                {ful.originalQuantity.toLocaleString()}
              </span>
              <span className="text-[11px] text-slate-500 font-medium block">
                {unitLabel} Requested
              </span>
            </div>

            {/* 2. Booked Quantity */}
            <div className="p-3.5 rounded-xl bg-emerald-50/60 border border-emerald-200/80 space-y-1 text-left">
              <span className="text-[10px] font-bold text-emerald-700 uppercase tracking-wider block">
                2. Booked Qty
              </span>
              <span className="text-base sm:text-lg font-extrabold text-emerald-800 block truncate">
                {ful.bookedQuantity.toLocaleString()}
              </span>
              <span className="text-[11px] text-emerald-600 font-medium block">
                {unitLabel} Confirmed
              </span>
            </div>

            {/* 3. Remaining Unfulfilled Quantity */}
            <div className="p-3.5 rounded-xl bg-sky-50/60 border border-sky-200/80 space-y-1 text-left">
              <span className="text-[10px] font-bold text-[#0284C7] uppercase tracking-wider block">
                3. Remaining Unfulfilled
              </span>
              <span className="text-base sm:text-lg font-extrabold text-[#0284C7] block truncate">
                {ful.remainingQuantity.toLocaleString()}
              </span>
              <span className="text-[11px] text-sky-700 font-medium block">
                {unitLabel} Pending Match
              </span>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
