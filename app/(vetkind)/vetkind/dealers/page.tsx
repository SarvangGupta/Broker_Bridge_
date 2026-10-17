import React from 'react';
import Link from 'next/link';
import { getVetKindDealersAction } from '@/src/server/actions/vetkind-actions';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Store,
  MapPin,
  Phone,
  Mail,
  ShieldCheck,
  Award,
  ArrowLeft,
  Building,
  CheckCircle2,
} from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function VetKindDealersPage() {
  const res = await getVetKindDealersAction();
  const dealers = res.data || [];

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-12">
      {/* Back button */}
      <div>
        <Link
          href="/vetkind"
          className="inline-flex items-center text-xs font-semibold text-emerald-800 hover:text-emerald-950 transition-colors"
        >
          <ArrowLeft className="w-4 h-4 mr-1.5" />
          Back to VetKind Home
        </Link>
      </div>

      {/* Header Banner */}
      <div className="bg-gradient-to-r from-emerald-950 via-slate-900 to-teal-950 rounded-3xl p-8 sm:p-12 text-white space-y-4">
        <div className="inline-flex items-center gap-2 bg-emerald-900/60 border border-emerald-500/30 px-3 py-1 rounded-full text-emerald-300 text-xs font-semibold">
          <Award className="w-3.5 h-3.5 text-amber-400" />
          <span>VETKIND NATIONWIDE DISTRIBUTION NETWORK</span>
        </div>
        <h1 className="text-3xl sm:text-4xl font-black tracking-tight">
          Authorized Dealers & Stockists Network
        </h1>
        <p className="text-sm sm:text-base text-slate-300 max-w-2xl leading-relaxed">
          Connect directly with certified VetKind pharmaceutical and feed supplement distributors across the premier dairy belts of Northern, Western, and Central India.
        </p>
      </div>

      {/* Dealers Grid */}
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-bold text-slate-900 flex items-center gap-2">
            <Store className="w-5 h-5 text-emerald-700" />
            Verified Stockists ({dealers.length})
          </h2>
          <span className="text-xs text-slate-500 font-medium">
            Active Regional Hubs
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-2 gap-6">
          {dealers.map((dealer) => (
            <Card
              key={dealer.id}
              className="border border-slate-200/90 hover:border-emerald-500/40 rounded-2xl shadow-xs transition-all p-6 space-y-4 bg-white"
            >
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="font-mono text-xs text-slate-400">{dealer.dealerCode}</span>
                    <Badge className="bg-emerald-100 text-emerald-800 border-emerald-200 text-[10px]">
                      {dealer.verificationStatus}
                    </Badge>
                  </div>
                  <h3 className="text-lg font-bold text-slate-900">
                    {dealer.businessName}
                  </h3>
                </div>
                <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center shrink-0">
                  <Building className="w-5 h-5" />
                </div>
              </div>

              <div className="space-y-2.5 text-xs text-slate-600 border-t border-slate-100 pt-4">
                <div className="flex items-center gap-2 text-slate-800 font-medium">
                  <MapPin className="w-4 h-4 text-emerald-600 shrink-0" />
                  <span>
                    {dealer.district}, {dealer.state}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <Phone className="w-4 h-4 text-slate-400 shrink-0" />
                  <span className="font-semibold text-slate-900">{dealer.mobile}</span>
                  <span className="text-slate-400">({dealer.contactPerson})</span>
                </div>
                {dealer.email && (
                  <div className="flex items-center gap-2">
                    <Mail className="w-4 h-4 text-slate-400 shrink-0" />
                    <span>{dealer.email}</span>
                  </div>
                )}
                <div className="pt-2 border-t border-slate-100/80">
                  <span className="font-semibold text-slate-700">Territory Coverage: </span>
                  <span className="text-emerald-800 font-medium">{dealer.territoryCovered}</span>
                </div>
              </div>
            </Card>
          ))}
        </div>
      </div>

      {/* Dealership Application CTA */}
      <div id="apply" className="bg-slate-900 text-white rounded-3xl p-8 sm:p-12 space-y-6">
        <div className="max-w-2xl space-y-3">
          <Badge className="bg-emerald-800 text-emerald-200 border-emerald-700">
            GROW WITH VETKIND
          </Badge>
          <h2 className="text-2xl sm:text-3xl font-black">
            Apply to Become an Exclusive Territory Distributor
          </h2>
          <p className="text-sm text-slate-300 leading-relaxed">
            We are expanding our authorized stockist network in high-density dairy clusters across Rajasthan, Uttar Pradesh, Madhya Pradesh, and South India. Enjoy competitive dealer margins, dedicated veterinary marketing support, and clinical sample allotments.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs font-semibold text-emerald-300 pt-2">
          <div className="flex items-center gap-2 bg-slate-800/80 p-3 rounded-xl border border-slate-700">
            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
            <span>Guaranteed Territory Exclusivity</span>
          </div>
          <div className="flex items-center gap-2 bg-slate-800/80 p-3 rounded-xl border border-slate-700">
            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
            <span>Direct Veterinary Rep Field Support</span>
          </div>
          <div className="flex items-center gap-2 bg-slate-800/80 p-3 rounded-xl border border-slate-700">
            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" />
            <span>Attractive Commercial Margins</span>
          </div>
        </div>

        <div className="pt-2">
          <a href="mailto:vetkindinfo@gmail.com?subject=Application for VetKind Territory Dealership">
            <Button size="lg" className="bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-sm">
              <Mail className="w-4 h-4 mr-2" />
              Apply via Email (vetkindinfo@gmail.com)
            </Button>
          </a>
        </div>
      </div>
    </div>
  );
}
