import React from 'react';
import { Skeleton } from '@/components/ui/skeleton';

export default function BrokerSupplyLoading() {
  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* 1. Header Skeleton */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div className="space-y-2">
          <Skeleton className="h-4 w-32 rounded-md" />
          <Skeleton className="h-8 w-56 rounded-lg" />
          <Skeleton className="h-4 w-72 rounded-md" />
        </div>
        <Skeleton className="h-9 w-36 rounded-lg" />
      </div>

      {/* 2. Search & Filter Bar Skeleton */}
      <div className="space-y-3">
        <Skeleton className="h-11 w-full rounded-xl" />
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <Skeleton className="h-10 w-full rounded-lg" />
          <Skeleton className="h-10 w-full rounded-lg" />
          <Skeleton className="h-10 w-full rounded-lg" />
          <Skeleton className="h-10 w-full rounded-lg" />
        </div>
      </div>

      {/* 3. Supply Cards Grid Skeleton (1 col mobile, 2 col desktop) */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-5">
        {[1, 2, 3, 4].map((i) => (
          <div
            key={i}
            className="p-5 rounded-xl border border-slate-200 bg-white space-y-4 shadow-2xs"
          >
            <div className="flex items-start justify-between gap-2">
              <div className="space-y-1.5 flex-1">
                <Skeleton className="h-5 w-48 rounded-md" />
                <Skeleton className="h-3.5 w-32 rounded-md" />
              </div>
              <Skeleton className="h-6 w-24 rounded-full" />
            </div>

            <Skeleton className="h-12 w-full rounded-lg" />

            <div className="grid grid-cols-2 gap-2.5">
              <Skeleton className="h-16 w-full rounded-lg" />
              <Skeleton className="h-16 w-full rounded-lg" />
            </div>

            <Skeleton className="h-16 w-full rounded-xl" />

            <div className="pt-3 border-t border-slate-100">
              <Skeleton className="h-12 w-full rounded-lg" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
