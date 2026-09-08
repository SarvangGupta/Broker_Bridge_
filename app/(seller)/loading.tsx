import React from 'react';

export default function SellerWorkspaceLoading() {
  return (
    <div className="min-h-screen bg-[#F8FAFC] flex flex-col font-sans antialiased text-slate-900 pb-16">
      {/* 1. TOP HEADER SKELETON */}
      <div className="h-16 w-full bg-white border-b border-slate-200/90 px-4 sm:px-6 lg:px-8 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-slate-200 animate-pulse" />
          <div className="h-4 w-32 bg-slate-200 rounded-md animate-pulse hidden sm:block" />
        </div>
        <div className="flex items-center gap-3">
          <div className="h-8 w-24 bg-slate-200 rounded-lg animate-pulse hidden sm:block" />
          <div className="w-8 h-8 rounded-full bg-slate-200 animate-pulse" />
        </div>
      </div>

      {/* 2. SUB-NAV SKELETON */}
      <div className="h-12 w-full bg-white border-b border-slate-200/80 px-4 sm:px-6 lg:px-8 flex items-center gap-4 overflow-x-hidden">
        {[1, 2, 3, 4, 5, 6, 7].map((i) => (
          <div
            key={i}
            className={`h-7 rounded-lg animate-pulse ${
              i === 1 ? 'w-28 bg-emerald-100' : 'w-20 bg-slate-100'
            }`}
          />
        ))}
      </div>

      {/* 3. MAIN WORKSPACE CONTAINER SKELETON */}
      <main className="max-w-6xl mx-auto w-full px-4 sm:px-6 lg:px-8 py-6 space-y-6">
        {/* Banner Skeleton */}
        <div className="p-6 bg-white rounded-2xl border border-slate-200/90 shadow-xs flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div className="space-y-2 w-full max-w-md">
            <div className="h-6 w-48 bg-slate-200 rounded-md animate-pulse" />
            <div className="h-4 w-64 bg-slate-100 rounded-md animate-pulse" />
          </div>
          <div className="h-10 w-36 bg-slate-200 rounded-xl animate-pulse shrink-0" />
        </div>

        {/* 4 Top KPI Cards Skeleton */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <div
              key={i}
              className="p-5 bg-white rounded-2xl border border-slate-200/90 shadow-xs space-y-3"
            >
              <div className="flex items-center justify-between">
                <div className="h-3 w-20 bg-slate-200 rounded animate-pulse" />
                <div className="w-8 h-8 rounded-xl bg-slate-100 animate-pulse" />
              </div>
              <div className="h-8 w-32 bg-slate-200 rounded-lg animate-pulse" />
              <div className="h-3 w-24 bg-slate-100 rounded animate-pulse" />
            </div>
          ))}
        </div>

        {/* Main Content / Table Card Skeleton */}
        <div className="p-6 bg-white rounded-2xl border border-slate-200/90 shadow-xs space-y-4">
          <div className="flex items-center justify-between pb-4 border-b border-slate-100">
            <div className="h-5 w-40 bg-slate-200 rounded animate-pulse" />
            <div className="h-8 w-24 bg-slate-100 rounded-lg animate-pulse" />
          </div>

          <div className="space-y-3 pt-2">
            {[1, 2, 3, 4, 5].map((row) => (
              <div
                key={row}
                className="h-12 w-full bg-slate-50 rounded-xl border border-slate-100 animate-pulse flex items-center px-4 justify-between"
              >
                <div className="h-4 w-36 bg-slate-200 rounded" />
                <div className="h-4 w-20 bg-slate-200 rounded" />
                <div className="h-4 w-28 bg-slate-200 rounded hidden sm:block" />
                <div className="h-6 w-16 bg-slate-200 rounded-md" />
              </div>
            ))}
          </div>
        </div>
      </main>
    </div>
  );
}
