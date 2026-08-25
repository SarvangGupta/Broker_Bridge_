'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Loader2, Layers, Building2 } from "lucide-react"
import { format } from "date-fns"

import { getBrokerAssignmentsAction } from "@/src/server/actions/broker-actions"

export function BrokerAssignments({ embedded = false }: { embedded?: boolean }) {
  const [assignments, setAssignments] = useState<any[]>([])
  const [loading, setLoading] = useState(false)

  const loadData = async () => {
    setLoading(true)
    const res = await getBrokerAssignmentsAction()
    
    if (res.success) setAssignments(res.data || [])
    
    setLoading(false)
  }

  useEffect(() => {
    loadData()
  }, [])

  const getStatusBadge = (status: string) => {
    const s = status?.toLowerCase() || ''
    
    if (s.includes('accepted') || s.includes('booked') || s.includes('closed') || s.includes('dispatched')) {
      return (
        <Badge
          variant="outline"
          className="bg-[#ECFDF5] text-[#047857] border-emerald-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full"
        >
          {status}
        </Badge>
      )
    }

    if (s.includes('open') || s.includes('sent')) {
      return (
        <Badge
          variant="outline"
          className="bg-[#EFF6FF] text-[#1D4ED8] border-blue-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full"
        >
          {status}
        </Badge>
      )
    }

    if (s.includes('countered')) {
      return (
        <Badge
          variant="outline"
          className="bg-[#FEF3C7] text-[#B45309] border-amber-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full"
        >
          {status}
        </Badge>
      )
    }

    // Cancelled, Rejected, or default
    return (
      <Badge
        variant="outline"
        className="bg-[#F1F5F9] text-[#475569] border-slate-200 font-semibold px-2.5 py-0.5 text-xs rounded-full"
      >
        {status}
      </Badge>
    )
  }

  const content = loading ? (
    <div className="flex justify-center p-12">
      <Loader2 className="animate-spin w-8 h-8 text-[#0D9488]" />
    </div>
  ) : assignments.length === 0 ? (
    <div className="border-2 border-dashed border-slate-200 bg-slate-50/50 rounded-2xl p-12 flex flex-col items-center justify-center text-center">
      <Layers className="w-12 h-12 text-slate-300 mb-3" />
      <h4 className="font-semibold text-slate-800 text-base mb-1">No Active Assignments</h4>
      <p className="text-sm text-slate-500 max-w-sm">
        You do not have any pending trade assignments from the Admin Deal Desk.
      </p>
    </div>
  ) : (
    <>
      {/* MOBILE VIEW (< md) */}
      <div className="md:hidden space-y-4">
        {assignments.map((req) => {
          const isBuyerReq = req.type === 'Buyer Requirement'

          return (
            <div 
              key={req.id} 
              className="bg-white rounded-2xl border border-slate-200/80 p-5 shadow-sm space-y-3"
            >
              <div className="flex items-center justify-between gap-2 flex-wrap">
                <div className="flex items-center gap-2">
                  <Badge 
                    variant="outline"
                    className={
                      isBuyerReq 
                        ? 'bg-[#EFF6FF] text-[#1D4ED8] border-blue-200/80 font-semibold px-2.5 py-1 text-xs rounded-full' 
                        : 'bg-[#ECFDF5] text-[#047857] border-emerald-200/80 font-semibold px-2.5 py-1 text-xs rounded-full'
                    }
                  >
                    {req.type}
                  </Badge>
                  {getStatusBadge(req.status)}
                </div>
                <span className="text-xs text-slate-400 font-medium">
                  {format(new Date(req.createdAt), "MMM d, yyyy")}
                </span>
              </div>

              <div>
                {(req.industryName || req.categoryName) && (
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-0.5">
                    {[req.industryName, req.categoryName].filter(Boolean).join(" • ")}
                  </span>
                )}
                <h4 className="text-base font-bold text-slate-900 leading-tight">
                  {req.commodityName || "Commodity"}
                </h4>
                <p className="text-xs text-slate-500 mt-0.5 flex items-center gap-1.5">
                  <Building2 className="w-3.5 h-3.5 text-slate-400" />
                  {req.companyName || "Unknown Company"}
                </p>
              </div>

              <div className="grid grid-cols-2 gap-3 py-3 px-3.5 bg-slate-50/80 rounded-xl border border-slate-100">
                <div>
                  <div className="text-[11px] font-semibold text-slate-600 uppercase">Quantity</div>
                  <div className="text-lg font-mono font-bold text-slate-900 tabular-nums">
                    {req.quantity}
                  </div>
                </div>
                <div>
                  <div className="text-[11px] font-semibold text-slate-600 uppercase">Target Price</div>
                  <div className="text-lg font-mono font-bold text-[#0D9488] tabular-nums">
                    ₹{req.targetPrice}
                  </div>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* DESKTOP TABLE VIEW (>= md) */}
      <div className="hidden md:block rounded-xl border border-slate-200/80 overflow-hidden bg-white">
        <Table>
          <TableHeader>
            <TableRow className="bg-slate-50/80 hover:bg-slate-50/80 border-b border-slate-200">
              <TableHead className="font-semibold text-slate-600">Date</TableHead>
              <TableHead className="font-semibold text-slate-600">Type</TableHead>
              <TableHead className="font-semibold text-slate-600">Company</TableHead>
              <TableHead className="font-semibold text-slate-600">Commodity</TableHead>
              <TableHead className="font-semibold text-slate-600 text-right">Quantity</TableHead>
              <TableHead className="font-semibold text-slate-600 text-right">Target Price</TableHead>
              <TableHead className="font-semibold text-slate-600 text-center">Status</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {assignments.map((req) => {
              const isBuyerReq = req.type === 'Buyer Requirement'

              return (
                <TableRow key={req.id} className="hover:bg-slate-50/50 transition-colors">
                  <TableCell className="text-xs text-slate-500 font-medium">
                    {format(new Date(req.createdAt), "MMM d, yyyy")}
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant="outline"
                      className={
                        isBuyerReq 
                          ? 'bg-[#EFF6FF] text-[#1D4ED8] border-blue-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full' 
                          : 'bg-[#ECFDF5] text-[#047857] border-emerald-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full'
                      }
                    >
                      {req.type}
                    </Badge>
                  </TableCell>
                  <TableCell className="font-medium text-slate-800">
                    {req.companyName || "-"}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-col">
                      {(req.industryName || req.categoryName) && (
                        <span className="text-[11px] font-semibold text-slate-400 tracking-wide uppercase">
                          {[req.industryName, req.categoryName].filter(Boolean).join(" • ")}
                        </span>
                      )}
                      <span className="font-semibold text-slate-900">{req.commodityName || "-"}</span>
                    </div>
                  </TableCell>
                  <TableCell className="text-right font-mono tabular-nums font-semibold text-slate-800">
                    {req.quantity}
                  </TableCell>
                  <TableCell className="text-right font-mono tabular-nums font-bold text-[#0D9488]">
                    ₹{req.targetPrice}
                  </TableCell>
                  <TableCell className="text-center">
                    {getStatusBadge(req.status)}
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </div>
    </>
  )

  if (embedded) {
    return <div>{content}</div>
  }

  return (
    <Card className="bg-white rounded-2xl border border-slate-200/80 shadow-sm overflow-hidden">
      <CardHeader className="border-b border-slate-100 pb-5">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-[#CCFBF1] flex items-center justify-center text-[#0D9488]">
            <Layers className="w-5 h-5" />
          </div>
          <div>
            <CardTitle className="text-xl font-bold text-slate-900">Deal Desk Tracking & Assignments</CardTitle>
            <CardDescription className="text-sm text-slate-500">
              Live lifecycle tracking of all buyer requirements, quotations, and booked deals.
            </CardDescription>
          </div>
        </div>
      </CardHeader>
      <CardContent className="pt-6">
        {content}
      </CardContent>
    </Card>
  )
}
