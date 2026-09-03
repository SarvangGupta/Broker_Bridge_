"use client";

import React from "react";
import { Truck, X } from "lucide-react";
import { useMediaQuery } from "@/src/hooks/use-media-query";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { LoadingReadinessForm } from "@/src/components/forms/loading-readiness-form";

export interface LoadingStatusModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  availabilityId: string;
  lotNumber?: string | null;
  commodityName?: string | null;
  initialData?: {
    loadingStatus?: string | null;
    loadingDuration?: number | null;
    loadingStartDate?: Date | string | null;
    loadingCapacity?: string | number | null;
    loadingRemarks?: string | null;
  };
  onSuccess?: () => void;
}

export function LoadingStatusModal({
  open,
  onOpenChange,
  availabilityId,
  lotNumber,
  commodityName,
  initialData,
  onSuccess,
}: LoadingStatusModalProps) {
  const isDesktop = useMediaQuery("(min-width: 768px)");

  const handleSuccess = () => {
    onOpenChange(false);
    onSuccess?.();
  };

  const handleCancel = () => {
    onOpenChange(false);
  };

  const headerContent = (
    <div className="flex items-center gap-3">
      <div className="h-10 w-10 sm:h-11 sm:w-11 rounded-xl bg-emerald-100 text-[#047857] flex items-center justify-center shrink-0 shadow-2xs">
        <Truck className="h-5 w-5 stroke-[2.2]" />
      </div>
      <div>
        <h2 className="text-lg sm:text-xl font-bold text-slate-900 leading-tight">
          Update Loading Readiness
        </h2>
        <p className="text-xs text-slate-500 mt-0.5">
          {lotNumber ? `Lot #${lotNumber}` : commodityName || "Inventory Lot"} • Inform brokers of stock dispatch availability
        </p>
      </div>
    </div>
  );

  if (isDesktop) {
    return (
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-[620px] max-h-[90vh] overflow-y-auto p-0 rounded-2xl border-slate-200 shadow-2xl">
          <DialogHeader className="p-6 pb-4 border-b border-slate-100 bg-slate-50/70 sticky top-0 z-10 backdrop-blur-xs">
            {headerContent}
          </DialogHeader>

          <div className="p-6">
            <LoadingReadinessForm
              availabilityId={availabilityId}
              lotNumber={lotNumber}
              commodityName={commodityName}
              initialData={initialData}
              onSuccess={handleSuccess}
              onCancel={handleCancel}
            />
          </div>
        </DialogContent>
      </Dialog>
    );
  }

  // Mobile Bottom Sheet Presentation
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="bottom"
        className="max-h-[92vh] overflow-y-auto p-0 rounded-t-3xl border-slate-200"
      >
        <SheetHeader className="p-5 pb-4 border-b border-slate-100 bg-slate-50/80 sticky top-0 z-10 backdrop-blur-xs">
          {headerContent}
        </SheetHeader>

        <div className="p-5 pb-8">
          <LoadingReadinessForm
            availabilityId={availabilityId}
            lotNumber={lotNumber}
            commodityName={commodityName}
            initialData={initialData}
            onSuccess={handleSuccess}
            onCancel={handleCancel}
          />
        </div>
      </SheetContent>
    </Sheet>
  );
}
