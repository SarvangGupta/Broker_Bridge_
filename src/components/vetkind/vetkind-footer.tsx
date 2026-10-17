import React from 'react';
import Link from 'next/link';
import { Stethoscope, ShieldCheck, Mail, MapPin, Phone, Award } from 'lucide-react';

export function VetKindFooter() {
  return (
    <footer className="bg-slate-900 text-slate-300 border-t border-slate-800">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-14">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10">
          {/* Brand Info */}
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-emerald-600 flex items-center justify-center text-white">
                <Stethoscope className="w-5 h-5 text-white" />
              </div>
              <span className="text-xl font-black text-white tracking-tight">
                Vet<span className="text-emerald-400">Kind</span>
              </span>
            </div>
            <p className="text-sm text-slate-400 leading-relaxed">
              VetKind Animal Health India is committed to delivering scientifically validated,
              chelated veterinary therapeutics and dairy herd health innovations to empower veterinarians,
              cooperatives, and dairy farmers.
            </p>
            <div className="flex items-center gap-2 text-xs text-emerald-400 font-medium">
              <ShieldCheck className="w-4 h-4" />
              <span>Certified Drug & Feed Supplement Standards</span>
            </div>
          </div>

          {/* Quick Links */}
          <div>
            <h4 className="text-sm font-bold text-white uppercase tracking-wider mb-4">
              Veterinary Portfolio
            </h4>
            <ul className="space-y-2.5 text-sm">
              <li>
                <Link href="/vetkind?category=nutritional-supplements" className="hover:text-emerald-400 transition-colors">
                  Nutritional & Mineral Supplements
                </Link>
              </li>
              <li>
                <Link href="/vetkind?category=dairy-hygiene" className="hover:text-emerald-400 transition-colors">
                  Dairy Hygiene & Teat Care
                </Link>
              </li>
              <li>
                <Link href="/vetkind?category=digestives-rumen" className="hover:text-emerald-400 transition-colors">
                  Digestives & Rumen Buffers
                </Link>
              </li>
              <li>
                <Link href="/vetkind?category=liver-tonics" className="hover:text-emerald-400 transition-colors">
                  Liver Tonics & Metabolic Energizers
                </Link>
              </li>
              <li>
                <Link href="/vetkind?category=reproduction-fertility" className="hover:text-emerald-400 transition-colors">
                  Reproduction & Fertility Enhancers
                </Link>
              </li>
            </ul>
          </div>

          {/* Corporate & Dealers */}
          <div>
            <h4 className="text-sm font-bold text-white uppercase tracking-wider mb-4">
              Network & Programs
            </h4>
            <ul className="space-y-2.5 text-sm">
              <li>
                <Link href="/vetkind/dealers" className="hover:text-emerald-400 transition-colors">
                  Authorized Stockist Locator
                </Link>
              </li>
              <li>
                <Link href="/vetkind/dealers#apply" className="hover:text-emerald-400 transition-colors">
                  Become an Exclusive Territory Dealer
                </Link>
              </li>
              <li>
                <Link href="/vetkind#enquiry" className="hover:text-emerald-400 transition-colors">
                  Dairy Cooperative Technical Supply
                </Link>
              </li>
              <li>
                <Link href="/vetkind#clinical-advisory" className="hover:text-emerald-400 transition-colors">
                  Veterinary Advisory Protocol
                </Link>
              </li>
            </ul>
          </div>

          {/* Contact Details */}
          <div>
            <h4 className="text-sm font-bold text-white uppercase tracking-wider mb-4">
              Contact & Technical Support
            </h4>
            <ul className="space-y-3 text-sm text-slate-400">
              <li className="flex items-start gap-2.5">
                <MapPin className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                <span>
                  VetKind Animal Health India Headquarters, Agro-Veterinary Complex, Sector 18,
                  Haryana & National Dairy Hub, India
                </span>
              </li>
              <li className="flex items-center gap-2.5">
                <Mail className="w-4 h-4 text-emerald-400 shrink-0" />
                <a href="mailto:vetkindinfo@gmail.com" className="hover:text-white transition-colors">
                  vetkindinfo@gmail.com
                </a>
              </li>
              <li className="flex items-center gap-2.5">
                <Phone className="w-4 h-4 text-emerald-400 shrink-0" />
                <span className="font-semibold text-white">1800-VET-KIND (Toll Free)</span>
              </li>
              <li className="flex items-center gap-2.5">
                <Award className="w-4 h-4 text-amber-400 shrink-0" />
                <span className="text-xs text-slate-300">Govt. Registered Feed Supplement Manufacturer</span>
              </li>
            </ul>
          </div>
        </div>

        {/* Bottom Disclaimer */}
        <div className="mt-12 pt-8 border-t border-slate-800 text-xs text-slate-500 flex flex-col md:flex-row justify-between items-center gap-4">
          <p>
            © {new Date().getFullYear()} VetKind Animal Health India. All rights reserved. For veterinary and animal health use only.
          </p>
          <div className="flex gap-6 text-xs text-slate-400">
            <span>GMP Compliant</span>
            <span>Zero Withdrawal Residues</span>
            <span>Technical Advisory Backed</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
