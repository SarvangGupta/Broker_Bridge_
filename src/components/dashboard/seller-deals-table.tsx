'use client'

import { useState } from 'react'
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { FileDisputeDialog } from "@/src/components/forms/file-dispute-dialog"
import { SellerDispatchForm } from "@/src/components/forms/seller-dispatch-form"
import { AlertTriangle, Truck, Handshake } from "lucide-react"

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
      <div className="flex flex-col items-center justify-center p-12 text-center bg-white border border-slate-200/80 rounded-2xl shadow-sm">
        <div className="w-14 h-14 rounded-2xl bg-[#ECFDF5] flex items-center justify-center mb-4 text-[#047857]">
          <Handshake className="w-7 h-7 stroke-[1.75]" />
        </div>
        <h3 className="text-lg font-bold text-slate-900 mb-1">No Active Deals</h3>
        <p className="text-sm text-slate-500 max-w-sm">
          When buyers accept your inventory quotations, booked orders and dispatch trackers will appear here.
        </p>
      </div>
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
              className="bg-white rounded-2xl border border-slate-200/80 p-5 shadow-sm space-y-4"
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

              {/* Action Buttons */}
              <div className="flex flex-col gap-2 pt-2 border-t border-slate-100">
                {isPendingDispatch && (
                  <Button 
                    size="lg"
                    onClick={() => setOpenDialogForDeal(row.deal.id)}
                    className="w-full bg-[#059669] hover:bg-[#047857] text-white min-h-[48px] rounded-xl font-semibold gap-2 shadow-sm cursor-pointer"
                  >
                    <Truck className="h-4 w-4" />
                    Dispatch Shipment
                  </Button>
                )}
                {canDispute && (
                  <Button 
                    size="lg"
                    variant="outline"
                    onClick={() => setActiveDisputeDealId(row.deal.id)}
                    className="w-full text-rose-600 hover:text-rose-700 hover:bg-rose-50 border-slate-200 hover:border-rose-200 min-h-[48px] rounded-xl font-semibold gap-2 cursor-pointer"
                  >
                    <AlertTriangle className="h-4 w-4" />
                    File Dispute
                  </Button>
                )}
              </div>
            </div>
          )
        })}
      </div>

      {/* DESKTOP TABLE VIEW (>= md) */}
      <div className="hidden md:block rounded-2xl border border-slate-200/80 bg-white overflow-hidden shadow-sm">
        <Table>
          <TableHeader>
            <TableRow className="bg-slate-50/80 hover:bg-slate-50/80 border-b border-slate-200">
              <TableHead className="font-semibold text-slate-600">Deal ID</TableHead>
              <TableHead className="font-semibold text-slate-600">Commodity</TableHead>
              <TableHead className="font-semibold text-slate-600">Quantity</TableHead>
              <TableHead className="font-semibold text-slate-600">Agreed Price</TableHead>
              <TableHead className="font-semibold text-slate-600">Status</TableHead>
              <TableHead className="text-right font-semibold text-slate-600">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {deals.map((row) => {
              const canDispute = row.deal.status !== 'Closed' && row.deal.status !== 'Disputed' && row.deal.status !== 'Cancelled'

              return (
                <TableRow key={row.deal.id} className="hover:bg-slate-50/50 transition-colors">
                  <TableCell className="font-mono text-xs font-semibold text-slate-500">
                    {row.deal.id.substring(0, 8).toUpperCase()}
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
                    {row.deal.status === 'Dispatch Pending' && (
                      <Button 
                        size="sm" 
                        onClick={() => setOpenDialogForDeal(row.deal.id)}
                        className="bg-[#059669] hover:bg-[#047857] text-white gap-1.5 h-9 font-medium shadow-sm cursor-pointer"
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

      {/* DISPATCH DIALOG */}
      {openDialogForDeal && (
        <Dialog 
          open={!!openDialogForDeal} 
          onOpenChange={(isOpen) => setOpenDialogForDeal(isOpen ? openDialogForDeal : null)}
        >
          <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle className="text-xl font-bold text-slate-900">Mark Deal as Dispatched</DialogTitle>
              <DialogDescription className="text-slate-500 text-sm">
                Enter logistics details and upload the Lorry Receipt (LR) / Invoice.
              </DialogDescription>
            </DialogHeader>
            <SellerDispatchForm 
              dealId={openDialogForDeal} 
              vehicleTypes={vehicleTypes} 
              onSuccess={() => {
                setOpenDialogForDeal(null)
                window.location.reload()
              }}
            />
          </DialogContent>
        </Dialog>
      )}

      {/* DISPUTE DIALOG */}
      {activeDisputeDealId && (
        <FileDisputeDialog
          dealId={activeDisputeDealId}
          open={!!activeDisputeDealId}
          onOpenChange={(open) => !open && setActiveDisputeDealId(null)}
          onSuccess={() => window.location.reload()}
        />
      )}
    </div>
  )
}
