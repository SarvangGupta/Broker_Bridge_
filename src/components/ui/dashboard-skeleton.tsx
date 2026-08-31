import React from 'react'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'

export function DashboardCardSkeleton({ className }: { className?: string }) {
  return (
    <Card className={`rounded-2xl border border-slate-200/90 shadow-xs bg-white ${className || ''}`}>
      <CardHeader className="pb-3 flex flex-row items-center justify-between space-y-0">
        <div className="space-y-2 flex-1">
          <Skeleton className="h-3.5 w-24 rounded-md" />
          <Skeleton className="h-7 w-32 rounded-lg" />
        </div>
        <Skeleton className="h-10 w-10 rounded-xl" />
      </CardHeader>
      <CardContent className="pt-0">
        <Skeleton className="h-3 w-48 rounded-md mt-1" />
      </CardContent>
    </Card>
  )
}

export function KpiGridSkeleton() {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
      <DashboardCardSkeleton />
      <DashboardCardSkeleton />
      <DashboardCardSkeleton />
    </div>
  )
}

export function ActionBannerSkeleton() {
  return (
    <div className="p-4 sm:p-5 rounded-2xl border border-slate-200 bg-white/80 space-y-3 shadow-xs">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Skeleton className="h-3 w-3 rounded-full" />
          <Skeleton className="h-4 w-44 rounded-md" />
        </div>
        <Skeleton className="h-3 w-32 rounded-md" />
      </div>
      <div className="p-4 rounded-xl border border-slate-100 bg-slate-50 flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Skeleton className="h-9 w-9 rounded-xl" />
          <div className="space-y-1.5">
            <Skeleton className="h-4 w-48 rounded-md" />
            <Skeleton className="h-3 w-64 rounded-md" />
          </div>
        </div>
        <Skeleton className="h-9 w-28 rounded-xl" />
      </div>
    </div>
  )
}

export function DashboardSkeleton() {
  return (
    <div className="space-y-6 sm:space-y-8 animate-in fade-in-50 duration-200">
      {/* Header Skeleton */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
        <div className="space-y-2">
          <div className="flex items-center gap-2">
            <Skeleton className="h-8 w-56 rounded-lg" />
            <Skeleton className="h-5 w-24 rounded-full" />
          </div>
          <Skeleton className="h-4 w-80 rounded-md" />
        </div>
        <Skeleton className="h-11 w-44 rounded-xl" />
      </div>

      {/* KPI Ribbon Skeleton */}
      <KpiGridSkeleton />

      {/* Action Banner Skeleton */}
      <ActionBannerSkeleton />

      {/* Quick Access Cards Skeleton */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card className="rounded-2xl border border-slate-200/90 p-5 sm:p-6 bg-white space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Skeleton className="h-10 w-10 rounded-xl" />
              <div className="space-y-1.5">
                <Skeleton className="h-5 w-40 rounded-md" />
                <Skeleton className="h-3 w-28 rounded-md" />
              </div>
            </div>
            <Skeleton className="h-6 w-16 rounded-full" />
          </div>
          <Skeleton className="h-4 w-full rounded-md" />
          <Skeleton className="h-11 w-full rounded-xl" />
        </Card>

        <Card className="rounded-2xl border border-slate-200/90 p-5 sm:p-6 bg-white space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Skeleton className="h-10 w-10 rounded-xl" />
              <div className="space-y-1.5">
                <Skeleton className="h-5 w-48 rounded-md" />
                <Skeleton className="h-3 w-32 rounded-md" />
              </div>
            </div>
            <Skeleton className="h-6 w-16 rounded-full" />
          </div>
          <Skeleton className="h-4 w-full rounded-md" />
          <Skeleton className="h-11 w-full rounded-xl" />
        </Card>
      </div>
    </div>
  )
}
