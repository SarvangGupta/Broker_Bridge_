'use client';

import React, { useState, useEffect, useTransition } from 'react';
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
import { Badge } from '@/components/ui/badge';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Scale,
  Building2,
  Tag,
  AlertCircle,
  CheckCircle2,
  Info,
  Loader2,
  ShieldAlert,
} from 'lucide-react';
import { useLanguage } from '@/src/lib/i18n/language-context';
import {
  proposeAllocationAction,
  confirmAllocationAction,
} from '@/src/server/actions/broker-allocation-actions';
import type { MatchedRequirementDetail, RankedBrokerSupplyMatch } from '@/src/server/actions/broker-match-actions';
import { toast } from 'sonner';

interface AllocationDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  requirement: MatchedRequirementDetail | null;
  offer: RankedBrokerSupplyMatch | null;
  onAllocationSuccess?: () => void;
}

export function AllocationDialog({
  open,
  onOpenChange,
  requirement,
  offer,
  onAllocationSuccess,
}: AllocationDialogProps) {
  const { t, formatCurrency, formatNumber, language } = useLanguage();
  const [isPending, startTransition] = useTransition();

  const [quantity, setQuantity] = useState<string>('');
  const [priceBasis, setPriceBasis] = useState<string>('FOR_DESTINATION');
  const [allocatedPrice, setAllocatedPrice] = useState<string>('');
  const [notes, setNotes] = useState<string>('');
  const [autoConfirm, setAutoConfirm] = useState<boolean>(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const remainingReqQty = requirement?.remainingQuantity ?? 0;
  const availableOfferQty = offer?.availableQuantity ?? 0;
  const unitLabel = requirement?.unitSymbol || requirement?.unitName || 'MT';

  // Initialize defaults on open
  useEffect(() => {
    if (requirement && offer) {
      const defaultQty = Math.min(requirement.remainingQuantity, offer.availableQuantity);
      setQuantity(defaultQty > 0 ? String(defaultQty) : '');
      setAllocatedPrice(String(offer.askingPrice || requirement.targetPrice || ''));
      setPriceBasis('FOR_DESTINATION');
      setNotes('');
      setErrorMsg(null);
    }
  }, [requirement, offer, open]);

  if (!requirement || !offer) return null;

  const numQty = parseFloat(quantity) || 0;
  const isOverReq = numQty > remainingReqQty;
  const isOverOffer = numQty > availableOfferQty;
  const isInvalidQty = numQty <= 0 || isOverReq || isOverOffer;

  const newRemainingReq = Math.max(0, remainingReqQty - numQty);
  const newRemainingOffer = Math.max(0, availableOfferQty - numQty);

  const handleSubmit = () => {
    setErrorMsg(null);
    if (numQty <= 0) {
      setErrorMsg(t('valAllocationPositive'));
      return;
    }
    if (isOverReq) {
      setErrorMsg(t('valAllocationExceedsReq'));
      return;
    }
    if (isOverOffer) {
      setErrorMsg(t('valAllocationExceedsOffer'));
      return;
    }

    startTransition(async () => {
      const proposeRes = await proposeAllocationAction({
        requirementId: requirement.id,
        availabilityId: offer.id,
        allocatedQuantity: numQty,
        priceBasis,
        allocatedPrice: parseFloat(allocatedPrice) || offer.askingPrice,
        notes: notes.trim() || undefined,
      });

      if (!proposeRes.success || !proposeRes.allocationId) {
        setErrorMsg(proposeRes.error || 'Failed to record proposed allocation');
        toast.error(proposeRes.error || 'Failed to record allocation');
        return;
      }

      if (autoConfirm) {
        const confirmRes = await confirmAllocationAction({
          allocationId: proposeRes.allocationId,
        });

        if (!confirmRes.success) {
          setErrorMsg(confirmRes.error || 'Allocation proposed but confirmation failed');
          toast.warning(`Allocation recorded as PROPOSED, but could not be confirmed: ${confirmRes.error}`);
          onAllocationSuccess?.();
          onOpenChange(false);
          return;
        }

        toast.success(t('allocationConfirmedSuccess'));
      } else {
        toast.success(t('allocationCreatedSuccess'));
      }

      onAllocationSuccess?.();
      onOpenChange(false);
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center gap-2">
            <Scale className="w-5 h-5 text-emerald-600" />
            <DialogTitle className="text-xl font-bold">
              {t('allocationDialogTitle')}
            </DialogTitle>
          </div>
          <DialogDescription className="text-sm text-slate-500">
            {t('allocationDialogDesc')}
          </DialogDescription>
        </DialogHeader>

        {/* Legal & Fiduciary Non-Reservation Disclaimer */}
        <div className="p-3 bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800 rounded-lg flex items-start gap-2.5 text-xs text-amber-800 dark:text-amber-300">
          <ShieldAlert className="w-4 h-4 mt-0.5 shrink-0 text-amber-600" />
          <p className="leading-relaxed">
            {t('brokerDisclaimerMatching')}
          </p>
        </div>

        {/* Matched Pair Summary */}
        <div className="grid grid-cols-2 gap-3 text-xs bg-slate-50 dark:bg-slate-900 p-3 rounded-lg border border-slate-200 dark:border-slate-800">
          <div>
            <span className="text-slate-500 block mb-1 font-medium">{t('navRequirements')}</span>
            <p className="font-semibold text-slate-800 dark:text-slate-200 text-sm">
              {requirement.requirementRef}
            </p>
            <p className="text-slate-600 dark:text-slate-400">
              {requirement.commodityName} • {requirement.gradeName}
            </p>
            <div className="mt-1 flex items-center gap-1.5">
              <span className="text-slate-500">{t('remainingQty')}:</span>
              <Badge variant="outline" className="font-mono font-bold text-emerald-700 bg-emerald-50 border-emerald-200">
                {formatNumber(remainingReqQty)} {unitLabel}
              </Badge>
            </div>
          </div>

          <div>
            <span className="text-slate-500 block mb-1 font-medium">{t('navOffers')}</span>
            <p className="font-semibold text-slate-800 dark:text-slate-200 text-sm">
              {offer.sellerCompanyName}
            </p>
            <p className="text-slate-600 dark:text-slate-400">
              {offer.lotNumber || 'Active Lot'} • {offer.gradeName}
            </p>
            <div className="mt-1 flex items-center gap-1.5">
              <span className="text-slate-500">{t('qtyAvailable')}:</span>
              <Badge variant="outline" className="font-mono font-bold text-blue-700 bg-blue-50 border-blue-200">
                {formatNumber(availableOfferQty)} {unitLabel}
              </Badge>
            </div>
          </div>
        </div>

        {/* Input Fields */}
        <div className="space-y-4 pt-1">
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <Label className="text-xs font-semibold text-slate-700 dark:text-slate-300">
                {t('allocationQtyLabel')} ({unitLabel}) *
              </Label>
              <button
                type="button"
                onClick={() => setQuantity(String(Math.min(remainingReqQty, availableOfferQty)))}
                className="text-xs text-emerald-600 hover:text-emerald-700 font-semibold underline"
              >
                {language === 'hi' ? 'अधिकतम संभव मात्रा भरें' : 'Fill Max Available'} ({Math.min(remainingReqQty, availableOfferQty)} {unitLabel})
              </button>
            </div>
            <Input
              type="number"
              step="any"
              min="0.1"
              value={quantity}
              onChange={(e) => setQuantity(e.target.value)}
              placeholder="e.g. 50"
              className={isInvalidQty && quantity ? 'border-red-500 focus-visible:ring-red-400' : ''}
            />
            {isOverReq && (
              <p className="text-xs text-red-500 mt-1 flex items-center gap-1">
                <AlertCircle className="w-3.5 h-3.5" />
                {t('valAllocationExceedsReq')} ({remainingReqQty} {unitLabel})
              </p>
            )}
            {isOverOffer && !isOverReq && (
              <p className="text-xs text-red-500 mt-1 flex items-center gap-1">
                <AlertCircle className="w-3.5 h-3.5" />
                {t('valAllocationExceedsOffer')} ({availableOfferQty} {unitLabel})
              </p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label className="text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5 block">
                {t('allocationPriceBasisLabel')}
              </Label>
              <Select value={priceBasis} onValueChange={(val) => { if (val) setPriceBasis(val); }}>
                <SelectTrigger className="text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="FOR_DESTINATION">FOR Destination (Delivered)</SelectItem>
                  <SelectItem value="EX_WAREHOUSE">Ex-Warehouse (Mandi)</SelectItem>
                  <SelectItem value="CIF">CIF (Port/Railhead)</SelectItem>
                  <SelectItem value="FOB">FOB (Free on Board)</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5 block">
                {t('allocationPriceLabel')} (₹/{unitLabel})
              </Label>
              <Input
                type="number"
                step="any"
                value={allocatedPrice}
                onChange={(e) => setAllocatedPrice(e.target.value)}
                placeholder="₹ Per Unit"
                className="text-xs font-mono"
              />
            </div>
          </div>

          <div>
            <Label className="text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5 block">
              {t('allocationNotesLabel')}
            </Label>
            <Textarea
              rows={2}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Operational notes, delivery terms, inspection conditions..."
              className="text-xs resize-none"
            />
          </div>

          {/* Allocation Balance Simulation */}
          {numQty > 0 && !isOverReq && !isOverOffer && (
            <div className="p-3 bg-emerald-50 dark:bg-emerald-950/20 border border-emerald-200 dark:border-emerald-800 rounded-lg text-xs space-y-1.5">
              <span className="font-semibold text-emerald-900 dark:text-emerald-300 flex items-center gap-1">
                <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                {language === 'hi' ? 'आवंटन प्रभाव पूर्वावलोकन' : 'Allocation Impact Simulation'}
              </span>
              <div className="grid grid-cols-2 gap-2 text-slate-700 dark:text-slate-300 pt-1">
                <div>
                  <span className="text-slate-500 block">{language === 'hi' ? 'मांग का नया शेष:' : 'New Requirement Balance:'}</span>
                  <span className="font-mono font-bold text-slate-900 dark:text-white">
                    {formatNumber(newRemainingReq)} {unitLabel} {newRemainingReq === 0 ? '✓ (100% Covered)' : ''}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block">{language === 'hi' ? 'विक्रेता लॉट का नया शेष:' : 'New Seller Lot Balance:'}</span>
                  <span className="font-mono font-bold text-slate-900 dark:text-white">
                    {formatNumber(newRemainingOffer)} {unitLabel}
                  </span>
                </div>
              </div>
            </div>
          )}

          {errorMsg && (
            <div className="p-2.5 bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 rounded-lg text-xs text-red-700 dark:text-red-400 flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}

          <div className="flex items-center gap-2 pt-1">
            <input
              type="checkbox"
              id="autoConfirm"
              checked={autoConfirm}
              onChange={(e) => setAutoConfirm(e.target.checked)}
              className="rounded border-slate-300 text-emerald-600 focus:ring-emerald-500 h-4 w-4"
            />
            <label htmlFor="autoConfirm" className="text-xs font-medium text-slate-700 dark:text-slate-300 cursor-pointer">
              {language === 'hi'
                ? 'तत्काल पुष्टि करें (आरक्षण लॉक और शेष राशि अपडेट करें)'
                : 'Confirm immediately (Locks quantity and increments fulfilled balance)'}
            </label>
          </div>
        </div>

        <DialogFooter className="pt-2 gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => onOpenChange(false)}
            disabled={isPending}
          >
            {language === 'hi' ? 'रद्द करें' : 'Cancel'}
          </Button>
          <Button
            type="button"
            size="sm"
            className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
            onClick={handleSubmit}
            disabled={isPending || isInvalidQty}
          >
            {isPending ? (
              <>
                <Loader2 className="w-4 h-4 mr-1.5 animate-spin" />
                {language === 'hi' ? 'प्रक्रिया जारी...' : 'Processing...'}
              </>
            ) : autoConfirm ? (
              t('confirmAllocation')
            ) : (
              t('proposeAllocation')
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
