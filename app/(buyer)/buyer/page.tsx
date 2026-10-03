import React from 'react';
import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';
import { getBuyerDashboardSummaryAction } from '@/src/server/actions/buyer-dashboard-actions';
import { BuyerDashboardHeader } from '@/src/components/buyer/dashboard/buyer-dashboard-header';
import { BuyerKpiGrid } from '@/src/components/buyer/dashboard/buyer-kpi-grid';
import { BuyerActionFeed } from '@/src/components/buyer/dashboard/buyer-action-feed';
import { BuyerActivePipeline } from '@/src/components/buyer/dashboard/buyer-active-pipeline';
import { CompanyOnboardingForm } from '@/src/components/forms/company-onboarding-form';

export const dynamic = 'force-dynamic';

export default async function BuyerDashboardPage() {
  const sessionRes = await verifyBuyerSession();

  // Onboarding Gate Failsafe
  if (!sessionRes.success || !sessionRes.data?.company) {
    return (
      <div className="w-full max-w-2xl mx-auto p-4 sm:p-6">
        <CompanyOnboardingForm />
      </div>
    );
  }

  const { company } = sessionRes.data;

  // Fetch unified dashboard payload
  const summaryRes = await getBuyerDashboardSummaryAction();
  const summaryData = summaryRes.data;

  return (
    <div className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6 w-full max-w-full overflow-hidden">
      {/* Task 2: Procurement Command Center Header */}
      <BuyerDashboardHeader
        companyName={company.name}
        isVerified={company.isVerified}
      />

      {/* Task 3: 4-Metric KPI Grid */}
      <BuyerKpiGrid kpis={summaryData.kpis} />

      {/* Task 4: P0 Action Required Feed */}
      <BuyerActionFeed actionItems={summaryData.actionRequired} />

      {/* Task 5: Pipeline & Live Fulfillment Cards */}
      <BuyerActivePipeline
        recentRequirements={summaryData.recentRequirements}
        activeShipments={summaryData.activeShipments}
      />
    </div>
  );
}
