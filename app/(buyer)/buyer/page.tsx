import { signOutAction } from "@/src/server/actions/auth-actions"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { createClient } from "@/lib/supabase/server"
import { getCompanyProfile } from "@/src/server/actions/company-actions"
import { CompanyOnboardingForm } from "@/src/components/forms/company-onboarding-form"
import { RequirementForm } from "@/src/components/forms/requirement-form"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { MyRequirementsTable } from "@/src/components/dashboard/my-requirements-table"
import { CompanyProfileCard } from "@/src/components/dashboard/company-profile-card"
import { BuyerQuotationsList } from "@/src/components/dashboard/buyer-quotations-list"
import { BuyerDealsTable } from "@/src/components/dashboard/buyer-deals-table"
import { RealtimeDealsListener } from "@/src/components/realtime-deals-listener"
import { PostRequirementDialog } from "@/src/components/dialogs/post-requirement-dialog"
import { BuyerHeaderDropdown } from "@/src/components/dashboard/buyer-header-dropdown"
import { getFullBuyerProfileDetailsAction } from "@/src/server/actions/user-profile-actions"
import { getBuyerKpisAction } from "@/src/server/actions/analytics-actions"
import { KpiCard, KpiGrid } from "@/src/components/dashboard/kpi-cards"
import { formatIndianCurrency } from "@/lib/utils"
import { Layers, Handshake, Wallet } from "lucide-react"

import { NotificationBell } from "@/src/components/layout/notification-bell"

export default async function BuyerDashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const [profileRes, fullProfileRes, kpisRes] = await Promise.all([
    getCompanyProfile(),
    getFullBuyerProfileDetailsAction(),
    getBuyerKpisAction(),
  ])
  const hasCompany = profileRes.success && !!profileRes.data
  const kpis = kpisRes.success ? kpisRes.data : null

  return (
    <div className={!hasCompany ? "flex min-h-screen items-center justify-center p-4 bg-slate-50 font-sans" : "flex flex-col min-h-screen w-full bg-[#F8FAFC] font-sans"}>
      <RealtimeDealsListener />
      {!hasCompany ? (
        <Card className="w-full max-w-2xl">
          <CardHeader>
            <CardTitle className="text-2xl text-primary">Action Required</CardTitle>
            <CardDescription className="text-base font-medium">
              Please complete your Company Profile to activate your trading account.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <CompanyOnboardingForm />
          </CardContent>
          <CardFooter className="justify-center border-t pt-4">
            <form action={signOutAction}>
              <Button type="submit" variant="ghost" size="sm">
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
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-lg bg-slate-900 flex items-center justify-center shadow-sm">
                  <span className="text-white font-bold text-xs tracking-tighter">BB</span>
                </div>
                <span className="font-semibold text-slate-900 hidden sm:inline-block">BrokerBridge</span>
              </div>
              <div className="flex items-center gap-3">
                <NotificationBell />
                <BuyerHeaderDropdown profile={profileRes.data} fullProfile={fullProfileRes.data} />
              </div>
            </div>
          </header>

          <Tabs defaultValue="requirements" className="flex flex-col flex-1 w-full">
            {/* SUB-HEADER & TABS */}
            <div className="w-full bg-white border-b border-border shrink-0">
              <div className="w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8">
                
                {/* Page Title & Primary Action */}
                <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center pt-6 pb-4 gap-4">
                  <div>
                    <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">Buyer Hub</h1>
                    <p className="text-sm sm:text-base text-slate-500 mt-1">Manage your requirements and deals.</p>
                  </div>
                  <div className="w-full sm:w-auto">
                    <PostRequirementDialog />
                  </div>
                </div>

                {/* KPI Overview Grid */}
                <div className="pb-6">
                  <KpiGrid className="grid-cols-1 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-3">
                    <KpiCard 
                      title="Active Requirements" 
                      value={kpis?.activeRequirementsCount ?? 0}
                      icon={Layers}
                      badgeColor="blue"
                      description="Open & partially fulfilled"
                    />
                    <KpiCard 
                      title="Booked Deals" 
                      value={kpis?.bookedDealsCount ?? 0}
                      icon={Handshake}
                      badgeColor="indigo"
                      description="Total confirmed transactions"
                    />
                    <KpiCard 
                      title="Total Value Spent" 
                      value={formatIndianCurrency(kpis?.totalSpent ?? 0)}
                      icon={Wallet}
                      badgeColor="emerald"
                      description="Cumulative deal value"
                    />
                  </KpiGrid>
                </div>

                {/* Full-Width Tabs List */}
                <TabsList className="flex h-auto w-full justify-start gap-6 p-0 bg-transparent rounded-none overflow-x-auto overflow-y-hidden flex-nowrap scrollbar-hide">
                  <TabsTrigger value="requirements" className="flex-shrink-0 min-h-[48px] data-[state=active]:border-b-2 data-[state=active]:border-[#1D4ED8] data-[state=active]:text-[#1D4ED8] data-[state=active]:shadow-none data-[state=active]:bg-transparent bg-transparent rounded-none px-1 pb-3 font-medium text-slate-500 text-sm sm:text-base">Requirements</TabsTrigger>
                  <TabsTrigger value="quotations" className="flex-shrink-0 min-h-[48px] data-[state=active]:border-b-2 data-[state=active]:border-[#1D4ED8] data-[state=active]:text-[#1D4ED8] data-[state=active]:shadow-none data-[state=active]:bg-transparent bg-transparent rounded-none px-1 pb-3 font-medium text-slate-500 text-sm sm:text-base">Offers</TabsTrigger>
                  <TabsTrigger value="deals" className="flex-shrink-0 min-h-[48px] data-[state=active]:border-b-2 data-[state=active]:border-[#1D4ED8] data-[state=active]:text-[#1D4ED8] data-[state=active]:shadow-none data-[state=active]:bg-transparent bg-transparent rounded-none px-1 pb-3 font-medium text-slate-500 text-sm sm:text-base">Deals</TabsTrigger>
                </TabsList>
              </div>
            </div>

            {/* CONTENT CANVAS */}
            <div className="flex-1 w-full bg-[#F8FAFC]">
              <div className="w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
                <TabsContent value="requirements" className="mt-0">
                  <MyRequirementsTable />
                </TabsContent>

                <TabsContent value="quotations" className="mt-0">
                  <BuyerQuotationsList />
                </TabsContent>

                <TabsContent value="deals" className="mt-0 outline-none">
                  <BuyerDealsTable />
                </TabsContent>
              </div>
            </div>
          </Tabs>
        </>
      )}
    </div>
  )
}
