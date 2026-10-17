import React from 'react';
import Link from 'next/link';
import {
  Building2,
  MapPin,
  User,
  ShieldCheck,
  FileText,
  Phone,
  Mail,
  ArrowLeft,
  Award,
  Lock,
  Building,
  CheckCircle2,
} from 'lucide-react';
import { getFullBuyerProfileDetailsAction } from '@/src/server/actions/company-actions';
import { KycStatusBadge } from '@/src/components/shared/kyc-status-badge';
import { PwaInstallCard } from '@/src/components/pwa/pwa-install-card';


export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function BuyerProfilePage() {
  const profileRes = await getFullBuyerProfileDetailsAction();

  if (!profileRes.success || !profileRes.data) {
    return (
      <div className="min-h-screen bg-[#F8FAFC] dark:bg-slate-950 p-4 sm:p-8 flex items-center justify-center">
        <div className="max-w-md w-full bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6 text-center shadow-sm">
          <div className="w-12 h-12 rounded-full bg-rose-100 dark:bg-rose-950/50 text-rose-600 dark:text-rose-400 mx-auto flex items-center justify-center mb-4">
            <Building2 className="w-6 h-6" />
          </div>
          <h2 className="text-lg font-bold text-slate-900 dark:text-slate-100">
            Profile Unavailable
          </h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-2">
            {profileRes.error || 'Failed to load organization profile details.'}
          </p>
          <Link
            href="/buyer"
            className="inline-flex items-center justify-center gap-2 mt-6 px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-200 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-lg transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            Return to Dashboard
          </Link>
        </div>
      </div>
    );
  }

  const { company, user } = profileRes.data;

  return (
    <div className="min-h-screen bg-[#F8FAFC] dark:bg-slate-950 text-slate-900 dark:text-slate-100 w-full overflow-x-hidden">
      {/* Top Sticky Navigation Header */}
      <div className="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 sticky top-0 z-30 px-4 sm:px-8 py-3.5 shadow-xs">
        <div className="max-w-5xl mx-auto flex items-center justify-between gap-3">
          <div className="flex items-center gap-3 min-w-0">
            <Link
              href="/buyer"
              className="p-1.5 text-slate-500 hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-100 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-lg transition-colors shrink-0"
              title="Back to Dashboard"
            >
              <ArrowLeft className="w-4 h-4 sm:w-5 sm:h-5" />
            </Link>
            <div className="min-w-0">
              <h1 className="text-base sm:text-lg font-bold truncate tracking-tight text-slate-900 dark:text-slate-100">
                Organization Profile & KYC
              </h1>
              <p className="text-xs text-slate-500 dark:text-slate-400 truncate hidden sm:block">
                Read-only buyer enterprise credentials & verified delivery locations
              </p>
            </div>
          </div>
          <KycStatusBadge
            isVerified={company.isVerified}
            status={company.onboardingStatus}
            size="sm"
          />
        </div>
      </div>

      {/* Main Responsive Body Container */}
      <main className="max-w-5xl mx-auto p-4 sm:p-6 sm:py-8 space-y-6">
        {/* Banner Alert for Verification Status */}
        <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-4 sm:p-6 shadow-sm flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div className="flex items-start gap-3.5">
            <div className="p-3 rounded-xl bg-blue-50 dark:bg-blue-950/50 text-blue-600 dark:text-blue-400 shrink-0">
              <Building2 className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <h2 className="text-lg font-bold text-slate-900 dark:text-slate-100">
                  {company.name}
                </h2>
                <KycStatusBadge
                  isVerified={company.isVerified}
                  status={company.onboardingStatus}
                  size="sm"
                />
              </div>
              <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
                Multi-Tenant Organization ID:{' '}
                <span className="font-mono text-slate-700 dark:text-slate-300">
                  {company.id}
                </span>
              </p>
            </div>
          </div>
          <div className="w-full sm:w-auto flex items-center justify-between sm:justify-end gap-3 pt-3 sm:pt-0 border-t sm:border-t-0 border-slate-100 dark:border-slate-800 shrink-0">
            <div className="text-left sm:text-right">
              <span className="text-xs text-slate-400 dark:text-slate-500 block uppercase font-medium">
                Trust Rating
              </span>
              <span className="text-sm font-bold text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                <Award className="w-4 h-4 inline" />
                {company.trustScore} / 100
              </span>
            </div>
          </div>
        </div>

        {/* 3-Column Grid for Sections */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Section 1: Company Overview */}
          <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-5 sm:p-6 shadow-sm space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="p-2 rounded-lg bg-emerald-50 dark:bg-emerald-950/50 text-emerald-600 dark:text-emerald-400">
                  <Building className="w-4 h-4" />
                </div>
                <h3 className="text-base font-semibold text-slate-900 dark:text-slate-100">
                  Company Overview
                </h3>
              </div>
              <span className="text-xs font-mono px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400">
                Read-Only
              </span>
            </div>

            <div className="space-y-3.5 text-sm">
              <div className="flex flex-col gap-1">
                <span className="text-xs text-slate-400 dark:text-slate-500 font-medium uppercase tracking-wider">
                  Registered Legal Name
                </span>
                <span className="font-medium text-slate-800 dark:text-slate-200">
                  {company.name}
                </span>
              </div>

              <div className="flex flex-col gap-1">
                <span className="text-xs text-slate-400 dark:text-slate-500 font-medium uppercase tracking-wider">
                  GSTIN / Tax Identification
                </span>
                {company.gst ? (
                  <span className="font-mono font-medium text-slate-900 dark:text-slate-100 bg-slate-50 dark:bg-slate-800/60 px-2.5 py-1.5 rounded-md border border-slate-200/80 dark:border-slate-700/80 w-fit">
                    {company.gst}
                  </span>
                ) : (
                  <span className="text-slate-400 italic text-xs">
                    Not Provided
                  </span>
                )}
              </div>

              <div className="flex flex-col gap-1">
                <span className="text-xs text-slate-400 dark:text-slate-500 font-medium uppercase tracking-wider">
                  Business Entity Type
                </span>
                <span className="font-medium text-slate-800 dark:text-slate-200">
                  {company.businessTypeName || 'Commercial Commodity Buyer'}
                </span>
              </div>

              <div className="flex flex-col gap-1 pt-2">
                <span className="text-xs text-slate-400 dark:text-slate-500 font-medium uppercase tracking-wider">
                  Platform Verification Status
                </span>
                <div className="pt-1">
                  <KycStatusBadge
                    isVerified={company.isVerified}
                    status={company.onboardingStatus}
                  />
                </div>
              </div>
            </div>
          </section>

          {/* Section 2: Primary Delivery Location */}
          <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-5 sm:p-6 shadow-sm space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="p-2 rounded-lg bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 dark:text-indigo-400">
                  <MapPin className="w-4 h-4" />
                </div>
                <h3 className="text-base font-semibold text-slate-900 dark:text-slate-100">
                  Primary Delivery Location
                </h3>
              </div>
              <span className="text-xs font-mono px-2 py-0.5 rounded bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-400">
                Master Data
              </span>
            </div>

            <div className="space-y-3.5 text-sm">
              <div className="grid grid-cols-2 gap-4">
                <div className="flex flex-col gap-1">
                  <span className="text-xs text-slate-400 dark:text-slate-500 font-medium uppercase tracking-wider">
                    State / Jurisdiction
                  </span>
                  <span className="font-medium text-slate-800 dark:text-slate-200">
                    {company.stateName || 'Not Configured'}
                  </span>
                </div>

                <div className="flex flex-col gap-1">
                  <span className="text-xs text-slate-400 dark:text-slate-500 font-medium uppercase tracking-wider">
                    District / Region
                  </span>
                  <span className="font-medium text-slate-800 dark:text-slate-200">
                    {company.districtName || 'Not Configured'}
                  </span>
                </div>
              </div>

              <div className="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200/60 dark:border-slate-700/60 space-y-1.5 mt-2">
                <span className="text-xs font-semibold text-slate-700 dark:text-slate-300 flex items-center gap-1.5">
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
                  Primary Logistics Destination
                </span>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  All procurement requirements and transport dispatches for this organization default to your primary registered state and district.
                </p>
              </div>
            </div>
          </section>

          {/* Section 3: User Details (BUYER_ADMIN) */}
          <section className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-5 sm:p-6 shadow-sm space-y-4 md:col-span-2">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
              <div className="flex items-center gap-2.5">
                <div className="p-2 rounded-lg bg-amber-50 dark:bg-amber-950/50 text-amber-600 dark:text-amber-400">
                  <User className="w-4 h-4" />
                </div>
                <h3 className="text-base font-semibold text-slate-900 dark:text-slate-100">
                  Authorized Buyer Administrator
                </h3>
              </div>
              <span className="text-xs font-mono px-2.5 py-0.5 rounded-full bg-amber-500/10 text-amber-700 dark:text-amber-400 font-semibold border border-amber-500/20">
                BUYER_ADMIN
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
              <div className="flex flex-col gap-1 p-3 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200/50 dark:border-slate-800">
                <span className="text-xs text-slate-400 dark:text-slate-500 font-medium uppercase tracking-wider flex items-center gap-1">
                  <User className="w-3.5 h-3.5" />
                  Full Name
                </span>
                <span className="font-semibold text-slate-900 dark:text-slate-100">
                  {user.name}
                </span>
              </div>

              <div className="flex flex-col gap-1 p-3 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200/50 dark:border-slate-800">
                <span className="text-xs text-slate-400 dark:text-slate-500 font-medium uppercase tracking-wider flex items-center gap-1">
                  <Mail className="w-3.5 h-3.5" />
                  Email Address
                </span>
                <span className="font-medium text-slate-800 dark:text-slate-200 truncate">
                  {user.email || 'Not Provided'}
                </span>
              </div>

              <div className="flex flex-col gap-1 p-3 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200/50 dark:border-slate-800">
                <span className="text-xs text-slate-400 dark:text-slate-500 font-medium uppercase tracking-wider flex items-center gap-1">
                  <Phone className="w-3.5 h-3.5" />
                  Registered Contact Phone
                </span>
                <span className="font-mono font-medium text-slate-800 dark:text-slate-200">
                  {user.mobile || 'Not Provided'}
                </span>
              </div>
            </div>

            <div className="flex items-center gap-2 pt-2 text-xs text-slate-500 dark:text-slate-400">
              <Lock className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <span>
                Single flat role model strictly enforced (`BUYER_ADMIN`). Protected by server-side session authentication.
              </span>
            </div>
          </section>

          {/* Section 4: Progressive Web App / Mobile Installation */}
          <section className="md:col-span-2">
            <PwaInstallCard role="BUYER" />
          </section>
        </div>
      </main>
    </div>
  );
}
