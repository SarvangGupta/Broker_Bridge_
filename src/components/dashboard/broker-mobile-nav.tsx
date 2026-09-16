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
} from 'lucide-react';
import { NotificationBell } from '@/src/components/layout/notification-bell';

export interface BrokerMobileNavProps {
  user?: {
    id?: string;
    name?: string | null;
    email?: string | null;
    role?: string | null;
  } | null;
}

const MOBILE_NAV_ITEMS = [
  {
    id: 'home',
    label: 'Home',
    href: '/broker',
    icon: LayoutDashboard,
  },
  {
    id: 'work',
    label: 'Work',
    href: '/broker/work',
    icon: Sparkles,
  },
  {
    id: 'deals',
    label: 'Deals',
    href: '/broker/deals',
    icon: Handshake,
  },
  {
    id: 'orders',
    label: 'Orders',
    href: '/broker/orders',
    icon: Truck,
  },
  {
    id: 'more',
    label: 'More',
    href: '/broker/more',
    icon: MoreHorizontal,
  },
];

export function BrokerMobileNav({ user }: BrokerMobileNavProps) {
  const pathname = usePathname();

  const isActive = (href: string) => {
    if (href === '/broker') {
      return pathname === '/broker';
    }
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  return (
    <>
      {/* 1. Mobile Sticky Top Header (md:hidden) */}
      <header className="md:hidden h-16 w-full bg-white border-b border-border flex items-center justify-between px-3.5 sticky top-0 z-40 shrink-0 select-none shadow-2xs">
        {/* Left: Logo & Title */}
        <Link href="/broker" className="flex items-center gap-2 min-w-0">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#0D9488] to-[#0F766E] flex items-center justify-center shadow-xs text-white font-black text-xs tracking-tighter shrink-0">
            BB
          </div>
          <div className="flex flex-col min-w-0">
            <div className="flex items-center gap-1.5">
              <span className="font-bold text-slate-900 text-sm tracking-tight truncate leading-none">
                BrokerBridge
              </span>
              <span className="px-1.5 py-0.2 rounded text-[9px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200/70 shrink-0">
                LITE
              </span>
            </div>
            <span className="text-[9px] font-mono font-semibold tracking-wider text-slate-400 uppercase mt-0.5">
              BROKER WORKSTATION
            </span>
          </div>
        </Link>

        {/* Right: Connectivity Dot + Notification Bell */}
        <div className="flex items-center gap-2 shrink-0">
          {/* Live Online Connectivity Indicator */}
          <div className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-emerald-50 border border-emerald-200/70" title="Broker System Online">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <span className="text-[9px] font-bold text-emerald-700 tracking-tight">LIVE</span>
          </div>

          <NotificationBell />
        </div>
      </header>

      {/* 2. Mobile Fixed Bottom Navigation Bar (md:hidden) */}
      <nav
        className="md:hidden fixed bottom-0 left-0 right-0 w-full h-16 bg-white border-t border-border z-50 flex justify-around items-center pb-safe shadow-[0_-4px_12px_rgba(0,0,0,0.03)] select-none"
        aria-label="Mobile Bottom Navigation"
      >
        {MOBILE_NAV_ITEMS.map((item) => {
          const active = isActive(item.href);
          const Icon = item.icon;

          return (
            <Link
              key={item.id}
              href={item.href}
              className={`flex flex-col items-center justify-center min-h-[48px] min-w-[48px] px-1 py-1 flex-1 relative transition-colors touch-manipulation ${
                active ? 'text-[#0D9488]' : 'text-slate-400 hover:text-slate-600 active:text-slate-900'
              }`}
              aria-current={active ? 'page' : undefined}
            >
              {/* Active Indicator Top Pill */}
              {active && (
                <span className="absolute top-0 w-8 h-1 rounded-full bg-[#0D9488]" />
              )}

              <Icon
                className={`w-5 h-5 transition-transform ${
                  active ? 'text-[#0D9488] stroke-[2.25] scale-105' : 'text-slate-400'
                }`}
              />

              <span
                className={`text-[10px] mt-1 tracking-tight leading-none ${
                  active ? 'font-bold text-[#0D9488]' : 'font-medium text-slate-500'
                }`}
              >
                {item.label}
              </span>
            </Link>
          );
        })}
      </nav>
    </>
  );
}
