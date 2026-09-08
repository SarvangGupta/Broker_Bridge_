"use client";

import React, { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import {
  FlaskConical,
  Award,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  RotateCcw,
  ShieldAlert,
  Loader2,
  Sparkles,
  ArrowRight,
  Truck,
  Lock,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import {
  finalizeDealAction,
  devResetDealVersionStatusAction,
} from "@/src/server/actions/finalization-actions";
import { createIdempotentBookingAction } from "@/src/server/actions/booking-actions";
import { SnapshotDetailsWithDiff } from "@/src/components/dashboard/visual-diff-snapshot";

interface DevFinalizationGateTesterProps {
  record: SnapshotDetailsWithDiff;
  className?: string;
}

export function DevFinalizationGateTester({
  record,
  className = "",
}: DevFinalizationGateTesterProps) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [isPending, startTransition] = useTransition();

  const isSellerConfirmed = record.status === "Seller Confirmed";
  const isFinalized = record.status === "Broker Finalized";

  // Handle Simulate Broker Finalization (Sprint 18.4)
  const handleSimulateFinalize = () => {
    startTransition(async () => {
      try {
        const res = await finalizeDealAction(record.requestId, record.versionNumber);

        if (res.success) {
          toast.success("Broker Finalization Gate Passed! 🎉", {
            description: res.message || `Deal Version ${record.versionNumber} is now finalized by Broker.`,
          });
          queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
          queryClient.invalidateQueries({ queryKey: ["in-app-notifications"] });
          router.refresh();
        } else {
          // Negative gate check caught!
          toast.error("Broker Finalization Gate Blocked 🛑", {
            description: res.error || "Pre-flight validation failed.",
          });
        }
      } catch (err: any) {
        toast.error("Broker Finalization Gate Blocked 🛑", {
          description: err.message || "Pre-flight validation failed.",
        });
      }
    });
  };

  // Handle Simulate System Booking (Sprint 18.5)
  const handleSimulateSystemBooking = () => {
    startTransition(async () => {
      try {
        const res = await createIdempotentBookingAction(record.requestId);

        if (res.success && res.bookingId) {
          toast.success("System Booking Created! 🚀", {
            description: `Unique Booking ID ${res.bookingId} issued and locked. Deal is now ready for dispatch!`,
          });
          queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
          queryClient.invalidateQueries({ queryKey: ["in-app-notifications"] });
          router.refresh();
        } else {
          toast.error("Booking Creation Failed 🛑", {
            description: res.error || "Failed to create booking.",
          });
        }
      } catch (err: any) {
        toast.error("Booking Creation Failed 🛑", {
          description: err.message || "Failed to create booking.",
        });
      }
    });
  };

  // Handle Dev Reset to Proposed
  const handleReset = (targetStatus: "Proposed" | "Seller Confirmed") => {
    startTransition(async () => {
      try {
        const res = await devResetDealVersionStatusAction(record.requestId, targetStatus);
        if (res.success) {
          toast.info(`Status reset to "${targetStatus}" for testing.`, {
            description: "You can now re-run the finalization gate pre-flight checks.",
          });
          queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
          router.refresh();
        } else {
          toast.error(res.error || "Reset failed");
        }
      } catch (err: any) {
        toast.error(err.message || "Reset failed");
      }
    });
  };

  return (
    <Card className={`border-dashed border-2 border-indigo-300 bg-indigo-50/40 shadow-xs ${className}`}>
      <CardHeader className="p-4 sm:p-5 pb-3">
        <div className="flex items-center justify-between gap-3 flex-wrap">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-lg bg-indigo-100 text-indigo-700 flex items-center justify-center shrink-0">
              <FlaskConical className="w-4 h-4 stroke-[2.25]" />
            </div>
            <div>
              <CardTitle className="text-sm sm:text-base font-bold text-slate-900 flex items-center gap-2">
                <span>Broker Finalization & Booking Simulator</span>
                <Badge variant="outline" className="bg-white border-indigo-200 text-indigo-700 font-bold text-[10px]">
                  Dev Mode
                </Badge>
              </CardTitle>
              <CardDescription className="text-xs text-slate-500">
                Test dual-confirmation system gates (Seller Confirmation ≠ Booking; Broker Finalization → System Booking ID)
              </CardDescription>
            </div>
          </div>

          <Badge
            className={`font-bold text-xs px-2.5 py-1 ${
              isFinalized
                ? "bg-teal-600 text-white"
                : isSellerConfirmed
                ? "bg-emerald-600 text-white"
                : "bg-amber-500 text-white"
            }`}
          >
            Current Status: {record.status}
          </Badge>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-5 pt-0 space-y-4">
        {/* Pre-Flight Gate Checklist */}
        <div className="p-3.5 rounded-xl bg-white border border-indigo-100 shadow-2xs space-y-2 text-xs">
          <span className="font-bold text-slate-900 block text-[11px] uppercase tracking-wider text-slate-400">
            Pre-Flight System Gate Checklist (v{record.versionNumber}):
          </span>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
            {/* Gate 1: Version Match */}
            <div className="flex items-center gap-2 p-2 rounded-lg bg-slate-50 border border-slate-100">
              <CheckCircle2 className="w-4 h-4 text-[#047857] shrink-0" />
              <div className="min-w-0">
                <span className="font-bold text-slate-800 block text-[11px]">Version Match</span>
                <span className="text-[10px] text-slate-500">v{record.versionNumber} Active</span>
              </div>
            </div>

            {/* Gate 2: Seller Confirmation */}
            <div
              className={`flex items-center gap-2 p-2 rounded-lg border ${
                isSellerConfirmed || isFinalized
                  ? "bg-emerald-50/70 border-emerald-200 text-emerald-900"
                  : "bg-rose-50/70 border-rose-200 text-rose-900"
              }`}
            >
              {isSellerConfirmed || isFinalized ? (
                <CheckCircle2 className="w-4 h-4 text-[#047857] shrink-0" />
              ) : (
                <XCircle className="w-4 h-4 text-rose-600 shrink-0" />
              )}
              <div className="min-w-0">
                <span className="font-bold block text-[11px]">Seller Confirmation</span>
                <span className="text-[10px]">
                  {isSellerConfirmed || isFinalized ? "Confirmed (Passed)" : "Missing (Will Block)"}
                </span>
              </div>
            </div>

            {/* Gate 3: Buyer Mandate */}
            <div className="flex items-center gap-2 p-2 rounded-lg bg-slate-50 border border-slate-100">
              <CheckCircle2 className="w-4 h-4 text-[#047857] shrink-0" />
              <div className="min-w-0">
                <span className="font-bold text-slate-800 block text-[11px]">Buyer Mandate</span>
                <span className="text-[10px] text-slate-500">Requirement Verified</span>
              </div>
            </div>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex flex-col sm:flex-row items-center gap-2.5 pt-1">
          {/* Simulate Broker Finalize Button (Sprint 18.4) */}
          <Button
            type="button"
            onClick={handleSimulateFinalize}
            disabled={isPending || isFinalized}
            className="w-full sm:flex-1 min-h-[48px] h-12 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs sm:text-sm rounded-xl cursor-pointer shadow-xs gap-2"
          >
            {isPending ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Running Pre-Flight Gate...</span>
              </>
            ) : (
              <>
                <Award className="w-4 h-4" />
                <span>
                  {isFinalized
                    ? "Broker Finalization Passed"
                    : isSellerConfirmed
                    ? "Simulate Broker Finalization (Expect SUCCESS)"
                    : "Simulate Broker Finalization (Expect GATE BLOCK)"}
                </span>
              </>
            )}
          </Button>

          {/* Reset Controls */}
          <div className="flex items-center gap-2 w-full sm:w-auto">
            <Button
              type="button"
              variant="outline"
              onClick={() => handleReset("Proposed")}
              disabled={isPending}
              className="flex-1 sm:flex-none border-slate-300 text-slate-700 text-xs font-semibold rounded-xl min-h-[48px] h-12 px-3.5 gap-1.5"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              <span>Reset 'Proposed'</span>
            </Button>

            <Button
              type="button"
              variant="outline"
              onClick={() => handleReset("Seller Confirmed")}
              disabled={isPending}
              className="flex-1 sm:flex-none border-emerald-300 text-[#047857] bg-emerald-50/50 hover:bg-emerald-50 text-xs font-semibold rounded-xl min-h-[48px] h-12 px-3.5 gap-1.5"
            >
              <CheckCircle2 className="w-3.5 h-3.5" />
              <span>Set 'Confirmed'</span>
            </Button>
          </div>
        </div>

        {/* SIMULATE SYSTEM BOOKING BUTTON (Sprint 18.5) */}
        {isFinalized && (
          <div className="pt-3 border-t border-indigo-200/80 space-y-2">
            <div className="flex items-center justify-between text-xs">
              <span className="font-bold text-emerald-900 flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5 text-emerald-600" />
                <span>Next Gate: System Booking Creation (Sprint 18.5)</span>
              </span>
              <Badge className="bg-emerald-100 text-emerald-800 border-emerald-300 text-[10px] font-bold">
                Ready to Lock & Book
              </Badge>
            </div>

            <Button
              type="button"
              onClick={handleSimulateSystemBooking}
              disabled={isPending}
              className="w-full min-h-[48px] h-12 bg-[#059669] hover:bg-[#047857] text-white font-black text-xs sm:text-sm rounded-xl cursor-pointer shadow-md gap-2 transition-all hover:scale-[1.005] active:scale-[0.995]"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin text-white" />
                  <span>Issuing Unique Booking ID (Sprint 18.5)...</span>
                </>
              ) : (
                <>
                  <Sparkles className="w-4 h-4 text-emerald-200" />
                  <span>Simulate System Booking (Sprint 18.5)</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
