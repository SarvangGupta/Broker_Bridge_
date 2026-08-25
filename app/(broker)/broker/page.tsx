import { signOutAction } from "@/src/server/actions/auth-actions"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { createClient } from "@/lib/supabase/server"
import { getCompanyProfile } from "@/src/server/actions/company-actions"
import { CompanyProfileCard } from "@/src/components/dashboard/company-profile-card"
import { CrmTaskFeed } from "@/src/components/dashboard/crm-task-feed"
import { AiMatchCenter } from "@/src/components/dashboard/ai-match-center"
import { QuotationsDealsTab } from "@/src/components/dashboard/quotations-deals-tab"
import { RealtimeDealsListener } from "@/src/components/realtime-deals-listener"
import { BrokerHeaderDropdown } from "@/src/components/dashboard/broker-header-dropdown"
import { getFullBuyerProfileDetailsAction } from "@/src/server/actions/user-profile-actions"
import { getTasksAction } from "@/src/server/actions/crm-actions"
import { getBrokerKpisAction } from "@/src/server/actions/analytics-actions"
import { KpiCard, KpiGrid } from "@/src/components/dashboard/kpi-cards"
import { formatIndianCurrency } from "@/lib/utils"
import { Coins, Handshake, Layers } from "lucide-react"
import { NotificationBell } from "@/src/components/layout/notification-bell"
import { isToday, isPast } from "date-fns"

export default async function BrokerDashboard() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const [profileRes, fullProfileRes, tasksRes, kpisRes] = await Promise.all([
    getCompanyProfile(),
    getFullBuyerProfileDetailsAction(),
    getTasksAction(),
    getBrokerKpisAction(),
  ])

  const profile = profileRes.success ? profileRes.data : null
  const fullProfileData = fullProfileRes.success ? fullProfileRes.data : null
  const tasks = tasksRes.success ? (tasksRes.data || []) : []
  const kpis = kpisRes.success ? kpisRes.data : null

  const hasPendingTasksToday = tasks.some((task: any) => {
    if (task.status !== 'Pending') return false
    const due = new Date(task.dueDate)
    return isToday(due) || isPast(due)
  })

  return (
    <div className="flex flex-col min-h-screen w-full bg-[#F8FAFC] font-sans">
      <RealtimeDealsListener />

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
            <BrokerHeaderDropdown profile={profile} fullProfile={fullProfileData} />
          </div>
        </div>
      </header>

      <Tabs defaultValue="aimatch" className="flex flex-col flex-1 w-full">
        {/* SUB-HEADER & TABS */}
        <div className="w-full bg-white border-b border-border shrink-0">
          <div className="w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8">
            
            {/* Page Title */}
            <div className="pt-6 pb-4">
              <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-900">Broker Workstation</h1>
              <p className="text-sm sm:text-base text-slate-500 mt-1">Manage your matches, clients, and CRM tasks.</p>
            </div>

            {/* KPI Overview Grid */}
            <div className="pb-6">
              <KpiGrid className="grid-cols-1 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-3">
                <KpiCard 
                  title="My Deal Value" 
                  value={formatIndianCurrency(kpis?.myGmv ?? 0)}
                  icon={Coins}
                  badgeColor="teal"
                  description="Cumulative brokered volume"
                />
                <KpiCard 
                  title="Active Deals" 
                  value={kpis?.activeDealsCount ?? 0}
                  icon={Handshake}
                  badgeColor="indigo"
                  description="In progress & dispatches"
                />
                <KpiCard 
                  title="Assigned Requirements" 
                  value={kpis?.openRequirementsCount ?? 0}
                  icon={Layers}
                  badgeColor="amber"
                  description="Open matching opportunities"
                />
              </KpiGrid>
            </div>

            {/* Refined Business Tabs List */}
            <TabsList className="flex h-auto w-full justify-start gap-6 p-0 bg-transparent rounded-none overflow-x-auto overflow-y-hidden flex-nowrap scrollbar-hide">
              <TabsTrigger 
                value="aimatch" 
                className="flex-shrink-0 min-h-[48px] data-[state=active]:border-b-2 data-[state=active]:border-[#0D9488] data-[state=active]:text-[#0D9488] data-[state=active]:shadow-none data-[state=active]:bg-transparent bg-transparent rounded-none px-1 pb-3 font-semibold text-slate-500 text-sm sm:text-base cursor-pointer transition-colors"
              >
                AI Match Center
              </TabsTrigger>
              <TabsTrigger 
                value="quotations" 
                className="flex-shrink-0 min-h-[48px] data-[state=active]:border-b-2 data-[state=active]:border-[#0D9488] data-[state=active]:text-[#0D9488] data-[state=active]:shadow-none data-[state=active]:bg-transparent bg-transparent rounded-none px-1 pb-3 font-semibold text-slate-500 text-sm sm:text-base cursor-pointer transition-colors"
              >
                Quotations & Deals
              </TabsTrigger>
              <TabsTrigger 
                value="crm" 
                className="flex-shrink-0 min-h-[48px] data-[state=active]:border-b-2 data-[state=active]:border-[#0D9488] data-[state=active]:text-[#0D9488] data-[state=active]:shadow-none data-[state=active]:bg-transparent bg-transparent rounded-none px-1 pb-3 font-semibold text-slate-500 text-sm sm:text-base cursor-pointer transition-colors relative flex items-center gap-2"
              >
                <span>CRM & Tasks</span>
                {hasPendingTasksToday && (
                  <span className="relative flex h-2.5 w-2.5">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-rose-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-rose-500"></span>
                  </span>
                )}
              </TabsTrigger>
              <TabsTrigger 
                value="workstation" 
                className="flex-shrink-0 min-h-[48px] data-[state=active]:border-b-2 data-[state=active]:border-[#0D9488] data-[state=active]:text-[#0D9488] data-[state=active]:shadow-none data-[state=active]:bg-transparent bg-transparent rounded-none px-1 pb-3 font-semibold text-slate-500 text-sm sm:text-base cursor-pointer transition-colors"
              >
                My Workstation
              </TabsTrigger>
            </TabsList>
          </div>
        </div>

        {/* CONTENT CANVAS */}
        <div className="flex-1 w-full bg-[#F8FAFC]">
          <div className="w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <TabsContent value="aimatch" className="mt-0 outline-none">
              <AiMatchCenter />
            </TabsContent>
            
            <TabsContent value="quotations" className="mt-0 outline-none">
              <QuotationsDealsTab />
            </TabsContent>
            
            <TabsContent value="crm" className="mt-0 outline-none">
              <CrmTaskFeed />
            </TabsContent>
            
            <TabsContent value="workstation" className="mt-0 outline-none">
              {profile ? (
                <CompanyProfileCard profile={profile as any} />
              ) : (
                <Card className="bg-white rounded-2xl border border-slate-200/80 shadow-sm p-6">
                  <CardHeader className="p-0 pb-4">
                    <CardTitle className="text-xl font-bold text-slate-900">Broker Profile</CardTitle>
                    <CardDescription className="text-sm text-slate-500">User: {user?.email}</CardDescription>
                  </CardHeader>
                  <CardContent className="p-0 pt-2">
                    <div className="p-6 bg-slate-50 rounded-xl border border-slate-200/60 text-sm text-slate-500 text-center">
                      No linked brokerage firm profile found. Use Profile Settings in the top right to configure your firm.
                    </div>
                  </CardContent>
                </Card>
              )}
            </TabsContent>
          </div>
        </div>
      </Tabs>
    </div>
  )
}
