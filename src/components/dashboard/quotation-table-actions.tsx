"use client"

import { Button, buttonVariants } from "@/components/ui/button"
import { Send, Loader2, FileText, Phone, MessageCircle, Edit } from "lucide-react"
import { useState } from "react"
import { sendQuotationAction, reviseQuotationAction } from "@/src/server/actions/quotation-actions"
import { toast } from "sonner"
import { useRouter } from "next/navigation"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Input } from "@/components/ui/input"

export function QuotationTableActions({ quote }: { quote: any }) {
  const [loading, setLoading] = useState(false)
  const [isReviseOpen, setIsReviseOpen] = useState(false)
  const [revisedPrice, setRevisedPrice] = useState(quote.counterPrice || quote.offeredPrice)
  
  // Format the existing validUntil date for the native date picker input (YYYY-MM-DD)
  const defaultDate = new Date(quote.validUntil).toISOString().split('T')[0]
  const [validUntil, setValidUntil] = useState(defaultDate)
  
  const router = useRouter()

  async function handleSend() {
    setLoading(true)
    try {
      const res = await sendQuotationAction(quote.id)
      if (res.success) {
        toast.success("WhatsApp Notification Sent!")
        router.refresh()
      } else {
        toast.error(res.error || "Failed to send WhatsApp message")
      }
    } catch (e) {
      toast.error("Unexpected error occurred")
    } finally {
      setLoading(false)
    }
  }

  async function handleRevise() {
    if (!revisedPrice || !validUntil) return toast.error("Please fill all fields");
    setLoading(true)
    try {
      const res = await reviseQuotationAction({
        quotation_id: quote.id,
        revised_price: Number(revisedPrice),
        valid_until: validUntil,
      })
      if (res.success) {
        toast.success("Revised quotation sent!")
        setIsReviseOpen(false)
        router.refresh()
      } else {
        toast.error(res.error || "Failed to send revised quotation")
      }
    } catch (e) {
      toast.error("Unexpected error occurred")
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex justify-end gap-2 items-center">
      {quote.status === 'Countered' && (
        <>
          <Button variant="default" size="sm" onClick={() => setIsReviseOpen(true)} className="bg-blue-600 hover:bg-blue-700 text-white">
            <Edit className="w-4 h-4 mr-2" />
            Revise Quote
          </Button>
          {quote.buyerMobile && (
            <>
              <a href={`tel:${quote.buyerMobile}`} className={buttonVariants({ variant: "outline", size: "icon" })} title={`Call Buyer: ${quote.buyerName}`}>
                <Phone className="w-4 h-4" />
              </a>
              <a href={`https://wa.me/${quote.buyerMobile}`} target="_blank" rel="noopener noreferrer" className={buttonVariants({ variant: "outline", size: "icon" })} title={`WhatsApp Buyer: ${quote.buyerName}`}>
                <MessageCircle className="w-4 h-4 text-green-600" />
              </a>
            </>
          )}
        </>
      )}

      <a 
        href={`/api/quotations/${quote.id}/pdf`} 
        target="_blank" 
        rel="noopener noreferrer"
        className={buttonVariants({ variant: "outline", size: "sm" })}
      >
        <FileText className="w-4 h-4 mr-2" />
        PDF
      </a>
      <Button variant="outline" size="sm" onClick={handleSend} disabled={loading}>
        {loading ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Send className="w-4 h-4 mr-2" />}
        WhatsApp
      </Button>

      <Dialog open={isReviseOpen} onOpenChange={setIsReviseOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Revise Quotation</DialogTitle>
            <DialogDescription>
              Submit a revised price to the buyer. This will overwrite the counter offer and send a new quotation PDF.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="revised_price">Revised Price (₹)</Label>
              <Input
                id="revised_price"
                type="number"
                value={revisedPrice}
                onChange={(e) => setRevisedPrice(e.target.value)}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="valid_until">Valid Until</Label>
              <Input
                id="valid_until"
                type="date"
                value={validUntil}
                onChange={(e) => setValidUntil(e.target.value)}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsReviseOpen(false)}>Cancel</Button>
            <Button onClick={handleRevise} disabled={loading} className="bg-blue-600 hover:bg-blue-700 text-white">
              {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Send Revised Quotation
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
