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
  DialogTrigger,
} from "@/components/ui/dialog"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"
import { RequirementForm } from "@/src/components/forms/requirement-form"
import { Plus } from "lucide-react"

export function PostRequirementDialog() {
  const [open, setOpen] = React.useState(false)
  const isDesktop = useMediaQuery("(min-width: 768px)")

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={setOpen}>
        <div onClick={() => setOpen(true)} className="w-full">
          <Button size="lg" className="bg-[#2563EB] hover:bg-blue-700 text-white font-medium shadow-md w-full">
            <Plus className="mr-2 h-5 w-5" />
            Post Requirement
          </Button>
        </div>
        <DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Post New Requirement</DialogTitle>
            <DialogDescription>
              Submit a new commodity requirement to the market.
            </DialogDescription>
          </DialogHeader>
          <RequirementForm onSuccess={() => setOpen(false)} />
        </DialogContent>
      </Dialog>
    )
  }

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <div onClick={() => setOpen(true)} className="w-full">
        <Button size="lg" className="w-full bg-[#2563EB] hover:bg-blue-700 text-white font-medium shadow-md min-h-[56px] text-lg">
          <Plus className="mr-2 h-5 w-5" />
          Post Requirement
        </Button>
      </div>
      <SheetContent side="bottom" className="h-[95vh] overflow-y-auto pt-10 px-4 rounded-t-xl">
        <SheetHeader className="mb-4 text-left">
          <SheetTitle>Post New Requirement</SheetTitle>
          <SheetDescription>
            Submit a new commodity requirement to the market.
          </SheetDescription>
        </SheetHeader>
        <RequirementForm onSuccess={() => setOpen(false)} />
      </SheetContent>
    </Sheet>
  )
}
