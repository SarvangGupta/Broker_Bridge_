import React from 'react'
import { RequirementWizard } from '@/src/components/buyer/requirements/requirement-wizard'
import { BackButton } from '@/src/components/ui/back-button'

export const dynamic = 'force-dynamic'

export default function NewBuyerRequirementPage() {
  return (
    <div className="w-full max-w-full overflow-x-hidden min-h-screen bg-slate-50/50">
      {/* Top Header */}
      <div className="bg-white border-b border-slate-200 px-4 py-3.5 flex items-center justify-between sticky top-0 z-30">
        <div className="flex items-center gap-3">
          <BackButton fallbackUrl="/buyer/requirements" />
          <div>
            <h1 className="text-base font-bold text-slate-900 leading-tight">
              Create Procurement Requirement
            </h1>
            <p className="text-xs text-slate-500">
              Post a new demand request to the BrokerBridge Deal Desk
            </p>
          </div>
        </div>
      </div>

      {/* 6-Step Wizard */}
      <RequirementWizard />
    </div>
  )
}
