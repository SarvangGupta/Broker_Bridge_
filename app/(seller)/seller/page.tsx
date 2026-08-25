import { signOutAction } from "@/src/server/actions/auth-actions"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { createClient } from "@/lib/supabase/server"
import { getCompanyProfile } from "@/src/server/actions/company-actions"
import { CompanyOnboardingForm } from "@/src/components/forms/company-onboarding-form"
import { MyAvailabilitiesTable } from "@/src/components/dashboard/my-availabilities-table"
import { SellerDealsTable } from "@/src/components/dashboard/seller-deals-table"
import { RealtimeDealsListener } from "@/src/components/realtime-deals-listener"
import { PostAvailabilityDialog } from "@/src/components/dialogs/post-availability-dialog"
import { SellerHeaderDropdown } from "@/src/components/dashboard/seller-header-dropdown"
import { getFullBuyerProfileDetailsAction } from "@/src/server/actions/user-profile-actions"
import { getMyAvailabilitiesAction } from "@/src/server/actions/availability-actions"
import { getDealsByCompanyAction } from "@/src/server/actions/deal-actions"
import { getMasterVehicleTypesAction } from "@/src/server/actions/master-data-actions"
import { getSellerKpisAction } from "@/src/server/actions/analytics-actions"
import { KpiCard, KpiGrid } from "@/src/components/dashboard/kpi-cards"
import { formatIndianCurrency } from "@/lib/utils"
import { Package, Truck, TrendingUp } from "lucide-react"

import { NotificationBell } from "@/src/components/layout/notification-bell"

export default async function SellerDashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const profileRes = await getCompanyProfile()
  const hasCompany = profileRes.success && !!profileRes.data

  let availabilities: any[] = []
  let deals: any[] = []
  let vehicleTypes: any[] = []
  let fullProfileData: any = null
  let kpis: any = null

  if (hasCompany) {
    const [availabilitiesRes, dealsRes, vehicleTypesRes, fullProfileRes, kpisRes] = await Promise.all([
      getMyAvailabilitiesAction(),
      getDealsByCompanyAction(),
      getMasterVehicleTypesAction(),
      getFullBuyerProfileDetailsAction(),
      getSellerKpisAction(),
    ])

    if (availabilitiesRes.success && availabilitiesRes.data) {
      availabilities = availabilitiesRes.data
    }
    if (dealsRes.success && dealsRes.data) {
      deals = dealsRes.data
    }
    if (vehicleTypesRes.success && vehicleTypesRes.data) {
      vehicleTypes = vehicleTypesRes.data
    }
    if (fullProfileRes.success && fullProfileRes.data) {
      fullProfileData = fullProfileRes.data
    }
    if (kpisRes.success && kpisRes.data) {
      kpis = kpisRes.data
    }
  }

  return (
    <div className={!hasCompany ? "flex min-h-screen items-center justify-center p-4 bg-slate-50 font-sans" : "flex flex-col min-h-screen w-full bg-[#F8FAFC] font-sans"}>
      <RealtimeDealsListener />
      
      {!hasCompany ? (
        <Card className="w-full max-w-2xl shadow-lg border-slate-200">
          <CardHeader>
            <CardTitle className="text-2xl font-bold text-slate-900">Action Required</CardTitle>
            <CardDescription className="text-base text-slate-600">
              Please complete your Company Profile to activate your trading account.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <CompanyOnboardingForm />
          </CardContent>
          <CardFooter className="justify-center border-t pt-4">
            <form action={signOutAction}>
              <Button type="submit" variant="ghost" size="sm" className="text-slate-600 hover:text-slate-900">
                Sign Out
              </Button>
            </form>
          </CardFooter>
        </Card>
      ) : (
        <>
          {/* TOP NAV APP SHELL */}
          <header className="w-full bg-white border-b border-border h-16 flex items-center shrink-0">
            <div className="w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8 flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-slate-900 flex items-center justify-center shadow-sm">
                  <span className="text-white font-bold text-xs tracking-tighter">BB</span>
                </div>
                <span className="font-semibold text-slate-900 hidden sm:inline-block tracking-tight text-lg">BrokerBridge</span>
              </div>
              <div className="flex items-center gap-3">
                <NotificationBell />
                <SellerHeaderDropdown profile={profileRes.data} fullProfile={fullProfileData} />
              </div>
            </div>
          </header>

          <Tabs defaultValue="inventory" className="flex flex-col flex-1 w-full">
            {/* SUB-HEADER & TABS */}
            <div className="w-full bg-white border-b border-border shrink-0">
              <div className="w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8">
                
                {/* Page Title & Primary Action */}
                <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center pt-6 pb-4 gap-4">
                  <div>
                    <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">Seller Dashboard</h1>
                    <p className="text-sm sm:text-base text-slate-500 mt-1">Manage your active inventory availabilities.</p>
                  </div>
                  <div className="w-full sm:w-auto">
                    <PostAvailabilityDialog />
                  </div>
                </div>

                {/* KPI Overview Grid */}
                <div className="pb-6">
                  <KpiGrid className="grid-cols-1 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-3">
                    <KpiCard 
                      title="Active Inventory" 
                      value={kpis?.activeAvailabilitiesCount ?? 0}
                      icon={Package}
                      badgeColor="emerald"
                      description="Open listed lots"
                    />
                    <KpiCard 
                      title="Pending Dispatches" 
                      value={kpis?.pendingDispatchesCount ?? 0}
                      icon={Truck}
                      badgeColor="amber"
                      description="Awaiting logistics dispatch"
                    />
                    <KpiCard 
                      title="Total Revenue" 
                      value={formatIndianCurrency(kpis?.totalRevenue ?? 0)}
                      icon={TrendingUp}
                      badgeColor="indigo"
                      description="Cumulative deal revenue"
                    />
                  </KpiGrid>
                </div>

                {/* Refined Business Tabs List */}
                <TabsList className="flex h-auto w-full justify-start gap-6 p-0 bg-transparent rounded-none overflow-x-auto overflow-y-hidden flex-nowrap scrollbar-hide">
                  <TabsTrigger 
                    value="inventory" 
                    className="flex-shrink-0 min-h-[48px] data-[state=active]:border-b-2 data-[state=active]:border-[#059669] data-[state=active]:text-[#059669] data-[state=active]:shadow-none data-[state=active]:bg-transparent bg-transparent rounded-none px-1 pb-3 font-semibold text-slate-500 text-sm sm:text-base cursor-pointer transition-colors"
                  >
                    My Inventory
                  </TabsTrigger>
                  <TabsTrigger 
                    value="deals" 
                    className="flex-shrink-0 min-h-[48px] data-[state=active]:border-b-2 data-[state=active]:border-[#059669] data-[state=active]:text-[#059669] data-[state=active]:shadow-none data-[state=active]:bg-transparent bg-transparent rounded-none px-1 pb-3 font-semibold text-slate-500 text-sm sm:text-base cursor-pointer transition-colors"
                  >
                    My Deals
                  </TabsTrigger>
                </TabsList>
              </div>
            </div>

            {/* CONTENT CANVAS */}
            <div className="flex-1 w-full bg-[#F8FAFC]">
              <div className="w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
                <TabsContent value="inventory" className="mt-0 outline-none">
                  <MyAvailabilitiesTable availabilities={availabilities as any} />
                </TabsContent>

                <TabsContent value="deals" className="mt-0 outline-none">
                  <SellerDealsTable deals={deals} vehicleTypes={vehicleTypes} />
                </TabsContent>
              </div>
            </div>
          </Tabs>
        </>
      )}
    </div>
  )
}
