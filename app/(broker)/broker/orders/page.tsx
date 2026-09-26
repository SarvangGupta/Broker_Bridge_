import React from 'react';
import Link from 'next/link';
import { Card, CardContent } from '@/components/ui/card';
import { Truck, PackageCheck, ArrowRight, ShieldCheck, Filter } from 'lucide-react';
import { getBrokerActiveOrdersAction } from '@/src/server/actions/broker-order-actions';
import { FinalizedDealCard } from '@/src/components/broker/orders/finalized-deal-card';

export const dynamic = 'force-dynamic';

export default async function BrokerOrdersPage() {
  const res = await getBrokerActiveOrdersAction();
  const activeOrders = res.success && res.data ? res.data : [];

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight flex items-center gap-2.5">
            <Truck className="w-7 h-7 text-[#0D9488]" />
            Orders & Logistics Workspace
          </h1>
          <p className="text-xs sm:text-sm text-slate-500 mt-1">
            Track active trade bookings, physical vehicle dispatches, and delivery fulfillment.
          </p>
        </div>

        {activeOrders.length > 0 && (
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-teal-50 border border-teal-200/80 text-teal-800 text-xs font-mono font-bold self-start sm:self-auto">
            <PackageCheck className="w-4 h-4 text-[#0D9488]" />
            <span>{activeOrders.length} Active Orders</span>
          </div>
        )}
      </div>

      {/* Orders Feed */}
      {activeOrders.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
          {activeOrders.map((order) => (
            <FinalizedDealCard key={order.id} order={order} />
          ))}
        </div>
      ) : (
        /* Standard Empty State Card */
        <Card className="border-dashed border-2 border-slate-200 bg-white/60">
          <CardContent className="p-8 sm:p-12 text-center space-y-4">
            <div className="mx-auto w-12 h-12 rounded-full bg-teal-50 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
              <Truck className="w-6 h-6" />
            </div>
            <div className="space-y-1 max-w-sm mx-auto">
              <h3 className="font-bold text-slate-800 text-base">No Active Logistics Orders</h3>
              <p className="text-xs sm:text-sm text-slate-500">
                Booked trade lots, vehicle dispatches, LR documents, and delivery tracking milestones will appear here once finalized.
              </p>
            </div>
            <Link href="/broker/deals" className="inline-block">
              <div className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold text-white bg-[#0D9488] hover:bg-[#0D9488]/90 shadow-xs cursor-pointer">
                <span>View Deals & Contracts</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </div>
            </Link>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
