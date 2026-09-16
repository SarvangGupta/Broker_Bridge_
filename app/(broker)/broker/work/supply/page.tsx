import React from 'react';
import {
  getBrokerSupplySearchAction,
  getRequirementContextAction,
  type SupplyFilters,
} from '@/src/server/actions/broker-supply-actions';
import {
  getCommoditiesAction,
  getGradesAction,
  getStatesAction,
} from '@/src/server/actions/master-data-actions';
import { BrokerSupplySearchWorkspace } from '@/src/components/broker/work/broker-supply-search-workspace';

export const dynamic = 'force-dynamic';

interface PageProps {
  searchParams: Promise<{
    requirementId?: string;
    commodity?: string;
    grade?: string;
    state?: string;
    maxPrice?: string;
    q?: string;
  }>;
}

export default async function BrokerSupplySearchPage({ searchParams }: PageProps) {
  const resolvedParams = await searchParams;
  const requirementId = resolvedParams.requirementId;

  // Initialize filters from URL parameters
  const initialFilters: SupplyFilters = {
    commodityId: resolvedParams.commodity || undefined,
    gradeId: resolvedParams.grade || undefined,
    stateId: resolvedParams.state || undefined,
    maxPrice: resolvedParams.maxPrice ? Number(resolvedParams.maxPrice) : undefined,
    searchQuery: resolvedParams.q || undefined,
  };

  // Parallel pre-fetching of supply data, master data, and optional requirement context
  const [supplyRes, commoditiesRes, gradesRes, statesRes, reqContextRes] = await Promise.all([
    getBrokerSupplySearchAction(initialFilters),
    getCommoditiesAction(),
    getGradesAction(),
    getStatesAction(),
    requirementId ? getRequirementContextAction(requirementId) : Promise.resolve({ success: false, data: undefined }),
  ]);

  const masterData = {
    commodities: (commoditiesRes.success && commoditiesRes.data ? commoditiesRes.data : []).map((c) => ({
      id: c.id,
      name: c.name,
    })),
    grades: (gradesRes.success && gradesRes.data ? gradesRes.data : []).map((g) => ({
      id: g.id,
      commodityId: g.commodityId,
      gradeName: g.gradeName,
    })),
    states: (statesRes.success && statesRes.data ? statesRes.data : []).map((s) => ({
      id: s.id,
      name: s.name,
    })),
  };

  const requirementContext = reqContextRes.success && reqContextRes.data ? reqContextRes.data : null;

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      <BrokerSupplySearchWorkspace
        initialLots={supplyRes.data || []}
        masterData={masterData}
        initialFilters={initialFilters}
        requirementContext={requirementContext}
        error={supplyRes.error}
      />
    </div>
  );
}
