import { signOutAction } from "@/src/server/actions/auth-actions"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { createClient } from "@/lib/supabase/server"
import { getCompanyProfile } from "@/src/server/actions/company-actions"
import { CompanyOnboardingForm } from "@/src/components/forms/company-onboarding-form"
import { RealtimeDealsListener } from "@/src/components/realtime-deals-listener"
import { getFullBuyerProfileDetailsAction } from "@/src/server/actions/user-profile-actions"
import { getMyAvailabilitiesAction } from "@/src/server/actions/availability-actions"
import { getDealsByCompanyAction } from "@/src/server/actions/deal-actions"
import { getMasterVehicleTypesAction } from "@/src/server/actions/master-data-actions"
import { getSellerCommandCenterDataAction, SellerCommandCenterData } from "@/src/server/actions/analytics-actions"
import { getSellerBrokerRequestsAction } from "@/src/server/actions/broker-request-actions"
import { SellerWorkspaceShell } from "@/src/components/dashboard/seller-workspace-shell"

export default async function SellerDashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const profileRes = await getCompanyProfile()
  const hasCompany = profileRes.success && !!profileRes.data

  let availabilities: any[] = []
  let deals: any[] = []
  let brokerRequests: any[] = []
  let vehicleTypes: any[] = []
  let fullProfileData: any = null
  let commandCenterData: SellerCommandCenterData | undefined = undefined
  let userRole = "SELLER_ADMIN"

  if (hasCompany) {
    const [availabilitiesRes, dealsRes, brokerRequestsRes, vehicleTypesRes, fullProfileRes, commandCenterRes] = await Promise.all([
      getMyAvailabilitiesAction(),
      getDealsByCompanyAction(),
      getSellerBrokerRequestsAction(),
      getMasterVehicleTypesAction(),
      getFullBuyerProfileDetailsAction(),
      getSellerCommandCenterDataAction(),
    ])

    if (availabilitiesRes.success && availabilitiesRes.data) {
      availabilities = availabilitiesRes.data
    }
    if (dealsRes.success && dealsRes.data) {
      deals = dealsRes.data
    }
    if (brokerRequestsRes.success && brokerRequestsRes.data) {
      brokerRequests = brokerRequestsRes.data
    }
    if (vehicleTypesRes.success && vehicleTypesRes.data) {
      vehicleTypes = vehicleTypesRes.data
    }
    if (fullProfileRes.success && fullProfileRes.data) {
      fullProfileData = fullProfileRes.data
      if (fullProfileData.user?.role) {
        userRole = fullProfileData.user.role
      }
    }
    if (commandCenterRes.success && commandCenterRes.data) {
      commandCenterData = commandCenterRes.data
    }
  }

  return (
    <div className={!hasCompany ? "flex min-h-screen items-center justify-center p-4 bg-slate-50 font-sans antialiased" : "min-h-screen w-full bg-[#F8FAFC] font-sans antialiased"}>
      <RealtimeDealsListener />
      
      {!hasCompany ? (
        <Card className="w-full max-w-2xl shadow-xl border-slate-200/90 rounded-2xl">
          <CardHeader className="p-6 sm:p-8 border-b border-slate-100 bg-slate-50/50">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-slate-900 flex items-center justify-center shadow-xs text-white font-bold text-sm">
                BB
              </div>
              <div>
                <CardTitle className="text-xl sm:text-2xl font-extrabold text-slate-900">
                  Complete Seller Onboarding
                </CardTitle>
                <CardDescription className="text-xs sm:text-sm text-slate-500 mt-0.5">
                  Enter your verified company details to access the Seller Trading Command Center.
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent className="p-6 sm:p-8">
            <CompanyOnboardingForm />
          </CardContent>
          <CardFooter className="justify-center border-t border-slate-100 p-4 bg-slate-50/30">
            <form action={signOutAction}>
              <Button type="submit" variant="ghost" size="sm" className="text-slate-500 hover:text-slate-800 text-xs">
                Sign out of session
              </Button>
            </form>
          </CardFooter>
        </Card>
      ) : (
        <SellerWorkspaceShell 
          profile={profileRes.data}
          fullProfile={fullProfileData}
          userRole={userRole}
          availabilities={availabilities}
          deals={deals}
          brokerRequests={brokerRequests}
          vehicleTypes={vehicleTypes}
          commandCenterData={commandCenterData}
        />
      )}
    </div>
  )
}
