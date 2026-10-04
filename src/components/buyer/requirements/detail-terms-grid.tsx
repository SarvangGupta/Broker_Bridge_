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
  Info
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

            {/* Requirement Documents Workspace Placeholder */}
            <div className="space-y-2 pt-1">
              <span className="text-[10px] uppercase font-bold text-slate-400 tracking-wider flex items-center justify-between">
                <span>Associated Documents</span>
                <span className="text-slate-400 font-normal">Sprint 34 Spec</span>
              </span>

              <div className="rounded-xl border border-dashed border-slate-200 p-3 text-center space-y-1 bg-slate-50/40">
                <FileText className="w-5 h-5 mx-auto text-slate-400" />
                <span className="text-[11px] font-semibold text-slate-600 block">
                  No Quality Documents Uploaded
                </span>
                <p className="text-[10px] text-slate-400">
                  Lab reports & weighbridge slips will attach here after broker proposal.
                </p>
              </div>
            </div>
          </CardContent>
        </div>
      </Card>
    </div>
  )
}
