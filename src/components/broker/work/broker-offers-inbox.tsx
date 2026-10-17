'use client';

import React, { useState, useEffect, useMemo } from 'react';
import {
  Package,
  Search,
  SlidersHorizontal,
  Building2,
  MapPin,
  Calendar,
  Lock,
  Truck,
  Plus,
  RefreshCw,
  AlertCircle,
  Clock,
  CheckCircle2,
  Layers,
  Edit2,
  XCircle,
  RotateCcw,
  ShieldCheck,
  ChevronRight,
  TrendingUp,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { formatIndianCurrency } from '@/lib/utils';
import {
  getBrokerSellerOffersAction,
  cancelBrokerSellerOfferAction,
  renewBrokerSellerOfferAction,
  type BrokerOfferItem,
} from '@/src/server/actions/broker-mandate-actions';
import { OfferFormDialog } from './offer-form-dialog';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { toast } from 'sonner';

type OfferFilter = 'ALL' | 'AVAILABLE' | 'PARTIAL' | 'RESERVED' | 'EXPIRING' | 'CLOSED';

export function BrokerOffersInbox() {
  const { t, formatCurrency, formatNumber, language } = useLanguage();

  const [offers, setOffers] = useState<BrokerOfferItem[]>([]);
  const [stats, setStats] = useState({
    totalOffers: 0,
    activeCount: 0,
    partiallyAvailableCount: 0,
    totalAvailableVolumeMT: 0,
    expiringSoonCount: 0,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Search & Filter
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<OfferFilter>('ALL');
  const [sortBy, setSortBy] = useState<'NEWEST' | 'VOLUME' | 'PRICE' | 'EXPIRING'>('NEWEST');

  // Modal states
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editingOffer, setEditingOffer] = useState<BrokerOfferItem | null>(null);

  // Cancellation Modal
  const [cancellingOffer, setCancellingOffer] = useState<BrokerOfferItem | null>(null);
  const [cancelReason, setCancelReason] = useState('');
  const [isCancelling, setIsCancelling] = useState(false);

  // Renewal Modal
  const [renewingOffer, setRenewingOffer] = useState<BrokerOfferItem | null>(null);
  const [renewDate, setRenewDate] = useState('');
  const [isRenewing, setIsRenewing] = useState(false);

  const loadOffers = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await getBrokerSellerOffersAction();
      if (res.success && res.data) {
        setOffers(res.data.offers);
        setStats(res.data.stats);
      } else {
        setError(res.error || 'Failed to load seller offers');
      }
    } catch (err: any) {
      setError(err?.message || 'Network error fetching offers');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadOffers();
  }, []);

  // Filter & Sort
  const filteredOffers = useMemo(() => {
    let list = [...offers];

    // Status filter
    if (activeFilter === 'AVAILABLE') {
      list = list.filter((o) => o.status === 'Open' || o.status === 'Available');
    } else if (activeFilter === 'PARTIAL') {
      list = list.filter((o) => o.status === 'Partially Available');
    } else if (activeFilter === 'RESERVED') {
      list = list.filter((o) => o.status === 'Reserved' || o.reservedQuantity > 0);
    } else if (activeFilter === 'EXPIRING') {
      list = list.filter((o) => o.isExpired || o.status === 'Expired');
    } else if (activeFilter === 'CLOSED') {
      list = list.filter((o) => o.status === 'Unavailable' || o.status === 'Cancelled');
    }

    // Search query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      list = list.filter(
        (o) =>
          o.commodityName.toLowerCase().includes(q) ||
          o.gradeName.toLowerCase().includes(q) ||
          o.sellerCompanyName.toLowerCase().includes(q) ||
          o.lotNumber.toLowerCase().includes(q) ||
          o.stateName.toLowerCase().includes(q) ||
          o.districtName.toLowerCase().includes(q)
      );
    }

    // Sorting
    list.sort((a, b) => {
      if (sortBy === 'VOLUME') {
        return b.availableQuantity - a.availableQuantity;
      }
      if (sortBy === 'PRICE') {
        return a.askingPrice - b.askingPrice;
      }
      if (sortBy === 'EXPIRING') {
        return new Date(a.validUntil).getTime() - new Date(b.validUntil).getTime();
      }
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });

    return list;
  }, [offers, activeFilter, searchQuery, sortBy]);

  // Cancel Handler
  const handleConfirmCancel = async () => {
    if (!cancellingOffer) return;
    if (!cancelReason.trim() || cancelReason.trim().length < 3) {
      toast.error(t('reasonRequired'));
      return;
    }

    setIsCancelling(true);
    try {
      const res = await cancelBrokerSellerOfferAction(cancellingOffer.id, cancelReason.trim());
      if (res.success) {
        toast.success(t('recordCancelledSuccess'));
        setCancellingOffer(null);
        setCancelReason('');
        loadOffers();
      } else {
        toast.error(res.error || 'Failed to cancel offer');
      }
    } catch (err: any) {
      toast.error(err?.message || 'An unexpected error occurred');
    } finally {
      setIsCancelling(false);
    }
  };

  // Renew Handler
  const handleConfirmRenew = async () => {
    if (!renewingOffer || !renewDate) return;

    setIsRenewing(true);
    try {
      const res = await renewBrokerSellerOfferAction(renewingOffer.id, new Date(renewDate).toISOString());
      if (res.success) {
        toast.success(t('recordRenewedSuccess'));
        setRenewingOffer(null);
        setRenewDate('');
        loadOffers();
      } else {
        toast.error(res.error || 'Failed to renew offer');
      }
    } catch (err: any) {
      toast.error(err?.message || 'An unexpected error occurred');
    } finally {
      setIsRenewing(false);
    }
  };

  const getLoadingBadge = (status: string) => {
    const s = status.toLowerCase();
    if (s.includes('ready') && !s.includes('not')) {
      return (
        <Badge className="bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-50 text-[11px] font-semibold">
          Ready to Load
        </Badge>
      );
    }
    if (s.includes('progress') || s.includes('loading')) {
      return (
        <Badge className="bg-blue-50 text-blue-700 border-blue-200 hover:bg-blue-50 text-[11px] font-semibold">
          Loading in Progress
        </Badge>
      );
    }
    if (s.includes('delayed') || s.includes('blocked')) {
      return (
        <Badge className="bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-50 text-[11px] font-semibold">
          Delayed / Blocked
        </Badge>
      );
    }
    return (
      <Badge className="bg-slate-100 text-slate-600 border-slate-200 hover:bg-slate-100 text-[11px]">
        {status || 'Not Ready'}
      </Badge>
    );
  };

  return (
    <div className="space-y-5">
      {/* Disclaimer Banner */}
      <div className="bg-amber-50/70 border border-amber-200/80 rounded-xl p-3 text-xs text-amber-900 flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <AlertCircle className="w-4 h-4 text-amber-600 shrink-0" />
          <span>{t('brokerDisclaimerNotOwner')}</span>
        </div>
        <Button
          onClick={() => {
            setEditingOffer(null);
            setIsFormOpen(true);
          }}
          className="min-h-[44px] h-10 px-3.5 bg-[#0D9488] hover:bg-teal-700 text-white font-bold text-xs rounded-lg shrink-0 flex items-center gap-1.5 shadow-xs"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>{t('actionCreateOffer')}</span>
        </Button>
      </div>

      {/* KPI Cards Strip */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {/* Total Offers */}
        <Card className="bg-white border-slate-200/80 shadow-2xs">
          <CardContent className="p-3.5 sm:p-4">
            <span className="text-[11px] font-medium text-slate-500 uppercase tracking-wider block">
              Total Offers
            </span>
            <div className="mt-1 flex items-baseline gap-2">
              <span className="text-xl sm:text-2xl font-bold text-slate-900">
                {stats.totalOffers}
              </span>
              <span className="text-xs text-slate-500">active mandates</span>
            </div>
          </CardContent>
        </Card>

        {/* Total Available Volume */}
        <Card className="bg-white border-slate-200/80 shadow-2xs">
          <CardContent className="p-3.5 sm:p-4">
            <span className="text-[11px] font-medium text-teal-700 uppercase tracking-wider block">
              Available Supply
            </span>
            <div className="mt-1 flex items-baseline gap-1.5">
              <span className="text-xl sm:text-2xl font-extrabold text-[#0D9488]">
                {formatNumber(stats.totalAvailableVolumeMT)}
              </span>
              <span className="text-xs font-semibold text-slate-600">MT</span>
            </div>
          </CardContent>
        </Card>

        {/* Active Ready Lots */}
        <Card className="bg-white border-slate-200/80 shadow-2xs">
          <CardContent className="p-3.5 sm:p-4">
            <span className="text-[11px] font-medium text-emerald-700 uppercase tracking-wider block">
              Ready to Dispatch
            </span>
            <div className="mt-1 flex items-baseline gap-2">
              <span className="text-xl sm:text-2xl font-bold text-emerald-600">
                {stats.activeCount}
              </span>
              <span className="text-xs text-slate-500">lots</span>
            </div>
          </CardContent>
        </Card>

        {/* Expiring Soon */}
        <Card className="bg-white border-slate-200/80 shadow-2xs">
          <CardContent className="p-3.5 sm:p-4">
            <span className="text-[11px] font-medium text-amber-700 uppercase tracking-wider block">
              Expiring Soon
            </span>
            <div className="mt-1 flex items-baseline gap-2">
              <span className="text-xl sm:text-2xl font-bold text-amber-600">
                {stats.expiringSoonCount}
              </span>
              <span className="text-xs text-slate-500">within 48h</span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Search & Filter Toolbar */}
      <div className="space-y-3">
        <div className="flex flex-col sm:flex-row gap-2.5">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            <Input
              type="text"
              placeholder="Search commodity, grade, seller, lot, state, mandi..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-10 min-h-[48px] h-12 bg-white border-slate-200/90 rounded-xl text-xs sm:text-sm"
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => setSearchQuery('')}
                className="absolute right-3.5 top-1/2 -translate-y-1/2 text-xs text-slate-400 hover:text-slate-600"
              >
                Clear
              </button>
            )}
          </div>

          <div className="flex items-center gap-2">
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value as any)}
              className="min-h-[48px] h-12 px-3 bg-white border border-slate-200/90 rounded-xl text-xs sm:text-sm text-slate-700 font-medium focus:ring-teal-500"
            >
              <option value="NEWEST">Newest First</option>
              <option value="VOLUME">Volume (High to Low)</option>
              <option value="PRICE">Price (Low to High)</option>
              <option value="EXPIRING">Expiring Soonest</option>
            </select>

            <Button
              variant="outline"
              onClick={loadOffers}
              className="min-h-[48px] h-12 px-3.5 border-slate-200 text-slate-600"
              title="Refresh"
            >
              <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin text-teal-600' : ''}`} />
            </Button>
          </div>
        </div>

        {/* Filter Chips */}
        <div className="w-full overflow-x-auto touch-pan-x pb-1 scrollbar-none">
          <div className="flex items-center gap-1.5 min-w-max">
            {[
              { key: 'ALL', label: 'All Offers', count: offers.length },
              { key: 'AVAILABLE', label: 'Available', count: stats.activeCount },
              { key: 'PARTIAL', label: 'Partially Available', count: stats.partiallyAvailableCount },
              { key: 'RESERVED', label: 'Reserved Lots', count: offers.filter((o) => o.reservedQuantity > 0).length },
              { key: 'EXPIRING', label: 'Expiring / Expired', count: offers.filter((o) => o.isExpired).length },
              { key: 'CLOSED', label: 'Cancelled / Closed', count: offers.filter((o) => o.status === 'Unavailable' || o.status === 'Cancelled').length },
            ].map((chip) => (
              <button
                key={chip.key}
                onClick={() => setActiveFilter(chip.key as any)}
                className={`min-h-[40px] px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-1.5 transition-all ${
                  activeFilter === chip.key
                    ? 'bg-[#0D9488] text-white shadow-xs'
                    : 'bg-white border border-slate-200/80 text-slate-600 hover:bg-slate-50'
                }`}
              >
                <span>{chip.label}</span>
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                    activeFilter === chip.key
                      ? 'bg-teal-700 text-white'
                      : 'bg-slate-100 text-slate-600'
                  }`}
                >
                  {chip.count}
                </span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Offer Cards List */}
      {isLoading ? (
        <div className="py-16 text-center text-slate-400 space-y-2">
          <RefreshCw className="w-6 h-6 animate-spin mx-auto text-[#0D9488]" />
          <p className="text-xs">{t('loadingText')}</p>
        </div>
      ) : error ? (
        <Card className="border-rose-200 bg-rose-50/50">
          <CardContent className="p-6 text-center space-y-3">
            <AlertCircle className="w-8 h-8 text-rose-600 mx-auto" />
            <h3 className="font-bold text-slate-800 text-base">{t('errorTitle')}</h3>
            <p className="text-xs text-slate-600">{error}</p>
            <Button
              variant="outline"
              onClick={loadOffers}
              className="min-h-[48px] h-12 border-rose-200 text-rose-700"
            >
              {t('retryAction')}
            </Button>
          </CardContent>
        </Card>
      ) : filteredOffers.length === 0 ? (
        <Card className="border-dashed border-2 border-slate-200 bg-slate-50/50">
          <CardContent className="p-12 text-center space-y-3">
            <Package className="w-10 h-10 text-slate-300 mx-auto" />
            <h3 className="font-bold text-slate-700 text-base">No Seller Offers Found</h3>
            <p className="text-xs text-slate-500 max-w-sm mx-auto">
              No material offers match your current filter. You can add a new seller offer or adjust filters.
            </p>
            <Button
              onClick={() => {
                setEditingOffer(null);
                setIsFormOpen(true);
              }}
              className="min-h-[48px] h-12 bg-[#0D9488] hover:bg-teal-700 text-white font-bold"
            >
              <Plus className="w-4 h-4 mr-1.5" />
              <span>{t('actionCreateOffer')}</span>
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredOffers.map((offer) => {
            const isClosed = offer.status === 'Unavailable' || offer.status === 'Cancelled';
            const unit = offer.unitSymbol || offer.unitName || 'MT';
            return (
              <Card
                key={offer.id}
                className={`bg-white border rounded-xl overflow-hidden shadow-2xs hover:shadow-md transition-all flex flex-col justify-between ${
                  offer.isExpired ? 'border-amber-300/80 bg-amber-50/20' : 'border-slate-200/80'
                }`}
              >
                <div className="p-4 sm:p-5 space-y-3">
                  {/* Top Bar: Seller & Status */}
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="font-bold text-slate-900 text-sm sm:text-base truncate">
                          {offer.sellerCompanyName}
                        </span>
                        <ShieldCheck className="w-4 h-4 text-[#0D9488] shrink-0" />
                      </div>
                      <div className="flex items-center gap-2 mt-0.5 text-xs text-slate-400 font-mono">
                        <span>{offer.lotNumber}</span>
                        <span>•</span>
                        <span className="font-sans text-slate-500">v{offer.version}</span>
                      </div>
                    </div>

                    <div className="flex flex-col items-end gap-1">
                      {getLoadingBadge(offer.loadingStatus)}
                      {offer.isExpired && (
                        <Badge className="bg-amber-100 text-amber-800 text-[10px]">
                          Expired
                        </Badge>
                      )}
                    </div>
                  </div>

                  {/* Commodity & Grade */}
                  <div className="bg-slate-50 rounded-lg p-2.5 border border-slate-100">
                    <span className="font-bold text-slate-800 text-sm sm:text-base">
                      {offer.commodityName}{' '}
                      <span className="text-[#0D9488] font-semibold text-xs sm:text-sm">
                        • {offer.gradeName}
                      </span>
                    </span>
                  </div>

                  {/* Quantity Breakdown Grid */}
                  <div className="grid grid-cols-4 gap-1.5 p-2 rounded-lg bg-slate-50/80 border border-slate-100 text-center">
                    <div>
                      <span className="text-[10px] text-slate-400 uppercase block font-medium">
                        {t('qtyOffered')}
                      </span>
                      <span className="text-xs font-bold text-slate-800">
                        {offer.offeredQuantity}
                      </span>
                    </div>
                    <div>
                      <span className="text-[10px] text-teal-600 uppercase block font-semibold">
                        {t('qtyAvailable')}
                      </span>
                      <span className="text-xs font-extrabold text-[#0D9488]">
                        {offer.availableQuantity}
                      </span>
                    </div>
                    <div>
                      <span className="text-[10px] text-amber-600 uppercase block font-medium">
                        {t('qtyReserved')}
                      </span>
                      <span className="text-xs font-bold text-amber-700">
                        {offer.reservedQuantity}
                      </span>
                    </div>
                    <div>
                      <span className="text-[10px] text-slate-500 uppercase block font-medium">
                        {t('qtySold')}
                      </span>
                      <span className="text-xs font-bold text-slate-600">
                        {offer.soldQuantity}
                      </span>
                    </div>
                  </div>

                  {/* Commercials: Asking Price & Location */}
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div className="p-2 rounded-lg bg-teal-50/40 border border-teal-100/60">
                      <span className="text-[10px] text-teal-800 font-medium block">
                        {t('fieldAskingPrice')}
                      </span>
                      <div className="text-sm font-bold text-[#0D9488] flex items-baseline gap-1">
                        <span>{formatCurrency(offer.askingPrice)}</span>
                        <span className="text-[10px] text-slate-500">/{unit}</span>
                      </div>
                      {offer.confidentialMinimumPrice && (
                        <div className="flex items-center gap-1 text-[10px] text-amber-700 mt-0.5">
                          <Lock className="w-2.5 h-2.5" />
                          <span>Floor: {formatCurrency(offer.confidentialMinimumPrice)}</span>
                        </div>
                      )}
                    </div>

                    <div className="p-2 rounded-lg bg-slate-50 border border-slate-100">
                      <span className="text-[10px] text-slate-500 font-medium block">
                        Warehouse Location
                      </span>
                      <div className="flex items-center gap-1 text-slate-800 font-semibold truncate mt-0.5">
                        <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                        <span className="truncate">
                          {offer.districtName}, {offer.stateName}
                        </span>
                      </div>
                      <span className="text-[10px] text-slate-400 block truncate">
                        Valid till: {offer.validUntilFormatted}
                      </span>
                    </div>
                  </div>

                  {offer.loadingRemarks && (
                    <p className="text-[11px] text-slate-500 italic bg-slate-50/50 p-2 rounded border border-slate-100">
                      &quot;{offer.loadingRemarks}&quot;
                    </p>
                  )}
                </div>

                {/* Bottom Broker Actions */}
                <div className="p-3 bg-slate-50/70 border-t border-slate-100 flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5">
                    {/* Edit button */}
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={isClosed}
                      onClick={() => {
                        setEditingOffer(offer);
                        setIsFormOpen(true);
                      }}
                      className="min-h-[40px] h-10 px-3 text-xs font-semibold border-slate-200 text-slate-700 hover:bg-slate-100"
                    >
                      <Edit2 className="w-3.5 h-3.5 mr-1 text-slate-500" />
                      <span>{t('actionEditOffer')}</span>
                    </Button>

                    {/* Renew button if expired or soon */}
                    {(offer.isExpired || offer.status === 'Expired') && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          setRenewingOffer(offer);
                          const f = new Date();
                          f.setDate(f.getDate() + 14);
                          setRenewDate(f.toISOString().split('T')[0]);
                        }}
                        className="min-h-[40px] h-10 px-3 text-xs font-semibold border-teal-200 text-[#0D9488] hover:bg-teal-50"
                      >
                        <RotateCcw className="w-3.5 h-3.5 mr-1" />
                        <span>{t('actionRenewOffer')}</span>
                      </Button>
                    )}
                  </div>

                  {/* Cancel button */}
                  {!isClosed && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => {
                        setCancellingOffer(offer);
                        setCancelReason('');
                      }}
                      className="min-h-[40px] h-10 px-2.5 text-xs text-rose-600 hover:text-rose-700 hover:bg-rose-50 font-medium"
                    >
                      <XCircle className="w-3.5 h-3.5 mr-1" />
                      <span>{t('actionCancelOffer')}</span>
                    </Button>
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* Create / Edit Dialog */}
      <OfferFormDialog
        open={isFormOpen}
        onOpenChange={setIsFormOpen}
        offer={editingOffer}
        onSuccess={loadOffers}
      />

      {/* Cancellation Confirmation Dialog */}
      <Dialog
        open={Boolean(cancellingOffer)}
        onOpenChange={(open) => !open && setCancellingOffer(null)}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold text-slate-900">
              {t('confirmCancelTitle')}
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              {t('confirmCancelPrompt')}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 py-2">
            <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-100 text-xs">
              <span className="font-semibold text-slate-800">
                {cancellingOffer?.sellerCompanyName}
              </span>
              <span className="text-slate-500 block">
                {cancellingOffer?.commodityName} • {cancellingOffer?.lotNumber}
              </span>
            </div>

            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">
                Cancellation Reason <span className="text-rose-500">*</span>
              </Label>
              <Input
                placeholder="e.g. Seller sold out locally, quality inspection failed"
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
                className="min-h-[48px] h-12 bg-white text-xs"
              />
            </div>
          </div>

          <DialogFooter className="flex flex-col-reverse sm:flex-row gap-2">
            <Button
              variant="outline"
              onClick={() => setCancellingOffer(null)}
              disabled={isCancelling}
              className="min-h-[48px] h-12 w-full sm:w-auto"
            >
              {t('actionCancel')}
            </Button>
            <Button
              onClick={handleConfirmCancel}
              disabled={isCancelling}
              className="min-h-[48px] h-12 w-full sm:w-auto bg-rose-600 hover:bg-rose-700 text-white font-bold"
            >
              {isCancelling ? 'Processing...' : t('actionConfirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Renewal Dialog */}
      <Dialog
        open={Boolean(renewingOffer)}
        onOpenChange={(open) => !open && setRenewingOffer(null)}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold text-slate-900">
              {t('actionRenewOffer')}
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              Extend validity date to reactivate this offer.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 py-2">
            <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-100 text-xs">
              <span className="font-semibold text-slate-800">
                {renewingOffer?.sellerCompanyName}
              </span>
              <span className="text-slate-500 block">
                {renewingOffer?.commodityName} • {renewingOffer?.lotNumber}
              </span>
            </div>

            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">
                New Expiration Date <span className="text-rose-500">*</span>
              </Label>
              <Input
                type="date"
                value={renewDate}
                min={new Date().toISOString().split('T')[0]}
                onChange={(e) => setRenewDate(e.target.value)}
                className="min-h-[48px] h-12 bg-white"
              />
            </div>
          </div>

          <DialogFooter className="flex flex-col-reverse sm:flex-row gap-2">
            <Button
              variant="outline"
              onClick={() => setRenewingOffer(null)}
              disabled={isRenewing}
              className="min-h-[48px] h-12 w-full sm:w-auto"
            >
              {t('actionCancel')}
            </Button>
            <Button
              onClick={handleConfirmRenew}
              disabled={isRenewing || !renewDate}
              className="min-h-[48px] h-12 w-full sm:w-auto bg-[#0D9488] hover:bg-teal-700 text-white font-bold"
            >
              {isRenewing ? 'Processing...' : t('actionConfirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
