'use client';

import React from 'react';
import Link from 'next/link';
import {
  PlusCircle,
  Package,
  Layers,
  Handshake,
  Truck,
  AlertTriangle,
  IndianRupee,
  Users,
  ArrowUpRight,
  Zap,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card';
import { useLanguage } from '@/src/lib/i18n/language-context';

export function BrokerQuickActions() {
  const { t } = useLanguage();

  const QUICK_ACTIONS = [
    {
      id: 'qa-req',
      title: t('qaNewRequirement'),
      description: t('qaNewRequirementDesc'),
      icon: PlusCircle,
      href: '/broker/work',
      color: 'text-[#0D9488] bg-teal-50 border-teal-200/80 group-hover:bg-[#0D9488] group-hover:text-white',
    },
    {
      id: 'qa-offer',
      title: t('qaNewOffer'),
      description: t('qaNewOfferDesc'),
      icon: Package,
      href: '/broker/work',
      color: 'text-indigo-600 bg-indigo-50 border-indigo-200/80 group-hover:bg-indigo-600 group-hover:text-white',
    },
    {
      id: 'qa-matching',
      title: t('qaOpenMatching'),
      description: t('qaOpenMatchingDesc'),
      icon: Layers,
      href: '/broker/work',
      color: 'text-blue-600 bg-blue-50 border-blue-200/80 group-hover:bg-blue-600 group-hover:text-white',
    },
    {
      id: 'qa-deals',
      title: t('qaReviewDeals'),
      description: t('qaReviewDealsDesc'),
      icon: Handshake,
      href: '/broker/deals',
      color: 'text-emerald-600 bg-emerald-50 border-emerald-200/80 group-hover:bg-emerald-600 group-hover:text-white',
    },
    {
      id: 'qa-logistics',
      title: t('qaTrackDeliveries'),
      description: t('qaTrackDeliveriesDesc'),
      icon: Truck,
      href: '/broker/orders',
      color: 'text-amber-600 bg-amber-50 border-amber-200/80 group-hover:bg-amber-600 group-hover:text-white',
    },
    {
      id: 'qa-disputes',
      title: t('qaMediateDisputes'),
      description: t('qaMediateDisputesDesc'),
      icon: AlertTriangle,
      href: '/broker/more/disputes',
      color: 'text-rose-600 bg-rose-50 border-rose-200/80 group-hover:bg-rose-600 group-hover:text-white',
    },
    {
      id: 'qa-commission',
      title: t('qaCommissionLedger'),
      description: t('qaCommissionLedgerDesc'),
      icon: IndianRupee,
      href: '/broker/more/commission',
      color: 'text-teal-700 bg-teal-50 border-teal-200/80 group-hover:bg-teal-700 group-hover:text-white',
    },
    {
      id: 'qa-directory',
      title: t('qaManageDirectory'),
      description: t('qaManageDirectoryDesc'),
      icon: Users,
      href: '/broker/directory',
      color: 'text-slate-700 bg-slate-100 border-slate-200 group-hover:bg-slate-800 group-hover:text-white',
    },
  ];

  return (
    <Card className="bg-white border border-slate-200/80 shadow-2xs rounded-2xl overflow-hidden">
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50 flex flex-row items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <Zap className="w-4 h-4 text-amber-500" />
            <CardTitle className="text-sm sm:text-base font-bold text-slate-900">
              {t('quickActionsTitle')}
            </CardTitle>
          </div>
          <CardDescription className="text-xs text-slate-500 mt-0.5">
            {t('quickActionsSub')}
          </CardDescription>
        </div>
      </CardHeader>

      <CardContent className="p-3 sm:p-4">
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 sm:gap-3">
          {QUICK_ACTIONS.map((item) => {
            const Icon = item.icon;

            return (
              <Link
                key={item.id}
                href={item.href}
                className="group p-3 rounded-xl border border-slate-200/80 bg-white hover:border-[#0D9488]/50 hover:shadow-xs transition-all flex flex-col justify-between min-h-[96px] select-none"
              >
                <div className="flex items-start justify-between gap-2">
                  <div
                    className={`w-8 h-8 rounded-lg border flex items-center justify-center shrink-0 transition-all ${item.color}`}
                  >
                    <Icon className="w-4 h-4" />
                  </div>
                  <ArrowUpRight className="w-3.5 h-3.5 text-slate-400 group-hover:text-[#0D9488] transition-colors" />
                </div>

                <div className="mt-2">
                  <div className="text-xs font-bold text-slate-900 group-hover:text-[#0D9488] transition-colors line-clamp-1">
                    {item.title}
                  </div>
                  <div className="text-[10px] text-slate-500 line-clamp-1 mt-0.5">
                    {item.description}
                  </div>
                </div>
              </Link>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
