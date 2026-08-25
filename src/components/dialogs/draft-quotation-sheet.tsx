'use client'

import * as React from "react"
import { useMediaQuery } from "@/src/hooks/use-media-query"
import { Plus, Send } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { QuotationForm } from "@/src/components/forms/quotation-form"

export function DraftQuotationSheet() {
  const [open, setOpen] = React.useState(false)
  const isDesktop = useMediaQuery("(min-width: 768px)")

  const triggerButton = (
    <Button 
      onClick={() => setOpen(true)}
      className="bg-[#0D9488] hover:bg-[#0F766E] text-white font-semibold shadow-sm hover:shadow transition-all duration-200 rounded-xl px-5 py-2.5 min-h-[44px] flex items-center justify-center gap-2 cursor-pointer text-sm w-full sm:w-auto"
    >
      <Plus className="w-4 h-4 stroke-[2.5]" />
      Draft Quotation
    </Button>
  )

  if (isDesktop) {
    return (
      <>
        {triggerButton}
        <Sheet open={open} onOpenChange={setOpen}>
          <SheetContent side="right" className="w-full sm:max-w-lg overflow-y-auto p-6 bg-white">
            <SheetHeader className="p-0 pb-6 border-b border-slate-100 text-left">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#CCFBF1] flex items-center justify-center text-[#0D9488]">
                  <Send className="w-5 h-5" />
                </div>
                <div>
                  <SheetTitle className="text-xl font-bold text-slate-900">Draft Trade Quotation</SheetTitle>
                  <SheetDescription className="text-xs text-slate-500 mt-0.5">
                    Match buyer and seller positions to issue a formal offer.
                  </SheetDescription>
                </div>
              </div>
            </SheetHeader>
            <div className="py-6">
              <QuotationForm onSuccess={() => setOpen(false)} />
            </div>
          </SheetContent>
        </Sheet>
      </>
    )
  }

  return (
    <>
      {triggerButton}
      <Sheet open={open} onOpenChange={setOpen}>
        <SheetContent side="bottom" className="h-[92vh] overflow-y-auto pt-6 px-4 rounded-t-2xl bg-white">
          <SheetHeader className="mb-4 text-left">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-[#CCFBF1] flex items-center justify-center text-[#0D9488]">
                <Send className="w-5 h-5" />
              </div>
              <div>
                <SheetTitle className="text-xl font-bold text-slate-900">Draft Trade Quotation</SheetTitle>
                <SheetDescription className="text-xs text-slate-500 mt-0.5">
                  Match buyer and seller positions to issue a formal offer.
                </SheetDescription>
              </div>
            </div>
          </SheetHeader>
          <div className="pb-8">
            <QuotationForm onSuccess={() => setOpen(false)} />
          </div>
        </SheetContent>
      </Sheet>
    </>
  )
}
