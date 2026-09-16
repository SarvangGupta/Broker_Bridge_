'use client';

import React, { useState, useTransition, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import {
  Send,
  Building2,
  ShieldCheck,
  Tag,
  Layers,
  Calendar,
  IndianRupee,
  Lock,
  Clock,
  Sparkles,
  Info,
  AlertCircle,
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
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { formatIndianCurrency } from '@/lib/utils';
import type { BrokerSupplyLot } from '@/src/server/actions/broker-supply-actions';
import { createBrokerRequestToSellerAction } from '@/src/server/actions/broker-outbound-actions';
import { toast } from 'sonner';

interface SendRequestDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  lot: BrokerSupplyLot | null;
  requirementContext?: {
    id: string;
    ref: string;
    commodityName?: string;
    quantity?: number;
    unit?: string;
  } | null;
  onSuccess?: () => void;
}

export function SendRequestDialog({
  open,
  onOpenChange,
  lot,
  requirementContext,
  onSuccess,
}: SendRequestDialogProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  const [proposedQuantity, setProposedQuantity] = useState<number>(50);
  const [proposedPrice, setProposedPrice] = useState<number>(0);
  const [deliveryDate, setDeliveryDate] = useState<string>('');
  const [brokerMessage, setBrokerMessage] = useState<string>('');

  // Pre-fill values whenever lot or requirementContext changes
  useEffect(() => {
    if (lot) {
      // Proposed quantity default
      const defaultQty = requirementContext?.quantity || Math.min(lot.availableQuantity, 50);
      setProposedQuantity(defaultQty);

      // Proposed price default (asking price from lot)
      setProposedPrice(lot.askingPrice);

      // Delivery date default (7 days ahead formatted YYYY-MM-DD)
      const defaultDelivery = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
      setDeliveryDate(defaultDelivery.toISOString().split('T')[0]);

      // Default broker message
      setBrokerMessage(
        'Broker proposal: Verified buyer requirement ready for immediate dispatch and standard escrow settlement.'
      );
    }
  }, [lot, requirementContext]);

  if (!lot) return null;

  const unitSymbol = lot.unitSymbol || lot.unitName || 'MT';
  const formattedAskingPrice = formatIndianCurrency(lot.askingPrice);
  const formattedFloorPrice = lot.confidentialMinimumPrice
    ? formatIndianCurrency(lot.confidentialMinimumPrice)
    : formattedAskingPrice;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!requirementContext?.id) {
      toast.error('No Buyer Requirement linked. Please select a requirement first.');
      return;
    }

    if (proposedQuantity <= 0) {
      toast.error('Proposed quantity must be greater than zero.');
      return;
    }

    if (proposedPrice <= 0) {
      toast.error('Proposed price must be greater than zero.');
      return;
    }

    startTransition(async () => {
      const res = await createBrokerRequestToSellerAction({
        requirement_id: requirementContext.id,
        availability_id: lot.id,
        proposed_quantity: proposedQuantity,
        proposed_price: proposedPrice,
        delivery_date: deliveryDate || null,
        broker_message: brokerMessage.trim() || undefined,
      });

      if (res.success) {
        toast.success(`Commercial request sent to ${lot.sellerCompanyName}!`);
        onOpenChange(false);
        if (onSuccess) {
          onSuccess();
        } else {
          router.push('/broker/work');
        }
      } else {
        toast.error(res.error || 'Failed to dispatch request to seller.');
      }
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg max-h-[90vh] overflow-y-auto p-4 sm:p-6 rounded-2xl">
        <DialogHeader className="text-left space-y-1 pb-2 border-b border-slate-100">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-teal-50 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
              <Send className="w-4 h-4" />
            </div>
            <div>
              <DialogTitle className="text-base sm:text-lg font-bold text-slate-900">
                Send Request to Seller
              </DialogTitle>
              <DialogDescription className="text-xs text-slate-500">
                Submit an outbound commercial proposal to Seller{' '}
                <span className="font-semibold text-slate-700">{lot.sellerCompanyName}</span>.
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 py-2">
          {/* 1. Target Summary Strip */}
          <div className="p-3 rounded-xl bg-slate-50 border border-slate-200/80 space-y-2 text-xs">
            <div className="flex items-center justify-between gap-2 flex-wrap">
              <span className="font-bold text-slate-800 text-sm">
                {lot.commodityName} <span className="text-[#0D9488]">• {lot.gradeName}</span>
              </span>
              <span className="font-mono text-[11px] text-slate-500 bg-white px-2 py-0.5 rounded border border-slate-200">
                {lot.lotNumber}
              </span>
            </div>

            <div className="grid grid-cols-2 gap-2 text-slate-600 pt-1 border-t border-slate-200/60">
              <div>
                <span className="text-[10px] uppercase font-bold text-slate-400 block">
                  Available Supply
                </span>
                <span className="font-semibold text-slate-800">
                  {lot.availableQuantity} {unitSymbol}
                </span>
              </div>
              <div>
                <span className="text-[10px] uppercase font-bold text-slate-400 block">
                  Seller Asking Rate
                </span>
                <span className="font-semibold text-slate-800">{formattedAskingPrice} / {unitSymbol}</span>
              </div>
            </div>

            {/* Confidential Floor Price (Broker only) */}
            <div className="flex items-center justify-between gap-2 pt-1 border-t border-slate-200/60 text-[11px] bg-amber-50/60 p-1.5 rounded text-amber-900">
              <div className="flex items-center gap-1 font-bold text-amber-800">
                <Lock className="w-3.5 h-3.5 text-amber-600" />
                <span>Broker Negotiation Floor:</span>
              </div>
              <span className="font-mono font-bold">{formattedFloorPrice} / {unitSymbol}</span>
            </div>
          </div>

          {/* 2. Linked Requirement Pill */}
          {requirementContext && (
            <div className="p-2.5 rounded-lg bg-teal-50/80 border border-teal-200/60 flex items-center justify-between text-xs">
              <span className="text-teal-800 font-medium">
                Fulfilling Buyer Requirement:
              </span>
              <span className="font-mono font-bold text-[#0D9488] bg-white px-2 py-0.5 rounded border border-teal-200">
                {requirementContext.ref}
              </span>
            </div>
          )}

          {/* 3. Proposed Quantity & Price Inputs */}
          <div className="grid grid-cols-2 gap-3">
            {/* Proposed Quantity */}
            <div className="space-y-1.5">
              <Label className="text-xs font-bold text-slate-700">
                Proposed Quantity ({unitSymbol}) *
              </Label>
              <Input
                type="number"
                min="1"
                max={lot.availableQuantity}
                value={proposedQuantity}
                onChange={(e) => setProposedQuantity(Number(e.target.value))}
                required
                className="min-h-[44px] h-11 bg-white border-slate-200 text-xs sm:text-sm font-semibold focus-visible:ring-[#0D9488]"
              />
              <span className="text-[10px] text-slate-400 block">
                Max available: {lot.availableQuantity} {unitSymbol}
              </span>
            </div>

            {/* Proposed Price */}
            <div className="space-y-1.5">
              <Label className="text-xs font-bold text-slate-700">
                Proposed Rate (₹/{unitSymbol}) *
              </Label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold text-xs">
                  ₹
                </span>
                <Input
                  type="number"
                  min="1"
                  value={proposedPrice}
                  onChange={(e) => setProposedPrice(Number(e.target.value))}
                  required
                  className="pl-7 min-h-[44px] h-11 bg-white border-slate-200 text-xs sm:text-sm font-bold text-slate-900 focus-visible:ring-[#0D9488]"
                />
              </div>
              <span className="text-[10px] text-slate-400 block">
                Asking: {formattedAskingPrice}
              </span>
            </div>
          </div>

          {/* 4. Target Delivery Date */}
          <div className="space-y-1.5">
            <Label className="text-xs font-bold text-slate-700 flex items-center gap-1">
              <Calendar className="w-3.5 h-3.5 text-[#0D9488]" />
              <span>Target Delivery Date</span>
            </Label>
            <Input
              type="date"
              value={deliveryDate}
              onChange={(e) => setDeliveryDate(e.target.value)}
              className="min-h-[44px] h-11 bg-white border-slate-200 text-xs sm:text-sm focus-visible:ring-[#0D9488]"
            />
          </div>

          {/* 5. Message to Seller */}
          <div className="space-y-1.5">
            <Label className="text-xs font-bold text-slate-700">
              Commercial Message to Seller (Optional)
            </Label>
            <Textarea
              placeholder="e.g. Buyer requires immediate loading with 100% letter of credit settlement..."
              value={brokerMessage}
              onChange={(e) => setBrokerMessage(e.target.value)}
              rows={3}
              className="text-xs sm:text-sm resize-none focus-visible:ring-[#0D9488]"
            />
            <p className="text-[10px] text-slate-400 italic">
              Privacy Protected: Buyer identity is automatically masked.
            </p>
          </div>

          {/* 6. Footer Actions */}
          <DialogFooter className="flex flex-col sm:flex-row gap-2 pt-3 border-t border-slate-100">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={isPending}
              className="min-h-[48px] h-12 w-full sm:w-auto text-xs font-semibold"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={isPending || proposedQuantity <= 0 || proposedPrice <= 0}
              className="min-h-[48px] h-12 flex-1 bg-[#0D9488] hover:bg-teal-700 text-white font-bold text-sm shadow-xs rounded-xl flex items-center justify-center gap-2"
            >
              {isPending ? (
                <span>Dispatching Request...</span>
              ) : (
                <>
                  <Send className="w-4 h-4" />
                  <span>Send Commercial Request</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
