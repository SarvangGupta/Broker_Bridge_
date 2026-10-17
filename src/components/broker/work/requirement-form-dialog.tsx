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
  createBrokerRequirementAction,
  updateBrokerRequirementAction,
  getBrokerTradeFormMasterDataAction,
  type TradeMasterData,
  type BrokerRequirementItem,
} from '@/src/server/actions/broker-mandate-actions';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { toast } from 'sonner';
import { Loader2, AlertCircle, FileText, CheckCircle2, Building2 } from 'lucide-react';

interface RequirementFormDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  requirement?: BrokerRequirementItem | null;
  onSuccess: () => void;
}

export function RequirementFormDialog({
  open,
  onOpenChange,
  requirement,
  onSuccess,
}: RequirementFormDialogProps) {
  const { t, language } = useLanguage();
  const isEdit = Boolean(requirement);

  // Form State
  const [buyerCompanyId, setBuyerCompanyId] = useState('');
  const [commodityId, setCommodityId] = useState('');
  const [gradeId, setGradeId] = useState('');
  const [quantity, setQuantity] = useState('');
  const [unitId, setUnitId] = useState('');
  const [targetPrice, setTargetPrice] = useState('');
  const [deliveryTerms, setDeliveryTerms] = useState('FOR Destination');
  const [targetDate, setTargetDate] = useState('');
  const [notes, setNotes] = useState('');

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
              // Default to MT unit if available
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
    if (requirement) {
      setBuyerCompanyId(requirement.buyerCompanyId || '');
      setCommodityId(requirement.commodityId || '');
      setGradeId(requirement.gradeId || '');
      setQuantity(String(requirement.requestedQuantity || ''));
      setTargetPrice(String(requirement.targetPrice || ''));
      setDeliveryTerms(requirement.deliveryTerms || 'FOR Destination');
      const d = requirement.targetDate ? requirement.targetDate.split('T')[0] : '';
      setTargetDate(d);
      setNotes('');
    } else {
      // Default new requirement date 7 days from today
      const future = new Date();
      future.setDate(future.getDate() + 7);
      setTargetDate(future.toISOString().split('T')[0]);
      setQuantity('');
      setTargetPrice('');
      setCommodityId('');
      setGradeId('');
      setBuyerCompanyId('');
      setNotes('');
    }
  }, [requirement, open]);

  // Filter grades based on selected commodity
  const availableGrades = React.useMemo(() => {
    if (!masterData || !commodityId) return [];
    return masterData.grades.filter((g) => g.commodityId === commodityId);
  }, [masterData, commodityId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    // Client-side validations
    if (!buyerCompanyId) {
      setErrorMessage(t('valBuyerRequired'));
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
    const numPrice = parseFloat(targetPrice);
    if (isNaN(numPrice) || numPrice <= 0) {
      setErrorMessage(t('valPricePositive'));
      return;
    }
    if (!unitId) {
      setErrorMessage('Please select a measurement unit');
      return;
    }
    if (!targetDate) {
      setErrorMessage(t('valDateFuture'));
      return;
    }

    // Expiry check
    const selectedDate = new Date(targetDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (selectedDate < today) {
      setErrorMessage(t('valDateFuture'));
      return;
    }

    // Quantity integrity check for Edit mode
    if (isEdit && requirement) {
      if (numQty < requirement.allocatedQuantity) {
        setErrorMessage(
          `Requested quantity (${numQty} MT) cannot be less than already allocated quantity (${requirement.allocatedQuantity} MT).`
        );
        return;
      }
    }

    setIsSubmitting(true);
    try {
      if (isEdit && requirement) {
        const res = await updateBrokerRequirementAction(requirement.id, {
          companyId: buyerCompanyId,
          commodityId,
          gradeId,
          quantity: numQty,
          unitId,
          targetPrice: numPrice,
          deliveryTermsId: deliveryTerms,
          targetDate: new Date(targetDate).toISOString(),
          notes: notes.trim() || undefined,
        });

        if (res.success) {
          toast.success(t('recordUpdatedSuccess'));
          onOpenChange(false);
          onSuccess();
        } else {
          setErrorMessage(res.error || 'Failed to update requirement');
        }
      } else {
        const res = await createBrokerRequirementAction({
          companyId: buyerCompanyId,
          commodityId,
          gradeId,
          quantity: numQty,
          unitId,
          targetPrice: numPrice,
          deliveryTermsId: deliveryTerms,
          targetDate: new Date(targetDate).toISOString(),
          notes: notes.trim() || undefined,
        });

        if (res.success) {
          toast.success(t('requirementCreatedSuccess'));
          onOpenChange(false);
          onSuccess();
        } else {
          setErrorMessage(res.error || 'Failed to create requirement');
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
              <FileText className="w-5 h-5" />
            </div>
            <div>
              <DialogTitle className="text-xl font-bold text-slate-900">
                {isEdit ? t('actionEditRequirement') : t('actionCreateRequirement')}
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
            {/* Buyer Selection */}
            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">
                {t('fieldSelectBuyer')} <span className="text-rose-500">*</span>
              </Label>
              <Select
                value={buyerCompanyId}
                onValueChange={(val) => setBuyerCompanyId(val || '')}
                disabled={isEdit} // Buyer company cannot be changed during update for audit safety
              >
                <SelectTrigger className="min-h-[48px] h-12 bg-white">
                  <SelectValue placeholder={t('fieldSelectBuyer')} />
                </SelectTrigger>
                <SelectContent className="max-h-60">
                  {masterData?.buyerCompanies.map((c) => (
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
                    setGradeId(''); // reset grade when commodity changes
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
                  {t('fieldQuantity')} <span className="text-rose-500">*</span>
                </Label>
                <Input
                  type="number"
                  step="any"
                  min="0.01"
                  placeholder="e.g. 100"
                  value={quantity}
                  onChange={(e) => setQuantity(e.target.value)}
                  className="min-h-[48px] h-12 bg-white"
                />
                {isEdit && requirement && requirement.allocatedQuantity > 0 && (
                  <p className="text-[11px] text-amber-700 font-medium">
                    Allocated so far: {requirement.allocatedQuantity} {requirement.unitSymbol}. Cannot reduce below this.
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

            {/* Price & Delivery Terms */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldTargetPrice')} (₹) <span className="text-rose-500">*</span>
                </Label>
                <Input
                  type="number"
                  step="any"
                  min="0.01"
                  placeholder="e.g. 52000"
                  value={targetPrice}
                  onChange={(e) => setTargetPrice(e.target.value)}
                  className="min-h-[48px] h-12 bg-white"
                />
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">
                  {t('fieldDeliveryTerms')}
                </Label>
                <Select value={deliveryTerms} onValueChange={(val) => setDeliveryTerms(val || 'FOR Destination')}>
                  <SelectTrigger className="min-h-[48px] h-12 bg-white">
                    <SelectValue placeholder={t('fieldDeliveryTerms')} />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="FOR Destination" className="min-h-[44px]">
                      FOR Destination (Delivered at Mill)
                    </SelectItem>
                    <SelectItem value="Ex-Factory" className="min-h-[44px]">
                      Ex-Factory / Ex-Warehouse (Buyer arranges freight)
                    </SelectItem>
                    <SelectItem value="CIF Port" className="min-h-[44px]">
                      CIF Port
                    </SelectItem>
                    <SelectItem value="FOB Mandi" className="min-h-[44px]">
                      FOB Mandi
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            {/* Target Delivery Date */}
            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">
                {t('fieldDeliveryDate')} <span className="text-rose-500">*</span>
              </Label>
              <Input
                type="date"
                value={targetDate}
                min={new Date().toISOString().split('T')[0]}
                onChange={(e) => setTargetDate(e.target.value)}
                className="min-h-[48px] h-12 bg-white"
              />
            </div>

            {/* Notes & Quality Requirements */}
            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">
                {t('fieldQualityNotes')}
              </Label>
              <Textarea
                rows={3}
                placeholder="Specific moisture, purity, packaging, or inspection requirements..."
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                className="bg-white resize-none text-xs"
              />
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
                  <span>{isEdit ? t('actionSave') : t('actionCreateRequirement')}</span>
                )}
              </Button>
            </DialogFooter>
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
}
