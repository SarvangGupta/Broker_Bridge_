'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  ArrowLeftRight,
  User,
  LogOut,
  ChevronDown,
  Building2,
  ShieldCheck,
} from 'lucide-react';
import { BUYER_NAV_ITEMS, BuyerNavItem } from './buyer-sidebar';
import { NotificationBell } from '@/src/components/layout/notification-bell';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { signOutAction } from '@/src/server/actions/auth-actions';

interface BuyerMobileNavProps {
  user?: {
    name?: string | null;
    email?: string | null;
    role?: string | null;
  } | null;
  company?: {
    name?: string | null;
    isVerified?: boolean | null;
  } | null;
}

export function BuyerMobileNav({ user, company }: BuyerMobileNavProps) {
  const pathname = usePathname();
  const router = useRouter();

  const isItemActive = (item: BuyerNavItem) => {
    if (item.href === '/buyer') {
      return pathname === '/buyer' || pathname === '/buyer/';
    }
    return pathname.startsWith(item.href);
  };

  const userName = user?.name || user?.email?.split('@')[0] || 'Buyer Admin';
  const companyName = company?.name || 'Buyer Enterprise';
  const initials = userName
    .split(' ')
    .map((n) => n[0])
    .join('')
    .substring(0, 2)
    .toUpperCase() || 'BA';

  return (
    <div className="md:hidden">
      {/* Sticky Top Header */}
      <header className="h-16 w-full bg-white border-b border-border flex items-center justify-between px-4 sticky top-0 z-40 select-none">
        {/* Left: Logo & Badge */}
        <Link href="/buyer" className="flex items-center gap-2 min-w-0">
          <div className="w-8 h-8 rounded-lg bg-[#0284C7] flex items-center justify-center text-white font-bold text-base shadow-xs shrink-0">
            B
          </div>
          <div className="min-w-0">
            <span className="font-bold text-slate-900 text-sm tracking-tight truncate block">
              BrokerBridge
            </span>
            <span className="text-[9px] font-extrabold text-[#0284C7] bg-[#E0F2FE] px-1 py-0.2 rounded uppercase block w-fit">
              BUYER
            </span>
          </div>
        </Link>

        {/* Right Actions: Notification Bell + User Profile Dropdown */}
        <div className="flex items-center gap-2 shrink-0">
          <NotificationBell />

          <DropdownMenu>
            <DropdownMenuTrigger className="focus:outline-none">
              <div className="flex items-center gap-1.5 p-1 rounded-full hover:bg-slate-100 transition-colors cursor-pointer">
                <div className="w-8 h-8 rounded-full bg-[#E0F2FE] text-[#0284C7] font-bold text-xs flex items-center justify-center border border-sky-200">
                  {initials}
                </div>
                <ChevronDown className="w-3.5 h-3.5 text-slate-400" />
              </div>
            </DropdownMenuTrigger>

            <DropdownMenuContent
              align="end"
              side="bottom"
              sideOffset={8}
              className="w-56 bg-white border border-border shadow-lg rounded-xl p-1 z-50"
            >
              <DropdownMenuLabel className="px-3 py-2">
                <div className="text-xs font-bold text-slate-900 truncate">
                  {userName}
                </div>
                <div className="text-[11px] font-medium text-slate-500 truncate flex items-center gap-1">
                  <Building2 className="w-3 h-3 inline text-slate-400 shrink-0" />
                  <span className="truncate">{companyName}</span>
                </div>
                {company?.isVerified && (
                  <div className="inline-flex items-center gap-1 text-[10px] font-semibold text-emerald-700 bg-emerald-50 px-1.5 py-0.5 rounded mt-1">
                    <ShieldCheck className="w-3 h-3" />
                    <span>Verified Buyer</span>
                  </div>
                )}
              </DropdownMenuLabel>

              <DropdownMenuSeparator className="my-1 border-t border-border" />

              {/* Crucial: Trader Workspace Toggle to /seller */}
              <DropdownMenuItem
                onClick={() => { window.location.href = '/seller'; }}
                className="px-3 py-2 rounded-lg text-xs font-semibold text-[#0284C7] hover:bg-[#E0F2FE] cursor-pointer flex items-center gap-2 transition-colors"
              >
                <ArrowLeftRight className="w-4 h-4 text-[#0284C7] shrink-0" />
                <span>Switch to Seller Workspace</span>
              </DropdownMenuItem>

              <DropdownMenuItem
                onClick={() => router.push('/buyer/profile')}
                className="px-3 py-2 rounded-lg text-xs font-medium text-slate-700 hover:bg-slate-100 cursor-pointer flex items-center gap-2 transition-colors"
              >
                <User className="w-4 h-4 text-slate-500 shrink-0" />
                <span>Organization Profile & KYC</span>
              </DropdownMenuItem>

              <DropdownMenuSeparator className="my-1 border-t border-border" />

              <DropdownMenuItem
                onClick={async () => {
                  await signOutAction();
                  window.location.href = '/login';
                }}
                className="px-3 py-2 rounded-lg text-xs font-medium text-rose-600 hover:bg-rose-50 cursor-pointer flex items-center gap-2 transition-colors"
              >
                <LogOut className="w-4 h-4 text-rose-500 shrink-0" />
                <span>Sign Out</span>
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </header>

      {/* Fixed Bottom Navigation Bar */}
      <nav
        aria-label="Buyer Mobile Bottom Navigation"
        className="fixed bottom-0 left-0 right-0 w-full h-16 bg-white border-t border-border z-50 flex justify-around items-center px-1 pb-safe select-none"
      >
        {BUYER_NAV_ITEMS.map((item) => {
          const Icon = item.icon;
          const isActive = isItemActive(item);

          return (
            <Link
              key={item.id}
              href={item.href}
              className={`
                flex flex-col items-center justify-center min-h-[48px] min-w-[48px] px-2 py-1 rounded-xl transition-all duration-150 flex-1
                ${
                  isActive
                    ? 'text-[#0284C7]'
                    : 'text-slate-500 hover:text-slate-900'
                }
              `}
            >
              <Icon
                className={`w-5 h-5 shrink-0 transition-all ${
                  isActive ? 'text-[#0284C7] stroke-[2.25] scale-110' : 'text-slate-400'
                }`}
              />
              <span
                className={`text-[11px] mt-0.5 truncate tracking-tight ${
                  isActive ? 'font-bold text-[#0284C7]' : 'font-medium text-slate-500'
                }`}
              >
                {item.label}
              </span>
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
