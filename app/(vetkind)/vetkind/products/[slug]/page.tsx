import React from 'react';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { getVetKindProductBySlugAction } from '@/src/server/actions/vetkind-actions';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  ArrowLeft,
  Package,
  ShieldCheck,
  Stethoscope,
  Sparkles,
  HeartPulse,
  Clock,
  Send,
  AlertTriangle,
  Award,
} from 'lucide-react';

interface ProductDetailPageProps {
  params: Promise<{
    slug: string;
  }>;
}

export const dynamic = 'force-dynamic';

export default async function VetKindProductDetailPage({
  params,
}: ProductDetailPageProps) {
  const { slug } = await params;
  const res = await getVetKindProductBySlugAction(slug);

  if (!res.success || !res.data) {
    notFound();
  }

  const product = res.data;

  return (
    <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-10 space-y-8">
      {/* Back button and breadcrumb */}
      <div className="flex items-center justify-between">
        <Link
          href="/vetkind"
          className="inline-flex items-center text-xs font-semibold text-emerald-800 hover:text-emerald-950 transition-colors"
        >
          <ArrowLeft className="w-4 h-4 mr-1.5" />
          Back to Full Catalogue
        </Link>
        <span className="text-xs font-mono text-slate-400">SKU: {product.sku}</span>
      </div>

      {/* Main Product Header Card */}
      <div className="bg-white rounded-3xl border border-slate-200/90 shadow-xs p-6 sm:p-10 space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xs font-bold text-emerald-800 bg-emerald-50 border border-emerald-200 px-3 py-1 rounded-full uppercase">
              {product.category}
            </span>
            {product.badge && (
              <Badge className="bg-amber-500 text-white font-semibold text-xs px-2.5 py-0.5">
                {product.badge}
              </Badge>
            )}
          </div>
          <div className="text-lg font-bold text-slate-900 bg-slate-50 px-4 py-1.5 rounded-xl border border-slate-100">
            MRP: <span className="text-emerald-700">{product.mrp}</span>
          </div>
        </div>

        <div className="space-y-3">
          <h1 className="text-2xl sm:text-4xl font-black text-slate-900 tracking-tight leading-tight">
            {product.name}
          </h1>
          <p className="text-base text-slate-600 leading-relaxed max-w-3xl">
            {product.shortDescription}
          </p>
        </div>

        {/* Species & Packaging Badges */}
        <div className="flex flex-wrap items-center gap-4 pt-4 border-t border-slate-100">
          <div className="space-y-1">
            <div className="text-xs font-bold text-slate-500 uppercase">Target Species</div>
            <div className="flex flex-wrap gap-1.5">
              {product.targetSpecies.map((s) => (
                <span
                  key={s}
                  className="bg-slate-100 text-slate-800 text-xs px-2.5 py-1 rounded-lg font-semibold"
                >
                  🐾 {s}
                </span>
              ))}
            </div>
          </div>

          <div className="space-y-1 sm:ml-auto">
            <div className="text-xs font-bold text-slate-500 uppercase">Standard Packaging</div>
            <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-800 bg-slate-50 border border-slate-200 px-3 py-1 rounded-lg">
              <Package className="w-4 h-4 text-emerald-600" />
              {product.packaging}
            </div>
          </div>
        </div>
      </div>

      {/* Deep Technical Monograph Sections */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Left Column: Technical Breakdown */}
        <div className="lg:col-span-2 space-y-6">
          {/* Detailed Description */}
          <div className="bg-white rounded-2xl border border-slate-200 p-6 sm:p-8 space-y-4">
            <div className="flex items-center gap-2 text-slate-900 font-bold text-base">
              <Sparkles className="w-5 h-5 text-emerald-600" />
              <h2>Therapeutic Rationale & Pharmacology</h2>
            </div>
            <p className="text-sm text-slate-600 leading-relaxed">
              {product.fullDescription}
            </p>
          </div>

          {/* Active Composition */}
          <div className="bg-white rounded-2xl border border-slate-200 p-6 sm:p-8 space-y-4">
            <div className="flex items-center gap-2 text-slate-900 font-bold text-base">
              <ShieldCheck className="w-5 h-5 text-emerald-600" />
              <h2>Active Pharmaceutical / Nutrient Composition</h2>
            </div>
            <div className="bg-emerald-50/60 p-4 rounded-xl border border-emerald-100 text-sm font-mono text-emerald-950 leading-relaxed">
              {product.composition}
            </div>
          </div>

          {/* Clinical Indications */}
          <div className="bg-white rounded-2xl border border-slate-200 p-6 sm:p-8 space-y-4">
            <div className="flex items-center gap-2 text-slate-900 font-bold text-base">
              <HeartPulse className="w-5 h-5 text-emerald-600" />
              <h2>Clinical Indications & Applications</h2>
            </div>
            <p className="text-sm text-slate-700 leading-relaxed font-medium bg-slate-50 p-4 rounded-xl border border-slate-100">
              {product.indications}
            </p>
          </div>

          {/* Dosage & Administration */}
          <div className="bg-white rounded-2xl border border-slate-200 p-6 sm:p-8 space-y-4">
            <div className="flex items-center gap-2 text-slate-900 font-bold text-base">
              <Clock className="w-5 h-5 text-emerald-600" />
              <h2>Dosage & Route of Administration</h2>
            </div>
            <div className="p-4 rounded-xl bg-slate-900 text-white space-y-2">
              <div className="text-xs text-emerald-400 font-semibold uppercase tracking-wider">
                Recommended Administration Schedule
              </div>
              <p className="text-sm leading-relaxed text-slate-200">
                {product.dosageInstructions}
              </p>
            </div>
          </div>
        </div>

        {/* Right Column: Compliance, Storage, and Enquiry Card */}
        <div className="space-y-6">
          {/* Compliance & Withdrawal Card */}
          <div className="bg-white rounded-2xl border border-slate-200 p-6 space-y-4">
            <h3 className="font-bold text-slate-900 text-sm flex items-center gap-2">
              <Award className="w-4 h-4 text-emerald-600" />
              Veterinary Compliance & Safety
            </h3>

            <div className="space-y-3 text-xs">
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-100 space-y-1">
                <span className="font-bold text-slate-700">Withdrawal Period:</span>
                <p className="text-emerald-800 font-semibold">{product.withdrawalPeriod}</p>
              </div>

              <div className="p-3 rounded-xl bg-slate-50 border border-slate-100 space-y-1">
                <span className="font-bold text-slate-700">Storage Guidance:</span>
                <p className="text-slate-600">{product.storageInstructions}</p>
              </div>
            </div>
          </div>

          {/* Direct Technical Inquiry CTA */}
          <div className="bg-gradient-to-br from-emerald-900 to-teal-950 text-white rounded-2xl p-6 space-y-4 shadow-md">
            <div className="flex items-center gap-2 text-emerald-300 text-xs font-bold">
              <Stethoscope className="w-4 h-4" />
              <span>DIRECT TECHNICAL ENQUIRY</span>
            </div>
            <h3 className="font-bold text-lg leading-tight">
              Procure or Consult on {product.name}
            </h3>
            <p className="text-xs text-emerald-100/80 leading-relaxed">
              Order commercial pack sizes, request institutional hospital pricing, or speak directly with our formulations doctor.
            </p>
            <div className="space-y-2 pt-2">
              <a href="mailto:vetkindinfo@gmail.com?subject=Enquiry on SKU: " className="block">
                <Button className="w-full bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-xs">
                  <Send className="w-3.5 h-3.5 mr-1.5" />
                  Request Commercial Quote
                </Button>
              </a>
              <Link href="/vetkind/dealers" className="block">
                <Button
                  variant="outline"
                  className="w-full border-emerald-700/60 bg-emerald-950/40 hover:bg-emerald-800 text-emerald-200 text-xs font-semibold"
                >
                  Find Nearest Stockist
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
