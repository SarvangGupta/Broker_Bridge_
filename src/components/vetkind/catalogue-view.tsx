'use client';

import React, { useState, useMemo } from 'react';
import { VetKindProductItem } from '@/src/server/actions/vetkind-actions';
import { VetKindProductCard } from './product-card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Search, Filter, Sparkles, AlertCircle } from 'lucide-react';

interface CatalogueViewProps {
  initialProducts: VetKindProductItem[];
  categories: { id: string; name: string; slug: string; description?: string | null }[];
}

const SPECIES_FILTERS = [
  { id: 'all', label: 'All Species' },
  { id: 'Cattle', label: '🐄 Cattle & Cows' },
  { id: 'Buffalo', label: '🐃 Buffalo' },
  { id: 'Calf', label: '🍼 Calves' },
  { id: 'Sheep', label: '🐑 Sheep & Goat' },
  { id: 'Poultry', label: '🐔 Poultry' },
];

export function VetKindCatalogueView({
  initialProducts,
  categories,
}: CatalogueViewProps) {
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [selectedSpecies, setSelectedSpecies] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');

  const filteredProducts = useMemo(() => {
    return initialProducts.filter((product) => {
      // Category match
      if (selectedCategory !== 'all' && product.categorySlug !== selectedCategory) {
        return false;
      }
      // Species match
      if (
        selectedSpecies !== 'all' &&
        !product.targetSpecies.some(
          (s) => s.toLowerCase() === selectedSpecies.toLowerCase()
        )
      ) {
        return false;
      }
      // Query match
      if (searchQuery.trim() !== '') {
        const q = searchQuery.toLowerCase().trim();
        const matchesName = product.name.toLowerCase().includes(q);
        const matchesSku = product.sku.toLowerCase().includes(q);
        const matchesDesc = product.shortDescription.toLowerCase().includes(q);
        const matchesIndications = product.indications.toLowerCase().includes(q);
        const matchesComp = product.composition.toLowerCase().includes(q);
        if (!matchesName && !matchesSku && !matchesDesc && !matchesIndications && !matchesComp) {
          return false;
        }
      }
      return true;
    });
  }, [initialProducts, selectedCategory, selectedSpecies, searchQuery]);

  return (
    <div className="space-y-8">
      {/* Search and Filters Header */}
      <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-xs space-y-5">
        <div className="flex flex-col md:flex-row gap-3 items-stretch md:items-center justify-between">
          {/* Search Bar */}
          <div className="relative flex-1">
            <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
            <Input
              type="text"
              placeholder="Search veterinary medicines, minerals, composition, or symptoms (e.g. Mastitis, Calcium, Ketosis)..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10 text-sm h-11 bg-slate-50/70 border-slate-200 focus:bg-white rounded-xl"
            />
          </div>

          {/* Active Results Counter */}
          <div className="flex items-center gap-2 text-xs font-semibold text-slate-500 self-end md:self-auto">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            Showing <strong className="text-slate-900">{filteredProducts.length}</strong> Formulations
          </div>
        </div>

        {/* Category Pills */}
        <div className="space-y-2">
          <div className="flex items-center gap-1.5 text-xs font-bold text-slate-700 uppercase tracking-wider">
            <Filter className="w-3.5 h-3.5 text-emerald-600" />
            Filter by Clinical Category:
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              key="all"
              variant={selectedCategory === 'all' ? 'default' : 'outline'}
              size="sm"
              onClick={() => setSelectedCategory('all')}
              className={`text-xs rounded-xl h-8 font-medium ${
                selectedCategory === 'all'
                  ? 'bg-emerald-800 text-white'
                  : 'border-slate-200 text-slate-700 hover:bg-slate-100'
              }`}
            >
              All Categories
            </Button>
            {categories.map((cat) => (
              <Button
                key={cat.slug}
                variant={selectedCategory === cat.slug ? 'default' : 'outline'}
                size="sm"
                onClick={() => setSelectedCategory(cat.slug)}
                className={`text-xs rounded-xl h-8 font-medium ${
                  selectedCategory === cat.slug
                    ? 'bg-emerald-800 text-white'
                    : 'border-slate-200 text-slate-700 hover:bg-slate-100'
                }`}
              >
                {cat.name}
              </Button>
            ))}
          </div>
        </div>

        {/* Species Pills */}
        <div className="flex flex-wrap items-center gap-2 pt-1 border-t border-slate-100">
          <span className="text-xs font-semibold text-slate-500 mr-1">Target Species:</span>
          {SPECIES_FILTERS.map((s) => (
            <button
              key={s.id}
              onClick={() => setSelectedSpecies(s.id)}
              className={`text-xs px-2.5 py-1 rounded-lg transition-all font-medium ${
                selectedSpecies === s.id
                  ? 'bg-emerald-100 text-emerald-900 border border-emerald-300 font-semibold'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200 border border-transparent'
              }`}
            >
              {s.label}
            </button>
          ))}
          {(selectedCategory !== 'all' || selectedSpecies !== 'all' || searchQuery !== '') && (
            <button
              onClick={() => {
                setSelectedCategory('all');
                setSelectedSpecies('all');
                setSearchQuery('');
              }}
              className="text-xs text-rose-600 hover:underline font-semibold ml-auto"
            >
              Reset Filters
            </button>
          )}
        </div>
      </div>

      {/* Product Grid */}
      {filteredProducts.length === 0 ? (
        <div className="bg-white border border-slate-200 rounded-2xl p-12 text-center space-y-4">
          <div className="w-12 h-12 bg-amber-50 text-amber-600 rounded-full flex items-center justify-center mx-auto">
            <AlertCircle className="w-6 h-6" />
          </div>
          <h3 className="text-lg font-bold text-slate-900">
            No products match your current filter
          </h3>
          <p className="text-sm text-slate-500 max-w-md mx-auto">
            Try adjusting your search query or species selector, or consult our veterinary team for custom formulation inquiries.
          </p>
          <Button
            onClick={() => {
              setSelectedCategory('all');
              setSelectedSpecies('all');
              setSearchQuery('');
            }}
            variant="outline"
            size="sm"
            className="text-xs font-semibold"
          >
            Clear All Filters
          </Button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredProducts.map((product) => (
            <VetKindProductCard key={product.id} product={product} />
          ))}
        </div>
      )}
    </div>
  );
}
