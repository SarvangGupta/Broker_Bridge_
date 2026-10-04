import React from 'react'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { PackageX, ArrowLeft, Plus } from 'lucide-react'

import { getBuyerRequirementDetailAction } from '@/src/server/actions/buyer-requirement-actions'
import { DetailFulfillmentCard } from '@/src/components/buyer/requirements/detail-fulfillment-card'
import { DetailTermsGrid } from '@/src/components/buyer/requirements/detail-terms-grid'
import { BackButton } from '@/src/components/ui/back-button'
import { Button } from '@/components/ui/button'

export const dynamic = 'force-dynamic'

interface PageProps {
  params: Promise<{ id: string }>
}

export default async function BuyerRequirementDetailPage({ params }: PageProps) {
  const resolvedParams = await params
  const reqId = resolvedParams.id

  if (!reqId) {
    notFound()
  }

  const res = await getBuyerRequirementDetailAction(reqId)

  if (!res.success || !res.data) {
    return (
      <div className="w-full max-w-full overflow-x-hidden min-h-screen bg-slate-50/50 p-4 sm:p-6 flex flex-col items-center justify-center">
        <div className="bg-white rounded-2xl border border-slate-200 p-8 sm:p-12 text-center max-w-md w-full space-y-4 shadow-sm">
          <div className="w-16 h-16 rounded-full bg-rose-50 text-rose-600 flex items-center justify-center mx-auto border border-rose-100">
            <PackageX className="w-8 h-8" />
          </div>

          <div className="space-y-1">
            <h2 className="text-lg font-bold text-slate-900">
              Requirement Not Found
            </h2>
            <p className="text-xs text-slate-500 leading-relaxed">
              This requirement does not exist, was removed, or belongs to another company account under organization isolation rules.
            </p>
          </div>

          <Link
            href="/buyer/requirements"
            className="inline-flex items-center justify-center min-h-[48px] px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs font-bold shadow-sm transition-all w-full"
          >
            <ArrowLeft className="w-4 h-4 mr-2" />
            Return to Requirements Inbox
          </Link>
        </div>
      </div>
    )
  }

  const data = res.data

  return (
    <div className="w-full max-w-full overflow-x-hidden min-h-screen bg-slate-50/50 pb-20">
      {/* Navigation Header Bar */}
      <div className="bg-white border-b border-slate-200 px-4 py-3.5 flex items-center justify-between sticky top-0 z-30 shadow-xs">
        <div className="flex items-center gap-3">
          <BackButton fallbackUrl="/buyer/requirements" />
          <div>
            <h1 className="text-base font-bold text-slate-900 leading-tight">
              Requirement Overview
            </h1>
            <p className="text-xs text-slate-500 font-mono">
              REQ-{data.requirement.id.substring(0, 8).toUpperCase()}
            </p>
          </div>
        </div>

        <Link
          href="/buyer/requirements/new"
          className="inline-flex items-center justify-center min-h-[44px] px-4 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs font-bold shadow-sm transition-all"
        >
          <Plus className="w-4 h-4 mr-1 stroke-[2.5]" />
          New Requirement
        </Link>
      </div>

      {/* Main Content Area */}
      <div className="max-w-4xl mx-auto px-4 py-5 space-y-5">
        {/* Top-Level Summary & Partial Fulfillment Tracker Card */}
        <DetailFulfillmentCard data={data} />

        {/* Commercial & Quality Terms Grid */}
        <DetailTermsGrid data={data} />
      </div>
    </div>
  )
}
