'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  LayoutDashboard,
  Sparkles,
  Handshake,
  Truck,
  Users2,
  Search,
  AlertTriangle,
  Wallet,
  FileText,
  MoreHorizontal,
  LogOut,
  SlidersHorizontal,
  MoreVertical,
  Bell,
} from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { signOutAction } from '@/src/server/actions/auth-actions';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { LanguageSelector } from '@/src/components/ui/language-selector';
import { TranslationKey } from '@/src/lib/i18n/translations';

export interface BrokerNavItem {
  id: string;
  translationKey: TranslationKey;
  fallbackLabel: string;
  href: string;
  icon: React.ElementType;
  badge?: string;
}

export const BROKER_CORE_NAV_ITEMS: BrokerNavItem[] = [
  {
    id: 'home',
    translationKey: 'navHome',
    fallbackLabel: 'Home',
    href: '/broker',
    icon: LayoutDashboard,
  },
  {
    id: 'search',
    translationKey: 'navGlobalSearch',
    fallbackLabel: 'Global Search',
    href: '/broker/search',
    icon: Search,
    badge: 'RB-07',
  },
  {
    id: 'work',
    translationKey: 'navWork',
    fallbackLabel: 'Work Desk',
    href: '/broker/work',
    icon: Sparkles,
  },
  {
    id: 'deals',
    translationKey: 'navDeals',
    fallbackLabel: 'Deals & Negotiations',
    href: '/broker/deals',
    icon: Handshake,
  },
  {
    id: 'orders',
    translationKey: 'navOrders',
    fallbackLabel: 'Orders & Dispatches',
    href: '/broker/orders',
    icon: Truck,
  },
  {
    id: 'directory',
    translationKey: 'navDirectory',
    fallbackLabel: 'Directory',
    href: '/broker/directory',
    icon: Users2,
    badge: 'RB-05',
  },
];

export const BROKER_FINANCE_NAV_ITEMS: BrokerNavItem[] = [
  {
    id: 'disputes',
    translationKey: 'navDisputes',
    fallbackLabel: 'Disputes & Claims',
    href: '/broker/more/disputes',
    icon: AlertTriangle,
  },
  {
    id: 'commission',
    translationKey: 'navCommission',
    fallbackLabel: 'Commission & Invoices',
    href: '/broker/more/commission',
    icon: Wallet,
  },
  {
    id: 'reports',
    translationKey: 'navReports',
    fallbackLabel: 'Reports',
    href: '/broker/reports',
    icon: FileText,
    badge: 'RB-07',
  },
  {
    id: 'more',
    translationKey: 'navMore',
    fallbackLabel: 'More Tools',
    href: '/broker/more',
    icon: MoreHorizontal,
  },
];

export interface BrokerSidebarProps {
  user?: {
    id?: string;
    name?: string | null;
    email?: string | null;
    role?: string | null;
  } | null;
  companyName?: string | null;
}

export function BrokerSidebar({ user, companyName }: BrokerSidebarProps) {
  const pathname = usePathname();
  const router = useRouter();
  const [isSigningOut, setIsSigningOut] = useState(false);
  const { t, language } = useLanguage();

  const isActive = (href: string) => {
    if (href === '/broker') {
      return pathname === '/broker';
    }
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  const handleSignOut = async () => {
    try {
      setIsSigningOut(true);
      await signOutAction();
    } catch (error: any) {
      if (error?.message === 'NEXT_REDIRECT' || error?.digest?.startsWith('NEXT_REDIRECT')) {
        throw error;
      }
      console.error('Failed to sign out:', error);
      setIsSigningOut(false);
    }
  };

  const userName = user?.name || t('defaultBrokerName');
  const displayCompany = companyName || t('defaultDeskName');

  const getInitials = (name: string) => {
    if (!name) return 'BR';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  };

  return (
    <aside className="hidden md:flex flex-col w-64 border-r border-slate-200/80 bg-white h-screen sticky top-0 shrink-0 z-30 select-none">
      {/* Top Section: Logo + BROKER WORKSTATION badge */}
      <div className="h-16 flex items-center justify-between px-4 border-b border-slate-100 shrink-0">
        <Link href="/broker" className="flex items-center gap-2.5 group">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#0D9488] to-[#0F766E] flex items-center justify-center shadow-xs text-white font-black text-xs tracking-tighter">
            BB
          </div>
          <div className="flex flex-col min-w-0">
            <span className="font-bold text-slate-900 text-sm tracking-tight leading-none group-hover:text-[#0D9488] transition-colors truncate">
              {t('brandName')}
            </span>
            <span className="text-[9px] font-mono font-bold tracking-widest text-[#0D9488] uppercase mt-0.5">
              {t('appSubTitle')}
            </span>
          </div>
        </Link>
        <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200/70">
          {t('editionBadge')}
        </span>
      </div>

      {/* Middle Section: Scrollable Navigation Array */}
      <nav className="flex-1 overflow-y-auto px-3 py-3 space-y-4">
        {/* Trading Workflows */}
        <div className="space-y-1">
          <div className="px-3 text-[10px] font-mono font-bold uppercase tracking-wider text-slate-400">
            {language === 'hi' ? 'व्यापार परिचालन' : 'Trading Desk'}
          </div>
          {BROKER_CORE_NAV_ITEMS.map((item) => {
            const active = isActive(item.href);
            const Icon = item.icon;
            const label = t(item.translationKey, item.fallbackLabel);

            return (
              <Link
                key={item.id}
                href={item.href}
                className={`flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-semibold transition-all duration-150 ${
                  active
                    ? 'bg-[#CCFBF1] text-[#0D9488] font-bold shadow-2xs'
                    : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50'
                }`}
              >
                <Icon
                  className={`w-4 h-4 shrink-0 transition-colors ${
                    active ? 'text-[#0D9488] stroke-[2.25]' : 'text-slate-400'
                  }`}
                />
                <span className="truncate flex-1">{label}</span>
                {item.badge && (
                  <span className="text-[9px] font-mono px-1.5 py-0.2 rounded bg-slate-100 text-slate-500 font-bold border border-slate-200/80">
                    {item.badge}
                  </span>
                )}
                {active && !item.badge && (
                  <span className="w-1.5 h-1.5 rounded-full bg-[#0D9488] shrink-0" />
                )}
              </Link>
            );
          })}
        </div>

        {/* Financial & Governance */}
        <div className="space-y-1">
          <div className="px-3 text-[10px] font-mono font-bold uppercase tracking-wider text-slate-400">
            {language === 'hi' ? 'वित्त व शासन' : 'Governance & Finance'}
          </div>
          {BROKER_FINANCE_NAV_ITEMS.map((item) => {
            const active = isActive(item.href);
            const Icon = item.icon;
            const label = t(item.translationKey, item.fallbackLabel);

            return (
              <Link
                key={item.id}
                href={item.href}
                className={`flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-semibold transition-all duration-150 ${
                  active
                    ? 'bg-[#CCFBF1] text-[#0D9488] font-bold shadow-2xs'
                    : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50'
                }`}
              >
                <Icon
                  className={`w-4 h-4 shrink-0 transition-colors ${
                    active ? 'text-[#0D9488] stroke-[2.25]' : 'text-slate-400'
                  }`}
                />
                <span className="truncate flex-1">{label}</span>
                {item.badge && (
                  <span className="text-[9px] font-mono px-1.5 py-0.2 rounded bg-slate-100 text-slate-500 font-bold border border-slate-200/80">
                    {item.badge}
                  </span>
                )}
                {active && !item.badge && (
                  <span className="w-1.5 h-1.5 rounded-full bg-[#0D9488] shrink-0" />
                )}
              </Link>
            );
          })}
        </div>

        {/* Notifications Quick Entry */}
        <div className="pt-2">
          <Link
            href="/broker/notifications"
            className={`flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-semibold transition-all duration-150 ${
              isActive('/broker/notifications')
                ? 'bg-[#CCFBF1] text-[#0D9488] font-bold shadow-2xs'
                : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50'
            }`}
          >
            <Bell className="w-4 h-4 text-slate-400 shrink-0" />
            <span className="truncate flex-1">{t('navNotifications')}</span>
          </Link>
        </div>
      </nav>

      {/* Language Switcher Section */}
      <div className="px-3 py-2 border-t border-slate-100 bg-slate-50/30 flex items-center justify-between gap-2 shrink-0">
        <span className="text-[11px] font-medium text-slate-500">
          {t('actionSelectLanguage')}:
        </span>
        <LanguageSelector variant="pill" />
      </div>

      {/* Bottom Anchor: User Profile Avatar & Sign Out Dropdown */}
      <div className="p-3 border-t border-slate-200/80 bg-slate-50/50 shrink-0">
        <DropdownMenu>
          <DropdownMenuTrigger className="w-full flex items-center justify-between gap-2 p-2 rounded-xl text-left hover:bg-white hover:shadow-2xs border border-transparent hover:border-slate-200 transition-all cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-[#0D9488]">
            <div className="flex items-center gap-2.5 min-w-0 flex-1">
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-[#CCFBF1] border border-teal-200/80 shadow-2xs shrink-0">
                <span className="font-bold text-xs text-[#0D9488] tracking-tight">
                  {getInitials(userName)}
                </span>
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-xs font-bold text-slate-900 truncate leading-tight">
                  {userName}
                </div>
                <div className="text-[11px] text-slate-500 truncate mt-0.5 font-medium">
                  {displayCompany}
                </div>
              </div>
            </div>
            <MoreVertical className="w-4 h-4 text-slate-400 shrink-0" />
          </DropdownMenuTrigger>

          <DropdownMenuContent className="w-60 mb-2 shadow-xl border-slate-200 rounded-xl p-1.5" side="top" align="start">
            <DropdownMenuGroup>
              <DropdownMenuLabel className="font-normal p-2.5 bg-slate-50 rounded-lg mb-1 border border-slate-100">
                <div className="flex flex-col space-y-1">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-sm font-bold text-slate-900 leading-tight truncate">
                      {userName}
                    </p>
                    <span className="shrink-0 px-2 py-0.5 rounded text-[10px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200">
                      {t('userRoleBroker')}
                    </span>
                  </div>
                  <p className="text-xs text-slate-500 truncate font-medium">
                    {user?.email || 'broker@brokerbridge.in'}
                  </p>
                </div>
              </DropdownMenuLabel>
            </DropdownMenuGroup>

            <DropdownMenuGroup>
              <DropdownMenuItem
                onClick={() => router.push('/broker/more')}
                className="flex items-center gap-2 px-2.5 py-2 text-xs font-semibold text-slate-700 rounded-lg hover:bg-slate-100 cursor-pointer"
              >
                <SlidersHorizontal className="w-4 h-4 text-slate-500" />
                <span>{t('navPreferences')}</span>
              </DropdownMenuItem>
            </DropdownMenuGroup>

            <DropdownMenuSeparator className="my-1 border-slate-100" />

            <DropdownMenuItem
              onClick={handleSignOut}
              disabled={isSigningOut}
              className="flex items-center gap-2 px-2.5 py-2 text-xs font-semibold text-red-600 rounded-lg hover:bg-red-50 cursor-pointer focus:bg-red-50 focus:text-red-700"
            >
              <LogOut className="w-4 h-4 text-red-500" />
              <span>{isSigningOut ? t('navSigningOut') : t('navSignOut')}</span>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </aside>
  );
}
