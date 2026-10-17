'use client';

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname, useSearchParams, useRouter } from 'next/navigation';
import {
  LayoutDashboard,
  Package,
  Handshake,
  Truck,
  MoreHorizontal,
  FlaskConical,
  Wallet,
  TrendingUp,
  FolderLock,
  Users,
  User,
  HelpCircle,
  LogOut,
  ArrowLeftRight,
  Building2,
  Sparkles,
} from 'lucide-react';
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from '@/components/ui/sheet';
import { NotificationBell } from '@/src/components/layout/notification-bell';
import { SellerHeaderDropdown } from '@/src/components/dashboard/seller-header-dropdown';
import { SellerProfileDialog } from '@/src/components/dialogs/seller-profile-dialog';
import { SupportDialog } from '@/src/components/dialogs/support-dialog';
import { signOutAction } from '@/src/server/actions/auth-actions';

export interface SellerMobileNavProps {
  profile?: any;
  fullProfile?: any;
  userRole?: string;
}

export function SellerMobileNav({
  profile,
  fullProfile,
  userRole = 'SELLER_ADMIN',
}: SellerMobileNavProps) {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const router = useRouter();
  const currentTab = searchParams?.get('tab');

  const [isMoreSheetOpen, setIsMoreSheetOpen] = useState(false);
  const [isProfileOpen, setIsProfileOpen] = useState(false);
  const [isSupportOpen, setIsSupportOpen] = useState(false);

  const [activeTab, setActiveTab] = useState(currentTab || 'dashboard');

  useEffect(() => {
    setActiveTab(currentTab || 'dashboard');
  }, [currentTab]);

  useEffect(() => {
    const handleCustomTabChange = (e: Event) => {
      const customEvent = e as CustomEvent<string>;
      if (customEvent.detail) {
        setActiveTab(customEvent.detail);
      }
    };
    const handlePopState = () => {
      const params = new URLSearchParams(window.location.search);
      setActiveTab(params.get('tab') || 'dashboard');
    };
    window.addEventListener('seller-tab-change', handleCustomTabChange);
    window.addEventListener('popstate', handlePopState);
    return () => {
      window.removeEventListener('seller-tab-change', handleCustomTabChange);
      window.removeEventListener('popstate', handlePopState);
    };
  }, []);

  const handleNavClick = (e: React.MouseEvent, item: { id: string; href: string }) => {
    if (pathname === '/seller') {
      e.preventDefault();
      window.history.pushState(null, '', item.href);
      setActiveTab(item.id);
      window.dispatchEvent(new CustomEvent('seller-tab-change', { detail: item.id }));
    }
  };

  const isSellerAdmin =
    userRole.toUpperCase().includes('ADMIN') ||
    userRole.toUpperCase().includes('SELLER') ||
    !userRole;

  const companyName = fullProfile?.company?.name || profile?.name || 'Seller Workspace';

  // Primary 4 Tabs
  const primaryTabs = [
    {
      id: 'dashboard',
      label: 'Dashboard',
      href: '/seller',
      icon: LayoutDashboard,
      isActive: pathname === '/seller' && (!activeTab || activeTab === 'dashboard'),
    },
    {
      id: 'inventory',
      label: 'Inventory',
      href: '/seller?tab=inventory',
      icon: Package,
      isActive: (pathname === '/seller' && activeTab === 'inventory') || pathname.startsWith('/seller/inventory'),
    },
    {
      id: 'deals',
      label: 'Deals',
      href: '/seller?tab=deals',
      icon: Handshake,
      isActive: (pathname === '/seller' && activeTab === 'deals') || pathname.startsWith('/seller/requests') || pathname.startsWith('/seller/deals'),
    },
    {
      id: 'orders',
      label: 'Orders',
      href: '/seller?tab=orders',
      icon: Truck,
      isActive: (pathname === '/seller' && activeTab === 'orders') || pathname.startsWith('/seller/dispatch'),
    },
  ];

  // Secondary Modules inside "More" Sheet
  const secondaryItems = [
    {
      id: 'quality',
      label: 'Quality & Lab',
      href: '/seller?tab=quality',
      icon: FlaskConical,
      description: 'COA certificates & parameters',
      isActive: pathname === '/seller' && activeTab === 'quality',
    },
    {
      id: 'payments',
      label: 'Settlement & Pay',
      href: '/seller?tab=payments',
      icon: Wallet,
      description: 'Receivables & payment ledger',
      isActive: (pathname === '/seller' && activeTab === 'payments') || pathname.startsWith('/seller/payments'),
    },
    {
      id: 'reports',
      label: 'Reports & Visibility',
      href: '/seller?tab=reports',
      icon: TrendingUp,
      description: 'Sales trends & inventory state',
      isActive: (pathname === '/seller' && activeTab === 'reports') || pathname.startsWith('/seller/reports'),
    },
    {
      id: 'documents',
      label: 'Documents Vault',
      href: '/seller?tab=documents',
      icon: FolderLock,
      description: 'Trade invoices & LR files',
      isActive: pathname === '/seller' && activeTab === 'documents',
    },
    ...(isSellerAdmin
      ? [
          {
            id: 'team',
            label: 'Team Management',
            href: '/seller?tab=team',
            icon: Users,
            description: 'Manage users & company KYC',
            isActive: pathname === '/seller' && activeTab === 'team',
          },
        ]
      : []),
  ];

  const isAnyMoreItemActive = secondaryItems.some((item) => item.isActive);

  const handleSignOut = async () => {
    await signOutAction();
  };

  return (
    <>
      {/* 1. Mobile Slim Top Header (md:hidden) */}
      <header className="flex md:hidden h-16 w-full border-b border-slate-200 items-center justify-between px-4 bg-white sticky top-0 z-40 shadow-2xs select-none">
        {/* Task 1: Top-Left Logo Block wrapped in <Link href="/seller"> with cursor-pointer */}
        <Link 
          href="/seller" 
          onClick={(e) => {
            if (pathname === '/seller') {
              e.preventDefault();
              window.history.pushState(null, '', '/seller');
              setActiveTab('dashboard');
              window.dispatchEvent(new CustomEvent('seller-tab-change', { detail: 'dashboard' }));
            }
          }}
          className="flex items-center gap-2.5 cursor-pointer group"
        >
          <div className="w-8 h-8 rounded-lg bg-slate-900 flex items-center justify-center shadow-xs shrink-0 text-white font-black text-xs">
            BB
          </div>
          <div className="flex flex-col">
            <span className="font-extrabold text-slate-900 tracking-tight text-sm leading-none group-hover:text-[#059669] transition-colors">
              BrokerBridge
            </span>
            <span className="text-[10px] text-[#059669] font-bold tracking-tight mt-0.5">
              Seller Workspace
            </span>
          </div>
        </Link>

        {/* Right Actions: Notifications & User Menu */}
        <div className="flex items-center gap-2">
          <NotificationBell />
          <SellerHeaderDropdown
            profile={profile}
            fullProfile={fullProfile}
            role={userRole}
          />
        </div>
      </header>

      {/* 2. Mobile Bottom Navigation Bar (md:hidden) */}
      {/* Task 3: fixed bottom-0 w-full h-16 bg-white border-t z-50 flex justify-around items-center pb-safe md:hidden */}
      <nav
        className="fixed bottom-0 left-0 right-0 w-full h-16 bg-white border-t border-slate-200 z-50 flex justify-around items-center pb-safe md:hidden shadow-[0_-4px_12px_rgba(0,0,0,0.03)] select-none"
        aria-label="Seller Mobile Bottom Navigation"
      >
        {/* Render 4 Primary Tabs */}
        {primaryTabs.map((tab) => {
          const Icon = tab.icon;
          return (
            <Link
              key={tab.id}
              href={tab.href}
              onClick={(e) => handleNavClick(e, tab)}
              className={`flex flex-col items-center justify-center min-h-[48px] min-w-[48px] px-1 py-1 flex-1 relative transition-colors touch-manipulation ${
                tab.isActive
                  ? 'text-[#059669]'
                  : 'text-slate-400 hover:text-slate-600 active:text-slate-900'
              }`}
              aria-current={tab.isActive ? 'page' : undefined}
            >
              {/* Active Indicator Top Pill */}
              {tab.isActive && (
                <span className="absolute top-0 w-8 h-1 rounded-full bg-[#059669]" />
              )}

              <Icon
                className={`w-5 h-5 transition-transform ${
                  tab.isActive ? 'text-[#059669] stroke-[2.25] scale-105' : 'text-slate-400'
                }`}
              />

              <span
                className={`text-[10px] mt-1 tracking-tight leading-none ${
                  tab.isActive ? 'font-bold text-[#059669]' : 'font-medium text-slate-500'
                }`}
              >
                {tab.label}
              </span>
            </Link>
          );
        })}

        {/* 5th Tab: "More" Button opening Bottom Sheet */}
        <button
          onClick={() => setIsMoreSheetOpen(true)}
          className={`flex flex-col items-center justify-center min-h-[48px] min-w-[48px] px-1 py-1 flex-1 relative transition-colors touch-manipulation cursor-pointer ${
            isAnyMoreItemActive
              ? 'text-[#059669]'
              : 'text-slate-400 hover:text-slate-600 active:text-slate-900'
          }`}
          aria-label="Open More modules"
        >
          {isAnyMoreItemActive && (
            <span className="absolute top-0 w-8 h-1 rounded-full bg-[#059669]" />
          )}

          <MoreHorizontal
            className={`w-5 h-5 transition-transform ${
              isAnyMoreItemActive ? 'text-[#059669] stroke-[2.25] scale-105' : 'text-slate-400'
            }`}
          />

          <span
            className={`text-[10px] mt-1 tracking-tight leading-none ${
              isAnyMoreItemActive ? 'font-bold text-[#059669]' : 'font-medium text-slate-500'
            }`}
          >
            More
          </span>
        </button>
      </nav>

      {/* 3. Mobile "More" Sliding Bottom Sheet Drawer */}
      <Sheet open={isMoreSheetOpen} onOpenChange={setIsMoreSheetOpen}>
        <SheetContent side="bottom" className="rounded-t-2xl max-h-[85vh] overflow-y-auto p-4 sm:p-6 bg-white border-t border-slate-200">
          <SheetHeader className="pb-3 border-b border-slate-100 text-left">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-[#ECFDF5] border border-emerald-200 flex items-center justify-center">
                <Sparkles className="w-4 h-4 text-[#059669]" />
              </div>
              <div>
                <SheetTitle className="text-base font-bold text-slate-900">
                  Seller Workspace Modules
                </SheetTitle>
                <SheetDescription className="text-xs text-slate-500">
                  {companyName} · Additional features
                </SheetDescription>
              </div>
            </div>
          </SheetHeader>

          {/* Secondary Links List */}
          <div className="py-3 space-y-1">
            <div className="px-2 pb-1 text-[10px] font-bold uppercase tracking-wider text-slate-400">
              Operations & Finance
            </div>
            {secondaryItems.map((item) => {
              const Icon = item.icon;
              return (
                <Link
                  key={item.id}
                  href={item.href}
                  onClick={(e) => {
                    setIsMoreSheetOpen(false);
                    handleNavClick(e, item);
                  }}
                  className={`flex items-center gap-3 p-3 rounded-xl min-h-[48px] transition-all cursor-pointer ${
                    item.isActive
                      ? 'bg-[#ECFDF5] text-[#059669] font-bold border border-emerald-200/80 shadow-2xs'
                      : 'text-slate-700 hover:bg-slate-50 font-medium'
                  }`}
                >
                  <div
                    className={`w-9 h-9 rounded-lg flex items-center justify-center shrink-0 ${
                      item.isActive ? 'bg-[#059669] text-white' : 'bg-slate-100 text-slate-600'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-xs font-bold leading-tight">{item.label}</div>
                    <div className="text-[11px] text-slate-400 font-normal truncate mt-0.5">
                      {item.description}
                    </div>
                  </div>
                </Link>
              );
            })}
          </div>

          {/* Quick Account Actions */}
          <div className="pt-2 border-t border-slate-100 space-y-1">
            <div className="px-2 pb-1 text-[10px] font-bold uppercase tracking-wider text-slate-400">
              Account & Utilities
            </div>

            <button
              onClick={() => {
                setIsMoreSheetOpen(false);
                window.location.href = '/buyer';
              }}
              className="w-full flex items-center gap-3 p-2.5 rounded-xl min-h-[48px] text-xs font-semibold text-emerald-800 hover:bg-emerald-50 transition-colors text-left cursor-pointer"
            >
              <ArrowLeftRight className="w-4 h-4 text-[#059669] shrink-0" />
              <span>Switch to Buyer Workspace</span>
            </button>

            <button
              onClick={() => {
                setIsMoreSheetOpen(false);
                setIsProfileOpen(true);
              }}
              className="w-full flex items-center gap-3 p-2.5 rounded-xl min-h-[48px] text-xs font-medium text-slate-700 hover:bg-slate-50 transition-colors text-left cursor-pointer"
            >
              <User className="w-4 h-4 text-slate-500 shrink-0" />
              <span>Organization & KYC Profile</span>
            </button>

            <button
              onClick={() => {
                setIsMoreSheetOpen(false);
                setIsSupportOpen(true);
              }}
              className="w-full flex items-center gap-3 p-2.5 rounded-xl min-h-[48px] text-xs font-medium text-slate-700 hover:bg-slate-50 transition-colors text-left cursor-pointer"
            >
              <HelpCircle className="w-4 h-4 text-slate-500 shrink-0" />
              <span>Help & Support Desk</span>
            </button>

            <button
              onClick={() => {
                setIsMoreSheetOpen(false);
                handleSignOut();
              }}
              className="w-full flex items-center gap-3 p-2.5 rounded-xl min-h-[48px] text-xs font-semibold text-rose-600 hover:bg-rose-50 transition-colors text-left cursor-pointer"
            >
              <LogOut className="w-4 h-4 text-rose-500 shrink-0" />
              <span>Sign out securely</span>
            </button>
          </div>
        </SheetContent>
      </Sheet>

      <SellerProfileDialog
        open={isProfileOpen}
        onOpenChange={setIsProfileOpen}
        initialProfileData={fullProfile}
      />
      <SupportDialog
        open={isSupportOpen}
        onOpenChange={setIsSupportOpen}
      />
    </>
  );
}
