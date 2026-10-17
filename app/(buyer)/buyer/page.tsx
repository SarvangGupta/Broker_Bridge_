import { getCompanyProfile } from '@/src/server/actions/company-actions';
import { getBuyerDashboardSummaryAction } from '@/src/server/actions/buyer-dashboard-actions';
import { BuyerDashboardHeader } from '@/src/components/buyer/dashboard/buyer-dashboard-header';
import { BuyerKpiGrid } from '@/src/components/buyer/dashboard/buyer-kpi-grid';
import { BuyerActionFeed } from '@/src/components/buyer/dashboard/buyer-action-feed';
import { BuyerActivePipeline } from '@/src/components/buyer/dashboard/buyer-active-pipeline';
import { CompanyOnboardingForm } from '@/src/components/forms/company-onboarding-form';

import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '@/components/ui/card';
import { SignOutButton } from '@/src/components/auth/sign-out-button';
import { Clock, XCircle } from 'lucide-react';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function BuyerDashboardPage() {
  const profileRes = await getCompanyProfile();
  const onboardingStatus = profileRes.status || 'NONE';
  const isApproved = onboardingStatus === 'APPROVED' && Boolean(profileRes.data?.id);

  // 1. PENDING STATUS: Verification in Progress
  if (onboardingStatus === 'PENDING') {
    return (
      <div className="w-full flex items-center justify-center p-4">
        <Card className="w-full max-w-xl bg-white shadow-xl border border-slate-200/90 rounded-2xl overflow-hidden text-center mx-auto my-8">
          <CardHeader className="p-8 sm:p-10 flex flex-col items-center border-b border-slate-100 bg-gradient-to-b from-amber-50/40 to-white">
            <div className="w-14 h-14 rounded-2xl bg-amber-100/80 text-amber-700 border border-amber-200 flex items-center justify-center mb-5 shadow-xs">
              <Clock className="h-7 w-7 animate-pulse text-amber-600" />
            </div>
            <span className="px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-amber-100 text-amber-800 border border-amber-200/80 mb-3">
              Verification in Progress
            </span>
            <CardTitle className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              Verification in Progress
            </CardTitle>
            <CardDescription className="text-sm sm:text-base text-slate-600 mt-2 max-w-md leading-relaxed">
              Your company profile has been submitted. Our Super Admin is currently reviewing your details. Once approved, you will gain full access to the Buyer Procurement Workspace.
            </CardDescription>
          </CardHeader>
          <CardContent className="p-6 bg-slate-50/30 text-xs text-slate-500">
            Company Submitted: <span className="font-semibold text-slate-700">{profileRes.data?.name || 'Company Profile'}</span>
          </CardContent>
          <CardFooter className="justify-center border-t border-slate-100 p-4 bg-slate-50/50">
            <SignOutButton />
          </CardFooter>
        </Card>
      </div>
    );
  }

  // 2. REJECTED STATUS: Registration Rejected
  if (onboardingStatus === 'REJECTED') {
    return (
      <div className="w-full flex items-center justify-center p-4">
        <Card className="w-full max-w-xl bg-white shadow-xl border border-rose-200/90 rounded-2xl overflow-hidden text-center mx-auto my-8">
          <CardHeader className="p-8 sm:p-10 flex flex-col items-center border-b border-rose-100 bg-gradient-to-b from-rose-50/40 to-white">
            <div className="w-14 h-14 rounded-2xl bg-rose-100/80 text-rose-700 border border-rose-200 flex items-center justify-center mb-5 shadow-xs">
              <XCircle className="h-7 w-7 text-rose-600" />
            </div>
            <span className="px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-rose-100 text-rose-800 border border-rose-200/80 mb-3">
              Registration Status: Rejected
            </span>
            <CardTitle className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              Registration Rejected
            </CardTitle>
            <CardDescription className="text-sm sm:text-base text-slate-600 mt-2 max-w-md leading-relaxed">
              Unfortunately, your company profile did not pass verification checks. Please contact the platform administrator for assistance.
            </CardDescription>
          </CardHeader>
          <CardContent className="p-6 bg-slate-50/30 text-xs text-slate-500">
            Company Profile: <span className="font-semibold text-slate-700">{profileRes.data?.name || 'Submitted Profile'}</span>
          </CardContent>
          <CardFooter className="justify-center border-t border-slate-100 p-4 bg-slate-50/50">
            <SignOutButton />
          </CardFooter>
        </Card>
      </div>
    );
  }

  // 3. NONE STATUS: Initial Onboarding Form Card
  if (!isApproved || !profileRes.data?.id) {
    return (
      <div className="w-full max-w-2xl mx-auto my-auto py-8 px-4">
        <Card className="bg-white shadow-[0_12px_40px_rgb(0,0,0,0.06)] border border-slate-200/90 rounded-2xl overflow-hidden">
          {/* Card Header */}
          <CardHeader className="p-6 sm:p-8 border-b border-slate-100 bg-gradient-to-b from-slate-50/80 to-white">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-xl bg-slate-900 flex items-center justify-center shadow-md text-white font-bold text-base tracking-tight">
                  BB
                </div>
                <div>
                  <div className="text-xs font-bold tracking-wider uppercase text-slate-500">
                    Buyer Procurement
                  </div>
                  <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
                    Complete Buyer Onboarding
                  </h1>
                </div>
              </div>
              <span className="hidden sm:inline-flex px-3 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200/60">
                Step 2 of 2
              </span>
            </div>
            <p className="text-sm text-slate-600 leading-relaxed">
              Enter your registered business details to activate your buyer account and start sourcing commodities on BrokerBridge.
            </p>
          </CardHeader>

          {/* Form Content */}
          <CardContent className="p-6 sm:p-8 bg-slate-50/20">
            <CompanyOnboardingForm />
          </CardContent>

          {/* Card Footer */}
          <CardFooter className="flex items-center justify-between border-t border-slate-100 px-6 sm:px-8 py-4 bg-slate-50/50 text-xs text-slate-500">
            <span>Wrong account? Sign out safely anytime.</span>
            <SignOutButton className="text-slate-600 hover:text-slate-900 text-xs font-medium cursor-pointer" />
          </CardFooter>
        </Card>
      </div>
    );
  }

  const company = profileRes.data!;

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
