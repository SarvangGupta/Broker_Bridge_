'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { VetKindProductItem } from '@/src/server/actions/vetkind-actions';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardFooter, CardHeader } from '@/components/ui/card';
import { CheckCircle2, ChevronRight, Package, ShieldCheck, Sparkles, Send } from 'lucide-react';
import { VetKindInquiryModal } from './inquiry-modal';

interface ProductCardProps {
  product: VetKindProductItem;
}

export function VetKindProductCard({ product }: ProductCardProps) {
  const [isInquiryOpen, setIsInquiryOpen] = useState(false);

  return (
    <>
      <Card className="flex flex-col h-full bg-white border border-slate-200/90 hover:border-emerald-500/50 hover:shadow-lg transition-all duration-300 rounded-2xl overflow-hidden group">
        <CardHeader className="p-5 pb-3 space-y-3 bg-gradient-to-b from-slate-50/70 to-white">
          <div className="flex items-center justify-between gap-2">
            <span className="text-[11px] font-semibold text-emerald-800 tracking-wide uppercase bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-100">
              {product.category}
            </span>
            {product.badge && (
              <Badge className="bg-amber-500 hover:bg-amber-600 text-white font-semibold text-[10px] px-2 py-0.5 rounded-full shadow-xs">
                {product.badge}
              </Badge>
            )}
          </div>

          <div>
            <div className="text-[11px] font-mono text-slate-400 mb-0.5">{product.sku}</div>
            <h3 className="text-lg font-bold text-slate-900 group-hover:text-emerald-700 transition-colors line-clamp-2">
              {product.name}
            </h3>
          </div>

          {/* Target Species Chips */}
          <div className="flex flex-wrap gap-1.5 pt-1">
            {product.targetSpecies.map((species) => (
              <span
                key={species}
                className="inline-flex items-center text-[10px] font-medium bg-slate-100 text-slate-700 px-2 py-0.5 rounded-full"
              >
                🐾 {species}
              </span>
            ))}
          </div>
        </CardHeader>

        <CardContent className="p-5 pt-3 flex-1 space-y-3.5 text-sm text-slate-600">
          <p className="text-xs text-slate-600 leading-relaxed line-clamp-3">
            {product.shortDescription}
          </p>

          {/* Quick Specifications */}
          <div className="space-y-2 bg-slate-50/80 p-3 rounded-xl border border-slate-100 text-xs">
            <div>
              <span className="font-semibold text-slate-800">Composition: </span>
              <span className="text-slate-600 line-clamp-2">{product.composition}</span>
            </div>
            <div>
              <span className="font-semibold text-slate-800">Indications: </span>
              <span className="text-emerald-700 line-clamp-1">{product.indications}</span>
            </div>
            <div className="flex items-center justify-between pt-1 border-t border-slate-200/60 text-[11px]">
              <span className="flex items-center gap-1 text-slate-500 font-medium">
                <Package className="w-3.5 h-3.5 text-slate-400" />
                {product.packaging}
              </span>
              <span className="font-bold text-slate-900">{product.mrp}</span>
            </div>
          </div>
        </CardContent>

        <CardFooter className="p-5 pt-0 gap-2">
          <Link href={`/vetkind/products/${product.slug}`} className="flex-1">
            <Button
              variant="outline"
              size="sm"
              className="w-full text-xs font-semibold border-slate-300 hover:border-emerald-600 hover:text-emerald-700"
            >
              Technical Monograph
              <ChevronRight className="w-3.5 h-3.5 ml-1" />
            </Button>
          </Link>
          <Button
            size="sm"
            onClick={() => setIsInquiryOpen(true)}
            className="bg-emerald-700 hover:bg-emerald-800 text-white text-xs font-semibold shadow-xs"
          >
            <Send className="w-3.5 h-3.5 mr-1" />
            Enquire
          </Button>
        </CardFooter>
      </Card>

      <VetKindInquiryModal
        isOpen={isInquiryOpen}
        onClose={() => setIsInquiryOpen(false)}
        preselectedProduct={product}
      />
    </>
  );
}
