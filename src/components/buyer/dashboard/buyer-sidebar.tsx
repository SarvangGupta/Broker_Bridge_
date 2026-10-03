'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  LayoutDashboard,
  ClipboardList,
  Handshake,
  Truck,
  MoreHorizontal,
  ArrowLeftRight,
  User,
  LogOut,
  ChevronUp,
  Building2,
  ShieldCheck,
} from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { signOutAction } from '@/src/server/actions/auth-actions';

export interface BuyerNavItem {
  id: string;
  label: string;
  href: string;
  icon: React.ElementType;
}

export const BUYER_NAV_ITEMS: BuyerNavItem[] = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    href: '/buyer',
    icon: LayoutDashboard,
  },
  {
    id: 'requirements',
    label: 'Requirements',
    href: '/buyer/requirements',
    icon: ClipboardList,
  },
  {
    id: 'proposals',
    label: 'Proposals',
    href: '/buyer/proposals',
    icon: Handshake,
  },
  {
    id: 'orders',
    label: 'Orders',
    href: '/buyer/orders',
    icon: Truck,
  },
  {
    id: 'more',
    label: 'More',
    href: '/buyer/more',
    icon: MoreHorizontal,
  },
];

interface BuyerSidebarProps {
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

export function BuyerSidebar({ user, company }: BuyerSidebarProps) {
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
    <aside
      className="hidden md:flex flex-col w-64 border-r border-border bg-white h-screen sticky top-0 shrink-0 z-30 select-none"
      aria-label="Buyer Desktop Sidebar"
    >
      {/* Top Branding Section */}
      <div className="h-16 px-5 flex items-center gap-3 border-b border-border shrink-0">
        <div className="w-9 h-9 rounded-xl bg-[#0284C7] flex items-center justify-center text-white font-bold text-lg shadow-sm">
          B
        </div>
        <div className="min-w-0">
          <div className="font-bold text-slate-900 leading-tight truncate">
            BrokerBridge
          </div>
          <div className="inline-flex items-center gap-1 text-[10px] font-bold tracking-wider text-[#0284C7] bg-[#E0F2FE] px-1.5 py-0.5 rounded uppercase">
            <span>BUYER WORKSPACE</span>
          </div>
        </div>
      </div>

      {/* Middle Navigation Array */}
      <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-1">
        <div className="px-3 pb-2 text-[11px] font-bold uppercase tracking-wider text-slate-400">
          Main Navigation
        </div>

        {BUYER_NAV_ITEMS.map((item) => {
          const Icon = item.icon;
          const isActive = isItemActive(item);

          return (
            <Link
              key={item.id}
              href={item.href}
              className={`
                group flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-sm transition-all duration-150 min-h-[44px]
                ${
                  isActive
                    ? 'bg-[#E0F2FE] text-[#0284C7] font-bold shadow-2xs border border-sky-200/80'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900 font-medium'
                }
              `}
            >
              <Icon
                className={`w-5 h-5 shrink-0 transition-colors ${
                  isActive
                    ? 'text-[#0284C7] stroke-[2.25]'
                    : 'text-slate-400 group-hover:text-slate-700'
                }`}
              />
              <span className="truncate flex-1">{item.label}</span>
            </Link>
          );
        })}
      </nav>

      {/* Task 2: Profile Anchor & Trader Workspace Toggle */}
      <div className="mt-auto border-t border-border p-3 shrink-0">
        <DropdownMenu>
          <DropdownMenuTrigger className="w-full focus:outline-none">
            <div className="flex items-center gap-3 p-2 rounded-xl hover:bg-slate-100 transition-colors w-full cursor-pointer text-left">
              <div className="w-9 h-9 rounded-full bg-[#E0F2FE] text-[#0284C7] font-bold text-xs flex items-center justify-center shrink-0 border border-sky-200">
                {initials}
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-xs font-bold text-slate-900 truncate">
                  {userName}
                </div>
                <div className="text-[11px] text-slate-500 truncate flex items-center gap-1">
                  <Building2 className="w-3 h-3 inline text-slate-400 shrink-0" />
                  <span className="truncate">{companyName}</span>
                </div>
              </div>
              <ChevronUp className="w-4 h-4 text-slate-400 shrink-0" />
            </div>
          </DropdownMenuTrigger>

          <DropdownMenuContent
            align="start"
            side="top"
            sideOffset={8}
            className="w-56 bg-white border border-border shadow-md rounded-xl p-1 z-50"
          >
            <DropdownMenuLabel className="px-3 py-2">
              <div className="text-xs font-bold text-slate-900 truncate">
                {userName}
              </div>
              <div className="text-[11px] font-medium text-slate-500 truncate">
                {user?.email || 'BUYER_ADMIN'}
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
              onClick={() => router.push('/seller')}
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
    </aside>
  );
}
