'use client'

import React, { useState, useTransition } from 'react'
import { AlertTriangle, Loader2, XCircle } from 'lucide-react'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group'
import { cancelRequirementAction } from '@/src/server/actions/buyer-requirement-actions'

const CANCELLATION_REASONS = [
  { id: 'sourced_internally', label: 'Sourced internally / Existing stock used' },
  { id: 'price_target_changed', label: 'Price target changed / Market rates revised' },
  { id: 'no_longer_needed', label: 'No longer needed / Procurement cancelled' },
  { id: 'found_alternative', label: 'Found alternative supplier offline' },
  { id: 'other', label: 'Other operational change' },
]

interface CancelRequirementDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  requirementId: string
  requirementTitle?: string
  onSuccess?: () => void
}

export function CancelRequirementDialog({
  open,
  onOpenChange,
  requirementId,
  requirementTitle,
  onSuccess,
}: CancelRequirementDialogProps) {
  const [selectedReason, setSelectedReason] = useState(CANCELLATION_REASONS[0].label)
  const [isPending, startTransition] = useTransition()

  const handleConfirmCancel = () => {
    if (!requirementId) return

    startTransition(async () => {
      try {
        const res = await cancelRequirementAction(requirementId, selectedReason)
        if (res.success) {
          toast.success('Requirement cancelled successfully.')
          onOpenChange(false)
          onSuccess?.()
        } else {
          toast.error(res.error || 'Failed to cancel requirement.')
        }
      } catch (err: any) {
        toast.error(err.message || 'An unexpected error occurred.')
      }
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[420px] w-[95vw] max-w-full overflow-x-hidden rounded-2xl p-5 border-slate-200">
        <DialogHeader className="space-y-2 text-left">
          <div className="flex items-center gap-2 text-rose-600">
            <div className="p-2 rounded-xl bg-rose-50 border border-rose-100">
              <AlertTriangle className="w-5 h-5" />
            </div>
            <DialogTitle className="text-base font-bold text-slate-900">
              Cancel Procurement Requirement
            </DialogTitle>
          </div>
          <DialogDescription className="text-xs text-slate-500 leading-relaxed">
            Are you sure you want to withdraw {requirementTitle ? <span className="font-semibold text-slate-800">"{requirementTitle}"</span> : 'this requirement'}? Matching brokers will no longer submit trade quotes.
          </DialogDescription>
        </DialogHeader>

        <div className="py-3 space-y-3">
          <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider block">
            Reason for Cancellation
          </label>
          <RadioGroup
            value={selectedReason}
            onValueChange={setSelectedReason}
            className="space-y-2"
          >
            {CANCELLATION_REASONS.map((reason) => (
              <label
                key={reason.id}
                className={cn(
                  "flex items-center space-x-3 rounded-xl border p-3 cursor-pointer text-xs transition-all min-h-[48px]",
                  selectedReason === reason.label 
                    ? "border-rose-500 bg-rose-50/50 ring-1 ring-rose-400 font-semibold text-slate-900" 
                    : "border-slate-200 bg-white text-slate-700 hover:border-slate-300"
                )}
              >
                <RadioGroupItem value={reason.label} id={reason.id} />
                <span className="flex-1 cursor-pointer">{reason.label}</span>
              </label>
            ))}
          </RadioGroup>
        </div>

        <DialogFooter className="flex flex-col-reverse sm:flex-row gap-2 pt-2 border-t border-slate-100">
          <Button
            type="button"
            variant="outline"
            disabled={isPending}
            onClick={() => onOpenChange(false)}
            className="w-full sm:w-auto min-h-[48px] text-xs font-semibold border-slate-300"
          >
            Keep Requirement
          </Button>

          <Button
            type="button"
            disabled={isPending}
            onClick={handleConfirmCancel}
            className="w-full sm:w-auto min-h-[48px] text-xs font-semibold bg-rose-600 hover:bg-rose-700 text-white shadow-sm"
          >
            {isPending ? (
              <>
                <Loader2 className="w-4 h-4 mr-1.5 animate-spin" />
                Cancelling...
              </>
            ) : (
              <>
                <XCircle className="w-4 h-4 mr-1.5" />
                Confirm Cancellation
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
