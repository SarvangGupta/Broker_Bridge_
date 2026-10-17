import { SignOutButton } from "@/src/components/auth/sign-out-button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { createClient } from "@/lib/supabase/server"
import { getCompanyProfile } from "@/src/server/actions/company-actions"
import { CompanyOnboardingForm } from "@/src/components/forms/company-onboarding-form"
import { RealtimeDealsListener } from "@/src/components/realtime-deals-listener"
import { getMyAvailabilitiesAction } from "@/src/server/actions/availability-actions"
import { getDealsByCompanyAction } from "@/src/server/actions/deal-actions"
import { getMasterVehicleTypesAction } from "@/src/server/actions/master-data-actions"
import { getSellerCommandCenterDataAction, SellerCommandCenterData } from "@/src/server/actions/analytics-actions"
import { getSellerBrokerRequestsAction } from "@/src/server/actions/broker-request-actions"
import { getSellerGlobalLabReportsAction, SellerGlobalLabReportItem } from "@/src/server/actions/lab-actions"
import { SellerWorkspaceShell } from "@/src/components/dashboard/seller-workspace-shell"
import { Clock, XCircle } from "lucide-react"

export const dynamic = "force-dynamic"
export const revalidate = 0

export default async function SellerDashboard() {
  const profileRes = await getCompanyProfile()
  const onboardingStatus = profileRes.status || 'NONE'
  const companyId = profileRes.data?.id || null
  const dbUser = profileRes.user || null

  let availabilities: any[] = []
  let deals: any[] = []
  let brokerRequests: any[] = []
  let vehicleTypes: any[] = []
  let labReports: SellerGlobalLabReportItem[] = []
  let commandCenterData: SellerCommandCenterData | undefined = undefined
  const userRole = dbUser?.role || "SELLER_ADMIN"

  const isApproved = onboardingStatus === 'APPROVED' && Boolean(companyId)

  if (isApproved) {
    const [availabilitiesRes, dealsRes, brokerRequestsRes, vehicleTypesRes, labReportsRes, commandCenterRes] = await Promise.all([
      getMyAvailabilitiesAction(),
      getDealsByCompanyAction(),
      getSellerBrokerRequestsAction(),
      getMasterVehicleTypesAction(),
      getSellerGlobalLabReportsAction(),
      getSellerCommandCenterDataAction(),
    ])

    if (availabilitiesRes.success && availabilitiesRes.data) availabilities = availabilitiesRes.data
    if (dealsRes.success && dealsRes.data) deals = dealsRes.data
    if (brokerRequestsRes.success && brokerRequestsRes.data) brokerRequests = brokerRequestsRes.data
    if (vehicleTypesRes.success && vehicleTypesRes.data) vehicleTypes = vehicleTypesRes.data
    if (labReportsRes.success && labReportsRes.data) labReports = labReportsRes.data
    if (commandCenterRes.success && commandCenterRes.data) commandCenterData = commandCenterRes.data
  }

  // 1. APPROVED STATUS & VALID COMPANY: Full Workspace
  if (isApproved) {
    return (
      <div className="w-full bg-[#F8FAFC] font-sans antialiased">
        <RealtimeDealsListener />
        <SellerWorkspaceShell 
          profile={profileRes.data}
          fullProfile={{ user: dbUser, company: profileRes.data }}
          userRole={userRole}
          availabilities={availabilities}
          deals={deals}
          brokerRequests={brokerRequests}
          vehicleTypes={vehicleTypes}
          labReports={labReports}
          commandCenterData={commandCenterData}
        />
      </div>
    )
  }

  // 2. PENDING STATUS: Verification in Progress
  if (onboardingStatus === 'PENDING') {
    return (
      <div className="w-full flex items-center justify-center p-4">
        <RealtimeDealsListener />
        <Card className="w-full max-w-xl bg-white shadow-xl border border-slate-200/90 rounded-2xl overflow-hidden text-center">
          <CardHeader className="p-8 sm:p-10 flex flex-col items-center border-b border-slate-100 bg-gradient-to-b from-amber-50/40 to-white">
            <div className="w-14 h-14 rounded-2xl bg-amber-100/80 text-amber-700 border border-amber-200 flex items-center justify-center mb-5 shadow-xs">
              <Clock className="h-7 w-7 animate-pulse" />
            </div>
            <span className="px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-amber-100 text-amber-800 border border-amber-200/80 mb-3">
              Verification in Progress
            </span>
            <CardTitle className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
              Verification in Progress
            </CardTitle>
            <CardDescription className="text-sm sm:text-base text-slate-600 mt-2 max-w-md leading-relaxed">
              Your company profile has been submitted. Our Super Admin is currently reviewing your details. We will contact you soon once approved.
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
    )
  }

  // 3. REJECTED STATUS: Destructive Red Accent Card
  if (onboardingStatus === 'REJECTED') {
    return (
      <div className="w-full flex items-center justify-center p-4">
        <RealtimeDealsListener />
        <Card className="w-full max-w-xl bg-white shadow-xl border border-rose-200/90 rounded-2xl overflow-hidden text-center">
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
              Unfortunately, your company profile did not pass our verification checks. Please contact the platform administrator for assistance.
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
    )
  }

  // 4. NONE STATUS / MISSING COMPANY ID: Initial Onboarding Form Card
  return (
    <div className="w-full flex items-center justify-center">
      <RealtimeDealsListener />
      <Card className="w-full max-w-2xl bg-white shadow-[0_12px_40px_rgb(0,0,0,0.06)] border border-slate-200/90 rounded-2xl overflow-hidden mx-auto my-8">
        <CardHeader className="p-6 sm:p-8 border-b border-slate-100 bg-gradient-to-b from-slate-50/80 to-white">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="w-11 h-11 rounded-xl bg-slate-900 flex items-center justify-center shadow-md text-white font-bold text-base tracking-tight">
                BB
              </div>
              <div>
                <div className="text-xs font-bold tracking-wider uppercase text-slate-500">
                  Seller Commodities
                </div>
                <CardTitle className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
                  Complete Seller Onboarding
                </CardTitle>
              </div>
            </div>
            <span className="hidden sm:inline-flex px-3 py-1 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200/60">
              Step 2 of 2
            </span>
          </div>
          <CardDescription className="text-sm text-slate-600 leading-relaxed">
            Enter your verified company details to access the Seller Trading Dashboard and publish commodity inventory.
          </CardDescription>
        </CardHeader>
        <CardContent className="p-6 sm:p-8 bg-slate-50/20">
          <CompanyOnboardingForm />
        </CardContent>
        <CardFooter className="flex items-center justify-between border-t border-slate-100 px-6 sm:px-8 py-4 bg-slate-50/50 text-xs text-slate-500">
          <span>Wrong account? Sign out safely anytime.</span>
          <SignOutButton className="text-slate-600 hover:text-slate-900 text-xs font-medium cursor-pointer" />
        </CardFooter>
      </Card>
    </div>
  )
}
