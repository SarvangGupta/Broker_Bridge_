'use client';

import { useEffect, useState } from "react"
import { Loader2 } from "lucide-react"
import { toast } from "sonner"
import { getBuyerQuotationsAction } from "@/src/server/actions/quotation-actions"
import { BuyerQuotationCard } from "./buyer-quotation-card"
import { Table, TableBody, TableHead, TableHeader, TableRow } from "@/components/ui/table"

export function BuyerQuotationsList() {
  const [quotations, setQuotations] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)

  const loadQuotations = async () => {
    setIsLoading(true)
    const res = await getBuyerQuotationsAction()
    if (res.success && res.data) {
      setQuotations(res.data)
    } else {
      toast.error(res.error || "Failed to load quotations.")
    }
    setIsLoading(false)
  }

  useEffect(() => {
    loadQuotations()
  }, [])

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-48 border rounded-lg bg-card text-card-foreground shadow-sm">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    )
  }

  if (quotations.length === 0) {
    return (
      <div className="flex flex-col justify-center items-center h-48 border rounded-lg bg-card text-card-foreground shadow-sm gap-2">
        <p className="text-muted-foreground font-medium">No active quotations found.</p>
        <p className="text-sm text-muted-foreground">Brokers will send quotations to your requirements.</p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="hidden md:block rounded-md border bg-card text-card-foreground shadow-sm overflow-hidden">
        <Table className="min-w-[800px]">
          <TableHeader>
            <TableRow>
              <TableHead>Commodity / Grade</TableHead>
              <TableHead>Seller</TableHead>
              <TableHead className="text-right">Offered Price</TableHead>
              <TableHead className="text-right">Qty</TableHead>
              <TableHead className="text-center">Status</TableHead>
              <TableHead className="text-right min-w-[200px]">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {quotations.map((q) => (
              <BuyerQuotationCard 
                key={`desktop-${q.quotation.id}`} 
                quotationData={q} 
                onActionComplete={loadQuotations} 
                variant="desktop"
              />
            ))}
          </TableBody>
        </Table>
      </div>

      <div className="md:hidden flex flex-col space-y-4">
        {quotations.map((q) => (
          <BuyerQuotationCard 
            key={`mobile-${q.quotation.id}`} 
            quotationData={q} 
            onActionComplete={loadQuotations} 
            variant="mobile"
          />
        ))}
      </div>
    </div>
  )
}
