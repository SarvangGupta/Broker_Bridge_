'use client';

import React, { useState, useMemo } from 'react';
import {
  FileText,
  Search,
  SlidersHorizontal,
  Sparkles,
  Inbox,
  AlertCircle,
  CheckCircle2,
  Layers,
  ArrowUpDown,
  RefreshCw,
  Plus,
  RotateCcw,
  XCircle,
} from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { RequirementCard } from './requirement-card';
import { RequirementFormDialog } from './requirement-form-dialog';
import {
  cancelBrokerRequirementAction,
  renewBrokerRequirementAction,
  type BrokerRequirementItem,
} from '@/src/server/actions/broker-mandate-actions';
import type {
  BrokerAssignedRequirement,
  BrokerOperationalStatus,
} from '@/src/server/actions/broker-work-actions';
import { useLanguage } from '@/src/lib/i18n/language-context';
import { toast } from 'sonner';

interface BrokerRequirementsInboxProps {
  initialRequirements: BrokerAssignedRequirement[];
  error?: string;
}

type FilterTab = 'ALL' | 'ACTION_REQUIRED' | 'NEW_DEMAND' | 'SOURCING' | 'PARTIAL';

export function BrokerRequirementsInbox({
  initialRequirements = [],
  error,
}: BrokerRequirementsInboxProps) {
  const { t } = useLanguage();

  const [requirementsList, setRequirementsList] = useState<BrokerAssignedRequirement[]>(initialRequirements);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<FilterTab>('ALL');
  const [sortBy, setSortBy] = useState<'NEWEST' | 'URGENT' | 'VOLUME'>('URGENT');

  // Modal states
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<BrokerRequirementItem | null>(null);

  // Cancellation Modal
  const [cancellingReq, setCancellingReq] = useState<BrokerAssignedRequirement | null>(null);
  const [cancelReason, setCancelReason] = useState('');
  const [isCancelling, setIsCancelling] = useState(false);

  // Renewal Modal
  const [renewingReq, setRenewingReq] = useState<BrokerAssignedRequirement | null>(null);
  const [renewDate, setRenewDate] = useState('');
  const [isRenewing, setIsRenewing] = useState(false);

  // Compute status counts for filter badges
  const counts = useMemo(() => {
    return {
      all: requirementsList.length,
      actionRequired: requirementsList.filter((r) => r.operationalStatus === 'Action Required').length,
      newDemand: requirementsList.filter((r) => r.operationalStatus === 'New Demand').length,
      sourcing: requirementsList.filter((r) => r.operationalStatus === 'Sourcing').length,
      partial: requirementsList.filter((r) => r.operationalStatus === 'Partially Fulfilled').length,
    };
  }, [requirementsList]);

  // Filter & Sort requirements
  const filteredRequirements = useMemo(() => {
    let list = [...requirementsList];

    // Filter by Tab
    if (activeFilter === 'ACTION_REQUIRED') {
      list = list.filter((r) => r.operationalStatus === 'Action Required');
    } else if (activeFilter === 'NEW_DEMAND') {
      list = list.filter((r) => r.operationalStatus === 'New Demand');
    } else if (activeFilter === 'SOURCING') {
      list = list.filter((r) => r.operationalStatus === 'Sourcing');
    } else if (activeFilter === 'PARTIAL') {
      list = list.filter((r) => r.operationalStatus === 'Partially Fulfilled');
    }

    // Filter by Search Query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      list = list.filter((r) => {
        return (
          r.commodityName.toLowerCase().includes(q) ||
          r.gradeName.toLowerCase().includes(q) ||
          r.buyerCompanyName.toLowerCase().includes(q) ||
          r.requirementRef.toLowerCase().includes(q) ||
          (r.categoryName && r.categoryName.toLowerCase().includes(q)) ||
          (r.industryName && r.industryName.toLowerCase().includes(q))
        );
      });
    }

    // Sort
    list.sort((a, b) => {
      if (sortBy === 'URGENT') {
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return new Date(a.targetDateRaw).getTime() - new Date(b.targetDateRaw).getTime();
      }
      if (sortBy === 'VOLUME') {
        return b.quantity - a.quantity;
      }
      // NEWEST
      return new Date(b.targetDateRaw).getTime() - new Date(a.targetDateRaw).getTime();
    });

    return list;
  }, [requirementsList, activeFilter, searchQuery, sortBy]);

  // Convert BrokerAssignedRequirement to BrokerRequirementItem for Form Dialog
  const handleEdit = (req: BrokerAssignedRequirement) => {
    const item: BrokerRequirementItem = {
      id: req.id,
      requirementRef: req.requirementRef,
      buyerCompanyId: '',
      buyerCompanyName: req.buyerCompanyName,
      commodityId: req.commodityId,
      commodityName: req.commodityName,
      gradeId: req.gradeId,
      gradeName: req.gradeName,
      requestedQuantity: req.quantity,
      allocatedQuantity: req.fulfilledQuantity,
      remainingQuantity: Math.max(0, req.quantity - req.fulfilledQuantity),
      fulfillmentPercentage: req.fulfillmentPercentage,
      unitName: req.unitName,
      unitSymbol: req.unitSymbol || 'MT',
      targetPrice: req.targetPrice,
      deliveryTerms: req.deliveryTerms,
      targetDate: req.targetDateRaw,
      targetDateFormatted: req.targetDateFormatted,
      isUrgent: req.isUrgent,
      hoursUntilTarget: req.hoursUntilTarget,
      isExpired: new Date(req.targetDateRaw) < new Date(),
      status: req.status,
      createdAt: '',
      createdAtFormatted: req.createdAtFormatted,
    };
    setEditingItem(item);
    setIsFormOpen(true);
  };

  // Cancel Handler
  const handleConfirmCancel = async () => {
    if (!cancellingReq) return;
    if (!cancelReason.trim() || cancelReason.trim().length < 3) {
      toast.error(t('reasonRequired'));
      return;
    }

    setIsCancelling(true);
    try {
      const res = await cancelBrokerRequirementAction(cancellingReq.id, cancelReason.trim());
      if (res.success) {
        toast.success(t('recordCancelledSuccess'));
        setRequirementsList((prev) =>
          prev.map((r) => (r.id === cancellingReq.id ? { ...r, status: 'Cancelled' } : r))
        );
        setCancellingReq(null);
        setCancelReason('');
      } else {
        toast.error(res.error || 'Failed to cancel requirement');
      }
    } catch (err: any) {
      toast.error(err?.message || 'An unexpected error occurred');
    } finally {
      setIsCancelling(false);
    }
  };

  // Renew Handler
  const handleConfirmRenew = async () => {
    if (!renewingReq || !renewDate) return;

    setIsRenewing(true);
    try {
      const res = await renewBrokerRequirementAction(renewingReq.id, new Date(renewDate).toISOString());
      if (res.success) {
        toast.success(t('recordRenewedSuccess'));
        setRequirementsList((prev) =>
          prev.map((r) =>
            r.id === renewingReq.id
              ? {
                  ...r,
                  status: 'Open',
                  targetDateRaw: new Date(renewDate).toISOString(),
                  targetDateFormatted: new Date(renewDate).toLocaleDateString('en-IN', {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                  }),
                  isUrgent: false,
                }
              : r
          )
        );
        setRenewingReq(null);
        setRenewDate('');
      } else {
        toast.error(res.error || 'Failed to renew requirement');
      }
    } catch (err: any) {
      toast.error(err?.message || 'An unexpected error occurred');
    } finally {
      setIsRenewing(false);
    }
  };

  if (error) {
    return (
      <Card className="border-rose-200 bg-rose-50/50">
        <CardContent className="p-6 text-center space-y-3">
          <AlertCircle className="w-8 h-8 text-rose-600 mx-auto" />
          <div className="space-y-1">
            <h3 className="font-bold text-slate-800 text-base">Unable to Load Requirements</h3>
            <p className="text-xs text-slate-600">{error}</p>
          </div>
          <Button
            variant="outline"
            onClick={() => window.location.reload()}
            className="min-h-[48px] h-12 border-rose-200 text-rose-700 hover:bg-rose-100"
          >
            <RefreshCw className="w-4 h-4 mr-2" />
            <span>Retry Connection</span>
          </Button>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4 sm:space-y-5">
      {/* Disclaimer Banner & Action Header */}
      <div className="bg-amber-50/70 border border-amber-200/80 rounded-xl p-3 text-xs text-amber-900 flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <AlertCircle className="w-4 h-4 text-amber-600 shrink-0" />
          <span>{t('brokerDisclaimerNotOwner')}</span>
        </div>
        <Button
          onClick={() => {
            setEditingItem(null);
            setIsFormOpen(true);
          }}
          className="min-h-[44px] h-10 px-3.5 bg-[#0D9488] hover:bg-teal-700 text-white font-bold text-xs rounded-lg shrink-0 flex items-center gap-1.5 shadow-xs"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>{t('actionCreateRequirement')}</span>
        </Button>
      </div>

      {/* Search & Operational Filter Bar */}
      <div className="flex flex-col gap-3">
        {/* Search Input Box */}
        <div className="relative w-full">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          <Input
            type="text"
            placeholder="Search by commodity, grade, buyer, or REQ ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10 min-h-[48px] h-12 bg-white border-slate-200/90 rounded-xl text-xs sm:text-sm focus-visible:ring-[#0D9488]"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-slate-400 hover:text-slate-600 px-1.5 py-0.5"
            >
              Clear
            </button>
          )}
        </div>

        {/* Operational Filter Chips */}
        <div className="w-full overflow-x-auto touch-pan-x pb-1 scrollbar-none">
          <div className="flex items-center gap-1.5 min-w-max">
            {/* All */}
            <button
              type="button"
              onClick={() => setActiveFilter('ALL')}
              className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                activeFilter === 'ALL'
                  ? 'bg-slate-900 text-white shadow-2xs'
                  : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200/80'
              }`}
            >
              <span>All Assigned</span>
              <span
                className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                  activeFilter === 'ALL'
                    ? 'bg-slate-800 text-slate-200'
                    : 'bg-slate-100 text-slate-500'
                }`}
              >
                {counts.all}
              </span>
            </button>

            {/* Action Required */}
            {counts.actionRequired > 0 && (
              <button
                type="button"
                onClick={() => setActiveFilter('ACTION_REQUIRED')}
                className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                  activeFilter === 'ACTION_REQUIRED'
                    ? 'bg-amber-600 text-white shadow-2xs'
                    : 'bg-amber-50 text-amber-800 hover:bg-amber-100 border border-amber-200/80'
                }`}
              >
                <span className="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse" />
                <span>Action Required</span>
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                    activeFilter === 'ACTION_REQUIRED'
                      ? 'bg-amber-700 text-white'
                      : 'bg-amber-200/70 text-amber-900'
                  }`}
                >
                  {counts.actionRequired}
                </span>
              </button>
            )}

            {/* New Demand */}
            <button
              type="button"
              onClick={() => setActiveFilter('NEW_DEMAND')}
              className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                activeFilter === 'NEW_DEMAND'
                  ? 'bg-[#0D9488] text-white shadow-2xs'
                  : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200/80'
              }`}
            >
              <Sparkles className="w-3.5 h-3.5 text-[#0D9488]" />
              <span>New Demand</span>
              <span
                className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                  activeFilter === 'NEW_DEMAND'
                    ? 'bg-teal-800 text-teal-100'
                    : 'bg-slate-100 text-slate-500'
                }`}
              >
                {counts.newDemand}
              </span>
            </button>

            {/* Sourcing */}
            <button
              type="button"
              onClick={() => setActiveFilter('SOURCING')}
              className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                activeFilter === 'SOURCING'
                  ? 'bg-blue-600 text-white shadow-2xs'
                  : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200/80'
              }`}
            >
              <Search className="w-3.5 h-3.5 text-blue-500" />
              <span>Sourcing</span>
              <span
                className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                  activeFilter === 'SOURCING'
                    ? 'bg-blue-700 text-blue-100'
                    : 'bg-slate-100 text-slate-500'
                }`}
              >
                {counts.sourcing}
              </span>
            </button>

            {/* Partially Fulfilled */}
            {counts.partial > 0 && (
              <button
                type="button"
                onClick={() => setActiveFilter('PARTIAL')}
                className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                  activeFilter === 'PARTIAL'
                    ? 'bg-indigo-600 text-white shadow-2xs'
                    : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200/80'
                }`}
              >
                <Layers className="w-3.5 h-3.5 text-indigo-500" />
                <span>Partial Supply</span>
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                    activeFilter === 'PARTIAL'
                      ? 'bg-indigo-700 text-indigo-100'
                      : 'bg-slate-100 text-slate-500'
                  }`}
                >
                  {counts.partial}
                </span>
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Grid of Cards or Empty State */}
      {filteredRequirements.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-5">
          {filteredRequirements.map((req) => (
            <RequirementCard
              key={req.id}
              requirement={req}
              onEdit={handleEdit}
              onCancel={(r) => {
                setCancellingReq(r);
                setCancelReason('');
              }}
              onRenew={(r) => {
                setRenewingReq(r);
                const future = new Date();
                future.setDate(future.getDate() + 7);
                setRenewDate(future.toISOString().split('T')[0]);
              }}
            />
          ))}
        </div>
      ) : (
        /* Empty State */
        <Card className="border-dashed border-2 border-slate-200 bg-white/70">
          <CardContent className="p-8 sm:p-12 text-center space-y-4">
            <div className="mx-auto w-14 h-14 rounded-2xl bg-teal-50 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
              <Inbox className="w-7 h-7" />
            </div>
            <div className="space-y-1.5 max-w-sm mx-auto">
              <h3 className="font-bold text-slate-900 text-base sm:text-lg">
                No Active Requirements
              </h3>
              <p className="text-xs sm:text-sm text-slate-500 leading-relaxed">
                {searchQuery || activeFilter !== 'ALL'
                  ? 'No buyer requirements matched your filter or search criteria. Try resetting filters.'
                  : 'You currently have no requirements assigned to you from the Deal Desk.'}
              </p>
            </div>
            <div className="flex flex-wrap items-center justify-center gap-2 pt-2">
              {(searchQuery || activeFilter !== 'ALL') && (
                <Button
                  variant="outline"
                  onClick={() => {
                    setSearchQuery('');
                    setActiveFilter('ALL');
                  }}
                  className="min-h-[48px] h-12 text-xs font-semibold"
                >
                  Reset All Filters
                </Button>
              )}
              <Button
                onClick={() => {
                  setEditingItem(null);
                  setIsFormOpen(true);
                }}
                className="min-h-[48px] h-12 bg-[#0D9488] hover:bg-teal-700 text-white font-bold text-xs"
              >
                <Plus className="w-4 h-4 mr-1.5" />
                <span>{t('actionCreateRequirement')}</span>
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Form Dialog for Create / Edit Requirement */}
      <RequirementFormDialog
        open={isFormOpen}
        onOpenChange={setIsFormOpen}
        requirement={editingItem}
        onSuccess={() => {
          window.location.reload();
        }}
      />

      {/* Cancellation Dialog */}
      <Dialog
        open={Boolean(cancellingReq)}
        onOpenChange={(open) => !open && setCancellingReq(null)}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold text-slate-900">
              {t('confirmCancelTitle')}
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              {t('confirmCancelPrompt')}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 py-2">
            <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-100 text-xs">
              <span className="font-semibold text-slate-800">
                {cancellingReq?.buyerCompanyName}
              </span>
              <span className="text-slate-500 block">
                {cancellingReq?.commodityName} • {cancellingReq?.requirementRef}
              </span>
            </div>

            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">
                Cancellation Reason <span className="text-rose-500">*</span>
              </Label>
              <Input
                placeholder="e.g. Buyer procured elsewhere, mill temporarily shut down"
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
                className="min-h-[48px] h-12 bg-white text-xs"
              />
            </div>
          </div>

          <DialogFooter className="flex flex-col-reverse sm:flex-row gap-2">
            <Button
              variant="outline"
              onClick={() => setCancellingReq(null)}
              disabled={isCancelling}
              className="min-h-[48px] h-12 w-full sm:w-auto"
            >
              {t('actionCancel')}
            </Button>
            <Button
              onClick={handleConfirmCancel}
              disabled={isCancelling}
              className="min-h-[48px] h-12 w-full sm:w-auto bg-rose-600 hover:bg-rose-700 text-white font-bold"
            >
              {isCancelling ? 'Processing...' : t('actionConfirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Renewal Dialog */}
      <Dialog
        open={Boolean(renewingReq)}
        onOpenChange={(open) => !open && setRenewingReq(null)}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base font-bold text-slate-900">
              {t('actionRenewRequirement')}
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              Extend required delivery date to reactivate matching for this mandate.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 py-2">
            <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-100 text-xs">
              <span className="font-semibold text-slate-800">
                {renewingReq?.buyerCompanyName}
              </span>
              <span className="text-slate-500 block">
                {renewingReq?.commodityName} • {renewingReq?.requirementRef}
              </span>
            </div>

            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">
                New Target Delivery Date <span className="text-rose-500">*</span>
              </Label>
              <Input
                type="date"
                value={renewDate}
                min={new Date().toISOString().split('T')[0]}
                onChange={(e) => setRenewDate(e.target.value)}
                className="min-h-[48px] h-12 bg-white"
              />
            </div>
          </div>

          <DialogFooter className="flex flex-col-reverse sm:flex-row gap-2">
            <Button
              variant="outline"
              onClick={() => setRenewingReq(null)}
              disabled={isRenewing}
              className="min-h-[48px] h-12 w-full sm:w-auto"
            >
              {t('actionCancel')}
            </Button>
            <Button
              onClick={handleConfirmRenew}
              disabled={isRenewing || !renewDate}
              className="min-h-[48px] h-12 w-full sm:w-auto bg-[#0D9488] hover:bg-teal-700 text-white font-bold"
            >
              {isRenewing ? 'Processing...' : t('actionConfirm')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
