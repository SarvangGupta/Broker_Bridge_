'use client';

import React from 'react';
import { Layers, FileText, Truck, IndianRupee } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { BuyerDashboardKpis } from '@/src/server/actions/buyer-dashboard-actions';

interface BuyerKpiGridProps {
  kpis: BuyerDashboardKpis;
}

export function BuyerKpiGrid({ kpis }: BuyerKpiGridProps) {
  const cards = [
    {
      id: 'active-reqs',
      title: 'Active Requirements',
      value: kpis.activeRequirementsCount,
      icon: Layers,
      highlight: false,
      badgeText: 'Live Demands',
      badgeBg: 'bg-slate-100 text-slate-700',
    },
    {
      id: 'proposals-pending',
      title: 'Proposals to Review',
      value: kpis.proposalsPendingCount,
      icon: FileText,
      highlight: true,
      badgeText: 'Action Required',
      badgeBg: 'bg-[#E0F2FE] text-[#0284C7]',
    },
    {
      id: 'active-orders',
      title: 'Active Orders',
      value: kpis.activeOrdersCount,
      icon: Truck,
      highlight: false,
      badgeText: 'In Logistics',
      badgeBg: 'bg-[#E0F2FE] text-[#0284C7]',
    },
    {
      id: 'payables-pending',
      title: 'Payables Pending',
      value: kpis.pendingPayablesFormatted,
      icon: IndianRupee,
      highlight: false,
      badgeText: 'Outstanding',
      badgeBg: 'bg-amber-100 text-amber-800',
    },
  ];

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 select-none">
      {cards.map((card) => {
        const Icon = card.icon;

        return (
          <Card
            key={card.id}
            className={`
              border rounded-2xl transition-all duration-150 shadow-2xs hover:shadow-xs
              ${
                card.highlight
                  ? 'border-[#0284C7]/40 bg-sky-50/30'
                  : 'border-slate-200/80 bg-white'
              }
            `}
          >
            <CardContent className="p-4 sm:p-5 flex flex-col justify-between h-full space-y-3">
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs sm:text-sm font-semibold text-slate-600 truncate">
                  {card.title}
                </span>
                <div
                  className={`
                    p-2 rounded-xl shrink-0
                    ${
                      card.highlight
                        ? 'bg-[#E0F2FE] text-[#0284C7]'
                        : 'bg-slate-100 text-slate-600'
                    }
                  `}
                >
                  <Icon className="w-4 h-4 sm:w-5 sm:h-5" />
                </div>
              </div>

              <div>
                <div
                  className={`
                    text-2xl sm:text-3xl font-bold tracking-tight truncate
                    ${card.highlight ? 'text-[#0284C7]' : 'text-slate-900'}
                  `}
                >
                  {card.value}
                </div>
                <div className="mt-2">
                  <span
                    className={`inline-block text-[10px] font-bold px-2 py-0.5 rounded-full ${card.badgeBg}`}
                  >
                    {card.badgeText}
                  </span>
                </div>
              </div>
            </CardContent>
          </Card>
        );
      })}
    </div>
  );
}
