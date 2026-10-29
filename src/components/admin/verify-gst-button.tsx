'use client'

import React, { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  CheckCircle2,
  ExternalLink,
  Loader2,
  Search,
  ShieldCheck,
  AlertCircle,
} from 'lucide-react'
import { toast } from 'sonner'
import { manuallyVerifyGstAction } from '@/src/server/actions/company-actions'

export interface VerifyGstButtonProps {
  companyId: string
  gstNumber: string
  isVerified: boolean
  className?: string
  onSuccess?: (data: any) => void
}

/**
 * Task 2: Rebuilt Admin GST Verification Trigger UI
 * Two-step manual verification workflow:
 * 1. "Search GST Online" (Secondary/Outline): Opens external search in new tab.
 * 2. "Mark as Verified" (Primary): Opens confirmation dialog and executes `manuallyVerifyGstAction`.
 * Touch targets maintain >= 48px for mobile accessibility on Tier-2 networks.
 */
export function VerifyGstButton({
  companyId,
  gstNumber,
  isVerified,
  className = '',
  onSuccess,
}: VerifyGstButtonProps) {
  const [loading, setLoading] = useState(false)
  const [verified, setVerified] = useState(isVerified)
  const [isConfirmOpen, setIsConfirmOpen] = useState(false)

  React.useEffect(() => {
    setVerified(isVerified)
  }, [isVerified])

  const cleanGst = gstNumber?.trim().toUpperCase() || ''
  const searchUrl = cleanGst
    ? `https://www.google.com/search?q=GST+Details+${encodeURIComponent(cleanGst)}`
    : 'https://services.gst.gov.in/services/searchtp'

  const handleConfirmManualVerification = async () => {
    if (!cleanGst) {
      toast.error('GSTIN is required for verification.')
      setIsConfirmOpen(false)
      return
    }

    setLoading(true)
    try {
      const res = await manuallyVerifyGstAction(companyId, cleanGst)
      if (res.success) {
        setVerified(true)
        setIsConfirmOpen(false)
        toast.success('GST Manually Verified', {
          description: 'The business has been locked as verified in the platform database.',
        })
        onSuccess?.(res.data)
      } else {
        toast.error('Verification Failed', {
          description: res.error || 'Could not record manual verification.',
        })
      }
    } catch (err: any) {
      toast.error('Verification Error', {
        description: err.message || 'An unexpected error occurred.',
      })
    } finally {
      setLoading(false)
    }
  }

  // If verified, render the green "Verified" badge (minimum 48px touch target)
  if (verified) {
    return (
      <div
        className={`min-h-[48px] px-3.5 text-xs font-semibold text-emerald-800 bg-emerald-50/90 border border-emerald-300/80 rounded-xl inline-flex items-center justify-center gap-2 shadow-none select-none cursor-default ${className}`}
      >
        <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
        <span>Verified</span>
      </div>
    )
  }

  // If false, render a Shadcn Card / bounded section with two distinct actions
  return (
    <>
      <Card
        className={`p-2.5 sm:p-3 bg-slate-50/90 border border-slate-200/90 rounded-xl shadow-xs inline-block text-left ${className}`}
      >
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
          {/* Action 1: Search GST Online (Secondary/Outline Link Button) */}
          <a
            href={searchUrl}
            target="_blank"
            rel="noopener noreferrer"
            title="Search GST details on external web portal in a new tab"
            className="min-h-[48px] px-3.5 text-xs font-semibold text-slate-700 bg-white hover:bg-slate-100 hover:text-slate-900 border border-slate-300 rounded-lg inline-flex items-center justify-center gap-2 shadow-xs transition-colors shrink-0"
          >
            <Search className="w-4 h-4 text-slate-500 shrink-0" />
            <span>Search GST Online</span>
            <ExternalLink className="w-3.5 h-3.5 text-slate-400 shrink-0" />
          </a>

          {/* Action 2: Mark as Verified (Primary Button) */}
          <Button
            type="button"
            size="sm"
            onClick={() => setIsConfirmOpen(true)}
            disabled={loading || !cleanGst}
            className="min-h-[48px] px-3.5 text-xs font-semibold bg-[#0D9488] hover:bg-[#0f766e] text-white rounded-lg inline-flex items-center justify-center gap-2 shadow-xs transition-colors shrink-0 disabled:opacity-50"
          >
            <ShieldCheck className="w-4 h-4 shrink-0" />
            <span>Mark as Verified</span>
          </Button>
        </div>
      </Card>

      {/* Confirmation Dialog */}
      <Dialog open={isConfirmOpen} onOpenChange={setIsConfirmOpen}>
        <DialogContent className="sm:max-w-md bg-white p-6 rounded-2xl shadow-xl border border-slate-200">
          <DialogHeader className="space-y-2">
            <div className="w-10 h-10 rounded-xl bg-teal-50 border border-teal-200 flex items-center justify-center text-teal-700 mb-1">
              <ShieldCheck className="w-5 h-5" />
            </div>
            <DialogTitle className="text-lg font-bold text-slate-900">
              Confirm Manual GST Verification
            </DialogTitle>
            <DialogDescription className="text-xs sm:text-sm text-slate-600 leading-relaxed">
              Have you checked the web portal and confirmed this GST is active and matches the company name?
            </DialogDescription>
          </DialogHeader>

          {/* Details Box */}
          <div className="my-2 p-3.5 bg-slate-50 border border-slate-200 rounded-xl space-y-1.5">
            <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider">
              GST Number to Lock
            </div>
            <div className="font-mono text-sm font-bold text-slate-900">
              {cleanGst || 'N/A'}
            </div>
            <p className="text-[11px] text-slate-500 pt-1">
              This action will mark the business as officially verified and stamp your Admin user ID in the platform audit ledger.
            </p>
          </div>

          <DialogFooter className="flex flex-col-reverse sm:flex-row sm:justify-end gap-2 pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsConfirmOpen(false)}
              disabled={loading}
              className="min-h-[48px] px-4 text-xs font-semibold rounded-lg"
            >
              Cancel
            </Button>
            <Button
              type="button"
              onClick={handleConfirmManualVerification}
              disabled={loading || !cleanGst}
              className="min-h-[48px] px-4 text-xs font-semibold bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg inline-flex items-center justify-center gap-2 shadow-sm"
            >
              {loading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin shrink-0" />
                  <span>Locking Verification...</span>
                </>
              ) : (
                <>
                  <CheckCircle2 className="w-4 h-4 shrink-0" />
                  <span>Confirm & Lock Verification</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}

export default VerifyGstButton
