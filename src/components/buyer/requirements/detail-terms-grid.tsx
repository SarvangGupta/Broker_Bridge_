'use client'

import React from 'react'
import { format } from 'date-fns'
import { 
  CreditCard, 
  MapPin, 
  Truck, 
  Package, 
  Calendar, 
  UserCheck, 
  FileText, 
  Globe, 
  Lock, 
  ArrowRight,
  Sparkles,
  Info,
  FlaskConical
} from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { cn } from '@/lib/utils'

interface DetailTermsGridProps {
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
      delivery_state_id?: string
      delivery_district_id?: string
      delivery_city_id?: string
      payment_terms?: string
      packaging_type?: string
      freight_terms?: string
      allow_partial_fulfillment?: boolean
    }
    commodityName?: string | null
    gradeName?: string | null
    unitSymbol?: string | null
    brokerName?: string | null
    qualitySpecs?: Array<{
      id: string
      parameterId: string
      targetValue: string | number
      tolerance?: string | number | null
      name: string
      unit?: string | null
      minValue?: string | number | null
      maxValue?: string | number | null
      isRequired?: boolean
    }>
    requiredDocuments?: string[]
  }
}

export function DetailTermsGrid({ data }: DetailTermsGridProps) {
  const req = data.requirement
  const unitLabel = data.unitSymbol || 'Unit'
  const totalBudget = Number(req.quantity || 0) * Number(req.targetPrice || 0)

  // Map status toNext Action badge
  const getNextActionText = (status: string) => {
    const s = (status || '').toLowerCase()
    if (s === 'draft') return 'Awaiting Final Submission'
    if (s === 'open' || s === 'sourcing') return 'Awaiting Broker Match Proposals'
    if (s === 'proposed') return 'Review Broker Proposals'
    if (s === 'negotiating') return 'Negotiating Counter-Offer'
    if (s === 'booked' || s === 'accepted') return 'Order Confirmed — Awaiting Dispatch'
    if (s === 'cancelled') return 'Requirement Cancelled'
    return 'Processing Deal Desk Match'
  }

  return (
    <div className="flex flex-col md:grid md:grid-cols-2 gap-4 w-full">
      {/* LEFT CARD: Commercials & Logistics */}
      <Card className="border-slate-200 shadow-sm bg-white rounded-2xl overflow-hidden">
        <CardHeader className="p-4 pb-3 border-b border-slate-100 bg-slate-50/50">
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-lg bg-sky-50 text-[#0284C7]">
              <CreditCard className="w-4 h-4" />
            </div>
            <CardTitle className="text-sm font-bold text-slate-900">
              Commercial & Freight Terms
            </CardTitle>
          </div>
        </CardHeader>
        <CardContent className="p-4 space-y-4 text-xs">
          {/* Target Price & Budget */}
          <div className="grid grid-cols-2 gap-3 p-3 bg-sky-50/50 rounded-xl border border-sky-100">
            <div>
              <span className="text-[10px] uppercase font-bold text-slate-400 block">Target Price</span>
              <span className="text-sm font-extrabold text-slate-900">
                ₹{req.targetPrice} <span className="text-[11px] font-normal text-slate-500">/{unitLabel}</span>
              </span>
            </div>
            <div>
              <span className="text-[10px] uppercase font-bold text-[#0284C7] block">Indicative Budget</span>
              <span className="text-sm font-extrabold text-[#0284C7]">
                ₹{totalBudget.toLocaleString('en-IN')}
              </span>
            </div>
          </div>

          <div className="space-y-3 divide-y divide-slate-100">
            {/* Delivery Window */}
            <div className="pt-2 flex items-center justify-between">
              <span className="text-slate-500 flex items-center gap-1.5">
                <Calendar className="w-3.5 h-3.5 text-slate-400" />
                Target Date:
              </span>
              <span className="font-bold text-slate-900 text-right">
                {req.targetDate ? format(new Date(req.targetDate), 'PPP') : 'As Agreed'}
              </span>
            </div>

            {/* Freight Model */}
            <div className="pt-2 flex items-center justify-between">
              <span className="text-slate-500 flex items-center gap-1.5">
                <Truck className="w-3.5 h-3.5 text-slate-400" />
                Freight Terms:
              </span>
              <span className="font-bold text-slate-900 text-right">
                {req.freight_terms || req.deliveryTermsId || 'EXW (Ex-Warehouse)'}
              </span>
            </div>

            {/* Payment Terms */}
            <div className="pt-2 flex items-center justify-between">
              <span className="text-slate-500 flex items-center gap-1.5">
                <CreditCard className="w-3.5 h-3.5 text-slate-400" />
                Payment Terms:
              </span>
              <span className="font-bold text-slate-900 text-right truncate max-w-[180px]">
                {req.payment_terms || '100% Advance'}
              </span>
            </div>

            {/* Packaging */}
            <div className="pt-2 flex items-center justify-between">
              <span className="text-slate-500 flex items-center gap-1.5">
                <Package className="w-3.5 h-3.5 text-slate-400" />
                Packaging:
              </span>
              <span className="font-bold text-slate-900 text-right">
                {req.packaging_type || '50kg Bags'}
              </span>
            </div>

            {/* Partial Fulfillment */}
            <div className="pt-2 flex items-center justify-between">
              <span className="text-slate-500 flex items-center gap-1.5">
                <Info className="w-3.5 h-3.5 text-slate-400" />
                Partial Lots:
              </span>
              <span className="font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full text-[11px] border border-emerald-200">
                {req.allow_partial_fulfillment !== false ? 'Allowed' : 'Full Lot Required'}
              </span>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* RIGHT CARD: Broker & Document Workspace */}
      <Card className="border-slate-200 shadow-sm bg-white rounded-2xl overflow-hidden flex flex-col justify-between">
        <div>
          <CardHeader className="p-4 pb-3 border-b border-slate-100 bg-slate-50/50">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="p-2 rounded-lg bg-sky-50 text-[#0284C7]">
                  <UserCheck className="w-4 h-4" />
                </div>
                <CardTitle className="text-sm font-bold text-slate-900">
                  Broker Assignment & Documents
                </CardTitle>
              </div>

              <span className="text-[11px] font-semibold text-[#0284C7] bg-sky-50 px-2 py-0.5 rounded-md border border-sky-100 flex items-center gap-1">
                {req.visibility === 'global' ? <Globe className="w-3 h-3" /> : <Lock className="w-3 h-3" />}
                {req.visibility === 'global' ? 'Global Pool' : 'Private Network'}
              </span>
            </div>
          </CardHeader>

          <CardContent className="p-4 space-y-4 text-xs">
            {/* Active Next Action Card */}
            <div className="p-3 bg-amber-50/70 border border-amber-200 rounded-xl space-y-1">
              <span className="text-[10px] uppercase font-bold text-amber-800 tracking-wider flex items-center gap-1">
                <Sparkles className="w-3 h-3 text-amber-600" />
                Current Action Status
              </span>
              <span className="text-xs font-bold text-amber-900 block">
                {getNextActionText(req.status)}
              </span>
            </div>

            {/* Assigned Broker Details */}
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
              <span className="text-[10px] uppercase font-bold text-slate-400 block">Preferred Broker</span>
              <span className="text-xs font-bold text-slate-900 block">
                {data.brokerName || 'Unassigned — Deal Desk Auto-Assigning'}
              </span>
            </div>

            {/* Mandatory Documents Section (Micro-Sprint 34.3 & 34.4) */}
            <div className="space-y-2 pt-1 flex flex-col w-full max-w-full">
              <div className="flex items-center justify-between flex-wrap gap-1">
                <span className="text-[10px] uppercase font-bold text-slate-500 tracking-wider">
                  Mandatory Fulfillment Documents
                </span>
                <span className="text-[10px] font-semibold text-[#0284C7] bg-sky-50 px-1.5 py-0.5 rounded border border-sky-100 shrink-0">
                  {data.requiredDocuments?.length || 0} Required
                </span>
              </div>

              {data.requiredDocuments && data.requiredDocuments.length > 0 ? (
                <div className="space-y-1.5 flex flex-col w-full">
                  <div className="p-2 rounded-lg bg-sky-50/60 border border-sky-100 text-[11px] text-slate-700 break-words leading-snug">
                    <span className="font-semibold text-[#0284C7]">Required: </span>
                    {data.requiredDocuments.join(', ')}
                  </div>
                  {data.requiredDocuments.map((docName, idx) => (
                    <div
                      key={idx}
                      className="p-2 rounded-lg border border-slate-200 bg-slate-50/70 flex items-center justify-between gap-2 text-xs w-full max-w-full"
                    >
                      <span className="font-semibold text-slate-800 flex items-center gap-1.5 min-w-0 break-words">
                        <FileText className="w-3.5 h-3.5 text-[#0284C7] shrink-0" />
                        <span className="break-words">{docName}</span>
                      </span>
                      <span className="text-[10px] font-semibold text-emerald-700 bg-emerald-50 px-1.5 py-0.5 rounded border border-emerald-200 shrink-0">
                        Gate
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="rounded-xl border border-dashed border-slate-200 p-3 text-center space-y-1 bg-slate-50/40 w-full">
                  <FileText className="w-5 h-5 mx-auto text-slate-400" />
                  <span className="text-[11px] font-semibold text-slate-600 block break-words">
                    Standard Commercial Invoices Apply
                  </span>
                  <p className="text-[10px] text-slate-400 break-words leading-tight">
                    No custom document checklist attached. Standard trade invoices and dispatch bilty will be enforced.
                  </p>
                </div>
              )}
            </div>
          </CardContent>
        </div>
      </Card>

      {/* Quality Specifications Section (Micro-Sprint 34.1, 34.2 & 34.4) */}
      <Card className="border-slate-200 shadow-sm bg-white rounded-2xl overflow-hidden md:col-span-2 w-full max-w-full">
        <CardHeader className="p-4 pb-3 border-b border-slate-100 bg-slate-50/50">
          <div className="flex items-center justify-between flex-wrap gap-2">
            <div className="flex items-center gap-2 min-w-0">
              <div className="p-2 rounded-lg bg-sky-50 text-[#0284C7] shrink-0">
                <FlaskConical className="w-4 h-4" />
              </div>
              <CardTitle className="text-sm font-bold text-slate-900 break-words">
                Quality Specifications (Master-Validated)
              </CardTitle>
            </div>
            <span className="text-[11px] font-semibold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200 shrink-0">
              {data.qualitySpecs && data.qualitySpecs.length > 0 
                ? `${data.qualitySpecs.length} Parameter${data.qualitySpecs.length > 1 ? 's' : ''} Enforced`
                : 'Standard Baseline'}
            </span>
          </div>
        </CardHeader>
        <CardContent className="p-4">
          {data.qualitySpecs && data.qualitySpecs.length > 0 ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3 w-full">
              {data.qualitySpecs.map((spec) => {
                const limitLabel = spec.maxValue 
                  ? `${spec.maxValue}${spec.unit ? ` ${spec.unit}` : ''} Max`
                  : spec.minValue 
                  ? `${spec.minValue}${spec.unit ? ` ${spec.unit}` : ''} Min`
                  : null;

                return (
                  <div
                    key={spec.id}
                    className="p-3 rounded-xl border border-slate-200 bg-slate-50/60 flex flex-col justify-between space-y-2 w-full max-w-full"
                  >
                    <div className="flex items-center justify-between gap-1 text-xs">
                      <span className="font-semibold text-slate-800 break-words">
                        {spec.name}
                      </span>
                      {spec.isRequired && (
                        <span className="text-[10px] text-rose-600 bg-rose-50 px-1.5 py-0.5 rounded font-bold border border-rose-200 shrink-0">
                          Mandatory
                        </span>
                      )}
                    </div>
                    
                    <div className="flex flex-col gap-1 pt-0.5">
                      <div className="flex items-baseline justify-between flex-wrap gap-1">
                        <span className="text-base font-extrabold text-[#0284C7]">
                          {spec.targetValue} <span className="text-xs font-normal text-slate-500">{spec.unit || ''}</span>
                        </span>
                        {limitLabel && (
                          <span className="text-[11px] font-bold text-slate-700 bg-white px-1.5 py-0.5 rounded border border-slate-200 shrink-0">
                            {limitLabel}
                          </span>
                        )}
                      </div>

                      {(spec.minValue !== null && spec.minValue !== undefined || spec.maxValue !== null && spec.maxValue !== undefined) && (
                        <span className="text-[10px] font-medium text-slate-400 break-words">
                          Permissible Range: {spec.minValue ?? '0'} – {spec.maxValue ?? '∞'}{spec.unit ? ` ${spec.unit}` : ''}
                        </span>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="rounded-xl border border-dashed border-slate-200 p-4 text-center space-y-1 bg-slate-50/40 w-full">
              <FlaskConical className="w-5 h-5 mx-auto text-slate-400" />
              <span className="text-xs font-semibold text-slate-700 block">
                Standard Grade Baseline Applied
              </span>
              <p className="text-[11px] text-slate-500 max-w-md mx-auto break-words">
                Default commercial grade specifications for this commodity apply. No customized parameter tolerances were overridden by the buyer.
              </p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
