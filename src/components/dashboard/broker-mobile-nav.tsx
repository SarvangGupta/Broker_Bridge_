'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Sparkles,
  Handshake,
  Truck,
  MoreHorizontal,
  Search,
} from 'lucide-react';
import { NotificationBell } from '@/src/components/layout/notification-bell';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { LanguageSelector } from '@/src/components/ui/language-selector';
import { TranslationKey } from '@/src/lib/i18n/translations';

export interface BrokerMobileNavProps {
  user?: {
    id?: string;
    name?: string | null;
    email?: string | null;
    role?: string | null;
  } | null;
}

interface MobileNavItem {
  id: string;
  translationKey: TranslationKey;
  fallbackLabel: string;
  href: string;
  icon: React.ElementType;
}

const MOBILE_NAV_ITEMS: MobileNavItem[] = [
  {
    id: 'home',
    translationKey: 'navHome',
    fallbackLabel: 'Home',
    href: '/broker',
    icon: LayoutDashboard,
  },
  {
    id: 'work',
    translationKey: 'navWork',
    fallbackLabel: 'Work',
    href: '/broker/work',
    icon: Sparkles,
  },
  {
    id: 'deals',
    translationKey: 'navDeals',
    fallbackLabel: 'Deals',
    href: '/broker/deals',
    icon: Handshake,
  },
  {
    id: 'orders',
    translationKey: 'navOrders',
    fallbackLabel: 'Orders',
    href: '/broker/orders',
    icon: Truck,
  },
  {
    id: 'more',
    translationKey: 'navMore',
    fallbackLabel: 'More',
    href: '/broker/more',
    icon: MoreHorizontal,
  },
];

export function BrokerMobileNav({ user }: BrokerMobileNavProps) {
  const pathname = usePathname();
  const { t } = useLanguage();

  const isActive = (href: string) => {
    if (href === '/broker') {
      return pathname === '/broker';
    }
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  return (
    <>
      {/* 1. Mobile Sticky Top Header (md:hidden) */}
      <header className="md:hidden h-16 w-full bg-white border-b border-slate-200/80 flex items-center justify-between px-3.5 sticky top-0 z-40 shrink-0 select-none shadow-2xs">
        {/* Left: Logo & Title */}
        <Link href="/broker" className="flex items-center gap-2 min-w-0">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#0D9488] to-[#0F766E] flex items-center justify-center shadow-xs text-white font-black text-xs tracking-tighter shrink-0">
            BB
          </div>
          <div className="flex flex-col min-w-0">
            <div className="flex items-center gap-1.5">
              <span className="font-bold text-slate-900 text-sm tracking-tight truncate leading-none">
                {t('brandName')}
              </span>
              <span className="px-1.5 py-0.2 rounded text-[9px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200/70 shrink-0">
                {t('editionBadge')}
              </span>
            </div>
            <span className="text-[9px] font-mono font-semibold tracking-wider text-slate-400 uppercase mt-0.5">
              {t('appSubTitle')}
            </span>
          </div>
        </Link>

        {/* Right: Language Selector + Live Connectivity Dot + Notification Bell */}
        <div className="flex items-center gap-2 shrink-0">
          {/* Compact Language Toggle */}
          <LanguageSelector variant="compact" />

          {/* Live Online Connectivity Indicator */}
          <div className="flex items-center gap-1 px-1.5 py-0.5 rounded-full bg-emerald-50 border border-emerald-200/70" title={t('systemOnline')}>
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span className="text-[9px] font-bold text-emerald-700 tracking-tight">{t('liveStatus')}</span>
          </div>

          {/* Global Search Shortcut */}
          <Link
            href="/broker/search"
            className="p-1.5 rounded-lg text-slate-500 hover:text-[#0D9488] hover:bg-teal-50 transition-colors"
            title={t('navGlobalSearch')}
            aria-label={t('navGlobalSearch')}
          >
            <Search className="w-4 h-4" />
          </Link>

          {/* Notification Bell */}
          <NotificationBell />
        </div>
      </header>

      {/* 2. Mobile Fixed Bottom Navigation Bar (md:hidden) */}
      <nav
        aria-label="Mobile Navigation"
        className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white border-t border-slate-200/80 shadow-[0_-2px_10px_rgba(0,0,0,0.05)] select-none safe-area-pb"
      >
        <div className="grid grid-cols-5 h-16 w-full max-w-lg mx-auto">
          {MOBILE_NAV_ITEMS.map((item) => {
            const active = isActive(item.href);
            const Icon = item.icon;
            const label = t(item.translationKey, item.fallbackLabel);

            return (
              <Link
                key={item.id}
                href={item.href}
                className={`flex flex-col items-center justify-center min-h-[48px] py-1 transition-colors relative ${
                  active ? 'text-[#0D9488]' : 'text-slate-500 hover:text-slate-900'
                }`}
              >
                {/* Active Indicator Top Glow */}
                {active && (
                  <span className="absolute top-0 left-1/2 -translate-x-1/2 w-8 h-0.5 bg-[#0D9488] rounded-full" />
                )}

                <div
                  className={`w-7 h-7 flex items-center justify-center rounded-lg transition-transform ${
                    active ? 'scale-110 bg-[#CCFBF1]/50' : ''
                  }`}
                >
                  <Icon
                    className={`w-4 h-4 transition-colors ${
                      active ? 'stroke-[2.5] text-[#0D9488]' : 'stroke-[1.75]'
                    }`}
                  />
                </div>
                <span
                  className={`text-[10px] mt-0.5 tracking-tight truncate max-w-[56px] leading-tight ${
                    active ? 'font-bold' : 'font-medium'
                  }`}
                >
                  {label}
                </span>
              </Link>
            );
          })}
        </div>
      </nav>
    </>
  );
}
