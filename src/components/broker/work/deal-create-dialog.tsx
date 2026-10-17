'use client';

import React, { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
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
import { Badge } from '@/components/ui/badge';
import {
  Handshake,
  Building2,
  Scale,
  Calendar,
  MapPin,
  FileText,
  AlertCircle,
  Loader2,
  ShieldCheck,
  CheckCircle2,
  ArrowRight,
} from 'lucide-react';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { createDealFromAllocationAction } from '@/src/server/actions/broker-deal-actions';
import type { BrokerAllocationDetail } from '@/src/server/actions/broker-allocation-actions';
import { toast } from 'sonner';

interface DealCreateDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  allocation: BrokerAllocationDetail | null;
  commodityName?: string;
  gradeName?: string | null;
  onSuccess?: (dealId: string) => void;
}

export function DealCreateDialog({
  open,
  onOpenChange,
  allocation,
  commodityName = 'Raw Material',
  gradeName,
  onSuccess,
}: DealCreateDialogProps) {
  const router = useRouter();
  const { t, language, formatNumber, formatCurrency } = useLanguage();
  const [isPending, startTransition] = useTransition();

  const [agreedPrice, setAgreedPrice] = useState<string>(
    allocation?.allocatedPrice ? String(allocation.allocatedPrice) : '52000'
  );
  const [agreedQuantity, setAgreedQuantity] = useState<string>(
    allocation?.allocatedQuantity ? String(allocation.allocatedQuantity) : '100'
  );
  const [priceBasis, setPriceBasis] = useState<string>(
    allocation?.priceBasis || 'FOR_DESTINATION'
  );
  const [deliveryLocation, setDeliveryLocation] = useState<string>(
    'Destination Buyer Hub / Mill'
  );
  const [deliveryDate, setDeliveryDate] = useState<string>(
    new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0]
  );
  const [deliveryTerms, setDeliveryTerms] = useState<string>('Ex-Warehouse / FOR');
  const [paymentTerms, setPaymentTerms] = useState<string>(
    '100% Advance against Invoice / Bank Transfer'
  );
  const [packagingType, setPackagingType] = useState<string>('50kg Jute Bags');
  const [brokerCommissionRate, setBrokerCommissionRate] = useState<string>('250');
  const [notes, setNotes] = useState<string>(allocation?.notes || '');
  const [formError, setFormError] = useState<string | null>(null);

  // Sync state when allocation changes
  React.useEffect(() => {
    if (allocation) {
      setAgreedPrice(allocation.allocatedPrice ? String(allocation.allocatedPrice) : '52000');
      setAgreedQuantity(String(allocation.allocatedQuantity));
      setPriceBasis(allocation.priceBasis || 'FOR_DESTINATION');
      setNotes(allocation.notes || '');
      setFormError(null);
    }
  }, [allocation]);

  if (!allocation) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    const priceNum = Number(agreedPrice);
    const qtyNum = Number(agreedQuantity);

    if (isNaN(priceNum) || priceNum <= 0) {
      setFormError(
        language === 'hi'
          ? 'कृपया मान्य सहमत मूल्य दर्ज करें'
          : 'Please enter a valid agreed price greater than zero'
      );
      return;
    }

    if (isNaN(qtyNum) || qtyNum <= 0) {
      setFormError(
        language === 'hi'
          ? 'कृपया मान्य अनुबंध मात्रा दर्ज करें'
          : 'Please enter a valid contract quantity'
      );
      return;
    }

    startTransition(async () => {
      const res = await createDealFromAllocationAction({
        allocationId: allocation.id,
        customTerms: {
          agreedPrice: priceNum,
          agreedQuantity: qtyNum,
          priceBasis,
          deliveryLocation: deliveryLocation.trim(),
          deliveryDate,
          deliveryTerms: deliveryTerms.trim(),
          paymentTerms: paymentTerms.trim(),
          packagingType: packagingType.trim(),
          brokerCommissionRate: Number(brokerCommissionRate) || 0,
          commissionBasis: '₹/MT',
          notes: notes.trim(),
        },
      });

      if (res.success && res.dealId) {
        toast.success(t('dealCreatedSuccess'));
        onOpenChange(false);
        if (onSuccess) {
          onSuccess(res.dealId);
        } else {
          router.push(`/broker/deals/${res.dealId}`);
        }
      } else {
        setFormError(res.error || 'Failed to create deal');
        toast.error(res.error || 'Failed to create deal');
      }
    });
  };

  const unitStr = allocation.unitSymbol || allocation.unitName || 'MT';
  const totalValuation = (Number(agreedPrice) || 0) * (Number(agreedQuantity) || 0);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-xl bg-teal-50 border border-teal-200/80 text-[#0D9488]">
              <Handshake className="w-5 h-5" />
            </div>
            <div>
              <DialogTitle className="text-lg font-bold text-slate-900">
                {t('createDealFromAllocation')}
              </DialogTitle>
              <DialogDescription className="text-xs text-slate-500">
                {language === 'hi'
                  ? 'आवंटन से औपचारिक सौदा अनुबंध तैयार करें और बातचीत शुरू करें।'
                  : 'Convert confirmed allocation into an authoritative deal draft and open negotiation.'}
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        {/* Allocation Context Header */}
        <div className="p-3 bg-slate-50 dark:bg-slate-900/60 rounded-xl border border-slate-200 dark:border-slate-800 space-y-2 text-xs">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <span className="font-mono font-bold text-slate-800 dark:text-slate-200">
                {allocation.allocationReference}
              </span>
              <Badge variant="outline" className="text-[10px] bg-emerald-50 text-emerald-700 border-emerald-200">
                {t('allocationStatusConfirmed')}
              </Badge>
            </div>
            <div className="font-mono text-xs font-semibold text-teal-700">
              {formatNumber(allocation.allocatedQuantity)} {unitStr}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-2 text-slate-600 dark:text-slate-400">
            <div>
              <span className="text-slate-400 block text-[11px]">{t('filterMaterial')}:</span>
              <span className="font-semibold text-slate-800 dark:text-slate-200">
                {commodityName} {gradeName ? `(${gradeName})` : ''}
              </span>
            </div>
            <div>
              <span className="text-slate-400 block text-[11px]">Seller:</span>
              <span className="font-semibold text-slate-800 dark:text-slate-200 flex items-center gap-1">
                <Building2 className="w-3.5 h-3.5 text-slate-400" />
                {allocation.sellerCompanyName}
              </span>
            </div>
          </div>
        </div>

        {formError && (
          <div className="p-3 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2 text-xs text-red-700">
            <AlertCircle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
            <span>{formError}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4 pt-1">
          {/* Commercial Terms Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div>
              <Label className="text-xs font-semibold text-slate-700">
                {t('contractQuantity')} ({unitStr}) *
              </Label>
              <Input
                type="number"
                value={agreedQuantity}
                onChange={(e) => setAgreedQuantity(e.target.value)}
                min="0.1"
                step="any"
                required
                className="text-xs h-9 font-mono mt-1"
              />
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700">
                {t('agreedPrice')} (₹/{unitStr}) *
              </Label>
              <Input
                type="number"
                value={agreedPrice}
                onChange={(e) => setAgreedPrice(e.target.value)}
                min="1"
                step="any"
                required
                className="text-xs h-9 font-mono mt-1"
              />
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700">
                {t('allocationPriceBasisLabel')}
              </Label>
              <select
                value={priceBasis}
                onChange={(e) => setPriceBasis(e.target.value)}
                className="w-full text-xs h-9 mt-1 rounded-md border border-slate-200 bg-white px-3 py-1 text-slate-900 shadow-xs focus:outline-hidden focus:ring-1 focus:ring-teal-600"
              >
                <option value="FOR_DESTINATION">FOR Destination (Freight Included)</option>
                <option value="EX_MILL">Ex-Mill / Ex-Warehouse (Buyer Arranges Freight)</option>
                <option value="FOR_BUYER_MILL">FOR Buyer Mill</option>
              </select>
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700">
                {t('brokerageCommission')} (₹/{unitStr})
              </Label>
              <Input
                type="number"
                value={brokerCommissionRate}
                onChange={(e) => setBrokerCommissionRate(e.target.value)}
                min="0"
                step="any"
                className="text-xs h-9 font-mono mt-1"
              />
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700 flex items-center gap-1">
                <MapPin className="w-3.5 h-3.5 text-slate-400" />
                Delivery Location
              </Label>
              <Input
                value={deliveryLocation}
                onChange={(e) => setDeliveryLocation(e.target.value)}
                placeholder="e.g. Warehouse Bay 4, Industrial Area"
                className="text-xs h-9 mt-1"
              />
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700 flex items-center gap-1">
                <Calendar className="w-3.5 h-3.5 text-slate-400" />
                Target Delivery Date
              </Label>
              <Input
                type="date"
                value={deliveryDate}
                onChange={(e) => setDeliveryDate(e.target.value)}
                className="text-xs h-9 font-mono mt-1"
              />
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700">Payment Terms</Label>
              <Input
                value={paymentTerms}
                onChange={(e) => setPaymentTerms(e.target.value)}
                className="text-xs h-9 mt-1"
              />
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700">Packaging Type</Label>
              <Input
                value={packagingType}
                onChange={(e) => setPackagingType(e.target.value)}
                className="text-xs h-9 mt-1"
              />
            </div>
          </div>

          <div>
            <Label className="text-xs font-semibold text-slate-700">
              Commercial Notes & Special Conditions
            </Label>
            <Input
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="e.g. Moisture max 12%, weighment at receiver weighbridge..."
              className="text-xs h-9 mt-1"
            />
          </div>

          {/* Valuation summary bar */}
          <div className="p-3 bg-teal-50/70 border border-teal-200/80 rounded-xl flex items-center justify-between text-xs">
            <span className="text-teal-900 font-medium">Estimated Contract Valuation:</span>
            <span className="font-mono font-bold text-teal-800 text-sm">
              {formatCurrency(totalValuation)}
            </span>
          </div>

          <DialogFooter className="gap-2 pt-2">
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
              type="submit"
              size="sm"
              className="bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-semibold text-xs"
              disabled={isPending}
            >
              {isPending ? (
                <>
                  <Loader2 className="w-3.5 h-3.5 mr-1.5 animate-spin" />
                  {language === 'hi' ? 'सौदा तैयार हो रहा है...' : 'Creating Deal...'}
                </>
              ) : (
                <>
                  <Handshake className="w-3.5 h-3.5 mr-1.5" />
                  {t('createDeal')}
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
