'use client';

import React, { useState, useTransition } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  Handshake,
  FileText,
  Building2,
  CheckCircle2,
  Clock,
  AlertCircle,
  ArrowRight,
  ArrowLeft,
  Scale,
  Calendar,
  MapPin,
  ShieldCheck,
  AlertTriangle,
  Loader2,
  History,
  Sparkles,
  Ban,
  RefreshCw,
  Lock,
  Tag,
  Check,
  ExternalLink,
  Info,
} from 'lucide-react';
import { useLanguage } from '@/src/lib/i18n/language-context';
import type {
  BrokerDealDetail,
  DealVersionTimelineItem,
} from '@/src/server/actions/broker-deal-actions';
import {
  updateDealTermsAction,
  recordPartyConfirmationAction,
  finalizeBrokerDealAction,
  cancelDealAction,
} from '@/src/server/actions/broker-deal-actions';
import { toast } from 'sonner';

interface DealNegotiationWorkspaceProps {
  initialData: BrokerDealDetail;
  onRefresh?: () => void;
}

export function DealNegotiationWorkspace({
  initialData,
  onRefresh,
}: DealNegotiationWorkspaceProps) {
  const router = useRouter();
  const { t, language, formatNumber, formatCurrency } = useLanguage();
  const [data, setData] = useState<BrokerDealDetail>(initialData);
  const [isPending, startTransition] = useTransition();

  // Modals state
  const [isRevisionOpen, setIsRevisionOpen] = useState(false);
  const [isConfirmModalOpen, setIsConfirmModalOpen] = useState(false);
  const [confirmingParty, setConfirmingParty] = useState<'BUYER' | 'SELLER'>('BUYER');
  const [confirmNotes, setConfirmNotes] = useState('');
  const [isCancelModalOpen, setIsCancelModalOpen] = useState(false);
  const [cancelReason, setCancelReason] = useState('');
  const [cancelError, setCancelError] = useState<string | null>(null);

  // Terms revision form state
  const latestSnapshot = data.versions[0]?.snapshot || {};
  const [revisedPrice, setRevisedPrice] = useState(String(data.summary.agreedPrice || '52000'));
  const [revisedQuantity, setRevisedQuantity] = useState(String(data.summary.agreedQuantity || '100'));
  const [revisedPriceBasis, setRevisedPriceBasis] = useState(data.summary.priceBasis || 'FOR_DESTINATION');
  const [revisedDeliveryLocation, setRevisedDeliveryLocation] = useState(
    data.summary.deliveryLocation || 'Destination Mill'
  );
  const [revisedDeliveryDate, setRevisedDeliveryDate] = useState(
    data.summary.deliveryDate || new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0]
  );
  const [revisedDeliveryTerms, setRevisedDeliveryTerms] = useState(
    latestSnapshot.deliveryTerms || 'Ex-Warehouse / FOR'
  );
  const [revisedPaymentTerms, setRevisedPaymentTerms] = useState(
    latestSnapshot.paymentTerms || '100% Advance against Invoice / Bank Transfer'
  );
  const [revisedPackagingType, setRevisedPackagingType] = useState(
    latestSnapshot.packagingType || '50kg Jute Bags'
  );
  const [revisedBrokerRate, setRevisedBrokerRate] = useState(
    String(latestSnapshot.brokerCommissionRate ?? '250')
  );
  const [revisionReason, setRevisionReason] = useState('');
  const [revisionError, setRevisionError] = useState<string | null>(null);

  const isFinalized = data.deal.status === 'Finalized';
  const isCancelled = data.deal.status === 'Cancelled';
  const isEditable = !isFinalized && !isCancelled && !['In Fulfillment', 'Completed'].includes(data.deal.status);
  const canFinalize = data.confirmations.canFinalize;

  // 1. Submit Terms Revision
  const handleRevisionSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setRevisionError(null);

    const priceNum = Number(revisedPrice);
    const qtyNum = Number(revisedQuantity);

    if (isNaN(priceNum) || priceNum <= 0) {
      setRevisionError(language === 'hi' ? 'कृपया मान्य मूल्य दर्ज करें' : 'Please enter a valid price');
      return;
    }
    if (isNaN(qtyNum) || qtyNum <= 0) {
      setRevisionError(language === 'hi' ? 'कृपया मान्य मात्रा दर्ज करें' : 'Please enter a valid quantity');
      return;
    }

    startTransition(async () => {
      const res = await updateDealTermsAction({
        dealId: data.deal.id,
        expectedVersion: data.confirmations.latestVersionNumber,
        terms: {
          agreedPrice: priceNum,
          agreedQuantity: qtyNum,
          priceBasis: revisedPriceBasis,
          deliveryLocation: revisedDeliveryLocation.trim(),
          deliveryDate: revisedDeliveryDate,
          deliveryTerms: revisedDeliveryTerms.trim(),
          paymentTerms: revisedPaymentTerms.trim(),
          packagingType: revisedPackagingType.trim(),
          brokerCommissionRate: Number(revisedBrokerRate) || 0,
          reason: revisionReason.trim() || undefined,
        },
      });

      if (res.success) {
        toast.success(t('termsUpdatedSuccess'));
        toast.warning(t('valMaterialTermsChanged'), { duration: 5000 });
        setIsRevisionOpen(false);
        setRevisionReason('');
        router.refresh();
        if (onRefresh) onRefresh();
      } else {
        setRevisionError(res.error || 'Failed to update deal terms');
        toast.error(res.error || 'Failed to update deal terms');
      }
    });
  };

  // 2. Submit Party Confirmation
  const handleConfirmSubmit = () => {
    startTransition(async () => {
      const res = await recordPartyConfirmationAction({
        dealId: data.deal.id,
        party: confirmingParty,
        versionNumber: data.confirmations.latestVersionNumber,
        verificationNotes: confirmNotes.trim() || undefined,
      });

      if (res.success) {
        toast.success(t('confirmationRecordedSuccess'));
        setIsConfirmModalOpen(false);
        setConfirmNotes('');
        router.refresh();
        if (onRefresh) onRefresh();
      } else {
        toast.error(res.error || 'Failed to record confirmation');
      }
    });
  };

  // 3. Submit Finalization Gate
  const handleFinalizeDeal = () => {
    if (!canFinalize) {
      toast.error(t('valBothConfirmationsRequired'));
      return;
    }

    startTransition(async () => {
      const res = await finalizeBrokerDealAction(
        data.deal.id,
        data.confirmations.latestVersionNumber
      );

      if (res.success) {
        toast.success(
          language === 'hi'
            ? `सौदा सफलतापूर्वक अंतिम रूप दिया गया! बुकिंग: ${res.bookingReference}`
            : `Deal finalized successfully! Booking reference: ${res.bookingReference}`
        );
        router.refresh();
        if (onRefresh) onRefresh();
      } else {
        toast.error(res.error || 'Pre-flight finalization gate blocked');
      }
    });
  };

  // 4. Submit Cancellation
  const handleCancelSubmit = () => {
    if (!cancelReason || cancelReason.trim().length < 3) {
      setCancelError(language === 'hi' ? 'कारण कम से कम 3 वर्णों का होना चाहिए' : 'Reason must be at least 3 characters');
      return;
    }

    startTransition(async () => {
      const res = await cancelDealAction({
        dealId: data.deal.id,
        reason: cancelReason.trim(),
      });

      if (res.success) {
        toast.success(t('dealCancelledSuccess'));
        setIsCancelModalOpen(false);
        router.refresh();
        if (onRefresh) onRefresh();
      } else {
        setCancelError(res.error || 'Failed to cancel deal');
        toast.error(res.error || 'Failed to cancel deal');
      }
    });
  };

  // Helper status color
  const getStatusBadgeVariant = (status: string) => {
    switch (status) {
      case 'Draft':
        return 'bg-slate-100 text-slate-800 border-slate-300 dark:bg-slate-800 dark:text-slate-300';
      case 'Negotiation':
        return 'bg-amber-50 text-amber-800 border-amber-300 dark:bg-amber-950/40 dark:text-amber-300';
      case 'Awaiting Buyer Confirmation':
      case 'Awaiting Seller Confirmation':
        return 'bg-blue-50 text-blue-800 border-blue-300 dark:bg-blue-950/40 dark:text-blue-300';
      case 'Ready to Finalize':
        return 'bg-emerald-50 text-emerald-800 border-emerald-400 dark:bg-emerald-950/40 dark:text-emerald-300 shadow-xs ring-1 ring-emerald-400';
      case 'Finalized':
        return 'bg-teal-50 text-teal-800 border-teal-300 dark:bg-teal-950/40 dark:text-teal-300';
      case 'Cancelled':
        return 'bg-red-50 text-red-800 border-red-300 dark:bg-red-950/40 dark:text-red-300';
      default:
        return 'bg-slate-100 text-slate-700';
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Header Card */}
      <Card className="border-slate-200 dark:border-slate-800 shadow-sm">
        <CardContent className="p-4 sm:p-6 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex flex-wrap items-center gap-2">
                <Badge
                  variant="outline"
                  className={`text-xs uppercase font-bold px-2.5 py-0.5 ${getStatusBadgeVariant(
                    data.deal.status
                  )}`}
                >
                  {data.deal.status}
                </Badge>
                <Badge variant="secondary" className="text-xs font-mono">
                  Version {data.confirmations.latestVersionNumber}
                </Badge>
                {data.booking && (
                  <Badge className="bg-[#0D9488] text-white font-mono text-xs">
                    {data.booking.bookingReference}
                  </Badge>
                )}
                {data.summary.allocationReference && (
                  <Badge variant="outline" className="text-xs font-mono text-slate-600">
                    Alloc: {data.summary.allocationReference}
                  </Badge>
                )}
              </div>

              <h2 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white tracking-tight flex items-center gap-2">
                {data.summary.commodityName}
                {data.summary.gradeName && (
                  <span className="text-slate-500 text-base font-normal">
                    • {data.summary.gradeName}
                  </span>
                )}
              </h2>

              <p className="text-xs text-slate-500">
                Created: {new Date(data.deal.createdAt).toLocaleDateString()} • Ref: #{data.deal.id.slice(0, 8)}
              </p>
            </div>

            {/* Action Buttons Toolbar */}
            <div className="flex flex-wrap items-center gap-2 self-start sm:self-center">
              {isEditable && (
                <>
                  <Button
                    size="sm"
                    variant="outline"
                    className="h-8 text-xs font-semibold text-slate-700 border-slate-300 hover:bg-slate-50"
                    onClick={() => {
                      setRevisedPrice(String(data.summary.agreedPrice));
                      setRevisedQuantity(String(data.summary.agreedQuantity));
                      setIsRevisionOpen(true);
                    }}
                    disabled={isPending}
                  >
                    <RefreshCw className="w-3.5 h-3.5 mr-1 text-slate-500" />
                    {t('updateTerms')}
                  </Button>

                  <Button
                    size="sm"
                    variant="ghost"
                    className="h-8 text-xs font-semibold text-red-600 hover:text-red-700 hover:bg-red-50"
                    onClick={() => {
                      setCancelReason('');
                      setCancelError(null);
                      setIsCancelModalOpen(true);
                    }}
                    disabled={isPending}
                  >
                    <Ban className="w-3.5 h-3.5 mr-1" />
                    {t('cancelDeal')}
                  </Button>
                </>
              )}

              {canFinalize && !isFinalized && (
                <Button
                  size="sm"
                  className="h-8 text-xs font-bold bg-[#0D9488] hover:bg-[#0D9488]/90 text-white shadow-xs animate-pulse"
                  onClick={handleFinalizeDeal}
                  disabled={isPending}
                >
                  {isPending ? (
                    <Loader2 className="w-3.5 h-3.5 mr-1.5 animate-spin" />
                  ) : (
                    <ShieldCheck className="w-3.5 h-3.5 mr-1.5" />
                  )}
                  {t('finalizeDeal')}
                </Button>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Grid: Left Column Counterparties & Confirmation Tracker, Right Column Terms & Version History */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column (1 col): Dual Counterparty Confirmation Card */}
        <div className="space-y-6">
          <Card className="border-slate-200 dark:border-slate-800 shadow-sm">
            <CardHeader className="py-3 px-4 border-b border-slate-100 dark:border-slate-800">
              <CardTitle className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-[#0D9488]" />
                Dual Counterparty Confirmation
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4 space-y-4">
              {/* Buyer Confirmation Box */}
              <div
                className={`p-3.5 rounded-xl border text-xs space-y-2 transition-all ${
                  data.confirmations.buyerConfirmed
                    ? 'bg-emerald-50/70 border-emerald-200 dark:bg-emerald-950/30 dark:border-emerald-800'
                    : 'bg-slate-50 border-slate-200 dark:bg-slate-900/40 dark:border-slate-800'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className="font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
                    <Building2 className="w-4 h-4 text-blue-600" />
                    Buyer: {data.buyerCompany.name}
                  </span>
                  {data.confirmations.buyerConfirmed ? (
                    <Badge className="bg-emerald-600 text-white text-[10px] gap-1">
                      <Check className="w-3 h-3" />
                      Confirmed (v{data.confirmations.latestVersionNumber})
                    </Badge>
                  ) : (
                    <Badge variant="outline" className="text-[10px] text-amber-700 border-amber-300">
                      Pending
                    </Badge>
                  )}
                </div>

                {data.confirmations.buyerConfirmed ? (
                  <p className="text-[11px] text-emerald-800 dark:text-emerald-400">
                    Confirmed on {new Date(data.confirmations.buyerConfirmedAt!).toLocaleString()}
                    {data.confirmations.buyerNotes && ` — "${data.confirmations.buyerNotes}"`}
                  </p>
                ) : (
                  <p className="text-[11px] text-slate-500">
                    Awaiting buyer digital signature or broker verification of terms.
                  </p>
                )}

                {!data.confirmations.buyerConfirmed && isEditable && (
                  <Button
                    size="sm"
                    variant="outline"
                    className="w-full h-7 text-xs border-blue-300 text-blue-700 hover:bg-blue-50"
                    onClick={() => {
                      setConfirmingParty('BUYER');
                      setConfirmNotes('');
                      setIsConfirmModalOpen(true);
                    }}
                    disabled={isPending}
                  >
                    <CheckCircle2 className="w-3.5 h-3.5 mr-1" />
                    {t('confirmAsBuyer')}
                  </Button>
                )}
              </div>

              {/* Seller Confirmation Box */}
              <div
                className={`p-3.5 rounded-xl border text-xs space-y-2 transition-all ${
                  data.confirmations.sellerConfirmed
                    ? 'bg-emerald-50/70 border-emerald-200 dark:bg-emerald-950/30 dark:border-emerald-800'
                    : 'bg-slate-50 border-slate-200 dark:bg-slate-900/40 dark:border-slate-800'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className="font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
                    <Building2 className="w-4 h-4 text-emerald-600" />
                    Seller: {data.sellerCompany.name}
                  </span>
                  {data.confirmations.sellerConfirmed ? (
                    <Badge className="bg-emerald-600 text-white text-[10px] gap-1">
                      <Check className="w-3 h-3" />
                      Confirmed (v{data.confirmations.latestVersionNumber})
                    </Badge>
                  ) : (
                    <Badge variant="outline" className="text-[10px] text-amber-700 border-amber-300">
                      Pending
                    </Badge>
                  )}
                </div>

                {data.confirmations.sellerConfirmed ? (
                  <p className="text-[11px] text-emerald-800 dark:text-emerald-400">
                    Confirmed on {new Date(data.confirmations.sellerConfirmedAt!).toLocaleString()}
                    {data.confirmations.sellerNotes && ` — "${data.confirmations.sellerNotes}"`}
                  </p>
                ) : (
                  <p className="text-[11px] text-slate-500">
                    Awaiting seller digital signature or broker verification of terms.
                  </p>
                )}

                {!data.confirmations.sellerConfirmed && isEditable && (
                  <Button
                    size="sm"
                    variant="outline"
                    className="w-full h-7 text-xs border-emerald-300 text-emerald-700 hover:bg-emerald-50"
                    onClick={() => {
                      setConfirmingParty('SELLER');
                      setConfirmNotes('');
                      setIsConfirmModalOpen(true);
                    }}
                    disabled={isPending}
                  >
                    <CheckCircle2 className="w-3.5 h-3.5 mr-1" />
                    {t('confirmAsSeller')}
                  </Button>
                )}
              </div>

              {/* Pre-Flight Gate Status Banner */}
              <div
                className={`p-3 rounded-xl border text-xs flex items-start gap-2.5 ${
                  canFinalize
                    ? 'bg-emerald-50 border-emerald-200 text-emerald-900'
                    : isFinalized
                    ? 'bg-teal-50 border-teal-200 text-teal-900'
                    : 'bg-amber-50 border-amber-200 text-amber-900'
                }`}
              >
                {canFinalize ? (
                  <ShieldCheck className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
                ) : isFinalized ? (
                  <CheckCircle2 className="w-4 h-4 text-teal-600 shrink-0 mt-0.5" />
                ) : (
                  <Lock className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                )}
                <div>
                  <span className="font-bold block">
                    {canFinalize
                      ? 'Pre-Flight Finalization Gate Unlocked'
                      : isFinalized
                      ? 'Contract Finalized & Booking Locked'
                      : 'Pre-Flight Gate Blocked'}
                  </span>
                  <span className="text-[11px] opacity-90">
                    {canFinalize
                      ? 'Both counterparty confirmations verified on exact latest version. Authorized broker may now issue final booking.'
                      : isFinalized
                      ? `Final contract snapshot locked under booking ${data.booking?.bookingReference}.`
                      : 'Both buyer and seller must confirm Version ' +
                        data.confirmations.latestVersionNumber +
                        ' before broker finalization.'}
                  </span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Right Column (2 cols): Current Terms & Version History */}
        <div className="lg:col-span-2 space-y-6">
          {/* Current Terms Snapshot */}
          <Card className="border-slate-200 dark:border-slate-800 shadow-sm">
            <CardHeader className="py-3 px-4 border-b border-slate-100 dark:border-slate-800 flex flex-row items-center justify-between">
              <CardTitle className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                <FileText className="w-4 h-4 text-[#0D9488]" />
                Current Active Terms (Version {data.confirmations.latestVersionNumber})
              </CardTitle>
              <Badge variant="outline" className="text-xs font-mono font-semibold">
                Valuation: {formatCurrency(data.summary.totalValuation)}
              </Badge>
            </CardHeader>
            <CardContent className="p-4 sm:p-6 space-y-4">
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 text-xs">
                <div>
                  <span className="text-slate-400 block text-[11px]">{t('contractQuantity')}</span>
                  <span className="font-mono font-bold text-sm text-slate-900 dark:text-white">
                    {formatNumber(data.summary.agreedQuantity)} {data.summary.unitSymbol}
                  </span>
                </div>

                <div>
                  <span className="text-slate-400 block text-[11px]">{t('agreedPrice')}</span>
                  <span className="font-mono font-bold text-sm text-teal-700 dark:text-teal-400">
                    {formatCurrency(data.summary.agreedPrice)}/{data.summary.unitSymbol}
                  </span>
                </div>

                <div>
                  <span className="text-slate-400 block text-[11px]">{t('allocationPriceBasisLabel')}</span>
                  <span className="font-semibold text-slate-800 dark:text-slate-200">
                    {data.summary.priceBasis}
                  </span>
                </div>

                <div>
                  <span className="text-slate-400 block text-[11px]">Delivery Location</span>
                  <span className="font-semibold text-slate-800 dark:text-slate-200 flex items-center gap-1">
                    <MapPin className="w-3.5 h-3.5 text-slate-400" />
                    {data.summary.deliveryLocation || 'Warehouse Bay'}
                  </span>
                </div>

                <div>
                  <span className="text-slate-400 block text-[11px]">Delivery Schedule</span>
                  <span className="font-semibold text-slate-800 dark:text-slate-200 flex items-center gap-1">
                    <Calendar className="w-3.5 h-3.5 text-slate-400" />
                    {data.summary.deliveryDate || 'Within 7 business days'}
                  </span>
                </div>

                <div>
                  <span className="text-slate-400 block text-[11px]">{t('brokerageCommission')}</span>
                  <span className="font-mono font-semibold text-slate-800 dark:text-slate-200">
                    ₹{latestSnapshot.brokerCommissionRate ?? 250}/MT
                  </span>
                </div>

                <div>
                  <span className="text-slate-400 block text-[11px]">Payment Terms</span>
                  <span className="text-slate-700 dark:text-slate-300">
                    {latestSnapshot.paymentTerms || '100% Advance against Invoice'}
                  </span>
                </div>

                <div>
                  <span className="text-slate-400 block text-[11px]">Packaging Type</span>
                  <span className="text-slate-700 dark:text-slate-300">
                    {latestSnapshot.packagingType || '50kg Jute Bags'}
                  </span>
                </div>

                <div>
                  <span className="text-slate-400 block text-[11px]">Delivery Terms</span>
                  <span className="text-slate-700 dark:text-slate-300">
                    {latestSnapshot.deliveryTerms || 'Ex-Warehouse / FOR'}
                  </span>
                </div>
              </div>

              {latestSnapshot.notes && (
                <div className="p-2.5 bg-slate-50 dark:bg-slate-900/50 rounded-lg border border-slate-200 dark:border-slate-800 text-xs text-slate-600 dark:text-slate-400">
                  <span className="font-semibold text-slate-800 dark:text-slate-200 block mb-0.5">
                    Special Conditions / Notes:
                  </span>
                  "{latestSnapshot.notes}"
                </div>
              )}
            </CardContent>
          </Card>

          {/* Version History & Diff Timeline */}
          <Card className="border-slate-200 dark:border-slate-800 shadow-sm">
            <CardHeader className="py-3 px-4 border-b border-slate-100 dark:border-slate-800">
              <CardTitle className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                <History className="w-4 h-4 text-[#0D9488]" />
                Versioned Negotiation History ({data.versions.length} Versions)
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4 sm:p-6 space-y-4">
              <div className="relative border-l-2 border-slate-200 dark:border-slate-800 ml-3 space-y-6">
                {data.versions.map((ver, idx) => (
                  <div key={ver.id} className="relative pl-6">
                    {/* Timeline bullet */}
                    <div
                      className={`absolute -left-[9px] top-0 w-4 h-4 rounded-full border-2 bg-white flex items-center justify-center ${
                        idx === 0
                          ? 'border-[#0D9488] ring-2 ring-teal-100'
                          : 'border-slate-400'
                      }`}
                    >
                      <div
                        className={`w-1.5 h-1.5 rounded-full ${
                          idx === 0 ? 'bg-[#0D9488]' : 'bg-slate-400'
                        }`}
                      />
                    </div>

                    <div className="space-y-1.5">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-bold text-xs text-slate-900 dark:text-white">
                          Version {ver.versionNumber}
                        </span>
                        <Badge
                          variant="outline"
                          className={`text-[10px] ${
                            ver.status === 'Draft'
                              ? 'bg-slate-50 text-slate-700'
                              : ver.status === 'Superseded'
                              ? 'bg-slate-100 text-slate-500'
                              : ver.status === 'Finalized' || ver.status === 'Broker Finalized'
                              ? 'bg-teal-50 text-teal-700'
                              : 'bg-amber-50 text-amber-700'
                          }`}
                        >
                          {ver.status}
                        </Badge>
                        <span className="text-[11px] text-slate-400">
                          {new Date(ver.createdAt).toLocaleString()} by {ver.actorName} ({ver.actorRole})
                        </span>
                      </div>

                      {ver.changeReason && (
                        <p className="text-xs text-slate-600 dark:text-slate-400 italic">
                          "{ver.changeReason}"
                        </p>
                      )}

                      {/* Visual Diffs between versions */}
                      {ver.diffs && ver.diffs.length > 0 && (
                        <div className="p-2.5 bg-slate-50 dark:bg-slate-900/60 rounded border border-slate-200 dark:border-slate-800 space-y-1">
                          <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">
                            Material Term Changes:
                          </span>
                          <div className="flex flex-wrap gap-2 text-xs">
                            {ver.diffs.map((diff, dIdx) => (
                              <span
                                key={dIdx}
                                className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-amber-50 text-amber-800 border border-amber-200 text-[11px]"
                              >
                                <strong>{diff.label}:</strong>
                                <span className="line-through text-slate-400">
                                  {String(diff.oldValue ?? 'None')}
                                </span>
                                <ArrowRight className="w-3 h-3 text-slate-400" />
                                <span className="font-semibold text-emerald-700">
                                  {String(diff.newValue)}
                                </span>
                              </span>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* MODAL 1: TERMS REVISION */}
      <Dialog open={isRevisionOpen} onOpenChange={setIsRevisionOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="text-base font-bold flex items-center gap-2">
              <RefreshCw className="w-5 h-5 text-[#0D9488]" />
              Revise Deal Terms (Issue Version {data.confirmations.latestVersionNumber + 1})
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              {language === 'hi'
                ? 'नियमों में बदलाव से एक नया अपरिवर्तनीय संस्करण तैयार होगा और पिछली स्वीकृतियां अमान्य हो जाएंगी।'
                : 'Material revisions create a new immutable version and strictly invalidate previous counterparty confirmations.'}
            </DialogDescription>
          </DialogHeader>

          {revisionError && (
            <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-xs text-red-700 flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-red-600 shrink-0" />
              <span>{revisionError}</span>
            </div>
          )}

          <form onSubmit={handleRevisionSubmit} className="space-y-4 pt-2">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div>
                <Label className="text-xs font-semibold">{t('agreedPrice')} (₹/MT) *</Label>
                <Input
                  type="number"
                  value={revisedPrice}
                  onChange={(e) => setRevisedPrice(e.target.value)}
                  className="text-xs h-9 mt-1 font-mono"
                  required
                />
              </div>

              <div>
                <Label className="text-xs font-semibold">{t('contractQuantity')} (MT) *</Label>
                <Input
                  type="number"
                  value={revisedQuantity}
                  onChange={(e) => setRevisedQuantity(e.target.value)}
                  className="text-xs h-9 mt-1 font-mono"
                  required
                />
              </div>

              <div>
                <Label className="text-xs font-semibold">{t('allocationPriceBasisLabel')}</Label>
                <select
                  value={revisedPriceBasis}
                  onChange={(e) => setRevisedPriceBasis(e.target.value)}
                  className="w-full text-xs h-9 mt-1 rounded-md border border-slate-200 bg-white px-3 py-1 shadow-xs"
                >
                  <option value="FOR_DESTINATION">FOR Destination</option>
                  <option value="EX_MILL">Ex-Mill / Ex-Warehouse</option>
                  <option value="FOR_BUYER_MILL">FOR Buyer Mill</option>
                </select>
              </div>

              <div>
                <Label className="text-xs font-semibold">{t('brokerageCommission')} (₹/MT)</Label>
                <Input
                  type="number"
                  value={revisedBrokerRate}
                  onChange={(e) => setRevisedBrokerRate(e.target.value)}
                  className="text-xs h-9 mt-1 font-mono"
                />
              </div>

              <div>
                <Label className="text-xs font-semibold">Delivery Location</Label>
                <Input
                  value={revisedDeliveryLocation}
                  onChange={(e) => setRevisedDeliveryLocation(e.target.value)}
                  className="text-xs h-9 mt-1"
                />
              </div>

              <div>
                <Label className="text-xs font-semibold">Target Delivery Date</Label>
                <Input
                  type="date"
                  value={revisedDeliveryDate}
                  onChange={(e) => setRevisedDeliveryDate(e.target.value)}
                  className="text-xs h-9 mt-1 font-mono"
                />
              </div>

              <div>
                <Label className="text-xs font-semibold">Payment Terms</Label>
                <Input
                  value={revisedPaymentTerms}
                  onChange={(e) => setRevisedPaymentTerms(e.target.value)}
                  className="text-xs h-9 mt-1"
                />
              </div>

              <div>
                <Label className="text-xs font-semibold">Packaging Type</Label>
                <Input
                  value={revisedPackagingType}
                  onChange={(e) => setRevisedPackagingType(e.target.value)}
                  className="text-xs h-9 mt-1"
                />
              </div>
            </div>

            <div>
              <Label className="text-xs font-semibold">Revision Reason *</Label>
              <Input
                value={revisionReason}
                onChange={(e) => setRevisionReason(e.target.value)}
                placeholder="e.g. Counter-offer accepted, freight adjustment, delivery date deferred..."
                className="text-xs h-9 mt-1"
                required
              />
            </div>

            <DialogFooter className="gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setIsRevisionOpen(false)}
                disabled={isPending}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                className="bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-semibold text-xs"
                disabled={isPending}
              >
                {isPending ? <Loader2 className="w-3.5 h-3.5 mr-1.5 animate-spin" /> : null}
                Save & Issue Version {data.confirmations.latestVersionNumber + 1}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* MODAL 2: RECORD PARTY CONFIRMATION */}
      <Dialog open={isConfirmModalOpen} onOpenChange={setIsConfirmModalOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold flex items-center gap-2">
              <CheckCircle2 className="w-5 h-5 text-emerald-600" />
              Record {confirmingParty === 'BUYER' ? 'Buyer' : 'Seller'} Confirmation
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              Confirming terms for Version {data.confirmations.latestVersionNumber} (
              {data.summary.agreedQuantity} MT @ ₹{data.summary.agreedPrice}/MT).
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 pt-2">
            <div>
              <Label className="text-xs font-semibold">Verification Notes / Reference</Label>
              <Input
                value={confirmNotes}
                onChange={(e) => setConfirmNotes(e.target.value)}
                placeholder="e.g. Confirmed verbally via registered phone / PO copy received"
                className="text-xs h-9 mt-1"
              />
            </div>
          </div>

          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setIsConfirmModalOpen(false)}
              disabled={isPending}
            >
              Cancel
            </Button>
            <Button
              type="button"
              size="sm"
              className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs"
              onClick={handleConfirmSubmit}
              disabled={isPending}
            >
              {isPending ? <Loader2 className="w-3.5 h-3.5 mr-1.5 animate-spin" /> : null}
              Confirm Version {data.confirmations.latestVersionNumber}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* MODAL 3: CANCEL DEAL */}
      <Dialog open={isCancelModalOpen} onOpenChange={setIsCancelModalOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold flex items-center gap-2 text-red-600">
              <AlertTriangle className="w-5 h-5" />
              {t('confirmCancelTitle')}
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              {language === 'hi'
                ? 'सौदा रद्द करने से जुड़े हुए सभी आवंटन मुक्त हो जाएंगे और मात्रा इन्वेंट्री में वापस आ जाएगी।'
                : 'Cancelling this deal releases all linked allocations and restores quantities back to available supply.'}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 pt-2">
            {cancelError && (
              <p className="text-xs text-red-600 bg-red-50 p-2 rounded border border-red-200">
                {cancelError}
              </p>
            )}
            <div>
              <Label className="text-xs font-semibold">{t('confirmCancelPrompt')} *</Label>
              <Input
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
                placeholder="e.g. Counterparties could not agree on payment terms, buyer cancelled requirement..."
                className="text-xs h-9 mt-1"
                required
              />
            </div>
          </div>

          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setIsCancelModalOpen(false)}
              disabled={isPending}
            >
              Cancel
            </Button>
            <Button
              type="button"
              size="sm"
              variant="destructive"
              className="font-semibold text-xs"
              onClick={handleCancelSubmit}
              disabled={isPending}
            >
              {isPending ? <Loader2 className="w-3.5 h-3.5 mr-1.5 animate-spin" /> : null}
              {t('cancelDeal')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
