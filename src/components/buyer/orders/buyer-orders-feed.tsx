'use client';

import React, { useState, useMemo } from 'react';
import Link from 'next/link';
import {
  PackageCheck,
  Search,
  Filter,
  Truck,
  PackageX,
  ArrowRight,
  Handshake,
} from 'lucide-react';
import { OrderSummaryCard } from '@/src/components/buyer/orders/order-summary-card';
import { BuyerOrderItem } from '@/src/types/buyer-order-types';
import { EmptyState } from '@/src/components/ui/empty-state';
import { Input } from '@/components/ui/input';
import { cn } from '@/lib/utils';

export interface BuyerOrdersFeedProps {
  orders: BuyerOrderItem[];
  className?: string;
}

type OrderStatusTab = 'ALL' | 'IN_TRANSIT' | 'DISPATCH_PLANNED' | 'DELIVERED';

export function BuyerOrdersFeed({ orders, className }: BuyerOrdersFeedProps) {
  const [selectedTab, setSelectedTab] = useState<OrderStatusTab>('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  // Tab counts
  const counts = useMemo(() => {
    let inTransit = 0;
    let planned = 0;
    let delivered = 0;

    for (const o of orders) {
      const s = o.status.toLowerCase();
      if (s.includes('transit') || s.includes('dispatched')) inTransit++;
      else if (s.includes('planned') || s.includes('booked')) planned++;
      else if (s.includes('delivered') || s.includes('completed')) delivered++;
    }

    return {
      all: orders.length,
      inTransit,
      planned,
      delivered,
    };
  }, [orders]);

  // Filtered orders list
  const filteredOrders = useMemo(() => {
    return orders.filter((o) => {
      // 1. Tab filtering
      const s = o.status.toLowerCase();
      if (selectedTab === 'IN_TRANSIT' && !s.includes('transit') && !s.includes('dispatched')) {
        return false;
      }
      if (selectedTab === 'DISPATCH_PLANNED' && !s.includes('planned') && !s.includes('booked')) {
        return false;
      }
      if (selectedTab === 'DELIVERED' && !s.includes('delivered') && !s.includes('completed')) {
        return false;
      }

      // 2. Search query filtering
      if (searchQuery.trim() !== '') {
        const q = searchQuery.toLowerCase().trim();
        const matchesBooking = o.bookingId.toLowerCase().includes(q);
        const matchesCommodity = o.commodityName.toLowerCase().includes(q);
        const matchesGrade = (o.gradeName || '').toLowerCase().includes(q);
        const matchesDeal = o.dealReference.toLowerCase().includes(q);
        const matchesLocation = o.deliveryLocation.toLowerCase().includes(q);
        return matchesBooking || matchesCommodity || matchesGrade || matchesDeal || matchesLocation;
      }

      return true;
    });
  }, [orders, selectedTab, searchQuery]);

  return (
    <div className={cn('w-full max-w-full space-y-5', className)}>
      {/* 1. Filter Bar & Search Input */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        {/* Horizontal Scrollable Tabs on Mobile */}
        <div className="flex items-center gap-1.5 overflow-x-auto no-scrollbar pb-1 sm:pb-0">
          <button
            type="button"
            onClick={() => setSelectedTab('ALL')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all shrink-0 cursor-pointer',
              selectedTab === 'ALL'
                ? 'bg-[#0284C7] text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200'
            )}
          >
            All Orders ({counts.all})
          </button>

          <button
            type="button"
            onClick={() => setSelectedTab('IN_TRANSIT')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all shrink-0 cursor-pointer',
              selectedTab === 'IN_TRANSIT'
                ? 'bg-indigo-600 text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200'
            )}
          >
            In Transit ({counts.inTransit})
          </button>

          <button
            type="button"
            onClick={() => setSelectedTab('DISPATCH_PLANNED')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all shrink-0 cursor-pointer',
              selectedTab === 'DISPATCH_PLANNED'
                ? 'bg-sky-600 text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200'
            )}
          >
            Dispatch Planned ({counts.planned})
          </button>

          <button
            type="button"
            onClick={() => setSelectedTab('DELIVERED')}
            className={cn(
              'min-h-[40px] px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all shrink-0 cursor-pointer',
              selectedTab === 'DELIVERED'
                ? 'bg-emerald-600 text-white shadow-xs'
                : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200'
            )}
          >
            Delivered ({counts.delivered})
          </button>
        </div>

        {/* Search Bar */}
        <div className="relative w-full sm:w-64 lg:w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400 pointer-events-none" />
          <Input
            type="text"
            placeholder="Search booking, commodity..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9 min-h-[42px] h-10 rounded-xl bg-white border-slate-200 text-xs sm:text-sm focus-visible:ring-[#0284C7]"
          />
        </div>
      </div>

      {/* 2. Orders Content Grid */}
      {filteredOrders.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5">
          {filteredOrders.map((order) => (
            <OrderSummaryCard key={order.id || order.bookingId} order={order} />
          ))}
        </div>
      ) : (
        /* 3. Empty State (PRD 38.2 Standard) */
        <div className="w-full min-h-[50vh] flex flex-col items-center justify-center py-10">
          <EmptyState
            title={orders.length === 0 ? 'No Active Orders' : 'No Matching Orders'}
            description={
              orders.length === 0
                ? 'Your confirmed deals will appear here once the Broker finalizes the Booking ID.'
                : `No orders matched your search query "${searchQuery}". Clear your search or switch tabs to view other orders.`
            }
            icon={orders.length === 0 ? Truck : PackageX}
            className="max-w-md w-full bg-white shadow-xs"
          >
            {orders.length === 0 ? (
              <div className="flex flex-col sm:flex-row gap-2.5 w-full pt-1">
                <Link
                  href="/buyer/proposals"
                  className="inline-flex items-center justify-center min-h-[48px] px-5 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs sm:text-sm font-bold shadow-xs transition-colors w-full"
                >
                  <Handshake className="w-4 h-4 mr-2" />
                  <span>Review Proposals</span>
                </Link>
                <Link
                  href="/buyer/requirements"
                  className="inline-flex items-center justify-center min-h-[48px] px-5 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-700 text-xs sm:text-sm font-semibold transition-colors w-full"
                >
                  <span>View Requirements</span>
                </Link>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => {
                  setSelectedTab('ALL');
                  setSearchQuery('');
                }}
                className="inline-flex items-center justify-center min-h-[48px] px-6 rounded-xl bg-slate-800 hover:bg-slate-900 text-white text-xs sm:text-sm font-bold shadow-xs transition-colors w-full cursor-pointer"
              >
                <span>Clear Filters</span>
              </button>
            )}
          </EmptyState>
        </div>
      )}
    </div>
  );
}
