import React, { Suspense } from 'react';
import { GlobalSearchWorkspace } from '@/src/components/search/global-search-workspace';
import { SearchEntityType } from '@/src/server/actions/broker-search-actions';
import { Loader2 } from 'lucide-react';

export const dynamic = 'force-dynamic';

export const metadata = {
  title: 'Global Search | RMBroker Command Center',
  description: 'Unified broker search across buyers, sellers, materials, requirements, offers, and deals',
};

interface SearchPageProps {
  searchParams?: Promise<{
    q?: string;
    entity?: string;
  }>;
}

export default async function BrokerSearchPage({ searchParams }: SearchPageProps) {
  const params = await searchParams;
  const initialQuery = params?.q || '';
  const initialFilter = (params?.entity as SearchEntityType) || 'all';

  return (
    <div className="w-full min-h-screen bg-[#F8FAFC]">
      <Suspense
        fallback={
          <div className="p-12 text-center text-slate-400 flex flex-col items-center gap-2">
            <Loader2 className="w-6 h-6 animate-spin text-[#0D9488]" />
            <span className="text-xs">Loading search desk...</span>
          </div>
        }
      >
        <GlobalSearchWorkspace
          initialQuery={initialQuery}
          initialFilter={initialFilter}
        />
      </Suspense>
    </div>
  );
}
