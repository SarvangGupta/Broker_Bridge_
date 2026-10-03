import React from 'react';
import { Skeleton } from '@/components/ui/skeleton';

export default function BuyerDashboardLoading() {
  return (
    <div
      className="max-w-7xl mx-auto p-4 sm:p-6 space-y-6 w-full max-w-full overflow-hidden select-none"
      aria-label="Loading Buyer Dashboard"
    >
      {/* 1. Header Skeleton */}
      <div className="bg-white border border-slate-200/80 p-4 sm:p-6 rounded-2xl shadow-2xs flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div className="space-y-2 w-full sm:w-2/3">
          <Skeleton className="h-7 w-56 sm:w-72 rounded-lg bg-slate-200/70 animate-pulse" />
          <Skeleton className="h-4 w-40 sm:w-56 rounded-md bg-slate-200/50 animate-pulse" />
        </div>
        <Skeleton className="h-12 w-full sm:w-44 rounded-xl bg-slate-200/80 animate-pulse shrink-0" />
      </div>

      {/* 2. 4-Card KPI Metric Grid Skeletons */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        {[1, 2, 3, 4].map((item) => (
          <div
            key={item}
            className="bg-white border border-slate-200/80 rounded-2xl p-4 sm:p-5 space-y-3 shadow-2xs"
          >
            <div className="flex items-center justify-between">
              <Skeleton className="h-4 w-24 rounded-md bg-slate-200/60" />
              <Skeleton className="h-8 w-8 rounded-xl bg-slate-200/70" />
            </div>
            <Skeleton className="h-8 w-16 sm:w-24 rounded-lg bg-slate-200/80" />
            <Skeleton className="h-4 w-20 rounded-full bg-slate-200/50" />
          </div>
        ))}
      </div>

      {/* 3. Action Required Feed Skeleton */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <Skeleton className="h-5 w-40 rounded-md bg-slate-200/60" />
          <Skeleton className="h-4 w-24 rounded-md bg-slate-200/50" />
        </div>
        <div className="bg-white border border-slate-200/80 border-l-4 border-l-sky-500 rounded-2xl p-4 sm:p-5 space-y-3 shadow-2xs">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div className="space-y-2 w-full sm:w-3/4">
              <Skeleton className="h-5 w-48 rounded-md bg-slate-200/70" />
              <Skeleton className="h-4 w-full rounded-md bg-slate-200/50" />
            </div>
            <Skeleton className="h-12 w-full sm:w-36 rounded-xl bg-slate-200/80 shrink-0" />
          </div>
        </div>
      </div>

      {/* 4. Two-Column Pipeline Skeletons */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {[1, 2].map((col) => (
          <div
            key={col}
            className="bg-white border border-slate-200/80 rounded-2xl p-4 sm:p-6 space-y-4 shadow-2xs"
          >
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2">
                <Skeleton className="h-8 w-8 rounded-xl bg-slate-200/70" />
                <div className="space-y-1">
                  <Skeleton className="h-4 w-36 rounded-md bg-slate-200/70" />
                  <Skeleton className="h-3 w-24 rounded-md bg-slate-200/50" />
                </div>
              </div>
              <Skeleton className="h-4 w-16 rounded-md bg-slate-200/60" />
            </div>

            <div className="space-y-3">
              {[1, 2, 3].map((row) => (
                <div
                  key={row}
                  className="p-3.5 rounded-xl border border-slate-100 bg-slate-50/60 space-y-2"
                >
                  <div className="flex items-center justify-between">
                    <Skeleton className="h-4 w-32 rounded-md bg-slate-200/70" />
                    <Skeleton className="h-4 w-16 rounded-full bg-slate-200/50" />
                  </div>
                  <Skeleton className="h-3 w-44 rounded-md bg-slate-200/50" />
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
