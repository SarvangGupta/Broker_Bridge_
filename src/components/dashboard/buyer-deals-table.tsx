'use client';

import { useEffect, useState } from "react"
import { format } from "date-fns"
import { toast } from "sonner"
import { Loader2 } from "lucide-react"

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"

import { getDealsByCompanyAction } from "@/src/server/actions/deal-actions"

import { FileDisputeDialog } from "@/src/components/forms/file-dispute-dialog"
import { PaymentConfirmationDialog } from "@/src/components/forms/payment-confirmation-dialog"
import { Button } from "@/components/ui/button"
import { AlertTriangle, CheckCircle } from "lucide-react"

import { VerificationBadge, TrustScore } from "@/src/components/ui/trust-badge"
import { SlaCountdown } from "@/src/components/ui/sla-badge"

export function BuyerDealsTable() {
  const [deals, setDeals] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [activeDisputeDealId, setActiveDisputeDealId] = useState<string | null>(null)
  const [activePaymentDealId, setActivePaymentDealId] = useState<{ id: string, amount: number } | null>(null)

  const loadDeals = async () => {
    setIsLoading(true)
    const res = await getDealsByCompanyAction()
    if (res.success && res.data) {
      setDeals(res.data)
    } else {
      toast.error(res.error || "Failed to load deals.")
    }
    setIsLoading(false)
  }

  useEffect(() => {
    loadDeals()
  }, [])

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-48 border rounded-lg bg-card text-card-foreground shadow-sm">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    )
  }

  if (deals.length === 0) {
    return (
      <div className="flex flex-col justify-center items-center h-48 border rounded-lg bg-card text-card-foreground shadow-sm gap-2">
        <p className="text-muted-foreground font-medium">No booked deals yet.</p>
        <p className="text-sm text-muted-foreground">Accept quotations to start trading.</p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="hidden md:block rounded-md border bg-card text-card-foreground shadow-sm overflow-hidden">
        <Table className="min-w-[800px]">
          <TableHeader>
            <TableRow>
              <TableHead>Deal ID / Date</TableHead>
              <TableHead>Commodity</TableHead>
              <TableHead>Grade</TableHead>
              <TableHead className="text-right">Agreed Qty</TableHead>
              <TableHead className="text-right">Agreed Price</TableHead>
              <TableHead>Counterparty</TableHead>
              <TableHead className="text-center">Status & SLA</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {deals.map((row) => {
              const { deal, commodity, grade, sellerCompany } = row
              const canDispute = deal.status !== 'Closed' && deal.status !== 'Disputed' && deal.status !== 'Cancelled'
              const canPay = deal.status === 'Dispatched' || deal.status === 'In Transit' || deal.status === 'Dispatch Pending'

              return (
                <TableRow key={deal.id}>
                  <TableCell className="font-medium">
                    <div className="truncate w-24 text-xs text-muted-foreground mb-1">{deal.id.split('-')[0]}...</div>
                    <div>{format(new Date(deal.createdAt), "MMM d, yyyy")}</div>
                  </TableCell>
                  <TableCell>{commodity.name}</TableCell>
                  <TableCell>{grade.gradeName}</TableCell>
                  <TableCell className="text-right">{deal.agreedQuantity}</TableCell>
                  <TableCell className="text-right font-bold text-primary">₹{deal.agreedPrice}</TableCell>
                  <TableCell>
                    <div className="flex flex-col gap-1">
                      <span className="font-semibold text-slate-900">{sellerCompany?.name || 'Unknown Supplier'}</span>
                      <div className="flex items-center gap-1.5 flex-wrap">
                        {sellerCompany?.isVerified && <VerificationBadge compact />}
                        <TrustScore score={sellerCompany?.trustScore} compact />
                      </div>
                    </div>
                  </TableCell>
                  <TableCell className="text-center">
                    <div className="flex flex-col items-center gap-1">
                      <Badge variant="secondary" className="bg-green-500/10 text-green-700">
                        {deal.status}
                      </Badge>
                      {deal.expectedDeliveryDate && (
                        <SlaCountdown targetDate={deal.expectedDeliveryDate} prefix="Dispatch:" compact />
                      )}
                    </div>
                  </TableCell>
                  <TableCell className="text-right space-x-2">
                    {canPay && (
                      <Button 
                        size="sm" 
                        onClick={() => setActivePaymentDealId({ id: deal.id, amount: deal.agreedPrice })}
                        className="gap-2 h-10 min-h-[40px] cursor-pointer"
                      >
                        <CheckCircle className="h-4 w-4" />
                        Pay
                      </Button>
                    )}
                    {canDispute && (
                      <Button 
                        size="sm" 
                        variant="destructive"
                        onClick={() => setActiveDisputeDealId(deal.id)}
                        className="gap-2 h-10 min-h-[40px] cursor-pointer"
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

      <div className="md:hidden flex flex-col space-y-4">
        {deals.map((row) => {
          const { deal, commodity, grade, sellerCompany } = row
          const canDispute = deal.status !== 'Closed' && deal.status !== 'Disputed' && deal.status !== 'Cancelled'
          const canPay = deal.status === 'Dispatched' || deal.status === 'In Transit' || deal.status === 'Dispatch Pending'

          return (
            <div key={deal.id} className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
              <div className="p-4 flex flex-col gap-3">
                <div className="flex justify-between items-start">
                  <div className="flex flex-col">
                    <span className="text-slate-500 text-sm font-medium">{commodity.name} &bull; {grade.gradeName}</span>
                    <span className="text-slate-900 font-bold text-lg mt-0.5">{deal.agreedQuantity} &bull; ₹{deal.agreedPrice}</span>
                  </div>
                  <Badge variant="secondary" className="bg-green-500/10 text-green-700">
                    {deal.status}
                  </Badge>
                </div>
                <div className="flex flex-col text-sm text-slate-600 mt-2">
                  <span className="font-semibold text-slate-900">{sellerCompany?.name || 'Unknown Seller'}</span>
                  <div className="flex items-center gap-1.5 mt-1 flex-wrap">
                    {sellerCompany?.isVerified && <VerificationBadge compact />}
                    <TrustScore score={sellerCompany?.trustScore} compact />
                  </div>
                  <span className="text-slate-400 text-xs mt-1.5">Deal #{deal.id.split('-')[0]} &bull; {format(new Date(deal.createdAt), "MMM d, yyyy")}</span>
                </div>
              </div>
              
              {(canPay || canDispute) && (
                <div className="border-t border-slate-100 bg-slate-50 p-2 flex gap-2">
                  {canPay && (
                    <Button 
                      size="sm" 
                      onClick={() => setActivePaymentDealId({ id: deal.id, amount: deal.agreedPrice })}
                      className="flex-1 gap-2 min-h-[44px]"
                    >
                      <CheckCircle className="h-4 w-4" />
                      Pay
                    </Button>
                  )}
                  {canDispute && (
                    <Button 
                      size="sm" 
                      variant="destructive"
                      onClick={() => setActiveDisputeDealId(deal.id)}
                      className="flex-1 gap-2 min-h-[44px]"
                    >
                      <AlertTriangle className="h-4 w-4" />
                      Dispute
                    </Button>
                  )}
                </div>
              )}
            </div>
          )
        })}
      </div>

      {activeDisputeDealId && (
        <FileDisputeDialog
          dealId={activeDisputeDealId}
          open={!!activeDisputeDealId}
          onOpenChange={(open) => !open && setActiveDisputeDealId(null)}
          onSuccess={loadDeals}
        />
      )}

      {activePaymentDealId && (
        <PaymentConfirmationDialog
          dealId={activePaymentDealId.id}
          amount={activePaymentDealId.amount}
          open={!!activePaymentDealId}
          onOpenChange={(open) => !open && setActivePaymentDealId(null)}
          onSuccess={loadDeals}
        />
      )}
    </div>
  )
}
