'use client'

import React, { useState } from 'react'
import { SellerHeader } from '@/src/components/dashboard/seller-header'
import { SellerNav } from '@/src/components/dashboard/seller-nav'
import { MyAvailabilitiesTable } from '@/src/components/dashboard/my-availabilities-table'
import { SellerDealsTable } from '@/src/components/dashboard/seller-deals-table'
import { PostAvailabilityDialog } from '@/src/components/dialogs/post-availability-dialog'
import { ActionRequiredBanner } from '@/src/components/dashboard/action-required-banner'
import { KpiCard, KpiGrid } from '@/src/components/dashboard/kpi-cards'
import { DataFreshness } from '@/src/components/ui/data-freshness'
import { formatIndianCurrency } from '@/lib/utils'
import { 
  Package, 
  Truck, 
  TrendingUp, 
  FlaskConical, 
  Handshake, 
  FolderLock, 
  Wallet, 
  Users, 
  ShieldCheck, 
  FileText,
  AlertCircle,
  ArrowRight,
  Sparkles
} from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { SellerCommandCenterData } from '@/src/server/actions/analytics-actions'

interface SellerWorkspaceShellProps {
  profile: any
  fullProfile?: any
  userRole?: string
  availabilities: any[]
  deals: any[]
  vehicleTypes: any[]
  commandCenterData?: SellerCommandCenterData
}

export function SellerWorkspaceShell({
  profile,
  fullProfile,
  userRole = "SELLER_ADMIN",
  availabilities,
  deals,
  vehicleTypes,
  commandCenterData,
}: SellerWorkspaceShellProps) {
  // Default to Command Center dashboard tab
  const [activeTab, setActiveTab] = useState('dashboard')
  const [mobileNavOpen, setMobileNavOpen] = useState(false)

  const companyName = fullProfile?.company?.name || profile?.name || "Seller Trading Workspace"
  const kpis = commandCenterData?.kpis || {
    activeAvailabilitiesCount: availabilities.length,
    pendingDispatchesCount: deals.filter(d => d.deal.status === 'Dispatch Pending').length,
    totalRevenue: 0,
  }
  const actionItems = commandCenterData?.actionItems || []

  return (
    <div className="flex flex-col min-h-screen w-full bg-[#F8FAFC] font-sans antialiased overflow-x-hidden">
      
      {/* 1. TOP STICKY HEADER */}
      <SellerHeader 
        profile={profile} 
        fullProfile={fullProfile} 
        userRole={userRole} 
        onMobileMenuToggle={() => setMobileNavOpen(true)}
      />

      {/* 2. RESPONSIVE MODULE SUB-NAV */}
      <SellerNav 
        activeTab={activeTab} 
        onTabChange={setActiveTab} 
        userRole={userRole}
        mobileOpen={mobileNavOpen}
        onMobileOpenChange={setMobileNavOpen}
        companyName={companyName}
      />

      {/* 3. MAIN WORKSPACE CANVAS */}
      <main className="flex-1 w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        
        {/* ========================================================================= */}
        {/* TAB 1: SELLER COMMAND CENTER (OPERATIONAL DASHBOARD)                       */}
        {/* ========================================================================= */}
        {activeTab === 'dashboard' && (
          <div className="space-y-6 sm:space-y-8 animate-in fade-in-50 duration-200">
            
            {/* Task 1: Page Header & Title Section with Data Freshness */}
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
              <div>
                <div className="flex items-center gap-2 flex-wrap">
                  <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 tracking-tight">
                    Seller Command Center
                  </h1>
                  <span className="hidden sm:inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-emerald-50 text-[#047857] border border-emerald-200">
                    Live Operational
                  </span>
                </div>
                <p className="text-xs sm:text-sm text-slate-500 mt-1">
                  High-priority operational overview, supply health & pending actions.
                </p>
              </div>

              {/* Top Right: Data Freshness Indicator + Primary Action */}
              <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 w-full sm:w-auto">
                <DataFreshness />
                <div className="w-full sm:w-auto">
                  <PostAvailabilityDialog />
                </div>
              </div>
            </div>

            {/* Task 2: Top KPI Ribbon (3 Cards) */}
            <section aria-label="Operational Metrics Summary">
              <KpiGrid className="grid-cols-1 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-3">
                <KpiCard 
                  title="ACTIVE INVENTORY" 
                  value={kpis.activeAvailabilitiesCount}
                  icon={Package}
                  badgeColor="emerald"
                  description="Open listed supply lots ready for matching"
                />
                <KpiCard 
                  title="PENDING DISPATCHES" 
                  value={kpis.pendingDispatchesCount}
                  icon={Truck}
                  badgeColor="amber"
                  description="Booked deals awaiting logistics transport"
                />
                <KpiCard 
                  title="TOTAL DEAL REVENUE" 
                  value={formatIndianCurrency(kpis.totalRevenue)}
                  icon={TrendingUp}
                  badgeColor="indigo"
                  description="Cumulative settled trade volume"
                />
              </KpiGrid>
            </section>

            {/* Task 3: P0 Action Required Section (Critical Task Alerts) */}
            <ActionRequiredBanner 
              actionItems={actionItems} 
              onNavigateTab={setActiveTab} 
            />

            {/* Task 4: Operational Quick Access Cards (Bottom Row - 2 Columns) */}
            <section aria-label="Operational Quick Access" className="space-y-3">
              <div className="flex items-center justify-between px-1">
                <h2 className="text-xs sm:text-sm font-bold uppercase tracking-wider text-slate-700">
                  Operational Workspaces
                </h2>
                <span className="text-xs text-slate-400 font-medium">Core Trading Engines</span>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                
                {/* Left Card: Active Inventory Lots */}
                <div className="bg-white rounded-2xl border border-slate-200/90 p-5 sm:p-6 shadow-xs flex flex-col justify-between hover:border-slate-300 transition-colors">
                  <div>
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <div className="p-2.5 rounded-xl bg-[#ECFDF5] text-[#047857] border border-emerald-100">
                          <Package className="w-5 h-5 stroke-[2]" />
                        </div>
                        <div>
                          <h3 className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
                            Active Inventory Lots
                          </h3>
                          <div className="text-xs text-slate-400 font-medium mt-0.5">Supply Lot Management</div>
                        </div>
                      </div>
                      <Badge variant="outline" className="bg-[#ECFDF5] text-[#047857] border-emerald-200 font-bold text-xs px-2.5 py-1">
                        {availabilities.length} Lots
                      </Badge>
                    </div>
                    <p className="text-xs sm:text-sm text-slate-600 mb-6 leading-relaxed">
                      Track stock availability, asking rates, validity dates, and loading readiness.
                    </p>
                  </div>
                  <Button 
                    onClick={() => setActiveTab('inventory')}
                    className="w-full min-h-[48px] bg-[#059669] hover:bg-[#047857] text-white font-bold rounded-xl cursor-pointer shadow-xs gap-2"
                  >
                    <span>Manage All Inventory</span>
                    <ArrowRight className="w-4 h-4" />
                  </Button>
                </div>

                {/* Right Card: Booked Deals & Dispatches */}
                <div className="bg-white rounded-2xl border border-slate-200/90 p-5 sm:p-6 shadow-xs flex flex-col justify-between hover:border-slate-300 transition-colors">
                  <div>
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <div className="p-2.5 rounded-xl bg-[#EFF6FF] text-[#1D4ED8] border border-blue-100">
                          <Truck className="w-5 h-5 stroke-[2]" />
                        </div>
                        <div>
                          <h3 className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
                            Booked Deals & Dispatches
                          </h3>
                          <div className="text-xs text-slate-400 font-medium mt-0.5">Logistics & Fulfilment</div>
                        </div>
                      </div>
                      <Badge variant="outline" className="bg-[#EFF6FF] text-[#1D4ED8] border-blue-200 font-bold text-xs px-2.5 py-1">
                        {deals.length} Active
                      </Badge>
                    </div>
                    <p className="text-xs sm:text-sm text-slate-600 mb-6 leading-relaxed">
                      Manage logistics dispatches, driver assignments, lorry receipts and disputes.
                    </p>
                  </div>
                  <Button 
                    onClick={() => setActiveTab('deals')}
                    variant="outline"
                    className="w-full min-h-[48px] border-slate-300 text-slate-800 hover:bg-slate-50 font-bold rounded-xl cursor-pointer shadow-2xs gap-2"
                  >
                    <span>View Booked Deals</span>
                    <ArrowRight className="w-4 h-4 text-slate-500" />
                  </Button>
                </div>

              </div>
            </section>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 2: INVENTORY & AVAILABILITY                                            */}
        {/* ========================================================================= */}
        {activeTab === 'inventory' && (
          <div className="space-y-6 animate-in fade-in-50 duration-200">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
              <div>
                <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
                  Inventory & Availabilities
                </h1>
                <p className="text-xs sm:text-sm text-slate-500 mt-1">
                  Manage active commodity lots, set asking prices, and monitor validity windows.
                </p>
              </div>
              <div className="flex items-center gap-3 w-full sm:w-auto">
                <DataFreshness />
                <div className="w-full sm:w-auto">
                  <PostAvailabilityDialog />
                </div>
              </div>
            </div>

            <MyAvailabilitiesTable availabilities={availabilities} />
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 3: QUALITY & LAB TESTING                                               */}
        {/* ========================================================================= */}
        {activeTab === 'quality' && (
          <div className="space-y-6 animate-in fade-in-50 duration-200">
            <div className="bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
              <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
                Quality & Laboratory Testing
              </h1>
              <p className="text-xs sm:text-sm text-slate-500 mt-1">
                Dynamic quality parameter templates, lab certificates & COA verification records.
              </p>
            </div>

            <Card className="rounded-2xl border-slate-200 shadow-xs bg-white">
              <CardHeader className="pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-3 rounded-2xl bg-emerald-50 text-[#047857]">
                    <FlaskConical className="w-6 h-6 stroke-[2]" />
                  </div>
                  <div>
                    <CardTitle className="text-lg font-bold text-slate-900">Lot Quality Engine</CardTitle>
                    <CardDescription className="text-sm text-slate-500">
                      Quality parameters are dynamically generated per commodity master template.
                    </CardDescription>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="p-4 rounded-xl bg-slate-50 border border-slate-100 flex items-start gap-3">
                  <ShieldCheck className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
                  <div className="text-xs sm:text-sm text-slate-600">
                    <span className="font-semibold text-slate-900">Lot Traceability Rule:</span> Every active lot is verified against commodity standards (Moisture, Admixture, Protein, Oil content). Full lab record creation and certificate uploads activate in Sprint 15.
                  </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-2">
                  <div className="p-4 rounded-xl border border-slate-200 bg-white space-y-1">
                    <div className="text-xs text-slate-400 font-semibold uppercase">Dynamic Templates</div>
                    <div className="text-base font-bold text-slate-900">Commodity-Driven</div>
                    <div className="text-xs text-slate-500">Moisture, foreign matter, grain size</div>
                  </div>
                  <div className="p-4 rounded-xl border border-slate-200 bg-white space-y-1">
                    <div className="text-xs text-slate-400 font-semibold uppercase">Lab Records</div>
                    <div className="text-base font-bold text-slate-900">NABL & Private Labs</div>
                    <div className="text-xs text-slate-500">Certificate No, Test Date, COA PDF</div>
                  </div>
                  <div className="p-4 rounded-xl border border-slate-200 bg-white space-y-1">
                    <div className="text-xs text-slate-400 font-semibold uppercase">Quality Freshness</div>
                    <div className="text-base font-bold text-[#059669]">Validity Tracking</div>
                    <div className="text-xs text-slate-500">Auto-flags stale or expired tests</div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 4: REQUESTS & DEALS                                                    */}
        {/* ========================================================================= */}
        {activeTab === 'deals' && (
          <div className="space-y-6 animate-in fade-in-50 duration-200">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
              <div>
                <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
                  Broker Requests & Deals
                </h1>
                <p className="text-xs sm:text-sm text-slate-500 mt-1">
                  Track broker commercial proposals, negotiations, and locked transaction bookings.
                </p>
              </div>
              <DataFreshness />
            </div>

            <SellerDealsTable deals={deals} vehicleTypes={vehicleTypes} />
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 5: ORDERS & DISPATCH                                                   */}
        {/* ========================================================================= */}
        {activeTab === 'orders' && (
          <div className="space-y-6 animate-in fade-in-50 duration-200">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
              <div>
                <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
                  Orders, Logistics & Dispatch
                </h1>
                <p className="text-xs sm:text-sm text-slate-500 mt-1">
                  Manage vehicle details, driver assignments, and live transit ETAs for booked deals.
                </p>
              </div>
              <DataFreshness />
            </div>

            <SellerDealsTable deals={deals} vehicleTypes={vehicleTypes} />
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 6: PAYMENTS & SETTLEMENT                                               */}
        {/* ========================================================================= */}
        {activeTab === 'payments' && (
          <div className="space-y-6 animate-in fade-in-50 duration-200">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
              <div>
                <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
                  Payments & Settlement View
                </h1>
                <p className="text-xs sm:text-sm text-slate-500 mt-1">
                  Track receivable balances, advance disbursements, payment confirmations & exceptions.
                </p>
              </div>
              <DataFreshness />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
              <KpiCard 
                title="TOTAL SETTLEMENT" 
                value={formatIndianCurrency(kpis.totalRevenue)}
                icon={Wallet}
                badgeColor="emerald"
                description="Cumulative completed trade settlements"
              />
              <KpiCard 
                title="IN TRANSIT VOLUME" 
                value={deals.filter(d => d.deal.status === 'In Transit').length}
                icon={Truck}
                badgeColor="amber"
                description="Deals currently moving on trucks"
              />
              <KpiCard 
                title="DISPUTE EXCEPTIONS" 
                value={deals.filter(d => d.deal.status === 'Disputed').length}
                icon={AlertCircle}
                badgeColor="amber"
                description="Deals undergoing mediation"
              />
            </div>

            <Card className="rounded-2xl border-slate-200 shadow-xs bg-white">
              <CardHeader>
                <CardTitle className="text-lg font-bold text-slate-900">Settlement Ledger</CardTitle>
                <CardDescription className="text-sm text-slate-500">
                  Transactions are settled following delivery confirmation and invoice reconciliation.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="p-8 text-center bg-slate-50 rounded-xl border border-dashed border-slate-200">
                  <Wallet className="w-10 h-10 text-slate-400 mx-auto mb-2 stroke-[1.5]" />
                  <h3 className="font-bold text-slate-800 text-sm">Settlement View Linked to Bookings</h3>
                  <p className="text-xs text-slate-500 max-w-sm mx-auto mt-1">
                    Direct payment records and invoice reconciliation breakdowns update as dispatches are confirmed.
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 7: DOCUMENTS VAULT                                                     */}
        {/* ========================================================================= */}
        {activeTab === 'documents' && (
          <div className="space-y-6 animate-in fade-in-50 duration-200">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
              <div>
                <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
                  Trade Documents Vault
                </h1>
                <p className="text-xs sm:text-sm text-slate-500 mt-1">
                  Secure repository for GST invoices, Lorry Receipts (LR), COA reports & trade agreements.
                </p>
              </div>
              <DataFreshness />
            </div>

            <Card className="rounded-2xl border-slate-200 shadow-xs bg-white">
              <CardHeader>
                <div className="flex items-center gap-3">
                  <div className="p-3 rounded-2xl bg-indigo-50 text-indigo-700">
                    <FolderLock className="w-6 h-6 stroke-[2]" />
                  </div>
                  <div>
                    <CardTitle className="text-lg font-bold text-slate-900">Encrypted Document Storage</CardTitle>
                    <CardDescription className="text-sm text-slate-500">
                      All uploaded files are protected by Supabase RLS and partitioned by deal reference.
                    </CardDescription>
                  </div>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div className="p-4 rounded-xl border border-slate-200 bg-white">
                    <FileText className="w-5 h-5 text-indigo-600 mb-2" />
                    <div className="font-bold text-slate-900 text-sm">Tax Invoices</div>
                    <div className="text-xs text-slate-500 mt-0.5">Commercial bills uploaded upon dispatch</div>
                  </div>
                  <div className="p-4 rounded-xl border border-slate-200 bg-white">
                    <Truck className="w-5 h-5 text-emerald-600 mb-2" />
                    <div className="font-bold text-slate-900 text-sm">Lorry Receipts (LR)</div>
                    <div className="text-xs text-slate-500 mt-0.5">Transporter receipts & weighbridge slips</div>
                  </div>
                  <div className="p-4 rounded-xl border border-slate-200 bg-white">
                    <FlaskConical className="w-5 h-5 text-amber-600 mb-2" />
                    <div className="font-bold text-slate-900 text-sm">Quality COA Reports</div>
                    <div className="text-xs text-slate-500 mt-0.5">Lab test certifications attached to lots</div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 8: TEAM & USER MANAGEMENT (SELLER_ADMIN ONLY)                          */}
        {/* ========================================================================= */}
        {activeTab === 'team' && (
          <div className="space-y-6 animate-in fade-in-50 duration-200">
            <div className="bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
              <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
                Team & Access Control
              </h1>
              <p className="text-xs sm:text-sm text-slate-500 mt-1">
                Manage authorized users and permissions for {companyName}.
              </p>
            </div>

            <Card className="rounded-2xl border-slate-200 shadow-xs bg-white">
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="p-3 rounded-2xl bg-emerald-50 text-[#047857]">
                      <Users className="w-6 h-6 stroke-[2]" />
                    </div>
                    <div>
                      <CardTitle className="text-lg font-bold text-slate-900">Organization Members</CardTitle>
                      <CardDescription className="text-sm text-slate-500">
                        Administered under Seller RBAC rules.
                      </CardDescription>
                    </div>
                  </div>
                  <Badge className="bg-emerald-100 text-[#047857] border-emerald-200 font-bold">
                    SELLER_ADMIN View
                  </Badge>
                </div>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-center justify-between p-4 rounded-xl bg-slate-50 border border-slate-200/70">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-emerald-600 text-white font-bold flex items-center justify-center text-sm">
                      {fullProfile?.user?.name?.[0]?.toUpperCase() || 'S'}
                    </div>
                    <div>
                      <div className="font-bold text-slate-900 text-sm">{fullProfile?.user?.name || 'Primary Contact'}</div>
                      <div className="text-xs text-slate-500">{fullProfile?.user?.email || fullProfile?.user?.mobile}</div>
                    </div>
                  </div>
                  <span className="px-2.5 py-1 rounded-md text-[11px] font-mono font-bold uppercase tracking-wider bg-emerald-100 text-[#047857] border border-emerald-200">
                    SELLER_ADMIN
                  </span>
                </div>
              </CardContent>
            </Card>
          </div>
        )}

      </main>
    </div>
  )
}
