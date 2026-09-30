import React, { Suspense } from "react";
import Link from "next/link";
import { ArrowLeft, Handshake, ShieldCheck, Loader2 } from "lucide-react";
import { getSellerBrokerRequestsAction } from "@/src/server/actions/broker-request-actions";
import { getCompanyProfile } from "@/src/server/actions/company-actions";
import { getFullBuyerProfileDetailsAction } from "@/src/server/actions/user-profile-actions";
import { BrokerRequestInbox } from "@/src/components/dashboard/broker-request-inbox";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export const dynamic = "force-dynamic";

export default async function SellerBrokerRequestsPage() {
  const [requestsRes, profileRes, fullProfileRes] = await Promise.all([
    getSellerBrokerRequestsAction(),
    getCompanyProfile(),
    getFullBuyerProfileDetailsAction(),
  ]);

  const requests = requestsRes.success && requestsRes.data ? requestsRes.data : [];

  return (
    <div className="min-h-screen bg-[#F8FAFC] font-sans antialiased">
      
      {/* TOP HEADER */}
      <header className="sticky top-0 z-30 bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-2xs">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Link
              href="/seller"
              className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-600 hover:text-slate-900 bg-slate-100 hover:bg-slate-200 px-3 py-2 rounded-xl transition-colors"
            >
              <ArrowLeft className="h-3.5 w-3.5" />
              <span>Back to Dashboard</span>
            </Link>

            <div className="hidden sm:flex items-center gap-2">
              <span className="text-slate-300">/</span>
              <span className="text-sm font-bold text-slate-900">Trade Offers</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <Badge variant="outline" className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs gap-1.5">
              <ShieldCheck className="h-3.5 w-3.5" />
              <span>Zero-Buyer Exposure Active</span>
            </Badge>
          </div>
        </div>
      </header>

      {/* MAIN CONTAINER */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        <Suspense fallback={
          <div className="flex items-center justify-center py-12">
            <Loader2 className="h-6 w-6 animate-spin text-emerald-600" />
          </div>
        }>
          <BrokerRequestInbox initialRequests={requests} />
        </Suspense>
      </main>
    </div>
  );
}
