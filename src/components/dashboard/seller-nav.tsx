'use client'

import React from 'react'
import { 
  LayoutDashboard, 
  Package, 
  FlaskConical, 
  Handshake, 
  Truck, 
  Wallet, 
  FolderLock, 
  Users,
  ChevronRight,
  Sparkles,
  TrendingUp
} from 'lucide-react'
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from "@/components/ui/sheet"
import { Badge } from "@/components/ui/badge"

export interface NavItem {
  id: string
  label: string
  shortLabel?: string
  icon: React.ElementType
  href?: string
  badge?: string
  adminOnly?: boolean
  description?: string
}

export const SELLER_NAV_ITEMS: NavItem[] = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    shortLabel: 'Dashboard',
    icon: LayoutDashboard,
    description: 'Operational overview & P0 action items',
  },
  {
    id: 'inventory',
    label: 'Inventory & Stock',
    shortLabel: 'Inventory',
    icon: Package,
    description: 'Active supply lots, pricing & renewals',
  },
  {
    id: 'quality',
    label: 'Quality & Lab',
    shortLabel: 'Quality',
    icon: FlaskConical,
    description: 'Dynamic parameters & COA lab records',
  },
  {
    id: 'deals',
    label: 'Requests & Deals',
    shortLabel: 'Deals',
    icon: Handshake,
    description: 'Broker requests, negotiations & bookings',
  },
  {
    id: 'orders',
    label: 'Orders & Dispatch',
    shortLabel: 'Dispatch',
    icon: Truck,
    description: 'Logistics tracking & shipment dispatch',
  },
  {
    id: 'payments',
    label: 'Settlement & Pay',
    shortLabel: 'Payments',
    icon: Wallet,
    description: 'Receivables, advances & payment status',
  },
  {
    id: 'reports',
    label: 'Reports & Visibility',
    shortLabel: 'Reports',
    icon: TrendingUp,
    description: 'Financial math, sales trends & inventory state',
  },
  {
    id: 'documents',
    label: 'Documents Vault',
    shortLabel: 'Documents',
    icon: FolderLock,
    description: 'Secure invoices, LR & trade documents',
  },
  {
    id: 'team',
    label: 'Team Management',
    shortLabel: 'Team',
    icon: Users,
    adminOnly: true,
    description: 'Manage users, permissions & KYC',
  },
]

interface SellerNavProps {
  activeTab: string
  onTabChange: (tabId: string) => void
  userRole?: string
  mobileOpen?: boolean
  onMobileOpenChange?: (open: boolean) => void
  companyName?: string
}

export function SellerNav({
  activeTab,
  onTabChange,
  userRole = "SELLER_ADMIN",
  mobileOpen = false,
  onMobileOpenChange,
  companyName = "Seller Workspace",
}: SellerNavProps) {
  const isSellerAdmin = 
    userRole.toUpperCase().includes("ADMIN") || 
    userRole.toUpperCase().includes("SELLER") ||
    !userRole

  const visibleNavItems = SELLER_NAV_ITEMS.filter(item => {
    if (item.adminOnly && !isSellerAdmin) return false
    return true
  })

  return (
    <>
      {/* DESKTOP / TABLET HORIZONTAL SUB-NAV BAR (>= md) */}
      <nav 
        aria-label="Seller module navigation"
        className="w-full bg-white border-b border-slate-200/80 shadow-[0_1px_2px_rgba(0,0,0,0.03)] shrink-0"
      >
        <div className="w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center space-x-1 sm:space-x-2 md:space-x-4 overflow-x-auto overflow-y-hidden scrollbar-hide py-1.5 min-h-[48px]">
            {visibleNavItems.map((item) => {
              const Icon = item.icon
              const isActive = activeTab === item.id

              return (
                <button
                  key={item.id}
                  onClick={() => onTabChange(item.id)}
                  type="button"
                  className={`
                    group relative inline-flex items-center gap-2 px-3 py-2 text-xs sm:text-sm font-medium rounded-lg whitespace-nowrap transition-all duration-150 cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-1
                    ${isActive 
                      ? 'text-[#047857] font-bold bg-emerald-50/80' 
                      : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100/70 font-semibold'
                    }
                  `}
                >
                  <Icon 
                    className={`w-4 h-4 transition-colors shrink-0 ${
                      isActive ? 'text-[#059669] stroke-[2.25]' : 'text-slate-400 group-hover:text-slate-700'
                    }`} 
                  />
                  <span>{item.shortLabel || item.label}</span>
                  {item.badge && (
                    <span className="px-1.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800">
                      {item.badge}
                    </span>
                  )}
                  
                  {/* Apple-style Forest Jade Active Underline */}
                  {isActive && (
                    <span 
                      className="absolute bottom-0 left-3 right-3 h-[2.5px] bg-[#059669] rounded-full shadow-xs" 
                      aria-hidden="true" 
                    />
                  )}
                </button>
              )
            })}
          </div>
        </div>
      </nav>

      {/* MOBILE SLIDE-OUT DRAWER / SHEET (< md) */}
      <Sheet open={mobileOpen} onOpenChange={onMobileOpenChange}>
        <SheetContent side="left" className="w-[85vw] max-w-sm p-0 flex flex-col bg-white">
          {/* Drawer Header */}
          <SheetHeader className="p-5 border-b border-slate-100 text-left bg-slate-50/60">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-slate-900 flex items-center justify-center shadow-sm shrink-0">
                <span className="text-white font-bold text-sm tracking-tighter">BB</span>
              </div>
              <div className="min-w-0 flex-1">
                <SheetTitle className="text-base font-bold text-slate-900 leading-snug truncate">
                  {companyName}
                </SheetTitle>
                <SheetDescription className="text-xs text-emerald-700 font-semibold flex items-center gap-1 mt-0.5">
                  <Sparkles className="w-3 h-3 text-emerald-600" />
                  Seller Operational Hub
                </SheetDescription>
              </div>
            </div>
          </SheetHeader>

          {/* Drawer Navigation Links */}
          <div className="flex-1 overflow-y-auto p-3 space-y-1.5">
            <div className="px-3 py-2 text-[11px] font-bold uppercase tracking-wider text-slate-400">
              Workspace Modules
            </div>

            {visibleNavItems.map((item) => {
              const Icon = item.icon
              const isActive = activeTab === item.id

              return (
                <button
                  key={item.id}
                  onClick={() => {
                    onTabChange(item.id)
                    if (onMobileOpenChange) onMobileOpenChange(false)
                  }}
                  type="button"
                  className={`
                    w-full flex items-center justify-between p-3.5 rounded-xl text-left transition-all min-h-[52px] cursor-pointer
                    ${isActive 
                      ? 'bg-[#ECFDF5] text-[#047857] font-bold border border-emerald-200/80 shadow-xs' 
                      : 'text-slate-700 hover:bg-slate-100/80 font-medium'
                    }
                  `}
                >
                  <div className="flex items-center gap-3.5 min-w-0">
                    <div className={`
                      p-2 rounded-lg shrink-0
                      ${isActive ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-500'}
                    `}>
                      <Icon className="w-4 h-4 stroke-[2]" />
                    </div>
                    <div className="min-w-0">
                      <div className="text-sm font-bold truncate leading-tight">
                        {item.label}
                      </div>
                      {item.description && (
                        <div className="text-[11px] text-slate-500 truncate mt-0.5 font-normal">
                          {item.description}
                        </div>
                      )}
                    </div>
                  </div>

                  <ChevronRight className={`w-4 h-4 shrink-0 ${isActive ? 'text-[#047857]' : 'text-slate-300'}`} />
                </button>
              )
            })}
          </div>

          {/* Drawer Footer Info */}
          <div className="p-4 border-t border-slate-100 bg-slate-50/50 text-xs text-slate-500 text-center">
            <div className="font-semibold text-slate-700">BrokerBridge Enterprise v3.0</div>
            <div className="text-[11px] text-slate-400 mt-0.5">Seller Operational Platform · Tier-2 India</div>
          </div>
        </SheetContent>
      </Sheet>
    </>
  )
}
