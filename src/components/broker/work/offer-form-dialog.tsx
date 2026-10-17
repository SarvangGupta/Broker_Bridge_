'use client';

import React, { useState, useEffect } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Alert, AlertDescription } from '@/components/ui/alert';
import {
  createBrokerSellerOfferAction,
  updateBrokerSellerOfferAction,
  getBrokerTradeFormMasterDataAction,
  type TradeMasterData,
  type BrokerOfferItem,
} from '@/src/server/actions/broker-mandate-actions';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { toast } from 'sonner';
import {
  Loader2,
  AlertCircle,
  Package,
  ShieldAlert,
  Building2,
  MapPin,
  Lock,
} from 'lucide-react';

interface OfferFormDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  offer?: BrokerOfferItem | null;
  onSuccess: () => void;
}

export function OfferFormDialog({
  open,
  onOpenChange,
  offer,
  onSuccess,
}: OfferFormDialogProps) {
  const { t, language } = useLanguage();
  const isEdit = Boolean(offer);

  // Form State
  const [sellerCompanyId, setSellerCompanyId] = useState('');
  const [commodityId, setCommodityId] = useState('');
  const [gradeId, setGradeId] = useState('');
  const [quantity, setQuantity] = useState('');
  const [unitId, setUnitId] = useState('');
  const [askingPrice, setAskingPrice] = useState('');
  const [confidentialPrice, setConfidentialPrice] = useState('');
  const [stateId, setStateId] = useState('');
  const [districtId, setDistrictId] = useState('');
  const [availableFrom, setAvailableFrom] = useState('');
  const [validUntil, setValidUntil] = useState('');
  const [loadingStatus, setLoadingStatus] = useState<
    'Not Ready' | 'Ready to Load' | 'Loading in Progress' | 'Delayed' | 'Blocked'
  >('Ready to Load');
  const [loadingRemarks, setLoadingRemarks] = useState('');

  // Master Data State
  const [masterData, setMasterData] = useState<TradeMasterData | null>(null);
  const [isLoadingMaster, setIsLoadingMaster] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Load Master Data on open
  useEffect(() => {
    if (open) {
      setErrorMessage(null);
      setIsLoadingMaster(true);
      getBrokerTradeFormMasterDataAction()
        .then((res) => {
          if (res.success && res.data) {
            setMasterData(res.data);
            if (!unitId && res.data.units.length > 0) {
              const mtUnit = res.data.units.find((u) => u.symbol === 'MT' || u.name.includes('Tonne'));
              setUnitId(mtUnit ? mtUnit.id : res.data.units[0].id);
            }
          } else {
            setErrorMessage(res.error || 'Failed to load master dropdown data');
          }
        })
        .finally(() => setIsLoadingMaster(false));
    }
  }, [open]);

  // Populate fields if editing
  useEffect(() => {
    if (offer) {
      setSellerCompanyId(offer.sellerCompanyId || '');
      setCommodityId(offer.commodityId || '');
      setGradeId(offer.gradeId || '');
      setQuantity(String(offer.offeredQuantity || ''));
      setAskingPrice(String(offer.askingPrice || ''));
      setConfidentialPrice(offer.confidentialMinimumPrice ? String(offer.confidentialMinimumPrice) : '');
      setStateId(offer.stateId || '');
      setDistrictId(offer.districtId || '');
      const af = offer.availableFrom ? offer.availableFrom.split('T')[0] : '';
      const vu = offer.validUntil ? offer.validUntil.split('T')[0] : '';
      setAvailableFrom(af);
      setValidUntil(vu);
      setLoadingStatus((offer.loadingStatus as any) || 'Ready to Load');
      setLoadingRemarks(offer.loadingRemarks || '');
    } else {
      const today = new Date().toISOString().split('T')[0];
      const future = new Date();
      future.setDate(future.getDate() + 14);
      setAvailableFrom(today);
      setValidUntil(future.toISOString().split('T')[0]);
      setQuantity('');
      setAskingPrice('');
      setConfidentialPrice('');
      setCommodityId('');
      setGradeId('');
      setSellerCompanyId('');
      setStateId('');
      setDistrictId('');
      setLoadingStatus('Ready to Load');
      setLoadingRemarks('');
    }
  }, [offer, open]);

  // Cascading Grades
  const availableGrades = React.useMemo(() => {
    if (!masterData || !commodityId) return [];
    return masterData.grades.filter((g) => g.commodityId === commodityId);
  }, [masterData, commodityId]);

  // Cascading Districts
  const availableDistricts = React.useMemo(() => {
    if (!masterData || !stateId) return [];
    return masterData.districts.filter((d) => d.stateId === stateId);
  }, [masterData, stateId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    // Client-side validations
    if (!sellerCompanyId) {
      setErrorMessage(t('valSellerRequired'));
      return;
    }
    if (!commodityId) {
      setErrorMessage(t('valCommodityRequired'));
      return;
    }
    if (!gradeId) {
      setErrorMessage(t('valGradeRequired'));
      return;
    }
    const numQty = parseFloat(quantity);
    if (isNaN(numQty) || numQty <= 0) {
      setErrorMessage(t('valQuantityPositive'));
      return;
    }
    const numPrice = parseFloat(askingPrice);
    if (isNaN(numPrice) || numPrice <= 0) {
      setErrorMessage(t('valPricePositive'));
      return;
    }
    const numFloor = confidentialPrice ? parseFloat(confidentialPrice) : null;
    if (numFloor !== null && (isNaN(numFloor) || numFloor <= 0)) {
      setErrorMessage('Floor price must be greater than zero');
      return;
    }
    if (numFloor !== null && numFloor > numPrice) {
      setErrorMessage('Confidential floor price cannot exceed asking price');
      return;
    }
    if (!stateId) {
      setErrorMessage('Please select a warehouse state location');
      return;
    }
    if (!districtId) {
      setErrorMessage('Please select a mandi/district location');
      return;
    }
    if (!unitId) {
      setErrorMessage('Please select a measurement unit');
      return;
    }
    if (!availableFrom || !validUntil) {
      setErrorMessage('Please specify available from and valid until dates');
      return;
    }

    const vuDate = new Date(validUntil);
    const afDate = new Date(availableFrom);
    if (vuDate < afDate) {
      setErrorMessage('Validity expiration date cannot precede available from date');
      return;
    }

    // Quantity integrity for Edit mode
    if (isEdit && offer) {
      const minRequired = (offer.reservedQuantity || 0) + (offer.soldQuantity || 0);
      if (numQty < minRequired) {
        setErrorMessage(
          `Total offered lot cannot be reduced below committed volume (${minRequired} MT: ${offer.reservedQuantity} MT reserved, ${offer.soldQuantity} MT sold).`
        );
        return;
      }
    }

    setIsSubmitting(true);
    try {
      if (isEdit && offer) {
        const res = await updateBrokerSellerOfferAction(offer.id, {
          companyId: sellerCompanyId,
          commodityId,
          gradeId,
          quantity: numQty,
          unitId,
          askingPrice: numPrice,
          confidentialMinimumPrice: numFloor,
          stateId,
          districtId,
          availableFrom: new Date(availableFrom).toISOString(),
          validUntil: new Date(validUntil).toISOString(),
          loadingStatus,
          loadingRemarks: loadingRemarks.trim() || undefined,
          expectedVersion: offer.version,
        });

        if (res.success) {
          toast.success(t('recordUpdatedSuccess'));
          onOpenChange(false);
          onSuccess();
        } else {
          setErrorMessage(res.error || 'Failed to update seller offer');
        }
      } else {
        const res = await createBrokerSellerOfferAction({
          companyId: sellerCompanyId,
          commodityId,
          gradeId,
          quantity: numQty,
          unitId,
          askingPrice: numPrice,
          confidentialMinimumPrice: numFloor,
          stateId,
          districtId,
          availableFrom: new Date(availableFrom).toISOString(),
          validUntil: new Date(validUntil).toISOString(),
          loadingStatus,
          loadingRemarks: loadingRemarks.trim() || undefined,
        });

        if (res.success) {
          toast.success(t('offerCreatedSuccess'));
          onOpenChange(false);
          onSuccess();
        } else {
          setErrorMessage(res.error || 'Failed to create seller offer');
        }
      }
    } catch (err: any) {
      setErrorMessage(err?.message || 'An unexpected error occurred');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-lg bg-teal-50 text-[#0D9488]">
              <Package className="w-5 h-5" />
            </div>
            <div>
              <DialogTitle className="text-xl font-bold text-slate-900">
                {isEdit ? t('actionEditOffer') : t('actionCreateOffer')}
              </DialogTitle>
              <DialogDescription className="text-xs text-slate-500 mt-0.5">
                {t('brokerDisclaimerNotOwner')}
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        {errorMessage && (
          <Alert variant="destructive" className="py-2.5">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <AlertDescription className="text-xs">{errorMessage}</AlertDescription>
          </Alert>
        )}

        {isLoadingMaster ? (
          <div className="py-12 flex flex-col items-center justify-center gap-2 text-slate-500">
            <Loader2 className="w-6 h-6 animate-spin text-[#0D9488]" />
            <p className="text-xs">{t('loadingText')}</p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4 pt-2">
            {/* Seller Company Selection */}
            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">
                {t('fieldSelectSeller')} <span className="text-rose-500">*</span>
              </Label>
              <Select
                value={sellerCompanyId}
                onValueChange={(val) => setSellerCompanyId(val || '')}
                disabled={isEdit}
              >
                <SelectTrigger className="min-h-[48px] h-12 bg-white">
                  <SelectValue placeholder={t('fieldSelectSeller')} />
                </SelectTrigger>
                <SelectContent className="max-h-60">
                  {masterData?.sellerCompanies.map((c) => (
                    <SelectItem key={c.id} value={c.id} className="min-h-[44px]">
                      <div className="flex items-center gap-2">
                        <Building2 className="w-4 h-4 text-slate-400" />
                        <span>{c.name}</span>
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Commodity & Grade Row */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldCommodity')} <span className="text-rose-500">*</span>
                </Label>
                <Select
                  value={commodityId}
                  onValueChange={(val) => {
                    setCommodityId(val || '');
                    setGradeId('');
                  }}
                >
                  <SelectTrigger className="min-h-[48px] h-12 bg-white">
                    <SelectValue placeholder={t('valCommodityRequired')} />
                  </SelectTrigger>
                  <SelectContent className="max-h-60">
                    {masterData?.commodities.map((comm) => (
                      <SelectItem key={comm.id} value={comm.id} className="min-h-[44px]">
                        <span>{comm.name}</span>
                        {comm.categoryName && (
                          <span className="text-xs text-slate-400 ml-1.5">({comm.categoryName})</span>
                        )}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldGrade')} <span className="text-rose-500">*</span>
                </Label>
                <Select
                  value={gradeId}
                  onValueChange={(val) => setGradeId(val || '')}
                  disabled={!commodityId || availableGrades.length === 0}
                >
                  <SelectTrigger className="min-h-[48px] h-12 bg-white">
                    <SelectValue
                      placeholder={
                        !commodityId
                          ? 'Select commodity first'
                          : availableGrades.length === 0
                          ? 'No grades available'
                          : t('valGradeRequired')
                      }
                    />
                  </SelectTrigger>
                  <SelectContent className="max-h-60">
                    {availableGrades.map((g) => (
                      <SelectItem key={g.id} value={g.id} className="min-h-[44px]">
                        {g.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Quantity & Unit Row */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('qtyOffered')} <span className="text-rose-500">*</span>
                </Label>
                <Input
                  type="number"
                  step="any"
                  min="0.01"
                  placeholder="e.g. 250"
                  value={quantity}
                  onChange={(e) => setQuantity(e.target.value)}
                  className="min-h-[48px] h-12 bg-white"
                />
                {isEdit && offer && (offer.reservedQuantity > 0 || offer.soldQuantity > 0) && (
                  <p className="text-[11px] text-amber-700 font-medium">
                    Committed: {offer.reservedQuantity} MT reserved, {offer.soldQuantity} MT sold. Minimum total allowed: {(offer.reservedQuantity || 0) + (offer.soldQuantity || 0)} MT.
                  </p>
                )}
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldUnit')} <span className="text-rose-500">*</span>
                </Label>
                <Select value={unitId} onValueChange={(val) => setUnitId(val || '')}>
                  <SelectTrigger className="min-h-[48px] h-12 bg-white">
                    <SelectValue placeholder={t('fieldUnit')} />
                  </SelectTrigger>
                  <SelectContent>
                    {masterData?.units.map((u) => (
                      <SelectItem key={u.id} value={u.id} className="min-h-[44px]">
                        {u.name} ({u.symbol})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Asking Price & Confidential Floor Price */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldAskingPrice')} (₹/MT) <span className="text-rose-500">*</span>
                </Label>
                <Input
                  type="number"
                  step="any"
                  min="0.01"
                  placeholder="e.g. 54500"
                  value={askingPrice}
                  onChange={(e) => setAskingPrice(e.target.value)}
                  className="min-h-[48px] h-12 bg-white"
                />
              </div>

              <div className="space-y-1.5">
                <div className="flex items-center gap-1.5">
                  <Label className="text-xs font-semibold text-slate-700">
                    {t('fieldFloorPrice')} (₹/MT)
                  </Label>
                  <span title="Confidential Broker Only">
                    <Lock className="w-3 h-3 text-amber-600" />
                  </span>
                </div>
                <Input
                  type="number"
                  step="any"
                  min="0.01"
                  placeholder="Optional broker floor"
                  value={confidentialPrice}
                  onChange={(e) => setConfidentialPrice(e.target.value)}
                  className="min-h-[48px] h-12 bg-white"
                />
              </div>
            </div>

            {/* Location: State & District */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldLocation')} <span className="text-rose-500">*</span>
                </Label>
                <Select
                  value={stateId}
                  onValueChange={(val) => {
                    setStateId(val || '');
                    setDistrictId('');
                  }}
                >
                  <SelectTrigger className="min-h-[48px] h-12 bg-white">
                    <SelectValue placeholder="Select Warehouse State" />
                  </SelectTrigger>
                  <SelectContent className="max-h-60">
                    {masterData?.states.map((s) => (
                      <SelectItem key={s.id} value={s.id} className="min-h-[44px]">
                        {s.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldDistrict')} <span className="text-rose-500">*</span>
                </Label>
                <Select
                  value={districtId}
                  onValueChange={(val) => setDistrictId(val || '')}
                  disabled={!stateId || availableDistricts.length === 0}
                >
                  <SelectTrigger className="min-h-[48px] h-12 bg-white">
                    <SelectValue
                      placeholder={
                        !stateId
                          ? 'Select state first'
                          : availableDistricts.length === 0
                          ? 'No districts available'
                          : t('fieldDistrict')
                      }
                    />
                  </SelectTrigger>
                  <SelectContent className="max-h-60">
                    {availableDistricts.map((d) => (
                      <SelectItem key={d.id} value={d.id} className="min-h-[44px]">
                        {d.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Dates: Available From & Valid Until */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldAvailableFrom')} <span className="text-rose-500">*</span>
                </Label>
                <Input
                  type="date"
                  value={availableFrom}
                  onChange={(e) => setAvailableFrom(e.target.value)}
                  className="min-h-[48px] h-12 bg-white"
                />
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldValidUntil')} <span className="text-rose-500">*</span>
                </Label>
                <Input
                  type="date"
                  value={validUntil}
                  min={availableFrom || new Date().toISOString().split('T')[0]}
                  onChange={(e) => setValidUntil(e.target.value)}
                  className="min-h-[48px] h-12 bg-white"
                />
              </div>
            </div>

            {/* Loading Readiness & Remarks */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldLoadingStatus')}
                </Label>
                <Select
                  value={loadingStatus}
                  onValueChange={(val: any) => setLoadingStatus((val || 'Ready to Load') as any)}
                >
                  <SelectTrigger className="min-h-[48px] h-12 bg-white">
                    <SelectValue placeholder={t('fieldLoadingStatus')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Ready to Load" className="min-h-[44px]">
                      Ready to Load (Immediate dispatch)
                    </SelectItem>
                    <SelectItem value="Not Ready" className="min-h-[44px]">
                      Not Ready (Material in processing)
                    </SelectItem>
                    <SelectItem value="Loading in Progress" className="min-h-[44px]">
                      Loading in Progress
                    </SelectItem>
                    <SelectItem value="Delayed" className="min-h-[44px]">
                      Delayed (Logistics/Labor pending)
                    </SelectItem>
                    <SelectItem value="Blocked" className="min-h-[44px]">
                      Blocked
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldQualityNotes')}
                </Label>
                <Input
                  placeholder="e.g. Weighbridge on site, 50kg bags"
                  value={loadingRemarks}
                  onChange={(e) => setLoadingRemarks(e.target.value)}
                  className="min-h-[48px] h-12 bg-white"
                />
              </div>
            </div>

            <DialogFooter className="pt-2 flex flex-col-reverse sm:flex-row gap-2">
              <Button
                type="button"
                variant="outline"
                onClick={() => onOpenChange(false)}
                disabled={isSubmitting}
                className="min-h-[48px] h-12 w-full sm:w-auto"
              >
                {t('actionCancel')}
              </Button>
              <Button
                type="submit"
                disabled={isSubmitting}
                className="min-h-[48px] h-12 w-full sm:w-auto bg-[#0D9488] hover:bg-teal-700 text-white font-bold"
              >
                {isSubmitting ? (
                  <div className="flex items-center gap-2">
                    <Loader2 className="w-4 h-4 animate-spin" />
                    <span>Processing...</span>
                  </div>
                ) : (
                  <span>{isEdit ? t('actionSave') : t('actionCreateOffer')}</span>
                )}
              </Button>
            </DialogFooter>
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
}
