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
  Building,
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
  TrendingUp,
} from 'lucide-react';
import { toast } from 'sonner';
import {
  sendProposalToBuyerSchema,
  type SendProposalToBuyerPayload,
  type BuyerNegotiationDetails,
} from '@/src/types/buyer-negotiation-schema';
import { sendProposalToBuyerAction } from '@/src/server/actions/broker-buyer-actions';
import { BrokerBuyerTimeline } from './broker-buyer-timeline';
import type { NegotiationTimelineItem } from '@/src/types/deal-version-schema';

interface BuyerNegotiationPanelProps {
  details: BuyerNegotiationDetails;
  timeline?: NegotiationTimelineItem[];
  onRefresh?: () => void;
}

export function BuyerNegotiationPanel({
  details,
  timeline = [],
  onRefresh,
}: BuyerNegotiationPanelProps) {
  const [isPending, startTransition] = useTransition();
  const [serverError, setServerError] = useState<string | null>(null);

  const form = useForm<SendProposalToBuyerPayload>({
    resolver: zodResolver(sendProposalToBuyerSchema),
    defaultValues: {
      requirement_id: details.requirementId,
      request_id: details.requestId || undefined,
      offered_price: details.offeredPrice || details.targetPrice,
      quantity: details.proposedQuantity || details.targetQuantity,
      delivery_date: details.deliveryDate || '',
      payment_terms: details.paymentTerms || 'Standard Escrow Settlement via Broker Desk',
      packaging: details.packagingType || 'Standard Packaging',
      broker_notes: '',
      expected_version_number: details.currentVersionNumber,
    },
  });

  // Re-sync form default values if active proposal details change
  useEffect(() => {
    form.reset({
      requirement_id: details.requirementId,
      request_id: details.requestId || undefined,
      offered_price: details.offeredPrice || details.targetPrice,
      quantity: details.proposedQuantity || details.targetQuantity,
      delivery_date: details.deliveryDate || '',
      payment_terms: details.paymentTerms || 'Standard Escrow Settlement via Broker Desk',
      packaging: details.packagingType || 'Standard Packaging',
      broker_notes: '',
      expected_version_number: details.currentVersionNumber,
    });
  }, [details, form]);

  const onSubmit = (data: SendProposalToBuyerPayload) => {
    setServerError(null);

    startTransition(async () => {
      // PRIVACY LOCK: Exclude any seller PII, seller min floor, or seller exact location
      const payload: SendProposalToBuyerPayload = {
        requirement_id: details.requirementId,
        request_id: details.requestId || undefined,
        offered_price: Number(data.offered_price),
        quantity: Number(data.quantity),
        delivery_date: data.delivery_date || null,
        payment_terms: data.payment_terms || 'Standard Escrow Settlement via Broker Desk',
        packaging: data.packaging || 'Standard Packaging',
        broker_notes: data.broker_notes?.trim() || '',
        expected_version_number: details.currentVersionNumber,
      };

      const res = await sendProposalToBuyerAction(payload);

      if (res.success) {
        toast.success(res.message || `Proposal v${res.newVersion} sent to Buyer!`);
        form.setValue('broker_notes', '');
        if (onRefresh) onRefresh();
      } else {
        setServerError(res.error || 'Failed to dispatch proposal to Buyer');
        toast.error(res.error || 'Failed to dispatch proposal');
      }
    });
  };

  const unitSymbol = details.unitSymbol || 'MT';
  const priceDelta = form.watch('offered_price') - details.targetPrice;

  return (
    <div className="w-full space-y-6">
      {/* 1. BUYER CHANNEL HEADER CARD */}
      <Card className="border border-slate-200/90 shadow-sm bg-gradient-to-r from-slate-900 via-slate-800 to-blue-950 text-white overflow-hidden">
        <CardContent className="p-4 sm:p-6 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-white/10">
            {/* Buyer Company & Requirement Badges */}
            <div className="space-y-1">
              <div className="flex items-center gap-2 flex-wrap">
                <Badge className="bg-blue-500/20 text-blue-300 border-blue-500/30 font-mono text-[10px] tracking-wider uppercase">
                  BUYER CHANNEL
                </Badge>
                <Badge className="bg-slate-800 text-slate-200 border-slate-700 font-mono text-[10px]">
                  v{details.currentVersionNumber} Active
                </Badge>
                <Badge variant="outline" className="text-emerald-400 border-emerald-500/40 text-[10px]">
                  {details.currentStatus}
                </Badge>
              </div>

              <h3 className="text-lg sm:text-xl font-bold tracking-tight text-white flex items-center gap-2 mt-1">
                <Building className="w-5 h-5 text-blue-400 shrink-0" />
                <span>{details.buyerCompanyName}</span>
                {details.buyerCompanyVerified && (
                  <ShieldCheck className="w-4 h-4 text-blue-400 shrink-0" />
                )}
              </h3>

              <p className="text-xs text-slate-300 font-medium">
                Requirement ID: <span className="font-mono text-blue-300 font-bold">#{details.requirementId.slice(0, 8)}</span>
              </p>
            </div>

            {/* Commodity & Grade Badges */}
            <div className="text-left sm:text-right space-y-1">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-white/10 text-xs font-semibold">
                <PackageCheck className="w-3.5 h-3.5 text-blue-300" />
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
              <span className="text-[10px] text-slate-400 font-mono uppercase block truncate">Buyer Target Price</span>
              <span className="text-xs sm:text-sm font-bold text-white truncate block">
                ₹{details.targetPrice.toLocaleString('en-IN')}/{unitSymbol}
              </span>
            </div>

            <div className="p-2.5 rounded-lg bg-white/5 border border-white/10 min-w-0">
              <span className="text-[10px] text-slate-400 font-mono uppercase block truncate">Required Volume</span>
              <span className="text-xs sm:text-sm font-bold text-white truncate block">
                {details.targetQuantity} {unitSymbol}
              </span>
            </div>

            <div className="p-2.5 rounded-lg bg-blue-500/10 border border-blue-500/30 col-span-2 min-w-0">
              <span className="text-[10px] text-blue-300 font-mono uppercase block truncate">Landed Rate to Buyer</span>
              <span className="text-xs sm:text-sm font-bold text-blue-300 truncate block">
                ₹{details.offeredPrice.toLocaleString('en-IN')}/{unitSymbol}
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
              Adjust Landed Proposal to Buyer
            </CardTitle>
          </div>
          <CardDescription className="text-xs text-slate-500">
            Submit revised landed price (including Broker margin), quantity, or delivery terms to the Buyer.
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
                {/* Offered Landed Price */}
                <FormField
                  control={form.control}
                  name="offered_price"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700 flex items-center gap-1">
                        <IndianRupee className="w-3.5 h-3.5 text-[#0D9488]" />
                        <span>Landed Rate to Buyer (₹ / {unitSymbol}) *</span>
                      </FormLabel>
                      <FormControl>
                        <Input
                          type="number"
                          step="0.01"
                          placeholder="Enter landed price"
                          className="h-11 text-sm font-semibold border-slate-200 focus-visible:ring-[#0D9488]"
                          {...field}
                          onChange={(e) => field.onChange(e.target.valueAsNumber || e.target.value)}
                        />
                      </FormControl>
                      {priceDelta !== 0 && (
                        <FormDescription
                          className={`text-[11px] font-medium ${
                            priceDelta <= 0 ? 'text-emerald-600' : 'text-amber-600 font-semibold'
                          }`}
                        >
                          {priceDelta <= 0
                            ? `-₹${Math.abs(priceDelta).toLocaleString('en-IN')} below Buyer target price (attractive to buyer)`
                            : `+₹${priceDelta.toLocaleString('en-IN')} above Buyer target price`}
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
                        Target requirement volume: {details.targetQuantity} {unitSymbol}
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
                        Payment & Escrow Terms
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
                          <SelectItem value="Standard Escrow Settlement via Broker Desk">
                            Standard Escrow Settlement via Broker Desk
                          </SelectItem>
                          <SelectItem value="100% Advance Escrow Deposit">
                            100% Advance Escrow Deposit
                          </SelectItem>
                          <SelectItem value="CAD (Cash Against Documents)">
                            CAD (Cash Against Documents)
                          </SelectItem>
                          <SelectItem value="LC at Sight (Irrevocable)">
                            LC at Sight (Irrevocable)
                          </SelectItem>
                          <SelectItem value="PDC 15 Days Post-Delivery">
                            PDC 15 Days Post-Delivery
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

              {/* Row 4: Message / Remarks to Buyer */}
              <FormField
                control={form.control}
                name="broker_notes"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs font-semibold text-slate-700">
                      Broker Message / Proposal Notes to Buyer
                    </FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Add commercial terms explanation or delivery schedule notes to the buyer..."
                        className="min-h-[80px] text-xs sm:text-sm border-slate-200 focus-visible:ring-[#0D9488]"
                        {...field}
                        value={field.value || ''}
                      />
                    </FormControl>
                    <FormDescription className="text-[11px] text-slate-500">
                      Visible exclusively to the Buyer. Zero Seller confidential information included.
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
                      <span>Sending Landed Proposal v{details.currentVersionNumber + 1}...</span>
                    </>
                  ) : (
                    <>
                      <Send className="w-4 h-4 mr-2" />
                      <span>Send Proposal to Buyer (v{details.currentVersionNumber + 1})</span>
                    </>
                  )}
                </Button>
              </div>
            </form>
          </Form>
        </CardContent>
      </Card>

      {/* 3. READ-ONLY BUYER CHANNEL HISTORY & TIMELINE */}
      <BrokerBuyerTimeline
        requirementId={details.requirementId}
        timeline={timeline}
        isLoading={isPending}
      />
    </div>
  );
}
