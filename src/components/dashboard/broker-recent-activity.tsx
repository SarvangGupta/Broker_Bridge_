'use client';

import React from 'react';
import Link from 'next/link';
import {
  Activity,
  Handshake,
  Truck,
  Layers,
  AlertTriangle,
  IndianRupee,
  Clock,
  ArrowRight,
  Inbox,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { BrokerRecentActivityItem } from '@/src/server/actions/broker-dashboard-actions';
import { useLanguage } from '@/src/lib/i18n/language-context';

export interface BrokerRecentActivityProps {
  activities: BrokerRecentActivityItem[];
}

export function BrokerRecentActivity({ activities }: BrokerRecentActivityProps) {
  const { t } = useLanguage();

  const getCategoryConfig = (category: BrokerRecentActivityItem['category']) => {
    switch (category) {
      case 'deals':
        return {
          icon: Handshake,
          color: 'text-emerald-600 bg-emerald-50 border-emerald-200',
          label: t('eventDeal'),
        };
      case 'logistics':
        return {
          icon: Truck,
          color: 'text-amber-600 bg-amber-50 border-amber-200',
          label: t('eventLogistics'),
        };
      case 'disputes':
        return {
          icon: AlertTriangle,
          color: 'text-rose-600 bg-rose-50 border-rose-200',
          label: t('eventDisputes'),
        };
      case 'finance':
        return {
          icon: IndianRupee,
          color: 'text-teal-600 bg-teal-50 border-teal-200',
          label: t('eventFinance'),
        };
      case 'requirements':
      default:
        return {
          icon: Layers,
          color: 'text-blue-600 bg-blue-50 border-blue-200',
          label: t('eventRequirements'),
        };
    }
  };

  return (
    <Card className="bg-white border border-slate-200/80 shadow-2xs rounded-2xl overflow-hidden">
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50 flex flex-row items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <Activity className="w-4 h-4 text-[#0D9488]" />
            <CardTitle className="text-sm sm:text-base font-bold text-slate-900">
              {t('recentActivityTitle')}
            </CardTitle>
          </div>
          <CardDescription className="text-xs text-slate-500 mt-0.5">
            {t('recentActivitySub')}
          </CardDescription>
        </div>
        <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-teal-50 text-[#0D9488] border border-teal-200">
          {activities.length} Events
        </span>
      </CardHeader>

      <CardContent className="p-3 sm:p-4">
        {activities.length === 0 ? (
          <div className="p-6 rounded-xl border border-dashed border-slate-200 bg-slate-50/50 text-center space-y-2">
            <Inbox className="w-8 h-8 text-slate-400 mx-auto" />
            <h4 className="text-xs font-bold text-slate-700">{t('noRecentActivityTitle')}</h4>
            <p className="text-[11px] text-slate-500 max-w-sm mx-auto">
              {t('noRecentActivityDesc')}
            </p>
          </div>
        ) : (
          <div className="relative pl-6 space-y-4 before:absolute before:left-2.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-slate-200/70">
            {activities.map((item) => {
              const config = getCategoryConfig(item.category);
              const Icon = config.icon;

              return (
                <div key={item.id} className="relative group">
                  {/* Timeline Node Indicator */}
                  <div
                    className={`absolute -left-6 top-0.5 w-5 h-5 rounded-full border flex items-center justify-center shrink-0 ${config.color}`}
                  >
                    <Icon className="w-2.5 h-2.5" />
                  </div>

                  {/* Event Card Content */}
                  <div className="p-3 rounded-xl border border-slate-200/70 bg-white hover:border-[#0D9488]/40 hover:shadow-2xs transition-all space-y-1.5">
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <Badge
                          variant="outline"
                          className={`text-[9px] font-bold uppercase tracking-wider py-0 px-1.5 border ${config.color}`}
                        >
                          {config.label}
                        </Badge>
                        <span className="text-[11px] font-mono font-bold text-slate-500">
                          {item.referenceId}
                        </span>
                      </div>

                      <div className="flex items-center gap-1 text-[10px] font-medium text-slate-400 shrink-0">
                        <Clock className="w-3 h-3" />
                        <span>{item.relativeTime}</span>
                      </div>
                    </div>

                    <h5 className="text-xs sm:text-sm font-bold text-slate-900 leading-snug">
                      {item.title}
                    </h5>

                    <p className="text-xs text-slate-600 leading-relaxed">
                      {item.description}
                    </p>

                    {item.actionHref && (
                      <div className="pt-1 flex justify-end">
                        <Link
                          href={item.actionHref}
                          className="inline-flex items-center gap-1 text-[11px] font-semibold text-[#0D9488] hover:text-[#0F766E] transition-colors"
                        >
                          <span>{t('viewDetails')}</span>
                          <ArrowRight className="w-3 h-3" />
                        </Link>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
