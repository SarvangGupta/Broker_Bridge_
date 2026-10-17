import React from 'react';
import Link from 'next/link';
import { Card, CardContent } from '@/components/ui/card';
import { Handshake, FileCheck2, ArrowRight, ShieldCheck, Plus } from 'lucide-react';
import { getBrokerDealsListAction } from '@/src/server/actions/broker-deal-actions';
import { BrokerDealsClient } from '@/src/components/broker/deals/broker-deals-client';
import { Button } from '@/components/ui/button';

export const dynamic = 'force-dynamic';

export default async function BrokerDealsPage() {
  const res = await getBrokerDealsListAction();
  const deals = res.success && res.deals ? res.deals : [];

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 dark:text-white tracking-tight flex items-center gap-2.5">
            <Handshake className="w-7 h-7 text-[#0D9488]" />
            Deals & Negotiations
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 mt-1">
            Broker-mediated contract negotiations, immutable version snapshots, and dual counterparty confirmations.
          </p>
        </div>

        <div className="flex items-center gap-2 self-start sm:self-auto">
          <Link href="/broker/work">
            <Button size="sm" className="bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-semibold text-xs shadow-xs">
              <Plus className="w-3.5 h-3.5 mr-1" />
              New Deal from Allocation
            </Button>
          </Link>
        </div>
      </div>

      {/* Main Deals Workspace Client */}
      <BrokerDealsClient initialDeals={deals} />
    </div>
  );
}
