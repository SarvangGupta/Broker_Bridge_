'use client'

import { useState } from 'react'
import Link from 'next/link'
import { SlaCountdown } from "@/src/components/ui/sla-badge"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { EmptyState } from "@/src/components/ui/empty-state"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { FileDisputeDialog } from "@/src/components/forms/file-dispute-dialog"
import { SellerDispatchForm } from "@/src/components/forms/seller-dispatch-form"
import { AlertTriangle, Truck, Handshake, Eye } from "lucide-react"

export function SellerDealsTable({ 
  deals, 
  vehicleTypes 
}: { 
  deals: any[]; 
  vehicleTypes: any[];
}) {
  const [openDialogForDeal, setOpenDialogForDeal] = useState<string | null>(null)
  const [activeDisputeDealId, setActiveDisputeDealId] = useState<string | null>(null)

  if (deals.length === 0) {
    return (
      <EmptyState
        icon={Handshake}
        title="No Active Deals"
        description="When buyers accept your inventory quotations, booked orders and dispatch trackers will appear here."
        className="bg-white border-slate-200/80 shadow-xs"
      />
    )
  }

  return (
    <div className="space-y-4">
      {/* MOBILE CARDS VIEW (< md) */}
      <div className="md:hidden space-y-4">
        {deals.map((row) => {
          const canDispute = row.deal.status !== 'Closed' && row.deal.status !== 'Disputed' && row.deal.status !== 'Cancelled'
          const isPendingDispatch = row.deal.status === 'Dispatch Pending'

          return (
            <div 
              key={row.deal.id}
              className="bg-white rounded-2xl border border-slate-200/80 p-5 shadow-xs space-y-4"
            >
              <div className="flex items-center justify-between">
                <div>
                  <span className="text-[11px] font-mono font-semibold uppercase text-slate-400">
                    DEAL #{row.deal.id.substring(0, 8).toUpperCase()}
                  </span>
                  <h4 className="text-base font-bold text-slate-900 leading-tight mt-0.5">
                    {row.commodity.name}
                  </h4>
                  <p className="text-xs text-slate-500">{row.grade.gradeName}</p>
                </div>
                <Badge 
                  variant="outline"
                  className={
                    row.deal.status === 'In Transit' ? 'bg-blue-50 text-blue-700 border-blue-200 font-semibold' :
                    row.deal.status === 'Dispatch Pending' ? 'bg-amber-50 text-amber-700 border-amber-200 font-semibold' :
                    row.deal.status === 'Closed' ? 'bg-[#ECFDF5] text-[#047857] border-emerald-200 font-semibold' :
                    'bg-slate-50 text-slate-700 border-slate-200 font-semibold'
                  }
                >
                  {row.deal.status}
                </Badge>
              </div>

              <div className="grid grid-cols-2 gap-3 py-3 px-3.5 bg-slate-50/80 rounded-xl border border-slate-100">
                <div>
                  <div className="text-[11px] font-medium text-slate-400 uppercase">Quantity</div>
                  <div className="text-lg font-bold text-slate-900">{row.deal.agreedQuantity} Qty</div>
                </div>
                <div>
                  <div className="text-[11px] font-medium text-slate-400 uppercase">Agreed Price</div>
                  <div className="text-lg font-bold text-[#059669]">₹{row.deal.agreedPrice}</div>
                </div>
              </div>

              {/* Action Buttons with 48px Touch Targets */}
              <div className="flex flex-col gap-2.5 pt-2 border-t border-slate-100">
                <Link
                  href={`/seller/deals/${row.deal.id}`}
                  className="w-full min-h-[48px] h-12 bg-slate-100 hover:bg-slate-200 text-slate-900 font-bold rounded-xl flex items-center justify-center gap-2 shadow-2xs transition-colors"
                >
                  <Eye className="h-4 w-4 text-slate-700" />
                  View Deal & Booking ID
                </Link>
                {isPendingDispatch && (
                  <Button 
                    onClick={() => setOpenDialogForDeal(row.deal.id)}
                    className="w-full min-h-[48px] h-12 bg-[#059669] hover:bg-[#047857] text-white font-bold rounded-xl flex items-center justify-center gap-2 shadow-xs cursor-pointer"
                  >
                    <Truck className="h-5 w-5" />
                    Dispatch Shipment
                  </Button>
                )}
                {canDispute && (
                  <Button 
                    variant="outline"
                    onClick={() => setActiveDisputeDealId(row.deal.id)}
                    className="w-full min-h-[48px] h-12 text-rose-600 hover:text-rose-700 hover:bg-rose-50 border-slate-200 font-semibold rounded-xl flex items-center justify-center gap-2 cursor-pointer"
                  >
                    <AlertTriangle className="h-4 w-4" />
                    Raise Dispute
                  </Button>
                )}
              </div>
            </div>
          )
        })}
      </div>

      {/* DESKTOP TABLE VIEW (>= md) */}
      <div className="hidden md:block bg-white rounded-2xl border border-slate-200/80 shadow-xs overflow-hidden">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader className="bg-slate-50/60">
              <TableRow>
                <TableHead className="font-bold text-slate-700">Deal Ref</TableHead>
                <TableHead className="font-bold text-slate-700">Commodity & Grade</TableHead>
                <TableHead className="font-bold text-slate-700">Quantity</TableHead>
                <TableHead className="font-bold text-slate-700">Agreed Price</TableHead>
                <TableHead className="font-bold text-slate-700">Status</TableHead>
                <TableHead className="text-right font-bold text-slate-700">Actions</TableHead>
              </TableRow>
            </TableHeader>
          <TableBody>
            {deals.map((row) => {
              const canDispute = row.deal.status !== 'Closed' && row.deal.status !== 'Disputed' && row.deal.status !== 'Cancelled'

              return (
                <TableRow key={row.deal.id} className="hover:bg-slate-50/50 transition-colors">
                  <TableCell className="font-mono text-xs font-semibold text-slate-500">
                    <Link
                      href={`/seller/deals/${row.deal.id}`}
                      className="text-emerald-700 hover:underline font-bold"
                    >
                      {row.deal.id.substring(0, 8).toUpperCase()}
                    </Link>
                  </TableCell>
                  <TableCell>
                    <div className="font-bold text-slate-900">{row.commodity.name}</div>
                    <div className="text-xs text-slate-500">{row.grade.gradeName}</div>
                  </TableCell>
                  <TableCell className="font-semibold text-slate-800">{row.deal.agreedQuantity}</TableCell>
                  <TableCell className="font-bold text-[#059669]">₹{row.deal.agreedPrice}</TableCell>
                  <TableCell>
                    <div className="flex flex-col gap-1">
                      <Badge 
                        variant="outline"
                        className={
                          row.deal.status === 'In Transit' ? 'bg-blue-50 text-blue-700 border-blue-200 font-semibold' : 
                          row.deal.status === 'Dispatch Pending' ? 'bg-amber-50 text-amber-700 border-amber-200 font-semibold' : 
                          row.deal.status === 'Closed' ? 'bg-[#ECFDF5] text-[#047857] border-emerald-200 font-semibold' :
                          'bg-slate-50 text-slate-700 border-slate-200 font-semibold'
                        }
                      >
                        {row.deal.status}
                      </Badge>
                      {row.deal.expectedDeliveryDate && (
                        <SlaCountdown targetDate={row.deal.expectedDeliveryDate} prefix="Deadline:" compact />
                      )}
                    </div>
                  </TableCell>
                  <TableCell className="text-right space-x-2">
                    <Link
                      href={`/seller/deals/${row.deal.id}`}
                      className="inline-flex items-center gap-1 text-xs font-bold text-slate-700 hover:text-slate-950 bg-slate-100 hover:bg-slate-200 px-3 py-2 rounded-lg transition-colors"
                    >
                      <Eye className="h-3.5 w-3.5" />
                      <span>Details</span>
                    </Link>
                    {row.deal.status === 'Dispatch Pending' && (
                      <Button 
                        size="sm" 
                        onClick={() => setOpenDialogForDeal(row.deal.id)}
                        className="bg-[#059669] hover:bg-[#047857] text-white gap-1.5 h-9 font-medium shadow-2xs cursor-pointer"
                      >
                        <Truck className="h-4 w-4" />
                        Dispatch
                      </Button>
                    )}
                    {canDispute && (
                      <Button 
                        size="sm" 
                        variant="outline"
                        onClick={() => setActiveDisputeDealId(row.deal.id)}
                        className="text-rose-600 hover:text-rose-700 hover:bg-rose-50 border-slate-200 hover:border-rose-200 gap-1.5 h-9 font-medium cursor-pointer"
                      >
                        <AlertTriangle className="h-4 w-4" />
                        Dispute
                      </Button>
                    )}
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
        </div>
      </div>

      {/* DISPATCH MODAL */}
      {openDialogForDeal && (() => {
        const selectedDealRow = deals.find((d) => d.deal.id === openDialogForDeal);
        const bookedQty = Number(selectedDealRow?.deal.agreedQuantity || 0);
        const unitSym = selectedDealRow?.unit?.symbol || selectedDealRow?.requirement?.unit || "";

        return (
          <Dialog open={!!openDialogForDeal} onOpenChange={(open) => !open && setOpenDialogForDeal(null)}>
            <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto rounded-3xl p-6 sm:p-8">
              <DialogHeader className="pb-4">
                <DialogTitle className="text-xl font-bold text-slate-900 flex items-center gap-2">
                  <Truck className="w-5 h-5 text-emerald-600" />
                  <span>Dispatch Order (Deal #{openDialogForDeal.substring(0, 8).toUpperCase()})</span>
                </DialogTitle>
                <DialogDescription>
                  Assign vehicle, driver, and specify shipment dispatch volume.
                </DialogDescription>
              </DialogHeader>
              <SellerDispatchForm
                dealId={openDialogForDeal}
                vehicleTypes={vehicleTypes}
                bookedQuantity={bookedQty}
                remainingQuantity={bookedQty}
                unitSymbol={unitSym}
                onSuccess={() => setOpenDialogForDeal(null)}
              />
            </DialogContent>
          </Dialog>
        );
      })()}

      {/* DISPUTE MODAL */}
      {activeDisputeDealId && (
        <FileDisputeDialog
          dealId={activeDisputeDealId}
          open={!!activeDisputeDealId}
          onOpenChange={(open) => !open && setActiveDisputeDealId(null)}
          onSuccess={() => setActiveDisputeDealId(null)}
        />
      )}
    </div>
  )
}
