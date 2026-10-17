import React from 'react';
import Link from 'next/link';
import {
  getVetKindCategoriesAction,
  getVetKindProductsAction,
} from '@/src/server/actions/vetkind-actions';
import { VetKindCatalogueView } from '@/src/components/vetkind/catalogue-view';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  ShieldCheck,
  Award,
  Sparkles,
  HeartPulse,
  TrendingUp,
  Stethoscope,
  Store,
  ChevronRight,
  CheckCircle2,
  PhoneCall,
} from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function VetKindHomePage() {
  const [categoriesRes, productsRes] = await Promise.all([
    getVetKindCategoriesAction(),
    getVetKindProductsAction(),
  ]);

  const categories = categoriesRes.data || [];
  const products = productsRes.data || [];

  return (
    <div className="space-y-16 pb-20">
      {/* Hero Section */}
      <section className="relative overflow-hidden bg-gradient-to-br from-emerald-950 via-slate-900 to-teal-950 text-white py-16 md:py-24 px-4 sm:px-6 lg:px-8 border-b border-emerald-900/40">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_30%,rgba(16,185,129,0.15),transparent_60%)] pointer-events-none" />

        <div className="max-w-7xl mx-auto relative z-10 space-y-8">
          <div className="max-w-3xl space-y-5">
            <div className="inline-flex items-center gap-2 bg-emerald-900/70 border border-emerald-500/30 px-3 py-1 rounded-full text-emerald-300 text-xs font-semibold backdrop-blur-xs">
              <Award className="w-3.5 h-3.5 text-amber-400" />
              <span>VETKIND ANIMAL HEALTH INDIA • OFFICIAL PORTAL</span>
            </div>

            <h1 className="text-3xl sm:text-4xl lg:text-5xl font-black tracking-tight leading-tight text-white">
              Empowering Indian Dairies & Veterinarians with{' '}
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-teal-300">
                Scientifically Proven Therapeutics
              </span>
            </h1>

            <p className="text-base sm:text-lg text-slate-300 leading-relaxed font-normal">
              High-absorption chelated minerals, barrier teat hygiene, live rumen probiotics, and reproductive enhancers designed to maximize milk yield, safeguard lactation persistency, and protect bovine health.
            </p>

            <div className="flex flex-wrap gap-3 pt-2">
              <a href="#catalogue">
                <Button
                  size="lg"
                  className="bg-emerald-600 hover:bg-emerald-500 text-white font-bold px-6 shadow-lg shadow-emerald-900/30"
                >
                  <Sparkles className="w-4 h-4 mr-2" />
                  Explore Veterinary Catalogue
                </Button>
              </a>
              <Link href="/vetkind/dealers">
                <Button
                  variant="outline"
                  size="lg"
                  className="border-slate-700 bg-slate-800/80 hover:bg-slate-700 text-slate-200 font-semibold px-6"
                >
                  <Store className="w-4 h-4 mr-2 text-emerald-400" />
                  Locate Authorized Dealers
                </Button>
              </Link>
            </div>
          </div>

          {/* Key Impact Metrics */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 pt-6 border-t border-slate-800">
            <div className="bg-slate-900/60 p-4 rounded-xl border border-slate-800">
              <div className="text-2xl sm:text-3xl font-black text-emerald-400">45,000+</div>
              <div className="text-xs text-slate-400 mt-1 font-medium">
                Dairy Bovines Protected
              </div>
            </div>
            <div className="bg-slate-900/60 p-4 rounded-xl border border-slate-800">
              <div className="text-2xl sm:text-3xl font-black text-emerald-400">99.4%</div>
              <div className="text-xs text-slate-400 mt-1 font-medium">
                Veterinary Clinical Satisfaction
              </div>
            </div>
            <div className="bg-slate-900/60 p-4 rounded-xl border border-slate-800">
              <div className="text-2xl sm:text-3xl font-black text-emerald-400">120+</div>
              <div className="text-xs text-slate-400 mt-1 font-medium">
                Authorized Stockist Network
              </div>
            </div>
            <div className="bg-slate-900/60 p-4 rounded-xl border border-slate-800">
              <div className="text-2xl sm:text-3xl font-black text-emerald-400">0 Days</div>
              <div className="text-xs text-slate-400 mt-1 font-medium">
                Milk Withdrawal Residue Period
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Main Interactive Catalogue Section */}
      <section id="catalogue" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
          <div>
            <div className="flex items-center gap-2 text-emerald-700 font-bold text-xs uppercase tracking-wider mb-1">
              <Stethoscope className="w-4 h-4" />
              Veterinary Formulations
            </div>
            <h2 className="text-2xl sm:text-3xl font-black text-slate-900">
              Product Catalogue & Formulations
            </h2>
          </div>
          <p className="text-xs sm:text-sm text-slate-500 max-w-md">
            Click on any formulation to inspect detailed therapeutic composition, target species dosages, and technical indications.
          </p>
        </div>

        <VetKindCatalogueView initialProducts={products} categories={categories} />
      </section>

      {/* Why VetKind: Scientific & Clinical Pillars */}
      <section className="bg-slate-100/70 border-y border-slate-200 py-16 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto space-y-12">
          <div className="text-center max-w-2xl mx-auto space-y-3">
            <Badge className="bg-emerald-100 text-emerald-800 border-emerald-200">
              THE VETKIND STANDARD
            </Badge>
            <h2 className="text-2xl sm:text-3xl font-black text-slate-900">
              Why Progressive Dairy Farmers & Clinicians Choose VetKind
            </h2>
            <p className="text-sm text-slate-600">
              Built on peer-reviewed veterinary pharmacokinetics and designed specifically for the unique dietary and climatic conditions of Indian dairy breeds.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="bg-white p-6 rounded-2xl border border-slate-200/80 shadow-xs space-y-3">
              <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center">
                <Sparkles className="w-5 h-5" />
              </div>
              <h3 className="font-bold text-slate-900">Bio-Chelated Minerals</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Chelation protects minerals from phytic acid binders in crop residues, yielding 3.2x higher bioavailability compared to conventional inorganic mineral salts.
              </p>
            </div>

            <div className="bg-white p-6 rounded-2xl border border-slate-200/80 shadow-xs space-y-3">
              <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center">
                <ShieldCheck className="w-5 h-5" />
              </div>
              <h3 className="font-bold text-slate-900">Zero Milk Residues</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Clean herbal bio-actives and organic nutrients ensure 100% compliance with dairy cooperative testing protocols, with zero chemical adulteration or withdrawal delays.
              </p>
            </div>

            <div className="bg-white p-6 rounded-2xl border border-slate-200/80 shadow-xs space-y-3">
              <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center">
                <HeartPulse className="w-5 h-5" />
              </div>
              <h3 className="font-bold text-slate-900">Rumen Ecoflora Protection</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Live micro-encapsulated yeast strains survive gastric transit to stabilize rumen pH (6.2-6.8), dramatically reducing acidosis in high-concentrate seasonal feeding.
              </p>
            </div>

            <div className="bg-white p-6 rounded-2xl border border-slate-200/80 shadow-xs space-y-3">
              <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center">
                <TrendingUp className="w-5 h-5" />
              </div>
              <h3 className="font-bold text-slate-900">Lactation Persistency</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Targeted galactagogues stimulate alveolar secretory activity to prevent premature post-peak lactation declines in crossbred cows and Murrah buffaloes.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Clinical Advisory & Help Banner */}
      <section id="clinical-advisory" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-gradient-to-r from-emerald-900 to-teal-900 rounded-3xl p-8 sm:p-12 text-white flex flex-col md:flex-row items-center justify-between gap-8 shadow-xl">
          <div className="space-y-4 max-w-xl">
            <div className="flex items-center gap-2 text-emerald-300 text-xs font-semibold">
              <Award className="w-4 h-4 text-amber-400" />
              <span>VETERINARY MEDICAL AFFAIRS</span>
            </div>
            <h2 className="text-2xl sm:text-3xl font-black">
              Need Expert Herd Health & Clinical Guidance?
            </h2>
            <p className="text-sm text-emerald-100/90 leading-relaxed">
              Our registered veterinary specialists provide technical consultations on mastitis outbreaks, repeat breeding diagnostics, negative energy balance, and custom herd nutrition protocols.
            </p>
            <div className="flex flex-wrap gap-4 text-xs font-semibold text-emerald-200">
              <span className="flex items-center gap-1.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                Case Diagnostic Protocols
              </span>
              <span className="flex items-center gap-1.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                Dairy Nutrition Plans
              </span>
              <span className="flex items-center gap-1.5">
                <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                Direct Veterinary Dispatch
              </span>
            </div>
          </div>

          <div className="bg-white/10 backdrop-blur-md p-6 rounded-2xl border border-white/20 text-center space-y-4 w-full md:w-auto shrink-0">
            <div className="text-xs text-emerald-200 font-medium">Toll-Free Helpline</div>
            <div className="text-xl sm:text-2xl font-black text-amber-300">1800-VET-KIND</div>
            <p className="text-xs text-emerald-100 max-w-xs">
              Mon – Sat: 8:00 AM – 7:00 PM IST
            </p>
            <a href="mailto:vetkindinfo@gmail.com" className="block">
              <Button className="w-full bg-white hover:bg-slate-100 text-emerald-950 font-bold text-xs">
                Email Technical Team
              </Button>
            </a>
          </div>
        </div>
      </section>
    </div>
  );
}
