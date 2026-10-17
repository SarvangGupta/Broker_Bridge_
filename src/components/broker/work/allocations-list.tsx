'use client';

import React, { useState, useTransition } from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import Link from 'next/link';
import {
  Scale,
  Building2,
  CheckCircle2,
  Clock,
  Ban,
  AlertTriangle,
  Loader2,
  ArrowRight,
  ShieldCheck,
  FileText,
  Handshake,
} from 'lucide-react';
import { useLanguage } from '@/src/lib/i18n/language-context';
import type { BrokerAllocationDetail, AllocationSummary } from '@/src/server/actions/broker-allocation-actions';
import {
  confirmAllocationAction,
  cancelAllocationAction,
} from '@/src/server/actions/broker-allocation-actions';
import { DealCreateDialog } from './deal-create-dialog';
import { toast } from 'sonner';

interface AllocationsListProps {
  allocations: BrokerAllocationDetail[];
  summary: AllocationSummary | null;
  onRefresh: () => void;
}

export function AllocationsList({ allocations, summary, onRefresh }: AllocationsListProps) {
  const { t, formatNumber, formatCurrency, language } = useLanguage();
  const [isPending, startTransition] = useTransition();

  // Cancel / Release dialog state
  const [cancelModalAllocation, setCancelModalAllocation] = useState<BrokerAllocationDetail | null>(null);
  const [cancelReason, setCancelReason] = useState<string>('');
  const [cancelError, setCancelError] = useState<string | null>(null);

  // Create Deal dialog state
  const [createDealAllocation, setCreateDealAllocation] = useState<BrokerAllocationDetail | null>(null);

  const handleConfirm = (allocationId: string) => {
    startTransition(async () => {
      const res = await confirmAllocationAction({ allocationId });
      if (res.success) {
        toast.success(t('allocationConfirmedSuccess'));
        onRefresh();
      } else {
        toast.error(res.error || 'Failed to confirm allocation');
      }
    });
  };

  const handleCancelSubmit = () => {
    if (!cancelModalAllocation) return;
    if (!cancelReason || cancelReason.trim().length < 3) {
      setCancelError(t('allocationReasonRequired'));
      return;
    }

    startTransition(async () => {
      const res = await cancelAllocationAction({
        allocationId: cancelModalAllocation.id,
        reason: cancelReason.trim(),
      });

      if (res.success) {
        toast.success(t('allocationCancelledSuccess'));
        setCancelModalAllocation(null);
        setCancelReason('');
        setCancelError(null);
        onRefresh();
      } else {
        setCancelError(res.error || 'Failed to release allocation');
        toast.error(res.error || 'Failed to release allocation');
      }
    });
  };

  const activeAllocations = allocations.filter((a) =>
    ['PROPOSED', 'CONFIRMED', 'COMMITTED_TO_DEAL'].includes(a.status)
  );

  return (
    <Card className="border-slate-200 dark:border-slate-800 shadow-sm">
      <CardHeader className="py-3 px-4 border-b border-slate-100 dark:border-slate-800 flex flex-row items-center justify-between">
        <div className="flex items-center gap-2">
          <Scale className="w-4 h-4 text-emerald-600" />
          <CardTitle className="text-sm font-bold text-slate-800 dark:text-slate-200">
            {t('activeAllocations')} ({activeAllocations.length})
          </CardTitle>
        </div>
        {summary && (
          <div className="flex items-center gap-2 text-xs">
            <span className="text-slate-500">{t('allocatedQty')}:</span>
            <span className="font-mono font-bold text-emerald-700 dark:text-emerald-400">
              {formatNumber(summary.totalAllocated)} {summary.unitSymbol || summary.unitName}
            </span>
            <span className="text-slate-400">/</span>
            <span className="text-slate-500">{t('requestedQty')}:</span>
            <span className="font-mono font-bold text-slate-700 dark:text-slate-300">
              {formatNumber(summary.totalRequested)} {summary.unitSymbol || summary.unitName}
            </span>
          </div>
        )}
      </CardHeader>

      <CardContent className="p-0">
        {activeAllocations.length === 0 ? (
          <div className="p-6 text-center text-xs text-slate-500">
            <Scale className="w-8 h-8 mx-auto mb-2 text-slate-300 dark:text-slate-600" />
            <p className="font-medium text-slate-600 dark:text-slate-400">
              {t('noAllocationsYet')}
            </p>
            <p className="mt-1 text-slate-400">
              {language === 'hi'
                ? 'नीचे दिए गए उपयुक्त विक्रेता ऑफर्स में से मात्रा आवंटित करें।'
                : 'Select suitable seller offers below to propose allocations.'}
            </p>
          </div>
        ) : (
          <div className="divide-y divide-slate-100 dark:divide-slate-800">
            {activeAllocations.map((alloc) => (
              <div
                key={alloc.id}
                className="p-3.5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 hover:bg-slate-50/50 dark:hover:bg-slate-900/50 transition-colors"
              >
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-xs font-bold text-slate-900 dark:text-white">
                      {alloc.allocationReference}
                    </span>
                    <Badge
                      variant="outline"
                      className={`text-[10px] font-semibold uppercase px-1.5 py-0 ${
                        alloc.status === 'CONFIRMED'
                          ? 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-300 dark:border-emerald-800'
                          : alloc.status === 'PROPOSED'
                          ? 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950/40 dark:text-amber-300 dark:border-amber-800'
                          : alloc.status === 'COMMITTED_TO_DEAL'
                          ? 'bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950/40 dark:text-blue-300 dark:border-blue-800'
                          : 'bg-slate-100 text-slate-600 border-slate-200'
                      }`}
                    >
                      {alloc.status === 'CONFIRMED'
                        ? t('allocationStatusConfirmed')
                        : alloc.status === 'PROPOSED'
                        ? t('allocationStatusProposed')
                        : alloc.status === 'COMMITTED_TO_DEAL'
                        ? t('allocationStatusCommitted')
                        : alloc.status}
                    </Badge>
                    {alloc.dealId && (
                      <Badge variant="secondary" className="text-[10px] bg-indigo-50 text-indigo-700">
                        {language === 'hi' ? 'सौदा से जुड़ा' : 'Deal Linked'}
                      </Badge>
                    )}
                  </div>

                  <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-600 dark:text-slate-400">
                    <span className="flex items-center gap-1 font-medium text-slate-800 dark:text-slate-200">
                      <Building2 className="w-3.5 h-3.5 text-slate-400" />
                      {alloc.sellerCompanyName}
                      {alloc.sellerCompanyVerified && (
                        <ShieldCheck className="w-3 h-3 text-blue-600 inline" />
                      )}
                    </span>
                    <span>•</span>
                    <span>
                      {t('fieldQuantity')}:{' '}
                      <strong className="text-slate-900 dark:text-white font-mono">
                        {formatNumber(alloc.allocatedQuantity)} {alloc.unitSymbol || alloc.unitName}
                      </strong>
                    </span>
                    {alloc.allocatedPrice && (
                      <>
                        <span>•</span>
                        <span>
                          {formatCurrency(alloc.allocatedPrice)}/{alloc.unitSymbol || alloc.unitName} ({alloc.priceBasis})
                        </span>
                      </>
                    )}
                  </div>

                  {alloc.notes && (
                    <p className="text-[11px] text-slate-500 italic">
                      "{alloc.notes}"
                    </p>
                  )}
                </div>

                <div className="flex items-center gap-1.5 self-end sm:self-center">
                  {alloc.status === 'PROPOSED' && (
                    <Button
                      size="sm"
                      variant="outline"
                      className="h-7 text-xs border-emerald-300 text-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-950/40"
                      onClick={() => handleConfirm(alloc.id)}
                      disabled={isPending}
                    >
                      <CheckCircle2 className="w-3.5 h-3.5 mr-1" />
                      {t('confirmAllocation')}
                    </Button>
                  )}

                  {alloc.status === 'CONFIRMED' && !alloc.dealId && (
                    <Button
                      size="sm"
                      className="h-7 text-xs bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-semibold shadow-xs"
                      onClick={() => setCreateDealAllocation(alloc)}
                      disabled={isPending}
                    >
                      <Handshake className="w-3.5 h-3.5 mr-1" />
                      {t('createDeal')}
                    </Button>
                  )}

                  {alloc.dealId && (
                    <Link href={`/broker/deals/${alloc.dealId}`}>
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-7 text-xs border-indigo-200 text-indigo-700 hover:bg-indigo-50"
                      >
                        <FileText className="w-3.5 h-3.5 mr-1" />
                        {language === 'hi' ? 'सौदा देखें' : 'View Deal'}
                      </Button>
                    </Link>
                  )}

                  {!alloc.dealId && (
                    <Button
                      size="sm"
                      variant="ghost"
                      className="h-7 text-xs text-red-600 hover:text-red-700 hover:bg-red-50 dark:hover:bg-red-950/30"
                      onClick={() => {
                        setCancelModalAllocation(alloc);
                        setCancelReason('');
                        setCancelError(null);
                      }}
                      disabled={isPending}
                    >
                      <Ban className="w-3.5 h-3.5 mr-1" />
                      {language === 'hi' ? 'रद्द / मुक्त करें' : 'Release'}
                    </Button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>

      {/* Cancel / Release Confirmation Dialog */}
      <Dialog
        open={!!cancelModalAllocation}
        onOpenChange={(open) => {
          if (!open) setCancelModalAllocation(null);
        }}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold flex items-center gap-2">
              <AlertTriangle className="w-5 h-5 text-red-500" />
              {t('confirmCancelTitle')}
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              {language === 'hi'
                ? 'इस आवंटन को मुक्त करने से आरक्षित मात्रा वापस उपलब्ध हो जाएगी और मांग का शेष बढ़ जाएगा।'
                : 'Releasing this allocation returns reserved quantity back to available supply and increases the requirement balance.'}
            </DialogDescription>
          </DialogHeader>

          {cancelModalAllocation && (
            <div className="space-y-3 pt-1">
              <div className="p-2.5 bg-slate-50 dark:bg-slate-900 rounded border border-slate-200 dark:border-slate-800 text-xs">
                <span className="text-slate-500 block">Record:</span>
                <span className="font-mono font-bold text-slate-800 dark:text-slate-200">
                  {cancelModalAllocation.allocationReference}
                </span>{' '}
                — {formatNumber(cancelModalAllocation.allocatedQuantity)}{' '}
                {cancelModalAllocation.unitSymbol || cancelModalAllocation.unitName} from{' '}
                {cancelModalAllocation.sellerCompanyName}
              </div>

              <div>
                <Label className="text-xs font-semibold mb-1 block">
                  {t('confirmCancelPrompt')} *
                </Label>
                <Input
                  value={cancelReason}
                  onChange={(e) => setCancelReason(e.target.value)}
                  placeholder="e.g. Buyer opted for alternative lot, spec mismatch, price renegotiated..."
                  className="text-xs"
                />
                {cancelError && (
                  <p className="text-xs text-red-500 mt-1">{cancelError}</p>
                )}
              </div>
            </div>
          )}

          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setCancelModalAllocation(null)}
              disabled={isPending}
            >
              {language === 'hi' ? 'रद्द करें' : 'Cancel'}
            </Button>
            <Button
              type="button"
              size="sm"
              variant="destructive"
              onClick={handleCancelSubmit}
              disabled={isPending}
            >
              {isPending ? (
                <>
                  <Loader2 className="w-3.5 h-3.5 mr-1.5 animate-spin" />
                  {language === 'hi' ? 'मुक्त हो रहा है...' : 'Releasing...'}
                </>
              ) : (
                language === 'hi' ? 'आवंटन मुक्त करें' : 'Confirm Release'
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Deal Creation Dialog */}
      <DealCreateDialog
        open={!!createDealAllocation}
        onOpenChange={(open) => {
          if (!open) setCreateDealAllocation(null);
        }}
        allocation={createDealAllocation}
        onSuccess={() => {
          setCreateDealAllocation(null);
          onRefresh();
        }}
      />
    </Card>
  );
}
