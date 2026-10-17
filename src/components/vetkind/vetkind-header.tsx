import React from 'react';
import Link from 'next/link';
import { ShieldCheck, Phone, Mail, Award, Stethoscope, Store, Sparkles } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';

export function VetKindHeader() {
  return (
    <header className="sticky top-0 z-40 w-full border-b border-emerald-950/10 bg-white/95 backdrop-blur-md shadow-xs">
      {/* Top Advisory Bar */}
      <div className="bg-gradient-to-r from-emerald-900 via-teal-900 to-emerald-950 text-white text-xs py-1.5 px-4">
        <div className="max-w-7xl mx-auto flex flex-wrap justify-between items-center gap-2">
          <div className="flex items-center gap-3">
            <span className="flex items-center gap-1 text-emerald-200 font-medium">
              <Award className="w-3.5 h-3.5 text-amber-400" />
              GMP & ISO 9001 Certified Veterinary Formulations
            </span>
            <span className="hidden md:inline-block text-emerald-400">•</span>
            <span className="hidden md:inline-block text-emerald-100/80">
              Trusted by 1,200+ Dairy Cooperatives & Progressive Bovine Farms
            </span>
          </div>
          <div className="flex items-center gap-4 text-emerald-100">
            <a
              href="mailto:vetkindinfo@gmail.com"
              className="flex items-center gap-1.5 hover:text-white transition-colors"
            >
              <Mail className="w-3 h-3 text-emerald-300" />
              <span>vetkindinfo@gmail.com</span>
            </a>
            <span className="text-emerald-500">•</span>
            <span className="flex items-center gap-1.5 font-semibold text-emerald-200">
              <Phone className="w-3 h-3 text-amber-400" />
              Toll-Free Helpline: 1800-VET-KIND
            </span>
          </div>
        </div>
      </div>

      {/* Main Navigation */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-18 flex items-center justify-between">
        <Link href="/vetkind" className="flex items-center gap-3 group">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-600 to-teal-800 flex items-center justify-center text-white shadow-md shadow-emerald-900/10 group-hover:scale-105 transition-transform">
            <Stethoscope className="w-6 h-6 text-emerald-100" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xl font-black tracking-tight text-slate-900">
                Vet<span className="text-emerald-700">Kind</span>
              </span>
              <Badge className="bg-emerald-50 text-emerald-800 border-emerald-200 text-[10px] font-semibold px-1.5 py-0">
                ANIMAL HEALTH INDIA
              </Badge>
            </div>
            <p className="text-[11px] text-slate-500 font-medium">
              Veterinary Therapeutics & Dairy Nutrition Solutions
            </p>
          </div>
        </Link>

        {/* Desktop Links */}
        <nav className="hidden md:flex items-center gap-6 text-sm font-semibold text-slate-700">
          <Link
            href="/vetkind"
            className="hover:text-emerald-700 transition-colors py-2 flex items-center gap-1.5"
          >
            <Sparkles className="w-4 h-4 text-emerald-600" />
            Products Catalogue
          </Link>
          <Link
            href="/vetkind/dealers"
            className="hover:text-emerald-700 transition-colors py-2 flex items-center gap-1.5"
          >
            <Store className="w-4 h-4 text-emerald-600" />
            Dealers & Stockists
          </Link>
          <Link
            href="/vetkind#clinical-advisory"
            className="hover:text-emerald-700 transition-colors py-2"
          >
            Dairy Solutions
          </Link>
          <Link
            href="/vetkind#about-vetkind"
            className="hover:text-emerald-700 transition-colors py-2"
          >
            About Us
          </Link>
        </nav>

        {/* Action Buttons */}
        <div className="flex items-center gap-3">
          <Link href="/vetkind/dealers#apply">
            <Button
              variant="outline"
              size="sm"
              className="border-emerald-300 text-emerald-800 hover:bg-emerald-50 font-semibold hidden sm:inline-flex"
            >
              Distributor Enquiries
            </Button>
          </Link>
          <Link href="/vetkind#enquiry">
            <Button
              size="sm"
              className="bg-emerald-700 hover:bg-emerald-800 text-white font-semibold shadow-xs"
            >
              Consult Technical Team
            </Button>
          </Link>
        </div>
      </div>
    </header>
  );
}
