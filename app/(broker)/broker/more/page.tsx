'use client';

import React from 'react';
import Link from 'next/link';
import { Card, CardContent } from '@/components/ui/card';
import {
  Users2,
  Wallet,
  FolderLock,
  AlertTriangle,
  UserCog,
  ChevronRight,
  Sparkles,
  LogOut,
  Zap,
} from 'lucide-react';
import { signOutAction } from '@/src/server/actions/auth-actions';

interface ToolItem {
  id: string;
  title: string;
  description: string;
  icon: React.ElementType;
  href?: string;
  badge?: string;
  color: string;
}

const MORE_TOOLS: ToolItem[] = [
  {
    id: 'commission',
    title: 'Commission & Revenue Ledger',
    description: 'Track locked buyer markups, seller deductions, and historical revenue spread.',
    icon: Zap,
    href: '/broker/more/commission',
    badge: 'Sprint 28',
    color: 'text-[#0D9488] bg-teal-50 border-teal-200/80',
  },
  {
    id: 'crm',
    title: 'CRM & Relationship Cards',
    description: '360-degree buyer/seller contact cards, open mandate telemetry, and 1-tap follow-up logging.',
    icon: Users2,
    href: '/broker/more/crm',
    badge: 'Sprint 28',
    color: 'text-blue-600 bg-blue-50 border-blue-200/80',
  },
  {
    id: 'payments',
    title: 'Payments & Settlement Ledger',
    description: 'Track trade settlements, brokerage invoices, payouts, and financial sheets.',
    icon: Wallet,
    href: '/broker/orders',
    badge: 'Live',
    color: 'text-emerald-600 bg-emerald-50 border-emerald-200/80',
  },
  {
    id: 'documents',
    title: 'Document Vault',
    description: 'Centralized repository of verified lab tests, e-way bills, and commercial contracts.',
    icon: FolderLock,
    badge: 'Vault',
    color: 'text-indigo-600 bg-indigo-50 border-indigo-200/80',
  },
  {
    id: 'disputes',
    title: 'Disputes & Exception Desk',
    description: 'Arbitrate trade differences, weight discrepancies, and quality variances.',
    icon: AlertTriangle,
    href: '/broker/more/disputes',
    badge: 'Sprint 28',
    color: 'text-amber-600 bg-amber-50 border-amber-200/80',
  },
  {
    id: 'settings',
    title: 'Personal Settings',
    description: 'Personal profile, notification channels, security, and interface preferences.',
    icon: UserCog,
    badge: 'Profile',
    color: 'text-slate-600 bg-slate-50 border-slate-200/80',
  },
];

export default function BrokerMorePage() {
  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">
          Additional Tools
        </h1>
        <p className="text-xs sm:text-sm text-slate-500 mt-1">
          Operational utilities, trade records, financial ledger, and personal configuration.
        </p>
      </div>

      {/* Vertical Navigation Menu (Min 48px touch targets) */}
      <div className="space-y-3">
        {MORE_TOOLS.map((tool) => {
          const Icon = tool.icon;
          const content = (
            <Card className="border border-border bg-white hover:border-[#0D9488]/40 hover:shadow-xs transition-all cursor-pointer group">
              <CardContent className="p-4 sm:p-5 flex items-center justify-between gap-4 min-h-[56px]">
                <div className="flex items-center gap-3.5 min-w-0 flex-1">
                  {/* Icon */}
                  <div
                    className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 border ${tool.color}`}
                  >
                    <Icon className="w-5 h-5" />
                  </div>

                  {/* Text */}
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <h3 className="font-bold text-slate-900 text-sm sm:text-base group-hover:text-[#0D9488] transition-colors truncate">
                        {tool.title}
                      </h3>
                      {tool.badge && (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase tracking-wider bg-slate-100 text-slate-600 border border-slate-200/80 shrink-0">
                          {tool.badge}
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-slate-500 mt-0.5 line-clamp-1 sm:line-clamp-2">
                      {tool.description}
                    </p>
                  </div>
                </div>

                {/* Arrow */}
                <div className="flex items-center text-slate-400 group-hover:text-[#0D9488] transition-colors shrink-0">
                  <ChevronRight className="w-5 h-5" />
                </div>
              </CardContent>
            </Card>
          );

          if (tool.href) {
            return (
              <Link key={tool.id} href={tool.href} className="block">
                {content}
              </Link>
            );
          }

          return <div key={tool.id}>{content}</div>;
        })}
      </div>

      {/* Sign Out Action Card */}
      <Card
        onClick={async () => {
          await signOutAction();
        }}
        className="border border-red-200/70 bg-red-50/30 hover:bg-red-50/70 transition-all cursor-pointer group"
      >
        <CardContent className="p-4 sm:p-5 flex items-center justify-between gap-4 min-h-[56px]">
          <div className="flex items-center gap-3.5 min-w-0 flex-1">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0 border border-red-200 bg-red-100/60 text-red-600">
              <LogOut className="w-5 h-5" />
            </div>
            <div className="min-w-0 flex-1">
              <h3 className="font-bold text-red-600 text-sm sm:text-base leading-tight">
                Sign Out
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Log out of your broker workstation session securely.
              </p>
            </div>
          </div>
          <ChevronRight className="w-5 h-5 text-red-400 group-hover:translate-x-0.5 transition-transform shrink-0" />
        </CardContent>
      </Card>

      {/* Bottom Information Callout */}
      <div className="p-4 rounded-xl bg-teal-50/60 border border-teal-200/60 flex items-start gap-3">
        <Sparkles className="w-5 h-5 text-[#0D9488] shrink-0 mt-0.5" />
        <div className="text-xs text-teal-900 leading-relaxed">
          <span className="font-bold">Broker Workstation Architecture:</span> Operating on a flat role model. Advanced CRM contact tracking and dispute arbitration modules are scheduled for automated rollout in Sprints 29 & 30.
        </div>
      </div>
    </div>
  );
}
