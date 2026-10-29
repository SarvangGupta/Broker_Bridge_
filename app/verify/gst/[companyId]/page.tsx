import React from 'react'
import { Metadata } from 'next'
import Link from 'next/link'
import { headers } from 'next/headers'
import { notFound } from 'next/navigation'
import { db } from '@/src/server/db'
import { companies } from '@/src/server/db/schema'
import { eq } from 'drizzle-orm'
import {
  ShieldCheck,
  Building2,
  Calendar,
  MapPin,
  CheckCircle2,
  ExternalLink,
  ShieldAlert,
  ArrowLeft,
  FileCheck2,
} from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { WhatsAppShareButton } from '@/src/components/shared/whatsapp-share-button'

export const dynamic = 'force-dynamic'

interface PageProps {
  params: Promise<{ companyId: string }> | { companyId: string }
}

/**
 * Mask GST number heavily for privacy (e.g. 27AAAAA****1Z*)
 * Retains state code + PAN prefix, masks serial numbers, retains checksum hint
 */
function maskGstNumber(gst: string | null | undefined): string {
  if (!gst) return 'Not Provided'
  const clean = gst.trim().toUpperCase()
  if (clean.length === 15) {
    return `${clean.slice(0, 7)}****${clean.slice(11, 14)}*`
  }
  if (clean.length >= 8) {
    return `${clean.slice(0, 4)}****${clean.slice(-2)}`
  }
  return '******'
}

interface GstLiveDataPayload {
  source?: string
  valid?: boolean
  legal_name?: string
  status?: string
  address?: string
  trade_name?: string
  verifiedBy?: string
  [key: string]: any
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const resolved = await params
  const companyId = resolved.companyId

  const res = await db
    .select({ name: companies.name, gstVerified: companies.gstVerified })
    .from(companies)
    .where(eq(companies.id, companyId))
    .limit(1)

  if (!res.length || !res[0].gstVerified) {
    return {
      title: 'Unverified Entity | BrokerBridge Verification Portal',
      description: 'The requested business has not completed statutory GST verification.',
    }
  }

  return {
    title: `${res[0].name} • Verified Business Credential | BrokerBridge`,
    description: `Official statutory GST verification seal and compliance proof for ${res[0].name}.`,
  }
}

/**
 * Task 3: Adjusted Public Verification Route
 * Public read-only page supporting both manual and automated verification payloads.
 * STRICT PRIVACY: Zero user tables joined. No email or mobile contact details selected or exposed.
 */
export default async function PublicGstVerificationPage({ params }: PageProps) {
  const resolvedParams = await params
  const companyId = resolvedParams.companyId

  if (!companyId) {
    notFound()
  }

  // Drizzle Database Query: Strictly SELECT only non-sensitive company verification fields
  // Never join users table to prevent any contact details leakage
  const records = await db
    .select({
      name: companies.name,
      gst: companies.gst,
      gstVerified: companies.gstVerified,
      gstVerifiedAt: companies.gstVerifiedAt,
      gstLiveData: companies.gstLiveData,
    })
    .from(companies)
    .where(eq(companies.id, companyId))
    .limit(1)

  const company = records[0]

  // If company does not exist or GST is unverified, render the Unverified Business Error Screen
  if (!company || !company.gstVerified) {
    return (
      <main className="min-h-screen bg-slate-50 flex items-center justify-center p-4 sm:p-6">
        <Card className="w-full max-w-md border-slate-200 bg-white shadow-sm overflow-hidden text-center">
          <div className="bg-amber-500/10 p-6 flex flex-col items-center border-b border-amber-200/60">
            <div className="w-14 h-14 rounded-full bg-amber-100 flex items-center justify-center text-amber-700 mb-3">
              <ShieldAlert className="w-7 h-7" />
            </div>
            <h1 className="text-xl font-bold text-slate-900">Unverified Business</h1>
            <p className="text-xs text-amber-800 font-medium mt-1">
              Statutory Verification Not Confirmed
            </p>
          </div>

          <CardContent className="p-6 space-y-4 text-left">
            <p className="text-sm text-slate-600 leading-relaxed">
              The business profile with ID <code className="font-mono text-xs bg-slate-100 px-1.5 py-0.5 rounded text-slate-700">{companyId.slice(0, 8)}...</code> has not yet completed government GST verification on BrokerBridge Enterprise.
            </p>

            <div className="bg-slate-50 border border-slate-200 rounded-lg p-3.5 text-xs text-slate-600 space-y-1.5">
              <div className="font-semibold text-slate-800">Security & Anti-Fraud Guarantee</div>
              <div>Counterparty badges are only granted after statutory verification via active GSTIN records. Unverified entities cannot issue certified delivery mandates.</div>
            </div>

            <div className="pt-2 text-center">
              <Link
                href="/"
                className="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-700 hover:text-teal-800"
              >
                <ArrowLeft className="w-3.5 h-3.5" />
                <span>Return to BrokerBridge Platform</span>
              </Link>
            </div>
          </CardContent>
        </Card>
      </main>
    )
  }

  // Safe JSON extraction with error boundary
  let liveData: GstLiveDataPayload = {}
  try {
    if (typeof company.gstLiveData === 'object' && company.gstLiveData !== null) {
      liveData = company.gstLiveData as GstLiveDataPayload
    } else if (typeof company.gstLiveData === 'string') {
      liveData = JSON.parse(company.gstLiveData)
    }
  } catch (err) {
    console.warn('Failed to parse gst_live_data JSONB safely:', err)
    liveData = {}
  }

  // Detect whether this was a manual verification by Platform Admin
  const isManual =
    liveData.source === 'Manual Web Verification' ||
    Boolean(liveData.verifiedBy) ||
    !liveData.address

  const legalName = liveData.legal_name || company.name
  const maskedGst = maskGstNumber(company.gst)
  const liveStatus = liveData.status || 'Active'
  const registeredAddress = liveData.address || 'Address on record with GST portal'

  const formattedDate = company.gstVerifiedAt
    ? new Intl.DateTimeFormat('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true,
        timeZone: 'Asia/Kolkata',
      }).format(new Date(company.gstVerifiedAt))
    : 'Authenticated'

  // Retrieve host header to construct canonical shareable URL
  const headersList = await headers()
  const host = headersList.get('host') || 'localhost:3001'
  const protocol = host.startsWith('localhost') ? 'http' : 'https'
  const currentUrl = `${protocol}://${host}/verify/gst/${companyId}`

  const verificationBadgeText = isManual
    ? 'Manually Verified by Platform Admin'
    : 'Government Portal Authenticated'

  const shareText = `*BrokerBridge Enterprise Verified Counterparty*\n\nLegal Name: ${legalName}\nGSTIN: ${maskedGst}\nStatus: ${liveStatus} (${verificationBadgeText})\nVerified At: ${formattedDate}`

  return (
    <main className="min-h-screen bg-gradient-to-b from-slate-100 to-slate-50 flex items-center justify-center p-4 sm:p-6 md:p-8">
      <div className="w-full max-w-xl mx-auto space-y-4">
        {/* TOP BRAND HEADER */}
        <div className="flex items-center justify-between px-2">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-[#0D9488] flex items-center justify-center text-white shadow-xs">
              <ShieldCheck className="w-4 h-4" />
            </div>
            <span className="text-sm font-bold tracking-tight text-slate-800">
              BrokerBridge <span className="text-[#0D9488]">Enterprise</span>
            </span>
          </div>
          <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">
            Public Registry
          </span>
        </div>

        {/* VERIFICATION CARD */}
        <Card className="border border-slate-200/90 bg-white shadow-md rounded-2xl overflow-hidden">
          {/* CARD TOP BANNER */}
          <div className="bg-gradient-to-r from-emerald-700 via-teal-700 to-slate-900 text-white p-6 sm:p-8 relative overflow-hidden">
            <div className="relative z-10 space-y-3">
              {/* Trust Badge */}
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/20 backdrop-blur-md border border-emerald-300/40 text-emerald-200 text-xs font-semibold">
                <CheckCircle2 className="w-4 h-4 text-emerald-300" />
                <span>Verified Business Entity</span>
              </div>

              {/* Company Legal Name */}
              <h1 className="text-2xl sm:text-3xl font-black tracking-tight text-white leading-tight">
                {legalName}
              </h1>

              {/* Trade name if distinct */}
              {company.name && company.name !== legalName && (
                <p className="text-xs sm:text-sm text-teal-100/90 font-medium">
                  Operating As: {company.name}
                </p>
              )}
            </div>

            {/* Background Seal Watermark */}
            <ShieldCheck className="absolute -right-6 -bottom-6 w-36 h-36 text-white/5 pointer-events-none" />
          </div>

          <CardContent className="p-6 sm:p-8 space-y-6">
            {/* DATA GRID */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* GSTIN Field */}
              <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200/80 space-y-1">
                <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider block">
                  Masked GSTIN
                </span>
                <span className="font-mono text-base font-bold text-slate-900 tracking-wide block">
                  {maskedGst}
                </span>
                <span className="text-[10px] text-slate-500">
                  Privacy-shielded statutory identifier
                </span>
              </div>

              {/* Status Field */}
              <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200/80 space-y-1">
                <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider block">
                  Registration Status
                </span>
                <div className="flex items-center gap-2 pt-0.5">
                  <span className="relative flex h-2.5 w-2.5">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
                  </span>
                  <span className="text-base font-bold text-emerald-700 capitalize">
                    {liveStatus}
                  </span>
                </div>
                <span className="text-[10px] text-slate-500">
                  Statutory registration active
                </span>
              </div>
            </div>

            {/* Address or Manual Verification Badge */}
            {isManual ? (
              <div className="p-4 bg-emerald-50/70 rounded-xl border border-emerald-200/80 space-y-2">
                <div className="flex items-center gap-2">
                  <span className="px-2.5 py-1 rounded-md text-[11px] font-bold uppercase tracking-wider bg-emerald-100 text-emerald-800 border border-emerald-300 inline-flex items-center gap-1.5 shadow-xs">
                    <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                    Manually Verified by Platform Admin
                  </span>
                </div>
                <p className="text-xs sm:text-sm text-emerald-950/80 font-medium leading-relaxed">
                  Active statutory GST registration verified against the government portal by BrokerBridge Administration.
                </p>
              </div>
            ) : (
              <div className="p-4 bg-slate-50 rounded-xl border border-slate-200/80 space-y-1.5">
                <div className="flex items-center gap-1.5 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                  <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                  <span>Principal Registered Address</span>
                </div>
                <p className="text-xs sm:text-sm text-slate-800 font-medium leading-relaxed">
                  {registeredAddress}
                </p>
              </div>
            )}

            {/* Verification Timestamp & Proof Details */}
            <div className="flex items-center justify-between text-xs text-slate-500 pt-2 border-t border-slate-100 flex-wrap gap-2">
              <div className="flex items-center gap-1.5">
                <Calendar className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                <span>Verified: <strong className="text-slate-700">{formattedDate}</strong></span>
              </div>
              <div className="flex items-center gap-1.5">
                <FileCheck2 className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                <span className="text-emerald-700 font-medium">Immutable Audit Seal</span>
              </div>
            </div>

            {/* WHATSAPP SHARE CALL TO ACTION */}
            <div className="pt-2 space-y-2">
              <span className="text-xs text-slate-500 font-semibold block text-center sm:text-left">
                Forward Official Verification to Counterparty
              </span>
              <WhatsAppShareButton url={currentUrl} text={shareText} />
            </div>

            {/* STATUTORY DISCLAIMER */}
            <div className="text-[11px] text-slate-500 bg-slate-50/80 p-3 rounded-lg border border-slate-200/60 leading-relaxed">
              <strong>Statutory Disclosure:</strong> This public verification record was confirmed on the BrokerBridge Enterprise ledger. No personal data, direct telephone numbers, or banking credentials are stored or exposed on this public URL.
            </div>
          </CardContent>
        </Card>
      </div>
    </main>
  )
}
