'use client';

import React, { useState, useTransition, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { 
  RefreshCw, 
  X, 
  TrendingDown, 
  TrendingUp, 
  Minus, 
  Calendar, 
  Scale, 
  Coins, 
  MessageSquare,
  AlertTriangle,
  Loader2
} from 'lucide-react';
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
import { Textarea } from '@/components/ui/textarea';
import { counterBuyerProposalAction } from '@/src/server/actions/buyer-proposal-actions';
import { toast } from 'sonner';

interface ProposalCounterDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  proposalId: string;
  expectedVersionNumber: number;
  currentPrice: number;
  currentQuantity: number;
  unitSymbol: string;
  commodityName: string;
  initialDeliveryDate?: string | null;
  onSuccess?: () => void;
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-IN', {
    maximumFractionDigits: 0,
  }).format(amount);
}

export function ProposalCounterDrawer({
  isOpen,
  onClose,
  proposalId,
  expectedVersionNumber,
  currentPrice,
  currentQuantity,
  unitSymbol,
  commodityName,
  initialDeliveryDate,
  onSuccess,
}: ProposalCounterDrawerProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  const [counterPrice, setCounterPrice] = useState<number | ''>(currentPrice);
  const [counterQuantity, setCounterQuantity] = useState<number | ''>(currentQuantity);
  const [deliveryDate, setDeliveryDate] = useState<string>(
    initialDeliveryDate ? initialDeliveryDate.split('T')[0] : ''
  );
  const [buyerNotes, setBuyerNotes] = useState<string>('');

  // Commercial Delta Calculations
  const numericPrice = typeof counterPrice === 'number' ? counterPrice : 0;
  const numericQuantity = typeof counterQuantity === 'number' ? counterQuantity : 0;

  const currentTotal = currentPrice * currentQuantity;
  const counterTotal = numericPrice * numericQuantity;
  const totalCostDiff = counterTotal - currentTotal;
  const priceUnitDiff = numericPrice - currentPrice;
  const quantityDiff = numericQuantity - currentQuantity;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!counterPrice || counterPrice <= 0) {
      toast.error('Please enter a valid counter price per unit.');
      return;
    }

    if (!counterQuantity || counterQuantity <= 0) {
      toast.error('Please enter a valid counter volume.');
      return;
    }

    startTransition(async () => {
      try {
        const res = await counterBuyerProposalAction({
          proposalId,
          expectedVersionNumber,
          counterPrice: Number(counterPrice),
          counterQuantity: Number(counterQuantity),
          deliveryDate: deliveryDate || undefined,
          buyerNotes: buyerNotes.trim() || undefined,
        });

        if (res.success) {
          toast.success(`Counter-offer submitted to Broker desk (Round ${res.newVersion || expectedVersionNumber + 1})!`);
          onClose();
          if (onSuccess) onSuccess();
          router.refresh();
        } else if (res.error === 'STALE_VERSION_DETECTED') {
          toast.error('The Broker has updated this proposal. Please refresh to review the latest terms.', {
            action: {
              label: 'Refresh',
              onClick: () => router.refresh(),
            },
            duration: 8000,
          });
          onClose();
        } else {
          toast.error(res.error || 'Failed to submit counter-offer.');
        }
      } catch (err: any) {
        toast.error(err.message || 'An unexpected error occurred.');
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="w-full max-w-lg max-h-[92vh] overflow-y-auto p-4 sm:p-6 rounded-2xl bg-white border border-slate-200 shadow-xl">
        <DialogHeader className="pb-3 border-b border-slate-100">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-sky-50 text-[#0284C7] flex items-center justify-center border border-sky-100 shrink-0">
              <RefreshCw className="w-4 h-4" />
            </div>
            <div>
              <DialogTitle className="text-base sm:text-lg font-bold text-slate-900 leading-tight">
                Submit Counter-Offer
              </DialogTitle>
              <DialogDescription className="text-xs text-slate-500">
                {commodityName} — Propose revised commercial terms to your broker
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 pt-2">
          {/* 1. Price & Quantity Fields */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            {/* Counter Price */}
            <div className="space-y-1.5">
              <label 
                htmlFor="counterPrice" 
                className="text-xs font-semibold text-slate-700 flex items-center gap-1.5"
              >
                <Coins className="w-3.5 h-3.5 text-[#0284C7]" />
                <span>Counter Rate (₹ / {unitSymbol}) *</span>
              </label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-sm font-semibold">
                  ₹
                </span>
                <Input
                  id="counterPrice"
                  type="number"
                  inputMode="decimal"
                  min="1"
                  step="any"
                  required
                  disabled={isPending}
                  value={counterPrice}
                  onChange={(e) => setCounterPrice(e.target.value === '' ? '' : Number(e.target.value))}
                  placeholder={String(currentPrice)}
                  className="pl-8 min-h-[48px] h-12 text-sm font-bold text-slate-900 rounded-xl border-slate-200 focus-visible:ring-[#0284C7]"
                />
              </div>
              <span className="text-[11px] text-slate-400 block">
                Current offered rate: ₹{formatCurrency(currentPrice)}/{unitSymbol}
              </span>
            </div>

            {/* Counter Quantity */}
            <div className="space-y-1.5">
              <label 
                htmlFor="counterQuantity" 
                className="text-xs font-semibold text-slate-700 flex items-center gap-1.5"
              >
                <Scale className="w-3.5 h-3.5 text-[#0284C7]" />
                <span>Volume ({unitSymbol}) *</span>
              </label>
              <Input
                id="counterQuantity"
                type="number"
                inputMode="numeric"
                min="1"
                step="any"
                required
                disabled={isPending}
                value={counterQuantity}
                onChange={(e) => setCounterQuantity(e.target.value === '' ? '' : Number(e.target.value))}
                placeholder={String(currentQuantity)}
                className="min-h-[48px] h-12 text-sm font-bold text-slate-900 rounded-xl border-slate-200 focus-visible:ring-[#0284C7]"
              />
              <span className="text-[11px] text-slate-400 block">
                Current volume: {formatCurrency(currentQuantity)} {unitSymbol}
              </span>
            </div>
          </div>

          {/* 2. Target Delivery Date */}
          <div className="space-y-1.5">
            <label 
              htmlFor="deliveryDate" 
              className="text-xs font-semibold text-slate-700 flex items-center gap-1.5"
            >
              <Calendar className="w-3.5 h-3.5 text-[#0284C7]" />
              <span>Target Delivery Date (Optional)</span>
            </label>
            <Input
              id="deliveryDate"
              type="date"
              disabled={isPending}
              value={deliveryDate}
              onChange={(e) => setDeliveryDate(e.target.value)}
              className="min-h-[48px] h-12 text-xs sm:text-sm text-slate-800 rounded-xl border-slate-200 focus-visible:ring-[#0284C7]"
            />
          </div>

          {/* 3. Live Delta Preview Card */}
          <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-2 text-xs">
            <div className="flex items-center justify-between gap-2">
              <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">
                Counter Commercial Impact
              </span>
              <span className="text-[11px] font-bold text-slate-700">
                Round {expectedVersionNumber + 1} Preview
              </span>
            </div>

            <div className="grid grid-cols-2 gap-2 pt-1 border-t border-slate-200/60">
              <div>
                <span className="text-slate-400 block text-[11px]">Proposed Total Value</span>
                <span className="text-sm font-bold text-slate-900">
                  ₹{formatCurrency(counterTotal)}
                </span>
              </div>

              <div>
                <span className="text-slate-400 block text-[11px]">Cost Movement</span>
                {totalCostDiff < 0 ? (
                  <span className="inline-flex items-center gap-1 text-emerald-700 font-bold text-xs">
                    <TrendingDown className="w-3.5 h-3.5" />
                    <span>-₹{formatCurrency(Math.abs(totalCostDiff))} (Savings)</span>
                  </span>
                ) : totalCostDiff > 0 ? (
                  <span className="inline-flex items-center gap-1 text-amber-700 font-bold text-xs">
                    <TrendingUp className="w-3.5 h-3.5" />
                    <span>+₹{formatCurrency(totalCostDiff)}</span>
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 text-slate-500 font-semibold text-xs">
                    <Minus className="w-3.5 h-3.5" />
                    <span>Unchanged</span>
                  </span>
                )}
              </div>
            </div>

            {priceUnitDiff !== 0 && (
              <div className="pt-1 text-[11px] text-slate-500">
                Rate adjustment:{' '}
                <span className="font-semibold text-slate-800">
                  {priceUnitDiff < 0 ? `-₹${formatCurrency(Math.abs(priceUnitDiff))}` : `+₹${formatCurrency(priceUnitDiff)}`} / {unitSymbol}
                </span>
              </div>
            )}
          </div>

          {/* 4. Notes to Broker */}
          <div className="space-y-1.5">
            <label 
              htmlFor="buyerNotes" 
              className="text-xs font-semibold text-slate-700 flex items-center gap-1.5"
            >
              <MessageSquare className="w-3.5 h-3.5 text-[#0284C7]" />
              <span>Notes to Broker (Commercial Rationale)</span>
            </label>
            <Textarea
              id="buyerNotes"
              rows={3}
              disabled={isPending}
              value={buyerNotes}
              onChange={(e) => setBuyerNotes(e.target.value)}
              placeholder="e.g. Target rate is ₹24,800/MT based on local mandi arrivals. Can confirm order today if delivered within 4 days."
              className="min-h-[80px] text-xs sm:text-sm text-slate-800 rounded-xl border-slate-200 focus-visible:ring-[#0284C7] resize-none"
            />
          </div>

          {/* 5. Footer Buttons with min-h-[48px] */}
          <DialogFooter className="flex flex-col-reverse sm:flex-row items-stretch sm:items-center justify-end gap-2 pt-2 border-t border-slate-100">
            <Button
              type="button"
              variant="outline"
              disabled={isPending}
              onClick={onClose}
              className="min-h-[48px] h-12 px-5 rounded-xl border-slate-200 text-slate-700 hover:bg-slate-50 text-xs sm:text-sm font-semibold"
            >
              Cancel
            </Button>

            <Button
              type="submit"
              disabled={isPending}
              className="min-h-[48px] h-12 px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] active:bg-[#075985] text-white text-xs sm:text-sm font-bold shadow-xs hover:shadow transition-all"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  <span>Submitting Counter...</span>
                </>
              ) : (
                <>
                  <RefreshCw className="w-4 h-4 mr-1.5" />
                  <span>Send Counter-Offer</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
