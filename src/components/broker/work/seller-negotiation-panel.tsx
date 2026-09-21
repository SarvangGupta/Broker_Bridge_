'use client';

import React, { useState, useTransition, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import {
  Form,
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormMessage,
  FormDescription,
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Building2,
  PackageCheck,
  Send,
  Loader2,
  Lock,
  Sparkles,
  ShieldCheck,
  Calendar,
  IndianRupee,
  Layers,
  AlertCircle,
  FileCheck2,
  CheckCircle2,
} from 'lucide-react';
import { toast } from 'sonner';
import {
  sendProposalToSellerSchema,
  type SendProposalToSellerPayload,
  type SellerNegotiationDetails,
} from '@/src/types/negotiation-schema';
import { sendProposalToSellerAction } from '@/src/server/actions/broker-negotiation-actions';
import { BrokerSellerTimeline } from './broker-seller-timeline';
import type { NegotiationTimelineItem } from '@/src/types/deal-version-schema';

interface SellerNegotiationPanelProps {
  details: SellerNegotiationDetails;
  timeline?: NegotiationTimelineItem[];
  onRefresh?: () => void;
}

export function SellerNegotiationPanel({
  details,
  timeline = [],
  onRefresh,
}: SellerNegotiationPanelProps) {
  const [isPending, startTransition] = useTransition();
  const [serverError, setServerError] = useState<string | null>(null);

  const form = useForm<SendProposalToSellerPayload>({
    resolver: zodResolver(sendProposalToSellerSchema),
    defaultValues: {
      request_id: details.requestId,
      offered_price: details.offeredPrice || details.askingPrice,
      quantity: details.proposedQuantity || details.availableQuantity,
      delivery_date: details.deliveryDate || '',
      payment_terms: details.paymentTerms || 'Standard Settlement via Broker Desk',
      packaging: details.packagingType || 'Standard Packaging',
      broker_notes: '',
      expected_version_number: details.currentVersionNumber,
    },
  });

  // Re-sync form default values if active proposal details change
  useEffect(() => {
    form.reset({
      request_id: details.requestId,
      offered_price: details.offeredPrice || details.askingPrice,
      quantity: details.proposedQuantity || details.availableQuantity,
      delivery_date: details.deliveryDate || '',
      payment_terms: details.paymentTerms || 'Standard Settlement via Broker Desk',
      packaging: details.packagingType || 'Standard Packaging',
      broker_notes: '',
      expected_version_number: details.currentVersionNumber,
    });
  }, [details, form]);

  const onSubmit = (data: SendProposalToSellerPayload) => {
    setServerError(null);

    startTransition(async () => {
      // GUARANTEED PRIVACY LOCK: Exclude any buyer PII or private buyer fields
      const payload: SendProposalToSellerPayload = {
        request_id: details.requestId,
        offered_price: Number(data.offered_price),
        quantity: Number(data.quantity),
        delivery_date: data.delivery_date || null,
        payment_terms: data.payment_terms || 'Standard Settlement via Broker Desk',
        packaging: data.packaging || 'Standard Packaging',
        broker_notes: data.broker_notes?.trim() || '',
        expected_version_number: details.currentVersionNumber,
      };

      const res = await sendProposalToSellerAction(payload);

      if (res.success) {
        toast.success(res.message || `Proposal v${res.newVersion} sent to Seller!`);
        form.setValue('broker_notes', '');
        if (onRefresh) onRefresh();
      } else {
        setServerError(res.error || 'Failed to dispatch proposal to Seller');
        toast.error(res.error || 'Failed to dispatch proposal');
      }
    });
  };

  const unitSymbol = details.unitSymbol || 'MT';
  const priceDelta = details.confidentialMinimumPrice
    ? form.watch('offered_price') - details.confidentialMinimumPrice
    : null;

  return (
    <div className="w-full space-y-6">
      {/* 1. SELLER CHANNEL HEADER CARD */}
      <Card className="border border-slate-200/90 shadow-sm bg-gradient-to-r from-slate-900 via-slate-800 to-teal-950 text-white overflow-hidden">
        <CardContent className="p-4 sm:p-6 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-white/10">
            {/* Seller Company & Lot Badges */}
            <div className="space-y-1">
              <div className="flex items-center gap-2 flex-wrap">
                <Badge className="bg-teal-500/20 text-teal-300 border-teal-500/30 font-mono text-[10px] tracking-wider uppercase">
                  SELLER CHANNEL
                </Badge>
                <Badge className="bg-slate-800 text-slate-200 border-slate-700 font-mono text-[10px]">
                  v{details.currentVersionNumber} Active
                </Badge>
                <Badge variant="outline" className="text-emerald-400 border-emerald-500/40 text-[10px]">
                  {details.currentStatus}
                </Badge>
              </div>

              <h3 className="text-lg sm:text-xl font-bold tracking-tight text-white flex items-center gap-2 mt-1">
                <Building2 className="w-5 h-5 text-teal-400 shrink-0" />
                <span>{details.sellerCompanyName}</span>
                {details.sellerCompanyVerified && (
                  <ShieldCheck className="w-4 h-4 text-teal-400 shrink-0" />
                )}
              </h3>

              <p className="text-xs text-slate-300 font-medium">
                Lot Number: <span className="font-mono text-teal-300 font-bold">{details.lotNumber}</span>
              </p>
            </div>

            {/* Commodity & Grade Badges */}
            <div className="text-left sm:text-right space-y-1">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white/10 text-xs font-semibold">
                <PackageCheck className="w-3.5 h-3.5 text-teal-300" />
                <span>{details.commodityName}</span>
              </div>
              <p className="text-[11px] text-slate-300 font-mono">
                {details.gradeName}
              </p>
            </div>
          </div>

          {/* Key Metrics Banner */}
          <div className="grid grid-cols-2 gap-2.5 pt-1">
            <div className="p-2.5 rounded-lg bg-white/5 border border-white/10 min-w-0">
              <span className="text-[10px] text-slate-400 font-mono uppercase block truncate">Seller Asking Price</span>
              <span className="text-xs sm:text-sm font-bold text-white truncate block">
                ₹{details.askingPrice.toLocaleString('en-IN')}/{unitSymbol}
              </span>
            </div>

            <div className="p-2.5 rounded-lg bg-white/5 border border-white/10 min-w-0">
              <span className="text-[10px] text-slate-400 font-mono uppercase block truncate">Available Lot Qty</span>
              <span className="text-xs sm:text-sm font-bold text-white truncate block">
                {details.availableQuantity} {unitSymbol}
              </span>
            </div>

            <div className="p-2.5 rounded-lg bg-teal-500/10 border border-teal-500/30 min-w-0">
              <span className="text-[10px] text-teal-300 font-mono uppercase block truncate">Last Offered Rate</span>
              <span className="text-xs sm:text-sm font-bold text-teal-300 truncate block">
                ₹{details.offeredPrice.toLocaleString('en-IN')}/{unitSymbol}
              </span>
            </div>

            {/* CONFIDENTIAL MINIMUM PRICE (BROKER EYES ONLY) */}
            <div className="p-2.5 rounded-lg bg-purple-500/15 border border-purple-500/30 relative min-w-0">
              <div className="flex items-center gap-1 text-[10px] text-purple-300 font-mono uppercase truncate">
                <Lock className="w-3 h-3 text-purple-300 shrink-0" />
                <span className="truncate">Seller Min Floor</span>
              </div>
              <span className="text-xs sm:text-sm font-bold text-purple-200 truncate block">
                {details.confidentialMinimumPrice
                  ? `₹${details.confidentialMinimumPrice.toLocaleString('en-IN')}/${unitSymbol}`
                  : 'Undisclosed'}
              </span>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 2. PROPOSAL ADJUSTMENT FORM */}
      <Card className="border border-slate-200 shadow-xs bg-white">
        <CardHeader className="pb-3 border-b border-slate-100">
          <div className="flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-[#0D9488]" />
            <CardTitle className="text-base font-bold text-slate-900">
              Adjust Seller Proposal Terms
            </CardTitle>
          </div>
          <CardDescription className="text-xs text-slate-500">
            Submit revised price, quantity, delivery, or commercial terms to the Seller.
          </CardDescription>
        </CardHeader>

        <CardContent className="pt-5">
          {serverError && (
            <div className="mb-4 p-3 rounded-lg bg-rose-50 border border-rose-200 text-rose-800 text-xs flex items-start gap-2">
              <AlertCircle className="w-4 h-4 text-rose-600 shrink-0 mt-0.5" />
              <span>{serverError}</span>
            </div>
          )}

          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
              {/* Row 1: Offered Price & Quantity */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {/* Offered Price */}
                <FormField
                  control={form.control}
                  name="offered_price"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700 flex items-center gap-1">
                        <IndianRupee className="w-3.5 h-3.5 text-[#0D9488]" />
                        <span>Offered Rate (₹ / {unitSymbol}) *</span>
                      </FormLabel>
                      <FormControl>
                        <Input
                          type="number"
                          step="0.01"
                          placeholder="Enter price per unit"
                          className="h-11 text-sm font-semibold border-slate-200 focus-visible:ring-[#0D9488]"
                          {...field}
                          onChange={(e) => field.onChange(e.target.valueAsNumber || e.target.value)}
                        />
                      </FormControl>
                      {priceDelta !== null && (
                        <FormDescription
                          className={`text-[11px] font-medium ${
                            priceDelta >= 0 ? 'text-emerald-600' : 'text-amber-600 font-semibold'
                          }`}
                        >
                          {priceDelta >= 0
                            ? `+₹${priceDelta.toLocaleString('en-IN')} above Seller confidential min floor`
                            : `-₹${Math.abs(priceDelta).toLocaleString('en-IN')} below Seller min floor (risk of seller rejection)`}
                        </FormDescription>
                      )}
                      <FormMessage className="text-[11px]" />
                    </FormItem>
                  )}
                />

                {/* Proposed Quantity */}
                <FormField
                  control={form.control}
                  name="quantity"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700 flex items-center gap-1">
                        <Layers className="w-3.5 h-3.5 text-[#0D9488]" />
                        <span>Proposed Quantity ({unitSymbol}) *</span>
                      </FormLabel>
                      <FormControl>
                        <Input
                          type="number"
                          step="0.1"
                          placeholder="Enter quantity"
                          className="h-11 text-sm font-semibold border-slate-200 focus-visible:ring-[#0D9488]"
                          {...field}
                          onChange={(e) => field.onChange(e.target.valueAsNumber || e.target.value)}
                        />
                      </FormControl>
                      <FormDescription className="text-[11px] text-slate-500">
                        Max available in lot: {details.availableQuantity} {unitSymbol}
                      </FormDescription>
                      <FormMessage className="text-[11px]" />
                    </FormItem>
                  )}
                />
              </div>

              {/* Row 2: Delivery Date & Payment Terms */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {/* Target Delivery Date */}
                <FormField
                  control={form.control}
                  name="delivery_date"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700 flex items-center gap-1">
                        <Calendar className="w-3.5 h-3.5 text-[#0D9488]" />
                        <span>Target Delivery Date</span>
                      </FormLabel>
                      <FormControl>
                        <Input
                          type="date"
                          className="h-11 text-sm border-slate-200 focus-visible:ring-[#0D9488]"
                          value={field.value || ''}
                          onChange={field.onChange}
                        />
                      </FormControl>
                      <FormMessage className="text-[11px]" />
                    </FormItem>
                  )}
                />

                {/* Payment Terms */}
                <FormField
                  control={form.control}
                  name="payment_terms"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">
                        Payment & Settlement Terms
                      </FormLabel>
                      <Select
                        onValueChange={field.onChange}
                        value={field.value || undefined}
                      >
                        <FormControl>
                          <SelectTrigger className="h-11 text-xs sm:text-sm border-slate-200">
                            <SelectValue placeholder="Select Payment Terms" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="Standard Settlement via Broker Desk">
                            Standard Settlement via Broker Desk
                          </SelectItem>
                          <SelectItem value="100% Advance Payment">100% Advance Payment</SelectItem>
                          <SelectItem value="CAD (Cash Against Documents)">
                            CAD (Cash Against Documents)
                          </SelectItem>
                          <SelectItem value="LC at Sight (Irrevocable)">
                            LC at Sight (Irrevocable)
                          </SelectItem>
                          <SelectItem value="PDC 15 Days Post-Dispatch">
                            PDC 15 Days Post-Dispatch
                          </SelectItem>
                          <SelectItem value="50% Advance / 50% on Weighment">
                            50% Advance / 50% on Weighment
                          </SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage className="text-[11px]" />
                    </FormItem>
                  )}
                />
              </div>

              {/* Row 3: Packaging Type */}
              <FormField
                control={form.control}
                name="packaging"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs font-semibold text-slate-700">
                      Packaging Specification
                    </FormLabel>
                    <Select
                      onValueChange={field.onChange}
                      value={field.value || undefined}
                    >
                      <FormControl>
                        <SelectTrigger className="h-11 text-xs sm:text-sm border-slate-200">
                          <SelectValue placeholder="Select Packaging Type" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="Standard Packaging">Standard Packaging</SelectItem>
                        <SelectItem value="50kg New PP Bags">50kg New PP Bags</SelectItem>
                        <SelectItem value="50kg Jute Bags (B-Twill)">
                          50kg Jute Bags (B-Twill)
                        </SelectItem>
                        <SelectItem value="1000kg Jumbo HDPE Bags">1000kg Jumbo HDPE Bags</SelectItem>
                        <SelectItem value="Bulk Loose / Tanker Loading">
                          Bulk Loose / Tanker Loading
                        </SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage className="text-[11px]" />
                  </FormItem>
                )}
              />

              {/* Row 4: Message / Remarks to Seller */}
              <FormField
                control={form.control}
                name="broker_notes"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs font-semibold text-slate-700">
                      Broker Remarks to Seller
                    </FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Add commercial counter notes or logistics instructions to the seller..."
                        className="min-h-[80px] text-xs sm:text-sm border-slate-200 focus-visible:ring-[#0D9488]"
                        {...field}
                        value={field.value || ''}
                      />
                    </FormControl>
                    <FormDescription className="text-[11px] text-slate-500">
                      Visible exclusively to the Seller. Zero Buyer private information included.
                    </FormDescription>
                    <FormMessage className="text-[11px]" />
                  </FormItem>
                )}
              />

              {/* SUBMIT BUTTON WITH min-h-[48px] TOUCH TARGET & useTransition */}
              <div className="pt-2">
                <Button
                  type="submit"
                  disabled={isPending}
                  className="w-full min-h-[48px] text-sm font-bold bg-[#0D9488] hover:bg-[#0F766E] text-white shadow-xs rounded-xl transition-all"
                >
                  {isPending ? (
                    <>
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                      <span>Sending Proposal v{details.currentVersionNumber + 1}...</span>
                    </>
                  ) : (
                    <>
                      <Send className="w-4 h-4 mr-2" />
                      <span>Send Proposal to Seller (v{details.currentVersionNumber + 1})</span>
                    </>
                  )}
                </Button>
              </div>
            </form>
          </Form>
        </CardContent>
      </Card>

      {/* 3. READ-ONLY SELLER CHANNEL HISTORY & TIMELINE */}
      <BrokerSellerTimeline
        requestId={details.requestId}
        timeline={timeline}
        isLoading={isPending}
      />
    </div>
  );
}
