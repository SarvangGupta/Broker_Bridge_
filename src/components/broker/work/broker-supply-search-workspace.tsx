'use client';

import React, { useState, useTransition, useMemo } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
  Search,
  SlidersHorizontal,
  ArrowLeft,
  PackageSearch,
  Sparkles,
  Inbox,
  AlertCircle,
  Building2,
  Tag,
  CheckCircle2,
  FileText,
  X,
} from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { SupplyCard } from './supply-card';
import { SupplyFiltersComponent } from './supply-filters';
import { SendRequestDialog } from './send-request-dialog';
import {
  getBrokerSupplySearchAction,
  type BrokerSupplyLot,
  type SupplyFilters,
} from '@/src/server/actions/broker-supply-actions';
import { toast } from 'sonner';

interface MasterDataOptions {
  commodities: { id: string; name: string }[];
  grades: { id: string; commodityId: string | null; gradeName: string }[];
  states: { id: string; name: string }[];
}

interface BrokerSupplySearchWorkspaceProps {
  initialLots: BrokerSupplyLot[];
  masterData: MasterDataOptions;
  initialFilters: SupplyFilters;
  requirementContext?: {
    id: string;
    ref: string;
    commodityName?: string;
    quantity?: number;
    unit?: string;
  } | null;
  error?: string;
}

export function BrokerSupplySearchWorkspace({
  initialLots = [],
  masterData,
  initialFilters,
  requirementContext,
  error,
}: BrokerSupplySearchWorkspaceProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [lots, setLots] = useState<BrokerSupplyLot[]>(initialLots);
  const [filters, setFilters] = useState<SupplyFilters>(initialFilters);
  const [searchQuery, setSearchQuery] = useState(initialFilters.searchQuery || '');
  const [selectedLotForModal, setSelectedLotForModal] = useState<BrokerSupplyLot | null>(null);
  const [isRequestDialogOpen, setIsRequestDialogOpen] = useState<boolean>(false);

  // Handle live filter updates using Server Action
  const handleFilterChange = (newFilters: SupplyFilters) => {
    setFilters(newFilters);
    startTransition(async () => {
      const res = await getBrokerSupplySearchAction({
        ...newFilters,
        searchQuery: searchQuery.trim() || undefined,
      });
      if (res.success && res.data) {
        setLots(res.data);
      } else if (res.error) {
        toast.error(res.error);
      }
    });
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    handleFilterChange({ ...filters, searchQuery: searchQuery.trim() || undefined });
  };

  const handleSelectLot = (lot: BrokerSupplyLot) => {
    setSelectedLotForModal(lot);
    setIsRequestDialogOpen(true);
  };

  return (
    <div className="space-y-5">
      {/* 1. Header Navigation & Breadcrumbs */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <Link
              href="/broker/work"
              className="inline-flex items-center h-8 px-2 text-slate-500 hover:text-slate-800 -ml-2 text-xs rounded-md hover:bg-slate-100 transition-colors"
            >
              <ArrowLeft className="w-3.5 h-3.5 mr-1" />
              <span>Back to Work Hub</span>
            </Link>
            <span className="text-slate-300">/</span>
            <span className="text-xs font-semibold text-slate-700">Seller Supply</span>
          </div>

          <div className="flex items-center gap-2.5">
            <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">
              Seller Supply Search
            </h1>
            <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase tracking-wider bg-[#CCFBF1] text-[#0D9488] border border-teal-200/70 shrink-0">
              DISCOVERY
            </span>
          </div>
          <p className="text-xs sm:text-sm text-slate-500">
            Search verified seller inventory, check loading readiness, and inspect confidential floor prices.
          </p>
        </div>

        <div className="flex items-center gap-2 text-xs font-medium text-slate-600 bg-white px-3 py-1.5 rounded-lg border border-slate-200/80 shadow-2xs w-fit">
          <PackageSearch className="w-3.5 h-3.5 text-[#0D9488]" />
          <span>{lots.length} Verified Supply Lots</span>
        </div>
      </div>

      {/* 2. Requirement Context Banner (if arrived from "Find Seller") */}
      {requirementContext && (
        <div className="p-3.5 sm:p-4 rounded-xl bg-teal-50/90 border border-teal-200/80 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="flex items-start gap-3">
            <div className="w-9 h-9 rounded-lg bg-[#0D9488] text-white flex items-center justify-center shrink-0 shadow-2xs">
              <FileText className="w-4 h-4" />
            </div>
            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <span className="text-xs font-bold text-teal-900">
                  Matching Supply for Buyer Requirement:
                </span>
                <span className="text-xs font-mono font-bold bg-white/80 px-2 py-0.5 rounded text-[#0D9488] border border-teal-200/60">
                  {requirementContext.ref}
                </span>
              </div>
              <p className="text-xs text-teal-700 mt-0.5">
                Target Commodity: <span className="font-semibold text-teal-900">{requirementContext.commodityName || 'Selected Commodity'}</span>
                {requirementContext.quantity && ` • Target Volume: ${requirementContext.quantity} ${requirementContext.unit || 'MT'}`}
              </p>
            </div>
          </div>

          <Link
            href="/broker/work/supply"
            className="inline-flex items-center justify-center min-h-[38px] h-9 px-3 bg-white border border-teal-300 text-teal-800 hover:bg-teal-100/60 text-xs font-semibold rounded-lg shrink-0 transition-colors"
          >
            <X className="w-3.5 h-3.5 mr-1" />
            <span>Clear Requirement Filter</span>
          </Link>
        </div>
      )}

      {/* 3. Search & Filter Bar */}
      <div className="space-y-3">
        <form onSubmit={handleSearchSubmit} className="relative w-full">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          <Input
            type="text"
            placeholder="Search by seller company, lot ID, commodity, or grade..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10 pr-24 min-h-[48px] h-12 bg-white border-slate-200/90 rounded-xl text-xs sm:text-sm focus-visible:ring-[#0D9488]"
          />
          <Button
            type="submit"
            size="sm"
            className="absolute right-1.5 top-1/2 -translate-y-1/2 min-h-[34px] h-8 bg-slate-900 hover:bg-slate-800 text-white text-xs font-semibold rounded-lg px-3"
          >
            Search
          </Button>
        </form>

        {/* Filters Component (Responsive Sheet on Mobile, Panel on Desktop) */}
        <SupplyFiltersComponent
          filters={filters}
          onFilterChange={handleFilterChange}
          masterData={masterData}
          totalResultsCount={lots.length}
        />
      </div>

      {/* 4. Loading Indicator */}
      {isPending && (
        <div className="text-center py-2 text-xs text-[#0D9488] font-semibold animate-pulse flex items-center justify-center gap-1.5">
          <Sparkles className="w-3.5 h-3.5" />
          <span>Searching active inventory...</span>
        </div>
      )}

      {/* 5. Supply Lots Grid or Empty State */}
      {error ? (
        <Card className="border-rose-200 bg-rose-50/50">
          <CardContent className="p-6 text-center space-y-3">
            <AlertCircle className="w-8 h-8 text-rose-600 mx-auto" />
            <div className="space-y-1">
              <h3 className="font-bold text-slate-800 text-base">Error Loading Supply</h3>
              <p className="text-xs text-slate-600">{error}</p>
            </div>
            <Button
              variant="outline"
              onClick={() => window.location.reload()}
              className="min-h-[48px] h-12"
            >
              Retry
            </Button>
          </CardContent>
        </Card>
      ) : lots.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-5">
          {lots.map((lot) => (
            <SupplyCard
              key={lot.id}
              lot={lot}
              requirementId={requirementContext?.id}
              onSelectLot={handleSelectLot}
            />
          ))}
        </div>
      ) : (
        /* Empty State */
        <Card className="border-dashed border-2 border-slate-200 bg-white/70">
          <CardContent className="p-8 sm:p-12 text-center space-y-4">
            <div className="mx-auto w-14 h-14 rounded-2xl bg-teal-50 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
              <PackageSearch className="w-7 h-7" />
            </div>
            <div className="space-y-1.5 max-w-sm mx-auto">
              <h3 className="font-bold text-slate-900 text-base sm:text-lg">
                No Matching Seller Inventory
              </h3>
              <p className="text-xs sm:text-sm text-slate-500 leading-relaxed">
                No active supply lots match your search criteria. Try loosening filters or searching another commodity.
              </p>
            </div>
            <Button
              variant="outline"
              onClick={() => {
                setSearchQuery('');
                handleFilterChange({});
              }}
              className="min-h-[48px] h-12 text-xs font-semibold"
            >
              Reset All Filters
            </Button>
          </CardContent>
        </Card>
      )}

      {/* Outbound Commercial Request Trigger Modal (Micro-Sprint 23.4) */}
      <SendRequestDialog
        open={isRequestDialogOpen}
        onOpenChange={setIsRequestDialogOpen}
        lot={selectedLotForModal}
        requirementContext={requirementContext}
        onSuccess={() => {
          router.push('/broker/work');
        }}
      />
    </div>
  );
}
