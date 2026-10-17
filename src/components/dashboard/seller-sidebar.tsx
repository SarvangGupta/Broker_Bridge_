'use client'

import React, { useState, useEffect, Suspense } from 'react'
import Link from 'next/link'
import { usePathname, useSearchParams, useRouter } from 'next/navigation'
import { 
  LayoutDashboard, 
  Package, 
  FlaskConical, 
  Handshake, 
  Truck, 
  Wallet, 
  TrendingUp, 
  FolderLock, 
  Users, 
  Sparkles,
  ChevronDown,
  ChevronUp,
  LogOut,
  User,
  HelpCircle,
  ArrowLeftRight,
  Building2,
  MoreHorizontal,
  MoreVertical,
  Smartphone
} from 'lucide-react'
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { SellerProfileDialog } from "@/src/components/dialogs/seller-profile-dialog"
import { SupportDialog } from "@/src/components/dialogs/support-dialog"
import { signOutAction } from "@/src/server/actions/auth-actions"
import { NotificationBell } from "@/src/components/layout/notification-bell"
import { SellerMobileNav } from "@/src/components/dashboard/seller-mobile-nav"

export interface NavItem {
  id: string
  label: string
  shortLabel?: string
  icon: React.ElementType
  href: string
  badge?: string
  adminOnly?: boolean
  description?: string
}

// 1. PRIMARY LINKS (Always visible in desktop sidebar & mobile nav)
export const PRIMARY_SELLER_NAV_ITEMS: NavItem[] = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    shortLabel: 'Dashboard',
    icon: LayoutDashboard,
    href: '/seller',
    description: 'Operational overview & P0 action items',
  },
  {
    id: 'inventory',
    label: 'Inventory & Stock',
    shortLabel: 'Inventory',
    icon: Package,
    href: '/seller?tab=inventory',
    description: 'Active supply lots, pricing & renewals',
  },
  {
    id: 'deals',
    label: 'Requests & Deals',
    shortLabel: 'Deals',
    icon: Handshake,
    href: '/seller?tab=deals',
    description: 'Broker requests, negotiations & bookings',
  },
  {
    id: 'orders',
    label: 'Orders & Dispatch',
    shortLabel: 'Dispatch',
    icon: Truck,
    href: '/seller?tab=orders',
    description: 'Logistics tracking & shipment dispatch',
  },
]

// 2. SECONDARY LINKS (Revealed inside "More" accordion / section)
export const SECONDARY_SELLER_NAV_ITEMS: NavItem[] = [
  {
    id: 'quality',
    label: 'Quality & Lab',
    shortLabel: 'Quality',
    icon: FlaskConical,
    href: '/seller?tab=quality',
    description: 'Dynamic parameters & COA lab records',
  },
  {
    id: 'payments',
    label: 'Settlement & Pay',
    shortLabel: 'Payments',
    icon: Wallet,
    href: '/seller?tab=payments',
    description: 'Receivables, advances & payment status',
  },
  {
    id: 'reports',
    label: 'Reports & Visibility',
    shortLabel: 'Reports',
    icon: TrendingUp,
    href: '/seller?tab=reports',
    description: 'Financial math, sales trends & inventory state',
  },
  {
    id: 'documents',
    label: 'Documents Vault',
    shortLabel: 'Documents',
    icon: FolderLock,
    href: '/seller?tab=documents',
    description: 'Secure invoices, LR & trade documents',
  },
  {
    id: 'team',
    label: 'Team Management',
    shortLabel: 'Team',
    icon: Users,
    href: '/seller?tab=team',
    adminOnly: true,
    description: 'Manage users, permissions & KYC',
  },
]

// Export combined list for backwards compatibility
export const SELLER_NAV_ITEMS: NavItem[] = [
  ...PRIMARY_SELLER_NAV_ITEMS,
  ...SECONDARY_SELLER_NAV_ITEMS,
]

interface SellerSidebarProps {
  profile?: any
  fullProfile?: any
  userRole?: string
}

function SidebarNavContent({
  profile,
  fullProfile,
  userRole = "SELLER_ADMIN",
  onItemClick,
}: {
  profile?: any
  fullProfile?: any
  userRole?: string
  onItemClick?: () => void
}) {
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const currentTab = searchParams?.get('tab')
  const [activeTab, setActiveTab] = useState(currentTab || 'dashboard')

  useEffect(() => {
    setActiveTab(currentTab || 'dashboard')
  }, [currentTab])

  useEffect(() => {
    const handleCustomTabChange = (e: Event) => {
      const customEvent = e as CustomEvent<string>
      if (customEvent.detail) {
        setActiveTab(customEvent.detail)
      }
    }
    const handlePopState = () => {
      const params = new URLSearchParams(window.location.search)
      setActiveTab(params.get('tab') || 'dashboard')
    }
    window.addEventListener('seller-tab-change', handleCustomTabChange)
    window.addEventListener('popstate', handlePopState)
    return () => {
      window.removeEventListener('seller-tab-change', handleCustomTabChange)
      window.removeEventListener('popstate', handlePopState)
    }
  }, [])

  const isSellerAdmin = 
    userRole.toUpperCase().includes("ADMIN") || 
    userRole.toUpperCase().includes("SELLER") ||
    !userRole

  const isItemActive = (item: NavItem) => {
    if (pathname === '/seller') {
      if (item.id === 'dashboard') {
        return !activeTab || activeTab === 'dashboard'
      }
      return activeTab === item.id
    }
    // Sub-route path matches
    if (item.id === 'reports' && pathname.startsWith('/seller/reports')) return true
    if (item.id === 'deals' && (pathname.startsWith('/seller/requests') || pathname.startsWith('/seller/deals'))) return true
    if (item.id === 'orders' && pathname.startsWith('/seller/dispatch')) return true
    if (item.id === 'payments' && pathname.startsWith('/seller/payments')) return true
    if (item.id === 'dashboard' && pathname.startsWith('/seller/notifications')) return true
    return false
  }

  const handleNavClick = (e: React.MouseEvent, item: NavItem) => {
    if (pathname === '/seller') {
      e.preventDefault()
      window.history.pushState(null, '', item.href)
      setActiveTab(item.id)
      window.dispatchEvent(new CustomEvent('seller-tab-change', { detail: item.id }))
    }
    onItemClick?.()
  }

  // Filter secondary items by admin role
  const visibleSecondaryItems = SECONDARY_SELLER_NAV_ITEMS.filter(item => {
    if (item.adminOnly && !isSellerAdmin) return false
    return true
  })

  // Auto-expand "More" if an active tab is inside secondary items
  const isAnySecondaryActive = visibleSecondaryItems.some(item => isItemActive(item))
  const [isMoreOpen, setIsMoreOpen] = useState(isAnySecondaryActive)

  useEffect(() => {
    if (isAnySecondaryActive) {
      setIsMoreOpen(true)
    }
  }, [isAnySecondaryActive])

  return (
    <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-1" aria-label="Seller Main Navigation">
      <div className="px-3 pb-2 text-[11px] font-bold uppercase tracking-wider text-slate-400">
        Primary Workspace
      </div>

      {/* Primary 4 Links */}
      {PRIMARY_SELLER_NAV_ITEMS.map((item) => {
        const Icon = item.icon
        const isActive = isItemActive(item)

        return (
          <Link
            key={item.id}
            href={item.href}
            onClick={(e) => handleNavClick(e, item)}
            className={`
              group flex items-center gap-3 px-4 py-3 rounded-xl text-sm transition-all duration-150 cursor-pointer min-h-[48px]
              ${isActive 
                ? 'bg-[#ECFDF5] text-[#059669] font-bold shadow-2xs border border-emerald-200/80' 
                : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900 font-medium'
              }
            `}
          >
            <Icon 
              className={`w-5 h-5 shrink-0 transition-colors ${
                isActive ? 'text-[#059669] stroke-[2.25]' : 'text-slate-400 group-hover:text-slate-700'
              }`} 
            />
            <span className="truncate flex-1">{item.label}</span>
            {item.badge && (
              <span className="px-1.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800">
                {item.badge}
              </span>
            )}
          </Link>
        )
      })}

      {/* Task 2: "More" Collapsible Accordion Section */}
      <div className="pt-2">
        <button
          onClick={() => setIsMoreOpen(!isMoreOpen)}
          className={`
            w-full group flex items-center justify-between gap-3 px-4 py-3 rounded-xl text-sm transition-all duration-150 cursor-pointer min-h-[48px] text-left
            ${isAnySecondaryActive
              ? 'bg-emerald-50/50 text-[#059669] font-bold'
              : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900 font-medium'
            }
          `}
        >
          <div className="flex items-center gap-3 min-w-0">
            <MoreHorizontal 
              className={`w-5 h-5 shrink-0 transition-colors ${
                isAnySecondaryActive ? 'text-[#059669] stroke-[2.25]' : 'text-slate-400 group-hover:text-slate-700'
              }`} 
            />
            <span className="truncate">More Modules</span>
          </div>

          <div className="flex items-center gap-1 shrink-0">
            {isAnySecondaryActive && (
              <span className="w-2 h-2 rounded-full bg-[#059669]" />
            )}
            {isMoreOpen ? (
              <ChevronUp className="w-4 h-4 text-slate-400" />
            ) : (
              <ChevronDown className="w-4 h-4 text-slate-400" />
            )}
          </div>
        </button>

        {/* Revealed Secondary Links */}
        {isMoreOpen && (
          <div className="mt-1 pl-3 space-y-1 border-l-2 border-emerald-100 ml-5 py-1">
            {visibleSecondaryItems.map((item) => {
              const Icon = item.icon
              const isActive = isItemActive(item)

              return (
                <Link
                  key={item.id}
                  href={item.href}
                  onClick={(e) => handleNavClick(e, item)}
                  className={`
                    group flex items-center gap-2.5 px-3 py-2.5 rounded-lg text-xs transition-all duration-150 cursor-pointer min-h-[44px]
                    ${isActive 
                      ? 'bg-[#ECFDF5] text-[#059669] font-bold border border-emerald-200/80 shadow-2xs' 
                      : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900 font-medium'
                    }
                  `}
                >
                  <Icon 
                    className={`w-4 h-4 shrink-0 transition-colors ${
                      isActive ? 'text-[#059669] stroke-[2.25]' : 'text-slate-400 group-hover:text-slate-700'
                    }`} 
                  />
                  <span className="truncate flex-1">{item.label}</span>
                </Link>
              )
            })}
          </div>
        )}
      </div>
    </nav>
  )
}

function SidebarProfileAnchor({
  profile,
  fullProfile,
  userRole = "SELLER_ADMIN",
}: SellerSidebarProps) {
  const router = useRouter()
  const [isProfileOpen, setIsProfileOpen] = useState(false)
  const [profileTab, setProfileTab] = useState("profile")
  const [isSupportOpen, setIsSupportOpen] = useState(false)

  const handleSignOut = async () => {
    await signOutAction()
  }

  const userName = fullProfile?.user?.name || profile?.name || "Seller User"
  const companyName = fullProfile?.company?.name || profile?.name || "Trading Organization"

  let displayRole = "SELLER_ADMIN"
  if (userRole) {
    const r = userRole.toUpperCase()
    if (r.includes("VIEWER")) displayRole = "SELLER_VIEWER"
    else if (r.includes("USER") || r.includes("OPERATOR")) displayRole = "SELLER_USER"
    else if (r.includes("ADMIN") || r.includes("SELLER")) displayRole = "SELLER_ADMIN"
  }

  const getInitials = (name: string) => {
    if (!name) return "S"
    const parts = name.trim().split(" ")
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase()
    }
    return name.substring(0, 2).toUpperCase()
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger className="w-full flex items-center justify-between gap-2 p-2 -m-1 rounded-xl text-left hover:bg-slate-100/90 transition-colors cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 select-none group">
          <div className="flex items-center gap-2.5 min-w-0 flex-1">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-[#ECFDF5] group-hover:bg-emerald-100 border border-emerald-300 shadow-2xs shrink-0 transition-colors">
              <span className="font-bold text-xs text-[#047857] tracking-tight">
                {getInitials(userName)}
              </span>
            </div>
            <div className="min-w-0 flex-1">
              <div className="text-xs font-bold text-slate-900 truncate leading-tight">
                {companyName}
              </div>
              <div className="text-[11px] text-slate-500 truncate mt-0.5 font-medium">
                {userName}
              </div>
            </div>
          </div>
          <MoreVertical className="w-4 h-4 text-slate-400 group-hover:text-slate-600 shrink-0" />
        </DropdownMenuTrigger>

        <DropdownMenuContent className="w-64 mb-2 shadow-xl border-slate-200/90 rounded-xl p-1.5" side="top" align="start">
          <DropdownMenuGroup>
            <DropdownMenuLabel className="font-normal p-2.5 bg-slate-50/80 rounded-lg mb-1 border border-slate-100">
              <div className="flex flex-col space-y-1.5">
                <div className="flex items-center justify-between gap-2">
                  <p className="text-sm font-bold text-slate-900 leading-tight truncate">
                    {userName}
                  </p>
                  <span className="shrink-0 px-2 py-0.5 rounded text-[10px] font-mono font-bold uppercase tracking-wider bg-emerald-100 text-[#047857] border border-emerald-200">
                    {displayRole}
                  </span>
                </div>
                
                <div className="flex items-center gap-1.5 text-xs text-slate-600">
                  <Building2 className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                  <span className="truncate font-medium">{companyName}</span>
                </div>
              </div>
            </DropdownMenuLabel>
          </DropdownMenuGroup>

          <DropdownMenuSeparator className="my-1" />

          {/* Switch to Buyer Workspace (Trader Dual-Profile Toggle) */}
          <DropdownMenuGroup>
            <DropdownMenuItem 
              className="cursor-pointer py-2.5 px-3 text-emerald-800 hover:text-emerald-900 focus:bg-emerald-50 focus:text-emerald-900 font-semibold rounded-lg transition-colors"
              onClick={() => router.push('/buyer')}
              onSelect={() => router.push('/buyer')}
            >
              <ArrowLeftRight className="mr-2.5 h-4 w-4 text-[#059669]" />
              <div className="flex flex-col">
                <span className="text-sm leading-snug">Switch to Buyer Workspace</span>
                <span className="text-[11px] font-normal text-slate-500">Access buyer requirements & deals</span>
              </div>
            </DropdownMenuItem>
          </DropdownMenuGroup>

          <DropdownMenuSeparator className="my-1" />

          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-slate-700 hover:text-slate-900 focus:bg-slate-50 rounded-lg transition-colors" 
            onClick={() => {
              setProfileTab("profile");
              setIsProfileOpen(true);
            }}
            onSelect={(e) => {
              e.preventDefault();
              setProfileTab("profile");
              setIsProfileOpen(true);
            }}
          >
            <User className="mr-2.5 h-4 w-4 text-slate-500" />
            <span className="font-medium text-sm">Organization & KYC Profile</span>
          </DropdownMenuItem>

          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-emerald-800 hover:text-emerald-900 focus:bg-emerald-50 focus:text-emerald-900 rounded-lg transition-colors" 
            onClick={() => {
              setProfileTab("app");
              setIsProfileOpen(true);
            }}
            onSelect={(e) => {
              e.preventDefault();
              setProfileTab("app");
              setIsProfileOpen(true);
            }}
          >
            <Smartphone className="mr-2.5 h-4 w-4 text-[#059669]" />
            <span className="font-semibold text-sm">Install Mobile App</span>
          </DropdownMenuItem>

          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-slate-700 hover:text-slate-900 focus:bg-slate-50 rounded-lg transition-colors" 
            onClick={() => setIsSupportOpen(true)}
            onSelect={(e) => {
              e.preventDefault();
              setIsSupportOpen(true);
            }}
          >
            <HelpCircle className="mr-2.5 h-4 w-4 text-slate-500" />
            <span className="font-medium text-sm">Help & Support Desk</span>
          </DropdownMenuItem>

          <DropdownMenuSeparator className="my-1" />

          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-rose-600 focus:text-rose-700 focus:bg-rose-50 font-medium rounded-lg transition-colors" 
            onClick={handleSignOut}
          >
            <LogOut className="mr-2.5 h-4 w-4" />
            <span className="text-sm">Sign out securely</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <SellerProfileDialog 
        open={isProfileOpen} 
        onOpenChange={setIsProfileOpen} 
        initialProfileData={fullProfile} 
        defaultTab={profileTab}
      />
      <SupportDialog 
        open={isSupportOpen} 
        onOpenChange={setIsSupportOpen} 
      />
    </>
  )
}

export function SellerSidebar({
  profile,
  fullProfile,
  userRole = "SELLER_ADMIN",
}: SellerSidebarProps) {
  const pathname = usePathname()

  return (
    <aside 
      className="hidden md:flex flex-col justify-between w-64 border-r border-slate-200 bg-white h-screen sticky top-0 shrink-0 select-none z-30 shadow-[1px_0_3px_rgba(0,0,0,0.02)]"
      aria-label="Seller Desktop Sidebar"
    >
      {/* 1. TOP SECTION: BRAND HEADER & NAVIGATION */}
      <div className="flex flex-col flex-1 min-h-0">
        {/* Task 1: Wrapped logo block in <Link href="/seller"> with cursor-pointer */}
        <Link 
          href="/seller" 
          onClick={(e) => {
            if (pathname === '/seller') {
              e.preventDefault()
              window.history.pushState(null, '', '/seller')
              window.dispatchEvent(new CustomEvent('seller-tab-change', { detail: 'dashboard' }))
            }
          }}
          className="p-5 border-b border-slate-100 flex items-center gap-3 shrink-0 cursor-pointer group hover:bg-slate-50/80 transition-colors"
        >
          <div className="w-10 h-10 rounded-xl bg-slate-900 flex items-center justify-center shadow-xs shrink-0 text-white font-black text-sm tracking-tighter">
            BB
          </div>
          <div className="flex flex-col min-w-0">
            <span className="font-extrabold text-slate-900 tracking-tight text-base leading-tight group-hover:text-[#059669] transition-colors">
              BrokerBridge
            </span>
            <span className="inline-flex items-center w-fit px-2 py-0.5 mt-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-emerald-50 text-[#047857] border border-emerald-200/80">
              Seller Workspace
            </span>
          </div>
        </Link>

        <Suspense fallback={<div className="flex-1 p-4 text-xs text-slate-400">Loading navigation...</div>}>
          <SidebarNavContent 
            profile={profile} 
            fullProfile={fullProfile} 
            userRole={userRole} 
          />
        </Suspense>
      </div>

      {/* 2. BOTTOM SECTION: PROFILE ANCHOR & NOTIFICATION BELL */}
      <div className="border-t border-slate-200 p-4 bg-white/50 shrink-0">
        <div className="flex items-center justify-between gap-2">
          <div className="flex-1 min-w-0">
            <SidebarProfileAnchor
              profile={profile}
              fullProfile={fullProfile}
              userRole={userRole}
            />
          </div>
          <div className="shrink-0">
            <NotificationBell />
          </div>
        </div>
      </div>
    </aside>
  )
}

// Export SellerMobileHeader for compatibility, rendering SellerMobileNav
export function SellerMobileHeader({
  profile,
  fullProfile,
  userRole = "SELLER_ADMIN",
}: SellerSidebarProps) {
  return (
    <SellerMobileNav 
      profile={profile}
      fullProfile={fullProfile}
      userRole={userRole}
    />
  )
}
