'use client';

import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Badge } from '@/components/ui/badge';
import {
  FileCheck2,
  IndianRupee,
  Calendar,
  Building2,
  Package,
  Truck,
  ShieldCheck,
  TrendingUp,
  AlertCircle,
  Sparkles,
  Loader2,
  Lock,
  ArrowRight,
} from 'lucide-react';
import { generateFinalDealSnapshotAction } from '@/src/server/actions/broker-deal-actions';

export interface DealBuilderInitialData {
  requestId: string;
  requirementId: string;
  sellerAvailabilityId?: string | null;
  lotId?: string | null;
  lotNumber?: string | null;
  commodityName: string;
  gradeName?: string | null;
  quantity: number;
  baseRate: number;
  deliveryDate: string;
  buyerMarkup: number;
  sellerDeduction: number;
  deliveryTerms?: string;
  deliveryLocation?: string;
  packagingType?: string;
  paymentTerms?: string;
  specialConditions?: string;
  unitSymbol?: string;
  expectedVersionNumber?: number;
  currentStatus?: string;
}

interface DealBuilderProps {
  initialData: DealBuilderInitialData;
  onSuccess?: (versionId: string, versionNumber: number) => void;
}

export function DealBuilder({ initialData, onSuccess }: DealBuilderProps) {
  const [formData, setFormData] = useState({
    quantity: initialData.quantity || 100,
    baseRate: initialData.baseRate || 50000,
    deliveryDate: initialData.deliveryDate || new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0],
    buyerMarkup: initialData.buyerMarkup ?? 250,
    sellerDeduction: initialData.sellerDeduction ?? 250,
    deliveryTerms: initialData.deliveryTerms || 'Ex-Warehouse / FOR',
    deliveryLocation: initialData.deliveryLocation || 'Warehouse Hub',
    packagingType: initialData.packagingType || '50kg Jute Bags',
    paymentTerms: initialData.paymentTerms || '100% Advance against Invoice / Bank Transfer',
    specialConditions: initialData.specialConditions || '',
  });

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Real-time Financial UX Calculations
  const unitSym = initialData.unitSymbol || 'MT';
  const qty = Math.max(0, Number(formData.quantity) || 0);
  const baseRateNum = Math.max(0, Number(formData.baseRate) || 0);
  const buyerMarkupNum = Math.max(0, Number(formData.buyerMarkup) || 0);
  const sellerDeductionNum = Math.max(0, Number(formData.sellerDeduction) || 0);

  const netBuyerRate = baseRateNum + buyerMarkupNum;
  const netSellerRate = Math.max(0, baseRateNum - sellerDeductionNum);

  const netBuyerPayable = netBuyerRate * qty;
  const netSellerSettlement = netSellerRate * qty;

  const brokerSpreadPerMT = buyerMarkupNum + sellerDeductionNum;
  const totalBrokerCommission = brokerSpreadPerMT * qty;

  const handleInputChange = (field: string, value: any) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    if (errorMessage) setErrorMessage(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    try {
      const payload = {
        requestId: initialData.requestId,
        requirementId: initialData.requirementId,
        sellerAvailabilityId: initialData.sellerAvailabilityId,
        lotId: initialData.lotId,
        lotNumber: initialData.lotNumber,
        commodityName: initialData.commodityName,
        gradeName: initialData.gradeName,
        quantity: qty,
        baseRate: baseRateNum,
        deliveryDate: formData.deliveryDate,
        unitSymbol: unitSym,
        buyerMarkup: buyerMarkupNum,
        sellerDeduction: sellerDeductionNum,
        deliveryTerms: formData.deliveryTerms,
        deliveryLocation: formData.deliveryLocation,
        packagingType: formData.packagingType,
        paymentTerms: formData.paymentTerms,
        specialConditions: formData.specialConditions,
        expectedVersionNumber: initialData.expectedVersionNumber,
      };

      const res = await generateFinalDealSnapshotAction(payload);

      if (res.success && res.version_id) {
        setSuccessMessage(res.message || 'Final Deal Snapshot Generated Successfully!');
        if (onSuccess) {
          onSuccess(res.version_id, res.version_number || 1);
        }
      } else {
        setErrorMessage(res.error || 'Failed to generate final deal snapshot.');
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'An unexpected error occurred.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="w-full max-w-7xl mx-auto space-y-6 text-slate-900">
      {/* 1. READ-ONLY HEADER DATA BANNER */}
      <Card className="border-teal-200/80 bg-gradient-to-r from-teal-900 via-slate-900 to-slate-950 text-white shadow-md overflow-hidden">
        <CardContent className="p-4 sm:p-6 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-teal-800/60 pb-3">
            <div className="flex items-center gap-2.5">
              <div className="w-10 h-10 rounded-xl bg-teal-500/20 border border-teal-400/40 flex items-center justify-center text-teal-300 shrink-0">
                <FileCheck2 className="w-5 h-5" />
              </div>
              <div>
                <div className="flex items-center gap-2 flex-wrap">
                  <h2 className="text-xl sm:text-2xl font-bold tracking-tight text-white">
                    {initialData.commodityName}
                  </h2>
                  <Badge className="bg-teal-500/20 text-teal-300 border-teal-400/40 text-xs font-semibold">
                    {initialData.gradeName || 'Standard Grade'}
                  </Badge>
                </div>
                <p className="text-xs text-teal-200/80 mt-0.5">
                  Broker Final Deal Builder • Version Snapshot Engine
                </p>
              </div>
            </div>

            <Badge variant="outline" className="bg-emerald-500/20 text-emerald-300 border-emerald-400/40 px-3 py-1 text-xs self-start sm:self-auto font-mono">
              Status: {initialData.currentStatus || 'Drafting Snapshot'}
            </Badge>
          </div>

          {/* Read-Only Metadata Chips */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
            <div className="bg-white/5 border border-white/10 rounded-lg p-2.5">
              <span className="text-teal-300/70 block text-[10px] uppercase font-bold tracking-wider">Commodity</span>
              <span className="font-semibold text-white truncate block">{initialData.commodityName}</span>
            </div>
            <div className="bg-white/5 border border-white/10 rounded-lg p-2.5">
              <span className="text-teal-300/70 block text-[10px] uppercase font-bold tracking-wider">Grade Spec</span>
              <span className="font-semibold text-white truncate block">{initialData.gradeName || 'Standard Grade'}</span>
            </div>
            <div className="bg-white/5 border border-white/10 rounded-lg p-2.5">
              <span className="text-teal-300/70 block text-[10px] uppercase font-bold tracking-wider">Lot ID</span>
              <span className="font-mono font-semibold text-white truncate block">{initialData.lotNumber || initialData.lotId || 'LOT-CONFIDENTIAL'}</span>
            </div>
            <div className="bg-white/5 border border-white/10 rounded-lg p-2.5">
              <span className="text-teal-300/70 block text-[10px] uppercase font-bold tracking-wider">Requirement ID</span>
              <span className="font-mono font-semibold text-white truncate block">{initialData.requirementId.slice(0, 12)}...</span>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* ERROR / SUCCESS ALERTS */}
      {errorMessage && (
        <div className="p-4 rounded-xl bg-red-50 border border-red-200 text-red-700 flex items-start gap-3 text-xs sm:text-sm">
          <AlertCircle className="w-5 h-5 text-red-600 shrink-0 mt-0.5" />
          <div className="flex-1 font-medium">{errorMessage}</div>
        </div>
      )}

      {successMessage && (
        <div className="p-4 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 flex items-start gap-3 text-xs sm:text-sm">
          <ShieldCheck className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
          <div className="flex-1 font-medium">{successMessage}</div>
        </div>
      )}

      {/* 2. MAIN FORM INPUT GROUPS & REAL-TIME CALCULATIONS */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* LEFT 2 COLUMNS: FORM INPUTS */}
        <div className="lg:col-span-2 space-y-6">
          {/* GROUP A: COMMERCIALS */}
          <Card className="border-slate-200 shadow-xs bg-white">
            <CardHeader className="pb-3 border-b border-slate-100">
              <CardTitle className="text-base font-bold flex items-center gap-2 text-slate-900">
                <IndianRupee className="w-4 h-4 text-teal-600" />
                1. Core Commercial Terms
              </CardTitle>
              <CardDescription className="text-xs text-slate-500">
                Set final agreed base volume, base rate, and scheduled delivery date.
              </CardDescription>
            </CardHeader>
            <CardContent className="p-4 sm:p-6 grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Final Quantity ({unitSym}) *</Label>
                <div className="relative">
                  <Input
                    type="number"
                    min="1"
                    step="any"
                    value={formData.quantity}
                    onChange={(e) => handleInputChange('quantity', e.target.value)}
                    className="h-12 min-h-[48px] text-sm font-medium pr-12"
                    required
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-400">
                    {unitSym}
                  </span>
                </div>
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Base Negotiated Rate (₹/{unitSym}) *</Label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-500">₹</span>
                  <Input
                    type="number"
                    min="1"
                    step="any"
                    value={formData.baseRate}
                    onChange={(e) => handleInputChange('baseRate', e.target.value)}
                    className="h-12 min-h-[48px] text-sm font-medium pl-8"
                    required
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Target Delivery Date *</Label>
                <div className="relative">
                  <Input
                    type="date"
                    value={formData.deliveryDate}
                    onChange={(e) => handleInputChange('deliveryDate', e.target.value)}
                    className="h-12 min-h-[48px] text-sm font-medium"
                    required
                  />
                </div>
              </div>
            </CardContent>
          </Card>

          {/* GROUP B: COMMISSION STRATEGY */}
          <Card className="border-teal-200/90 shadow-xs bg-teal-50/30">
            <CardHeader className="pb-3 border-b border-teal-100">
              <div className="flex items-center justify-between">
                <CardTitle className="text-base font-bold flex items-center gap-2 text-teal-950">
                  <TrendingUp className="w-4 h-4 text-teal-700" />
                  2. Broker Commission Strategy
                </CardTitle>
                <Badge className="bg-teal-700 text-white text-[11px] font-mono">
                  Spread: ₹{brokerSpreadPerMT.toLocaleString('en-IN')}/{unitSym}
                </Badge>
              </div>
              <CardDescription className="text-xs text-teal-800/80">
                Configure Buyer markup and Seller deduction to establish landed rates and total margin spread.
              </CardDescription>
            </CardHeader>
            <CardContent className="p-4 sm:p-6 grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Buyer Markup per {unitSym} (₹)</Label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-500">+₹</span>
                  <Input
                    type="number"
                    min="0"
                    step="any"
                    value={formData.buyerMarkup}
                    onChange={(e) => handleInputChange('buyerMarkup', e.target.value)}
                    className="h-12 min-h-[48px] text-sm font-medium pl-9 border-teal-200 focus:border-teal-500 bg-white"
                  />
                </div>
                <p className="text-[11px] text-slate-500">
                  Added to Base Rate for Buyer Landed Rate.
                </p>
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Seller Deduction per {unitSym} (₹)</Label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-xs font-bold text-slate-500">-₹</span>
                  <Input
                    type="number"
                    min="0"
                    step="any"
                    value={formData.sellerDeduction}
                    onChange={(e) => handleInputChange('sellerDeduction', e.target.value)}
                    className="h-12 min-h-[48px] text-sm font-medium pl-9 border-teal-200 focus:border-teal-500 bg-white"
                  />
                </div>
                <p className="text-[11px] text-slate-500">
                  Deducted from Base Rate for Seller Net Settlement.
                </p>
              </div>
            </CardContent>
          </Card>

          {/* GROUP C: LOGISTICS */}
          <Card className="border-slate-200 shadow-xs bg-white">
            <CardHeader className="pb-3 border-b border-slate-100">
              <CardTitle className="text-base font-bold flex items-center gap-2 text-slate-900">
                <Truck className="w-4 h-4 text-teal-600" />
                3. Logistics & Packaging Terms
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4 sm:p-6 grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Transport Terms</Label>
                <Input
                  type="text"
                  value={formData.deliveryTerms}
                  onChange={(e) => handleInputChange('deliveryTerms', e.target.value)}
                  className="h-12 min-h-[48px] text-sm"
                  placeholder="e.g. Ex-Warehouse / FOR Destination"
                />
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Packaging Type</Label>
                <Input
                  type="text"
                  value={formData.packagingType}
                  onChange={(e) => handleInputChange('packagingType', e.target.value)}
                  className="h-12 min-h-[48px] text-sm"
                  placeholder="e.g. 50kg Jute Bags / HDPE Bags"
                />
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Delivery Location</Label>
                <Input
                  type="text"
                  value={formData.deliveryLocation}
                  onChange={(e) => handleInputChange('deliveryLocation', e.target.value)}
                  className="h-12 min-h-[48px] text-sm"
                  placeholder="e.g. Warehouse / Mandi Hub"
                />
              </div>
            </CardContent>
          </Card>

          {/* GROUP D: FINANCIALS & SPECIAL CONDITIONS */}
          <Card className="border-slate-200 shadow-xs bg-white">
            <CardHeader className="pb-3 border-b border-slate-100">
              <CardTitle className="text-base font-bold flex items-center gap-2 text-slate-900">
                <Building2 className="w-4 h-4 text-teal-600" />
                4. Financial Terms & Special Conditions
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4 sm:p-6 space-y-4">
              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Payment Terms</Label>
                <Input
                  type="text"
                  value={formData.paymentTerms}
                  onChange={(e) => handleInputChange('paymentTerms', e.target.value)}
                  className="h-12 min-h-[48px] text-sm"
                  placeholder="e.g. 100% Advance against Invoice / Bank Transfer"
                />
              </div>

              <div className="space-y-1.5">
                <Label className="text-xs font-semibold text-slate-700">Special Conditions & Quality Remarks</Label>
                <Textarea
                  value={formData.specialConditions}
                  onChange={(e) => handleInputChange('specialConditions', e.target.value)}
                  rows={3}
                  className="text-sm min-h-[80px]"
                  placeholder="Enter any quality tolerances, loading requirements, or custom commercial clauses..."
                />
              </div>
            </CardContent>
          </Card>
        </div>

        {/* RIGHT COLUMN: REAL-TIME FINANCIAL UX CALCULATOR CARD */}
        <div className="lg:col-span-1 space-y-6">
          <Card className="border-teal-200/90 shadow-md bg-white sticky top-6">
            <CardHeader className="bg-slate-900 text-white rounded-t-xl pb-4">
              <div className="flex items-center justify-between">
                <CardTitle className="text-base font-bold flex items-center gap-2">
                  <Sparkles className="w-4 h-4 text-teal-400" />
                  Real-Time Net Financials
                </CardTitle>
                <Badge className="bg-teal-500/20 text-teal-300 border-teal-400/40 text-[10px] font-mono">
                  Broker Eyes Only
                </Badge>
              </div>
              <CardDescription className="text-xs text-slate-400 mt-1">
                Calculated landed pricing, net settlements, and gross commission spread.
              </CardDescription>
            </CardHeader>

            <CardContent className="p-4 sm:p-6 space-y-5">
              {/* Buyer Breakdown */}
              <div className="p-3.5 rounded-xl bg-blue-50/70 border border-blue-200/70 space-y-2">
                <div className="flex items-center justify-between text-xs font-bold text-blue-900">
                  <span>Buyer Net Payable</span>
                  <Badge variant="outline" className="bg-blue-100 text-blue-800 border-blue-300 text-[10px]">
                    Landed Rate
                  </Badge>
                </div>
                <div className="flex items-baseline justify-between">
                  <span className="text-xs text-slate-600">Rate ({unitSym}):</span>
                  <span className="font-bold text-slate-900 text-sm">
                    ₹{netBuyerRate.toLocaleString('en-IN')}/{unitSym}
                  </span>
                </div>
                <div className="flex items-baseline justify-between border-t border-blue-200/60 pt-1.5">
                  <span className="text-xs font-semibold text-blue-950">Total Payable:</span>
                  <span className="font-extrabold text-blue-950 text-base sm:text-lg font-mono">
                    ₹{netBuyerPayable.toLocaleString('en-IN')}
                  </span>
                </div>
              </div>

              {/* Seller Breakdown */}
              <div className="p-3.5 rounded-xl bg-amber-50/70 border border-amber-200/70 space-y-2">
                <div className="flex items-center justify-between text-xs font-bold text-amber-900">
                  <span>Seller Net Settlement</span>
                  <Badge variant="outline" className="bg-amber-100 text-amber-800 border-amber-300 text-[10px]">
                    Net Floor
                  </Badge>
                </div>
                <div className="flex items-baseline justify-between">
                  <span className="text-xs text-slate-600">Rate ({unitSym}):</span>
                  <span className="font-bold text-slate-900 text-sm">
                    ₹{netSellerRate.toLocaleString('en-IN')}/{unitSym}
                  </span>
                </div>
                <div className="flex items-baseline justify-between border-t border-amber-200/60 pt-1.5">
                  <span className="text-xs font-semibold text-amber-950">Total Settlement:</span>
                  <span className="font-extrabold text-amber-950 text-base sm:text-lg font-mono">
                    ₹{netSellerSettlement.toLocaleString('en-IN')}
                  </span>
                </div>
              </div>

              {/* Total Commission Spread */}
              <div className="p-4 rounded-xl bg-teal-900 text-white shadow-xs space-y-2">
                <div className="flex items-center justify-between text-xs font-bold">
                  <span className="text-teal-300 flex items-center gap-1.5">
                    <TrendingUp className="w-3.5 h-3.5 text-teal-400" />
                    Broker Total Commission
                  </span>
                  <span className="text-[10px] font-mono text-teal-200">
                    ₹{brokerSpreadPerMT}/{unitSym}
                  </span>
                </div>
                <div className="text-2xl font-black font-mono text-teal-300 tracking-tight">
                  ₹{totalBrokerCommission.toLocaleString('en-IN')}
                </div>
                <div className="text-[10px] text-teal-200/80 flex items-center gap-1 pt-1 border-t border-teal-800">
                  <Lock className="w-3 h-3 text-teal-400 shrink-0" />
                  <span>Privacy Lock Active: Buyer & Seller receive isolated snapshots.</span>
                </div>
              </div>

              {/* Primary Action Button */}
              <Button
                type="submit"
                disabled={isSubmitting || qty <= 0 || baseRateNum <= 0}
                className="w-full h-12 min-h-[48px] bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-bold text-sm sm:text-base rounded-xl shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-5 h-5 animate-spin" />
                    <span>Generating Final Deal...</span>
                  </>
                ) : (
                  <>
                    <FileCheck2 className="w-5 h-5" />
                    <span>Generate Final Deal Snapshot</span>
                    <ArrowRight className="w-4 h-4 ml-1" />
                  </>
                )}
              </Button>

              <p className="text-[11px] text-slate-500 text-center leading-relaxed">
                Generates an immutable contract version in <code className="font-mono text-slate-700">deal_versions</code> and triggers dual confirmations for Buyer and Seller.
              </p>
            </CardContent>
          </Card>
        </div>
      </div>
    </form>
  );
}
