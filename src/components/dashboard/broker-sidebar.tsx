'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  LayoutDashboard,
  Sparkles,
  Handshake,
  Truck,
  MoreHorizontal,
  LogOut,
  SlidersHorizontal,
  ChevronRight,
  ShieldCheck,
  User,
  MoreVertical,
  Smartphone,
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
import { BrokerProfileDialog } from '@/src/components/dialogs/broker-profile-dialog';


export interface BrokerNavItem {
  id: string;
  label: string;
  href: string;
  icon: React.ElementType;
  description?: string;
  badge?: string;
}

export const BROKER_NAV_ITEMS: BrokerNavItem[] = [
  {
    id: 'home',
    label: 'Home',
    href: '/broker',
    icon: LayoutDashboard,
    description: 'Operational overview & action items',
  },
  {
    id: 'work',
    label: 'Work',
    href: '/broker/work',
    icon: Sparkles,
    description: 'Demand-supply matching & inquiries',
  },
  {
    id: 'deals',
    label: 'Deals',
    href: '/broker/deals',
    icon: Handshake,
    description: 'Active negotiations & finalizations',
  },
  {
    id: 'orders',
    label: 'Orders',
    href: '/broker/orders',
    icon: Truck,
    description: 'Booked lots & logistics dispatches',
  },
  {
    id: 'more',
    label: 'More',
    href: '/broker/more',
    icon: MoreHorizontal,
    description: 'CRM contacts, tasks & settings',
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
  const [isProfileOpen, setIsProfileOpen] = useState(false);
  const [profileTab, setProfileTab] = useState("profile");

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

  const userName = user?.name || 'Broker Partner';
  const displayCompany = companyName || 'Brokerage Desk';

  const getInitials = (name: string) => {
    if (!name) return 'BR';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  };

  return (
    <aside className="hidden md:flex flex-col w-64 border-r border-border bg-white h-screen sticky top-0 shrink-0 z-30 select-none">
      {/* Top Section: Logo + BROKER WORKSTATION badge */}
      <div className="h-16 flex items-center justify-between px-4 border-b border-border shrink-0">
        <Link href="/broker" className="flex items-center gap-2.5 group">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#0D9488] to-[#0F766E] flex items-center justify-center shadow-xs text-white font-black text-xs tracking-tighter">
            BB
          </div>
          <div className="flex flex-col">
            <span className="font-bold text-slate-900 text-sm tracking-tight leading-none group-hover:text-[#0D9488] transition-colors">
              BrokerBridge
            </span>
            <span className="text-[9px] font-mono font-bold tracking-widest text-[#0D9488] uppercase mt-0.5">
              WORKSTATION
            </span>
          </div>
        </Link>
        <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200/70">
          LITE
        </span>
      </div>

      {/* Middle Section: Navigation Array */}
      <nav className="flex-1 overflow-y-auto px-3 py-4 space-y-1">
        {BROKER_NAV_ITEMS.map((item) => {
          const active = isActive(item.href);
          const Icon = item.icon;

          return (
            <Link
              key={item.id}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150 ${
                active
                  ? 'bg-[#CCFBF1] text-[#0D9488] font-bold shadow-xs'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50'
              }`}
            >
              <Icon
                className={`w-5 h-5 shrink-0 transition-colors ${
                  active ? 'text-[#0D9488] stroke-[2.25]' : 'text-slate-400 group-hover:text-slate-600'
                }`}
              />
              <span className="truncate flex-1">{item.label}</span>
              {active && (
                <span className="w-1.5 h-1.5 rounded-full bg-[#0D9488] shrink-0" />
              )}
            </Link>
          );
        })}
      </nav>

      {/* Bottom Anchor: User Profile Avatar & Sign Out Dropdown */}
      <div className="p-3 border-t border-border bg-slate-50/50 shrink-0">
        <DropdownMenu>
          <DropdownMenuTrigger className="w-full flex items-center justify-between gap-2 p-2 rounded-xl text-left hover:bg-white hover:shadow-xs border border-transparent hover:border-border transition-all cursor-pointer outline-none focus-visible:ring-2 focus-visible:ring-[#0D9488]">
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

          <DropdownMenuContent className="w-60 mb-2 shadow-xl border-border rounded-xl p-1.5" side="top" align="start">
            <DropdownMenuGroup>
              <DropdownMenuLabel className="font-normal p-2.5 bg-slate-50 rounded-lg mb-1 border border-slate-100">
                <div className="flex flex-col space-y-1">
                  <div className="flex items-center justify-between gap-2">
                    <p className="text-sm font-bold text-slate-900 leading-tight truncate">
                      {userName}
                    </p>
                    <span className="shrink-0 px-2 py-0.5 rounded text-[10px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200">
                      BROKER
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
                onClick={() => {
                  setProfileTab("profile");
                  setIsProfileOpen(true);
                }}
                className="flex items-center gap-2 px-2.5 py-2 text-xs font-semibold text-slate-700 rounded-lg hover:bg-slate-100 cursor-pointer"
              >
                <User className="w-4 h-4 text-slate-500" />
                <span>Profile Settings</span>
              </DropdownMenuItem>

              <DropdownMenuItem
                onClick={() => {
                  setProfileTab("app");
                  setIsProfileOpen(true);
                }}
                className="flex items-center gap-2 px-2.5 py-2 text-xs font-semibold text-teal-800 rounded-lg hover:bg-teal-50 cursor-pointer"
              >
                <Smartphone className="w-4 h-4 text-teal-600" />
                <span>Install Mobile App</span>
              </DropdownMenuItem>

              <DropdownMenuItem
                onClick={() => router.push('/broker/more')}
                className="flex items-center gap-2 px-2.5 py-2 text-xs font-semibold text-slate-700 rounded-lg hover:bg-slate-100 cursor-pointer"
              >
                <SlidersHorizontal className="w-4 h-4 text-slate-500" />
                <span>Workspace Preferences</span>
              </DropdownMenuItem>
            </DropdownMenuGroup>

            <DropdownMenuSeparator className="my-1 border-slate-100" />

            <DropdownMenuItem
              onClick={handleSignOut}
              disabled={isSigningOut}
              className="flex items-center gap-2 px-2.5 py-2 text-xs font-semibold text-red-600 rounded-lg hover:bg-red-50 cursor-pointer focus:bg-red-50 focus:text-red-700"
            >
              <LogOut className="w-4 h-4 text-red-500" />
              <span>{isSigningOut ? 'Signing out...' : 'Sign Out'}</span>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <BrokerProfileDialog 
        open={isProfileOpen} 
        onOpenChange={setIsProfileOpen} 
        defaultTab={profileTab}
      />
    </aside>
  );
}
