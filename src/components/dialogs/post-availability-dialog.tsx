'use client'

import * as React from "react"
import { useMediaQuery } from "@/src/hooks/use-media-query"
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
import { AvailabilityForm } from "@/src/components/forms/availability-form"
import { Plus } from "lucide-react"

export function PostAvailabilityDialog() {
  const [open, setOpen] = React.useState(false)
  const isDesktop = useMediaQuery("(min-width: 768px)")

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={setOpen}>
        <div onClick={() => setOpen(true)} className="w-full sm:w-auto">
          <Button 
            size="lg" 
            className="bg-[#059669] hover:bg-[#047857] text-white font-semibold shadow-md hover:shadow-lg transition-all duration-200 w-full sm:w-auto min-h-[48px] px-6 rounded-lg flex items-center justify-center gap-2 text-base cursor-pointer"
          >
            <Plus className="h-5 w-5 stroke-[2.5]" />
            Post Availability
          </Button>
        </div>
        <DialogContent className="sm:max-w-[650px] max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="text-xl font-bold text-slate-900">Post New Inventory Availability</DialogTitle>
            <DialogDescription className="text-slate-500 text-sm">
              List available commodity stock for matching and trade quotation.
            </DialogDescription>
          </DialogHeader>
          <div className="py-2">
            <AvailabilityForm onSuccess={() => setOpen(false)} />
          </div>
        </DialogContent>
      </Dialog>
    )
  }

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <div onClick={() => setOpen(true)} className="w-full">
        <Button 
          size="lg" 
          className="w-full bg-[#059669] hover:bg-[#047857] text-white font-semibold shadow-md min-h-[56px] text-lg rounded-xl flex items-center justify-center gap-2 cursor-pointer active:scale-[0.99] transition-transform"
        >
          <Plus className="h-6 w-6 stroke-[2.5]" />
          Post Availability
        </Button>
      </div>
      <SheetContent side="bottom" className="h-[95vh] overflow-y-auto pt-8 px-4 rounded-t-2xl">
        <SheetHeader className="mb-4 text-left">
          <SheetTitle className="text-xl font-bold text-slate-900">Post New Inventory Availability</SheetTitle>
          <SheetDescription className="text-slate-500 text-sm">
            List available commodity stock for matching and trade quotation.
          </SheetDescription>
        </SheetHeader>
        <div className="pb-8">
          <AvailabilityForm onSuccess={() => setOpen(false)} />
        </div>
      </SheetContent>
    </Sheet>
  )
}
