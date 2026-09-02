"use client";

import { useState } from "react";
import { format } from "date-fns";
import { toast } from "sonner";
import { Loader2, MapPin, Calendar, Ban, RefreshCw, Pencil, FlaskConical, FileText } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { QualityStatusBadge } from "@/src/components/dashboard/quality-status-badge";
import { cancelAvailabilityAction } from "@/src/server/actions/availability-actions";
import { LabTestForm } from "@/src/components/forms/lab-test-form";

export interface InventoryCardProps {
  item: {
    id: string;
    commodityId?: string | null;
    quantity: number | string;
    price: string | number;
    status: string;
    createdAt: Date | string;
    validUntil: Date | string;
    commodityName: string | null;
    categoryName?: string | null;
    industryName?: string | null;
    gradeName: string | null;
    unitSymbol: string | null;
    stateName: string | null;
    districtName: string | null;
    lotNumber?: string | null;
    labTestStatus?: string | null;
    labTestValidUntil?: Date | string | null;
    labTestTestDate?: Date | string | null;
    labTestId?: string | null;
  };
  onCancelSuccess?: () => void;
}

export function InventoryCard({ item, onCancelSuccess }: InventoryCardProps) {
  const router = useRouter();
  const [cancelling, setCancelling] = useState(false);
  const [labDialogOpen, setLabDialogOpen] = useState(false);

  const isOpen = item.status === "Active" || item.status === "Open";
  const isExpired = item.status === "Expired";
  const canUploadLabReport = ["Active", "Open", "Draft", "Pending Approval"].includes(item.status);

  async function handleCancel() {
    setCancelling(true);
    try {
      const res = await cancelAvailabilityAction(item.id);
      if (res.success) {
        toast.success("Availability lot cancelled successfully");
        onCancelSuccess?.();
      } else {
        toast.error(res.error || "Failed to cancel availability lot");
      }
    } catch (error: any) {
      toast.error(error.message || "An unexpected error occurred");
    } finally {
      setCancelling(false);
    }
  }

  return (
    <div className="bg-white rounded-2xl border border-slate-200/80 p-5 sm:p-6 shadow-xs hover:shadow-md transition-all duration-200 flex flex-col justify-between relative group">
      <div>
        {/* TOP HEADER: Breadcrumb • Commodity • Quality Parameter & Status Badge */}
        <div className="flex items-start justify-between gap-2 mb-3">
          <div>
            {(item.industryName || item.categoryName) && (
              <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                {[item.industryName, item.categoryName].filter(Boolean).join(" • ")}
              </span>
            )}
            <span className="text-xs font-bold uppercase tracking-wider text-slate-700 block">
              {item.commodityName || "Commodity"}
            </span>
            <h3 className="text-base sm:text-lg font-semibold text-slate-900 leading-tight">
              {item.gradeName || "Standard Grade"}
            </h3>
            {item.lotNumber && (
              <span className="text-[11px] font-mono font-medium text-slate-500 block mt-0.5">
                Lot #{item.lotNumber}
              </span>
            )}
          </div>
          <div className="flex flex-col items-end gap-1.5 shrink-0">
            <Badge
              variant="outline"
              className={
                isOpen
                  ? "bg-emerald-50 text-emerald-700 border-emerald-200/80 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full"
                  : isExpired
                  ? "bg-amber-50 text-amber-700 border-amber-200/80 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full"
                  : "bg-slate-100 text-slate-600 border-slate-200 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full"
              }
            >
              {item.status === "Open" ? "Active" : item.status}
            </Badge>

            {/* Quality Readiness Badge */}
            <QualityStatusBadge
              status={item.labTestStatus}
              validUntil={item.labTestValidUntil}
              testDate={item.labTestTestDate}
            />
          </div>
        </div>

        {/* STATS: Quantity & Asking Rate */}
        <div className="grid grid-cols-2 gap-3 py-3 px-3.5 bg-slate-50/80 rounded-xl border border-slate-100 mb-4">
          <div>
            <span className="text-[11px] font-medium text-slate-400 uppercase tracking-wider block">
              Available Stock
            </span>
            <span className="text-base sm:text-lg font-bold text-slate-900">
              {item.quantity} {item.unitSymbol || "Units"}
            </span>
          </div>
          <div>
            <span className="text-[11px] font-medium text-slate-400 uppercase tracking-wider block">
              Asking Rate
            </span>
            <span className="text-base sm:text-lg font-bold text-[#059669]">
              ₹{item.price}
            </span>
          </div>
        </div>

        {/* LOCATION & VALIDITY METADATA */}
        <div className="space-y-1.5 text-xs text-slate-500">
          <div className="flex items-center gap-1.5">
            <MapPin className="h-3.5 w-3.5 text-slate-400 shrink-0" />
            <span className="truncate">
              {[item.districtName, item.stateName].filter(Boolean).join(", ") || "Location Unspecified"}
            </span>
          </div>
          <div className="flex items-center gap-1.5">
            <Calendar className="h-3.5 w-3.5 text-slate-400 shrink-0" />
            <span className="font-medium text-slate-600">
              Valid till {format(new Date(item.validUntil), "MMM d, yyyy")}
            </span>
          </div>
        </div>
      </div>

      {/* ACTION FOOTER */}
      {(isOpen || canUploadLabReport || isExpired) && (
        <div className="pt-4 mt-4 border-t border-slate-100 space-y-2.5">
          {/* Lab Test Evidence Trigger */}
          {canUploadLabReport && (
            <Button
              type="button"
              variant="outline"
              size="lg"
              onClick={() => setLabDialogOpen(true)}
              className="w-full min-h-[48px] h-12 text-slate-800 hover:text-slate-900 hover:bg-emerald-50/60 border-slate-300 hover:border-emerald-300 font-semibold rounded-xl text-sm sm:text-base transition-colors flex items-center justify-center gap-2 cursor-pointer shadow-xs group/btn"
            >
              <FlaskConical className="h-4 w-4 text-emerald-600 group-hover/btn:scale-110 transition-transform" />
              <span>{item.labTestId ? "Manage Lab Report" : "Upload Lab Report"}</span>
            </Button>
          )}

          {/* Active Inventory Actions: Cancel & Edit */}
          {isOpen && (
            <div className="grid grid-cols-2 gap-3">
              <Button
                variant="outline"
                size="lg"
                disabled={cancelling}
                onClick={handleCancel}
                className="w-full min-h-[48px] h-12 text-rose-600 hover:text-rose-700 hover:bg-rose-50 border-slate-200 hover:border-rose-200 font-semibold rounded-xl text-sm sm:text-base transition-colors flex items-center justify-center gap-2 cursor-pointer"
              >
                {cancelling ? (
                  <Loader2 className="h-4 w-4 animate-spin text-rose-600" />
                ) : (
                  <>
                    <Ban className="h-4 w-4" />
                    Cancel
                  </>
                )}
              </Button>
              <Link
                href={`?edit=${item.id}`}
                className="w-full min-h-[48px] h-12 bg-slate-100 hover:bg-slate-200 text-slate-800 font-semibold rounded-xl text-sm sm:text-base transition-colors flex items-center justify-center gap-2 cursor-pointer shadow-xs"
              >
                <Pencil className="h-4 w-4" />
                Edit
              </Link>
            </div>
          )}

          {/* Expired Inventory Action: Quick Renew */}
          {isExpired && (
            <div>
              <Link
                href={`?renew=${item.id}`}
                className="w-full min-h-[48px] h-12 bg-[#059669] hover:bg-[#047857] text-white font-semibold rounded-xl text-sm sm:text-base transition-colors flex items-center justify-center gap-2 cursor-pointer shadow-xs"
              >
                <RefreshCw className="h-4 w-4" />
                Quick Renew
              </Link>
            </div>
          )}
        </div>
      )}

      {/* Lab Evidence Modal Dialog */}
      {canUploadLabReport && (
        <Dialog open={labDialogOpen} onOpenChange={setLabDialogOpen}>
          <DialogContent className="sm:max-w-[780px] max-h-[90vh] overflow-y-auto p-0 rounded-2xl">
            <DialogHeader className="p-6 pb-4 border-b border-slate-100 bg-slate-50/70 sticky top-0 z-10 backdrop-blur-xs">
              <div className="flex items-center gap-2.5">
                <div className="h-10 w-10 rounded-xl bg-emerald-100/90 text-emerald-700 flex items-center justify-center shrink-0 shadow-2xs">
                  <FlaskConical className="h-5 w-5" />
                </div>
                <div>
                  <DialogTitle className="text-lg sm:text-xl font-bold text-slate-900">
                    Manage Laboratory Evidence: {item.lotNumber ? `Lot #${item.lotNumber}` : item.commodityName || "Availability Lot"}
                  </DialogTitle>
                  <DialogDescription className="text-xs text-slate-500 mt-0.5">
                    Submit analytical laboratory parameters and physical COA test certificates for this supply lot.
                  </DialogDescription>
                </div>
              </div>
            </DialogHeader>

            <div className="p-4 sm:p-6">
              <LabTestForm
                availabilityId={item.id}
                commodityId={item.commodityId || ""}
                onSuccess={() => {
                  setLabDialogOpen(false);
                  toast.success("Laboratory test record updated successfully");
                  router.refresh();
                }}
                onCancel={() => setLabDialogOpen(false)}
              />
            </div>
          </DialogContent>
        </Dialog>
      )}
    </div>
  );
}
