'use client';

import React, { useState, useTransition } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'next/navigation';
import { 
  Scale, 
  Send, 
  Loader2, 
  AlertTriangle, 
  RefreshCw, 
  DollarSign, 
  Package, 
  Calendar, 
  FileCheck, 
  Truck, 
  ShieldCheck, 
  FileText,
  TrendingDown,
  TrendingUp,
  Minus,
  Sparkles
} from 'lucide-react';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { toast } from 'sonner';
import { 
  buyerCounterOfferSchema, 
  BuyerCounterOfferFormValues,
  NEGOTIATION_PAYMENT_TERMS,
  NEGOTIATION_PACKAGING_TYPES,
  NEGOTIATION_FREIGHT_TERMS,
  NEGOTIATION_INSPECTION_TERMS
} from '@/src/lib/validations/buyer-negotiation-schema';
import { submitBuyerCounterOfferAction } from '@/src/server/actions/buyer-negotiation-actions';
import { cn } from '@/lib/utils';

export interface CounterOfferFormProps {
  proposalId: string;
  currentVersionNumber: number;
  unitSymbol?: string;
  initialData: {
    price: number;
    quantity: number;
    deliveryDate?: string | null;
    paymentTerms?: string | null;
    packaging?: string | null;
    freight?: string | null;
    inspection?: string | null;
    buyerNotes?: string | null;
  };
  onSuccess?: (newVersion: number) => void;
  onCancel?: () => void;
  className?: string;
}

export function CounterOfferForm({
  proposalId,
  currentVersionNumber,
  unitSymbol = 'MT',
  initialData,
  onSuccess,
  onCancel,
  className,
}: CounterOfferFormProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [staleVersionError, setStaleVersionError] = useState<string | null>(null);

  // Format today's date for date-picker min attribute (YYYY-MM-DD)
  const todayStr = new Date().toISOString().split('T')[0];

  const defaultDeliveryDate = initialData.deliveryDate
    ? initialData.deliveryDate.split('T')[0]
    : '';

  const form = useForm<BuyerCounterOfferFormValues>({
    resolver: zodResolver(buyerCounterOfferSchema),
    defaultValues: {
      proposal_id: proposalId,
      expected_version_number: currentVersionNumber,
      counter_price: initialData.price || 0,
      counter_quantity: initialData.quantity || 0,
      delivery_date: defaultDeliveryDate,
      payment_terms: initialData.paymentTerms || NEGOTIATION_PAYMENT_TERMS[0],
      packaging: initialData.packaging || NEGOTIATION_PACKAGING_TYPES[0],
      freight: initialData.freight || NEGOTIATION_FREIGHT_TERMS[0],
      inspection: initialData.inspection || NEGOTIATION_INSPECTION_TERMS[0],
      buyer_notes_to_broker: '',
    },
  });

  const watchedPrice = form.watch('counter_price');
  const watchedQuantity = form.watch('counter_quantity');
  const watchedNotes = form.watch('buyer_notes_to_broker') || '';

  // Calculate live deltas against current baseline
  const priceDelta = (watchedPrice || 0) - (initialData.price || 0);
  const qtyDelta = (watchedQuantity || 0) - (initialData.quantity || 0);
  const totalOfferedValue = (watchedPrice || 0) * (watchedQuantity || 0);

  const onSubmit = (values: BuyerCounterOfferFormValues) => {
    setStaleVersionError(null);

    startTransition(async () => {
      try {
        const res = await submitBuyerCounterOfferAction({
          proposal_id: values.proposal_id,
          expected_version_number: values.expected_version_number,
          counter_price: values.counter_price,
          counter_quantity: values.counter_quantity,
          delivery_date: typeof values.delivery_date === 'string' ? values.delivery_date : values.delivery_date?.toISOString(),
          payment_terms: values.payment_terms,
          packaging: values.packaging,
          freight: values.freight,
          inspection: values.inspection || null,
          buyer_notes_to_broker: values.buyer_notes_to_broker || null,
        });

        if (!res.success) {
          if (res.error === 'STALE_VERSION_DETECTED') {
            setStaleVersionError(
              res.message ||
                'The Broker Desk has revised this proposal to a newer version. Please refresh the page to view the latest terms before countering.'
            );
          } else {
            toast.error(res.message || res.error || 'Failed to submit counter offer.');
          }
          return;
        }

        const newVersion = res.newVersion || currentVersionNumber + 1;
        toast.success(
          `Counter offer submitted to Broker Desk (Version v${newVersion})!`
        );

        if (onSuccess) {
          onSuccess(newVersion);
        }

        router.refresh();
      } catch (err: any) {
        toast.error(err.message || 'An unexpected error occurred while submitting.');
      }
    });
  };

  return (
    <div className={cn('w-full max-w-full overflow-x-hidden space-y-4', className)}>
      {/* Stale Version Alert Banner */}
      {staleVersionError && (
        <Alert variant="destructive" className="rounded-xl border-rose-300 bg-rose-50 text-rose-900 animate-in fade-in-50">
          <AlertTriangle className="h-4 w-4 text-rose-600 shrink-0" />
          <AlertTitle className="text-xs font-bold">Stale Version Conflict</AlertTitle>
          <AlertDescription className="text-xs space-y-2 mt-1">
            <p>{staleVersionError}</p>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => router.refresh()}
              className="min-h-[44px] h-10 border-rose-300 text-rose-800 hover:bg-rose-100 font-bold text-xs"
            >
              <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
              <span>Refresh Deal to Latest Version</span>
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {/* Live Delta Summary Card */}
      <div className="rounded-xl p-3 sm:p-4 bg-sky-50/60 border border-sky-200/80 space-y-2 text-xs">
        <div className="flex items-center justify-between">
          <span className="font-bold text-slate-800 flex items-center gap-1.5 text-xs">
            <Sparkles className="w-3.5 h-3.5 text-[#0284C7]" />
            <span>Counter Terms Preview</span>
          </span>
          <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-white text-[#0284C7] border border-sky-200">
            Target v{currentVersionNumber + 1}
          </span>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 pt-1">
          <div className="bg-white p-2 rounded-lg border border-sky-100 shadow-2xs">
            <span className="text-[10px] text-slate-400 font-bold uppercase block">Rate Delta</span>
            <div className="flex items-center gap-1 font-extrabold text-xs sm:text-sm mt-0.5">
              {priceDelta === 0 ? (
                <span className="text-slate-600 flex items-center gap-0.5">
                  <Minus className="w-3 h-3 text-slate-400" /> Unchanged
                </span>
              ) : priceDelta < 0 ? (
                <span className="text-emerald-700 flex items-center gap-0.5">
                  <TrendingDown className="w-3.5 h-3.5 text-emerald-600" />
                  -₹{Math.abs(priceDelta).toLocaleString('en-IN')}
                </span>
              ) : (
                <span className="text-amber-700 flex items-center gap-0.5">
                  <TrendingUp className="w-3.5 h-3.5 text-amber-600" />
                  +₹{priceDelta.toLocaleString('en-IN')}
                </span>
              )}
            </div>
          </div>

          <div className="bg-white p-2 rounded-lg border border-sky-100 shadow-2xs">
            <span className="text-[10px] text-slate-400 font-bold uppercase block">Quantity Delta</span>
            <div className="flex items-center gap-1 font-extrabold text-xs sm:text-sm mt-0.5">
              {qtyDelta === 0 ? (
                <span className="text-slate-600 flex items-center gap-0.5">
                  <Minus className="w-3 h-3 text-slate-400" /> Unchanged
                </span>
              ) : (
                <span className={qtyDelta > 0 ? 'text-sky-700' : 'text-slate-700'}>
                  {qtyDelta > 0 ? `+${qtyDelta}` : qtyDelta} {unitSymbol}
                </span>
              )}
            </div>
          </div>

          <div className="bg-white p-2 rounded-lg border border-sky-100 shadow-2xs col-span-2 sm:col-span-1">
            <span className="text-[10px] text-slate-400 font-bold uppercase block">Counter Lot Total</span>
            <span className="font-extrabold text-xs sm:text-sm text-slate-900 mt-0.5 block truncate">
              ₹{totalOfferedValue.toLocaleString('en-IN')}
            </span>
          </div>
        </div>
      </div>

      {/* Main Form */}
      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
          <div className="flex flex-col md:grid md:grid-cols-2 gap-3.5 sm:gap-4">
            {/* 1. Counter Price (Numeric, inputMode="decimal") */}
            <FormField
              control={form.control}
              name="counter_price"
              render={({ field }) => (
                <FormItem className="space-y-1.5">
                  <FormLabel className="text-xs font-bold text-slate-800 flex items-center gap-1">
                    <DollarSign className="w-3.5 h-3.5 text-[#0284C7]" />
                    <span>Landed Counter Rate / {unitSymbol} (₹) *</span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      step="any"
                      inputMode="decimal"
                      placeholder="e.g. 52000"
                      disabled={isPending}
                      className="min-h-[48px] h-12 rounded-xl text-sm font-bold bg-white border-slate-300 focus:border-[#0284C7]"
                      {...field}
                      onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)}
                    />
                  </FormControl>
                  <FormMessage className="text-[11px]" />
                </FormItem>
              )}
            />

            {/* 2. Counter Quantity (Numeric, inputMode="decimal") */}
            <FormField
              control={form.control}
              name="counter_quantity"
              render={({ field }) => (
                <FormItem className="space-y-1.5">
                  <FormLabel className="text-xs font-bold text-slate-800 flex items-center gap-1">
                    <Package className="w-3.5 h-3.5 text-[#0284C7]" />
                    <span>Counter Volume ({unitSymbol}) *</span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      step="any"
                      inputMode="decimal"
                      placeholder="e.g. 25"
                      disabled={isPending}
                      className="min-h-[48px] h-12 rounded-xl text-sm font-bold bg-white border-slate-300 focus:border-[#0284C7]"
                      {...field}
                      onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)}
                    />
                  </FormControl>
                  <FormMessage className="text-[11px]" />
                </FormItem>
              )}
            />

            {/* 3. Delivery Date Picker (prevents past dates) */}
            <FormField
              control={form.control}
              name="delivery_date"
              render={({ field }) => (
                <FormItem className="space-y-1.5">
                  <FormLabel className="text-xs font-bold text-slate-800 flex items-center gap-1">
                    <Calendar className="w-3.5 h-3.5 text-[#0284C7]" />
                    <span>Target Delivery Date *</span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      type="date"
                      min={todayStr}
                      disabled={isPending}
                      className="min-h-[48px] h-12 rounded-xl text-sm bg-white border-slate-300 focus:border-[#0284C7]"
                      value={typeof field.value === 'string' ? field.value : ''}
                      onChange={(e) => field.onChange(e.target.value)}
                    />
                  </FormControl>
                  <FormMessage className="text-[11px]" />
                </FormItem>
              )}
            />

            {/* 4. Payment Terms Select Dropdown */}
            <FormField
              control={form.control}
              name="payment_terms"
              render={({ field }) => (
                <FormItem className="space-y-1.5">
                  <FormLabel className="text-xs font-bold text-slate-800 flex items-center gap-1">
                    <FileCheck className="w-3.5 h-3.5 text-[#0284C7]" />
                    <span>Payment Terms *</span>
                  </FormLabel>
                  <Select
                    disabled={isPending}
                    value={field.value}
                    onValueChange={(val: string | null) => field.onChange(val || '')}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full min-h-[48px] h-12 rounded-xl bg-white border-slate-300 text-xs sm:text-sm">
                        <SelectValue placeholder="Select Payment Terms" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {NEGOTIATION_PAYMENT_TERMS.map((opt) => (
                        <SelectItem key={opt} value={opt} className="min-h-[48px] text-xs sm:text-sm">
                          {opt}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage className="text-[11px]" />
                </FormItem>
              )}
            />

            {/* 5. Packaging Select Dropdown */}
            <FormField
              control={form.control}
              name="packaging"
              render={({ field }) => (
                <FormItem className="space-y-1.5">
                  <FormLabel className="text-xs font-bold text-slate-800 flex items-center gap-1">
                    <Package className="w-3.5 h-3.5 text-[#0284C7]" />
                    <span>Packaging Specification *</span>
                  </FormLabel>
                  <Select
                    disabled={isPending}
                    value={field.value}
                    onValueChange={(val: string | null) => field.onChange(val || '')}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full min-h-[48px] h-12 rounded-xl bg-white border-slate-300 text-xs sm:text-sm">
                        <SelectValue placeholder="Select Packaging" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {NEGOTIATION_PACKAGING_TYPES.map((opt) => (
                        <SelectItem key={opt} value={opt} className="min-h-[48px] text-xs sm:text-sm">
                          {opt}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage className="text-[11px]" />
                </FormItem>
              )}
            />

            {/* 6. Freight Terms Select Dropdown */}
            <FormField
              control={form.control}
              name="freight"
              render={({ field }) => (
                <FormItem className="space-y-1.5">
                  <FormLabel className="text-xs font-bold text-slate-800 flex items-center gap-1">
                    <Truck className="w-3.5 h-3.5 text-[#0284C7]" />
                    <span>Freight & Transit Terms *</span>
                  </FormLabel>
                  <Select
                    disabled={isPending}
                    value={field.value}
                    onValueChange={(val: string | null) => field.onChange(val || '')}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full min-h-[48px] h-12 rounded-xl bg-white border-slate-300 text-xs sm:text-sm">
                        <SelectValue placeholder="Select Freight Terms" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {NEGOTIATION_FREIGHT_TERMS.map((opt) => (
                        <SelectItem key={opt} value={opt} className="min-h-[48px] text-xs sm:text-sm">
                          {opt}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage className="text-[11px]" />
                </FormItem>
              )}
            />
          </div>

          {/* 7. Inspection Terms Select Dropdown (Full Width) */}
          <FormField
            control={form.control}
            name="inspection"
            render={({ field }) => (
              <FormItem className="space-y-1.5">
                <FormLabel className="text-xs font-bold text-slate-800 flex items-center gap-1">
                  <ShieldCheck className="w-3.5 h-3.5 text-[#0284C7]" />
                  <span>Quality Inspection & Lab Testing Requirement</span>
                </FormLabel>
                <Select
                  disabled={isPending}
                  value={field.value}
                  onValueChange={(val: string | null) => field.onChange(val || '')}
                >
                  <FormControl>
                    <SelectTrigger className="w-full min-h-[48px] h-12 rounded-xl bg-white border-slate-300 text-xs sm:text-sm">
                      <SelectValue placeholder="Select Inspection Terms" />
                    </SelectTrigger>
                  </FormControl>
                  <SelectContent>
                    {NEGOTIATION_INSPECTION_TERMS.map((opt) => (
                      <SelectItem key={opt} value={opt} className="min-h-[48px] text-xs sm:text-sm">
                        {opt}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <FormMessage className="text-[11px]" />
              </FormItem>
            )}
          />

          {/* 8. Textarea: Message to Broker */}
          <FormField
            control={form.control}
            name="buyer_notes_to_broker"
            render={({ field }) => (
              <FormItem className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <FormLabel className="text-xs font-bold text-slate-800 flex items-center gap-1">
                    <FileText className="w-3.5 h-3.5 text-[#0284C7]" />
                    <span>Commercial Note to Broker Desk (Optional)</span>
                  </FormLabel>
                  <span className="text-[11px] text-slate-400">
                    {watchedNotes.length}/500 chars
                  </span>
                </div>
                <FormControl>
                  <Textarea
                    rows={3}
                    disabled={isPending}
                    maxLength={500}
                    placeholder="Provide justification or remarks for the Broker Desk (e.g. Countering rate based on bulk lift commitment or market quote)..."
                    className="rounded-xl text-sm bg-white border-slate-300 focus:border-[#0284C7] resize-none"
                    {...field}
                  />
                </FormControl>
                <FormMessage className="text-[11px]" />
              </FormItem>
            )}
          />

          {/* Action Bar */}
          <div className="flex items-center justify-end gap-3 pt-2 border-t border-slate-100">
            {onCancel && (
              <Button
                type="button"
                variant="ghost"
                onClick={onCancel}
                disabled={isPending}
                className="min-h-[48px] px-5 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-100"
              >
                Cancel
              </Button>
            )}

            <Button
              type="submit"
              disabled={isPending}
              className="min-h-[48px] px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs sm:text-sm font-bold shadow-xs transition-colors flex items-center gap-2 cursor-pointer"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Submitting Counter to Broker Desk...</span>
                </>
              ) : (
                <>
                  <Send className="w-4 h-4" />
                  <span>Submit Counter Offer (v{currentVersionNumber + 1})</span>
                </>
              )}
            </Button>
          </div>
        </form>
      </Form>
    </div>
  );
}
