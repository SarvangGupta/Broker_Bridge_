'use client';

import React, { useState, useEffect } from 'react';
import {
  SlidersHorizontal,
  X,
  RotateCcw,
  IndianRupee,
  Check,
  Building2,
  MapPin,
  Tag,
  Layers,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
  SheetFooter,
  SheetTrigger,
} from '@/components/ui/sheet';
import { Badge } from '@/components/ui/badge';
import type { SupplyFilters } from '@/src/server/actions/broker-supply-actions';

interface MasterDataOptions {
  commodities: { id: string; name: string }[];
  grades: { id: string; commodityId: string | null; gradeName: string }[];
  states: { id: string; name: string }[];
}

interface SupplyFiltersProps {
  filters: SupplyFilters;
  onFilterChange: (filters: SupplyFilters) => void;
  masterData: MasterDataOptions;
  totalResultsCount: number;
}

export function SupplyFiltersComponent({
  filters,
  onFilterChange,
  masterData,
  totalResultsCount,
}: SupplyFiltersProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [localFilters, setLocalFilters] = useState<SupplyFilters>(filters);

  // Sync local filters when props change
  useEffect(() => {
    setLocalFilters(filters);
  }, [filters]);

  // Name resolution helpers to avoid showing raw UUIDs
  const getCommodityName = (id?: string) => {
    if (!id || id === 'all') return 'All Commodities';
    const found = masterData.commodities.find((c) => c.id === id);
    return found ? found.name : 'All Commodities';
  };

  const getGradeName = (id?: string) => {
    if (!id || id === 'all') return 'All Grades';
    const found = masterData.grades.find((g) => g.id === id);
    return found ? found.gradeName : 'All Grades';
  };

  const getStateName = (id?: string) => {
    if (!id || id === 'all') return 'All States';
    const found = masterData.states.find((s) => s.id === id);
    return found ? found.name : 'All States';
  };

  // Filter grades by selected commodity
  const availableGrades = React.useMemo(() => {
    if (!localFilters.commodityId || localFilters.commodityId === 'all') {
      return masterData.grades;
    }
    return masterData.grades.filter(
      (g) => !g.commodityId || g.commodityId === localFilters.commodityId
    );
  }, [localFilters.commodityId, masterData.grades]);

  // Calculate active filter count
  const activeCount = React.useMemo(() => {
    let count = 0;
    if (filters.commodityId && filters.commodityId !== 'all') count++;
    if (filters.gradeId && filters.gradeId !== 'all') count++;
    if (filters.stateId && filters.stateId !== 'all') count++;
    if (filters.maxPrice && filters.maxPrice > 0) count++;
    return count;
  }, [filters]);

  const handleApply = () => {
    onFilterChange(localFilters);
    setIsOpen(false);
  };

  const handleReset = () => {
    const resetValues: SupplyFilters = {
      commodityId: undefined,
      gradeId: undefined,
      stateId: undefined,
      maxPrice: undefined,
      searchQuery: filters.searchQuery,
    };
    setLocalFilters(resetValues);
    onFilterChange(resetValues);
    setIsOpen(false);
  };

  // Reusable Filter Form Content for Mobile Drawer
  const filterFormContent = (
    <div className="space-y-4 py-2">
      {/* 1. Commodity Dropdown */}
      <div className="space-y-1.5">
        <Label className="text-xs font-bold text-slate-700 flex items-center gap-1.5">
          <Tag className="w-3.5 h-3.5 text-[#0D9488]" />
          <span>Commodity</span>
        </Label>
        <Select
          value={localFilters.commodityId || 'all'}
          onValueChange={(val) =>
            setLocalFilters((prev) => {
              const updated: SupplyFilters = {
                ...prev,
                commodityId: val === 'all' || !val ? undefined : val,
                gradeId: undefined,
              };
              return updated;
            })
          }
        >
          <SelectTrigger className="w-full min-h-[48px] h-12 bg-white border-slate-200 text-xs sm:text-sm">
            <SelectValue placeholder="All Commodities">
              {getCommodityName(localFilters.commodityId)}
            </SelectValue>
          </SelectTrigger>
          <SelectContent className="max-h-60">
            <SelectItem value="all">All Commodities</SelectItem>
            {masterData.commodities.map((c) => (
              <SelectItem key={c.id} value={c.id}>
                {c.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* 2. Grade Dropdown */}
      <div className="space-y-1.5">
        <Label className="text-xs font-bold text-slate-700 flex items-center gap-1.5">
          <Layers className="w-3.5 h-3.5 text-[#0D9488]" />
          <span>Quality Parameter / Grade</span>
        </Label>
        <Select
          value={localFilters.gradeId || 'all'}
          onValueChange={(val) =>
            setLocalFilters((prev) => {
              const updated: SupplyFilters = {
                ...prev,
                gradeId: val === 'all' || !val ? undefined : val,
              };
              return updated;
            })
          }
        >
          <SelectTrigger className="w-full min-h-[48px] h-12 bg-white border-slate-200 text-xs sm:text-sm">
            <SelectValue placeholder="All Grades / Specifications">
              {getGradeName(localFilters.gradeId)}
            </SelectValue>
          </SelectTrigger>
          <SelectContent className="max-h-60">
            <SelectItem value="all">All Grades</SelectItem>
            {availableGrades.map((g) => (
              <SelectItem key={g.id} value={g.id}>
                {g.gradeName}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* 3. State Location */}
      <div className="space-y-1.5">
        <Label className="text-xs font-bold text-slate-700 flex items-center gap-1.5">
          <MapPin className="w-3.5 h-3.5 text-[#0D9488]" />
          <span>Warehouse State</span>
        </Label>
        <Select
          value={localFilters.stateId || 'all'}
          onValueChange={(val) =>
            setLocalFilters((prev) => {
              const updated: SupplyFilters = {
                ...prev,
                stateId: val === 'all' || !val ? undefined : val,
              };
              return updated;
            })
          }
        >
          <SelectTrigger className="w-full min-h-[48px] h-12 bg-white border-slate-200 text-xs sm:text-sm">
            <SelectValue placeholder="All States">
              {getStateName(localFilters.stateId)}
            </SelectValue>
          </SelectTrigger>
          <SelectContent className="max-h-60">
            <SelectItem value="all">All States</SelectItem>
            {masterData.states.map((s) => (
              <SelectItem key={s.id} value={s.id}>
                {s.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* 4. Max Asking Price */}
      <div className="space-y-1.5">
        <Label className="text-xs font-bold text-slate-700 flex items-center gap-1.5">
          <IndianRupee className="w-3.5 h-3.5 text-[#0D9488]" />
          <span>Max Asking Price (₹)</span>
        </Label>
        <div className="relative">
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold text-xs">
            ₹
          </span>
          <Input
            type="number"
            placeholder="e.g. 6000"
            value={localFilters.maxPrice !== undefined ? localFilters.maxPrice : ''}
            onChange={(e) => {
              const val = e.target.value ? Number(e.target.value) : undefined;
              setLocalFilters((prev) => ({ ...prev, maxPrice: val }));
            }}
            className="pl-7 min-h-[48px] h-12 bg-white border-slate-200 text-xs sm:text-sm"
          />
        </div>
      </div>
    </div>
  );

  return (
    <div>
      {/* Mobile Trigger Button (Visible on small screens) */}
      <div className="flex items-center justify-between gap-2 md:hidden">
        <Sheet open={isOpen} onOpenChange={setIsOpen}>
          <SheetTrigger className="w-full min-h-[48px] h-12 bg-white border border-slate-200 shadow-2xs font-semibold text-xs sm:text-sm text-slate-700 flex items-center justify-between px-4 rounded-xl cursor-pointer hover:bg-slate-50 transition-colors">
            <div className="flex items-center gap-2">
              <SlidersHorizontal className="w-4 h-4 text-[#0D9488]" />
              <span>Filter Supply Inventory</span>
            </div>
            {activeCount > 0 ? (
              <Badge className="bg-[#0D9488] text-white text-[11px] px-2 py-0.5 font-bold">
                {activeCount} active
              </Badge>
            ) : (
              <span className="text-xs text-slate-400 font-normal">All Supply</span>
            )}
          </SheetTrigger>

          <SheetContent side="bottom" className="rounded-t-2xl max-h-[85vh] overflow-y-auto p-5">
            <SheetHeader className="text-left pb-2 border-b border-slate-100">
              <SheetTitle className="text-lg font-bold text-slate-900 flex items-center justify-between">
                <span>Filter Seller Inventory</span>
                {activeCount > 0 && (
                  <button
                    type="button"
                    onClick={handleReset}
                    className="text-xs text-rose-600 font-semibold hover:underline flex items-center gap-1"
                  >
                    <RotateCcw className="w-3.5 h-3.5" />
                    <span>Reset</span>
                  </button>
                )}
              </SheetTitle>
              <SheetDescription className="text-xs text-slate-500">
                Filter active lots by commodity, grade specifications, location, or asking price.
              </SheetDescription>
            </SheetHeader>

            {filterFormContent}

            <SheetFooter className="flex flex-col gap-2 pt-4 border-t border-slate-100 mt-2">
              <Button
                type="button"
                onClick={handleApply}
                className="w-full min-h-[48px] h-12 bg-[#0D9488] hover:bg-teal-700 text-white font-bold text-sm rounded-xl"
              >
                Apply Filters ({totalResultsCount} Lots Found)
              </Button>
            </SheetFooter>
          </SheetContent>
        </Sheet>
      </div>

      {/* Desktop Panel View (Visible on md/lg screens) */}
      <div className="hidden md:block bg-white p-4 rounded-xl border border-slate-200/80 shadow-2xs space-y-4">
        <div className="flex items-center justify-between border-b border-slate-100 pb-3">
          <div className="flex items-center gap-2">
            <SlidersHorizontal className="w-4 h-4 text-[#0D9488]" />
            <span className="font-bold text-slate-900 text-sm">Filter Inventory</span>
            {activeCount > 0 && (
              <Badge className="bg-[#CCFBF1] text-[#0D9488] border-teal-200 text-[10px] font-bold">
                {activeCount} active
              </Badge>
            )}
          </div>
          {activeCount > 0 && (
            <button
              type="button"
              onClick={handleReset}
              className="text-xs text-slate-400 hover:text-rose-600 font-medium flex items-center gap-1 transition-colors"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              <span>Reset</span>
            </button>
          )}
        </div>

        <div className="grid grid-cols-4 gap-3">
          {/* Commodity Dropdown */}
          <div className="space-y-1">
            <Label className="text-[11px] font-semibold text-slate-500">Commodity</Label>
            <Select
              value={filters.commodityId || 'all'}
              onValueChange={(val) =>
                onFilterChange({
                  ...filters,
                  commodityId: val === 'all' || !val ? undefined : val,
                  gradeId: undefined,
                })
              }
            >
              <SelectTrigger className="w-full min-h-[48px] h-12 bg-slate-50/70 border-slate-200 text-xs">
                <SelectValue placeholder="All Commodities">
                  {getCommodityName(filters.commodityId)}
                </SelectValue>
              </SelectTrigger>
              <SelectContent className="max-h-60">
                <SelectItem value="all">All Commodities</SelectItem>
                {masterData.commodities.map((c) => (
                  <SelectItem key={c.id} value={c.id}>
                    {c.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Grade Dropdown */}
          <div className="space-y-1">
            <Label className="text-[11px] font-semibold text-slate-500">Grade / Quality</Label>
            <Select
              value={filters.gradeId || 'all'}
              onValueChange={(val) =>
                onFilterChange({
                  ...filters,
                  gradeId: val === 'all' || !val ? undefined : val,
                })
              }
            >
              <SelectTrigger className="w-full min-h-[48px] h-12 bg-slate-50/70 border-slate-200 text-xs">
                <SelectValue placeholder="All Grades">
                  {getGradeName(filters.gradeId)}
                </SelectValue>
              </SelectTrigger>
              <SelectContent className="max-h-60">
                <SelectItem value="all">All Grades</SelectItem>
                {availableGrades.map((g) => (
                  <SelectItem key={g.id} value={g.id}>
                    {g.gradeName}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* State Dropdown */}
          <div className="space-y-1">
            <Label className="text-[11px] font-semibold text-slate-500">State</Label>
            <Select
              value={filters.stateId || 'all'}
              onValueChange={(val) =>
                onFilterChange({
                  ...filters,
                  stateId: val === 'all' || !val ? undefined : val,
                })
              }
            >
              <SelectTrigger className="w-full min-h-[48px] h-12 bg-slate-50/70 border-slate-200 text-xs">
                <SelectValue placeholder="All States">
                  {getStateName(filters.stateId)}
                </SelectValue>
              </SelectTrigger>
              <SelectContent className="max-h-60">
                <SelectItem value="all">All States</SelectItem>
                {masterData.states.map((s) => (
                  <SelectItem key={s.id} value={s.id}>
                    {s.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Max Price */}
          <div className="space-y-1">
            <Label className="text-[11px] font-semibold text-slate-500">Max Asking Price (₹)</Label>
            <div className="relative">
              <span className="absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400 font-bold text-xs">
                ₹
              </span>
              <Input
                type="number"
                placeholder="e.g. 6000"
                value={filters.maxPrice !== undefined ? filters.maxPrice : ''}
                onChange={(e) => {
                  const val = e.target.value ? Number(e.target.value) : undefined;
                  onFilterChange({ ...filters, maxPrice: val });
                }}
                className="pl-6 min-h-[48px] h-12 bg-slate-50/70 border-slate-200 text-xs"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
