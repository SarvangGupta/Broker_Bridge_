"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { format } from "date-fns";
import {
  Loader2,
  Calendar as CalendarIcon,
  Truck,
  Clock,
  AlertTriangle,
  AlertCircle,
  CheckCircle2,
  Info,
  CalendarCheck,
  Building2,
  Layers,
} from "lucide-react";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { cn } from "@/lib/utils";

import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
  FormDescription,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";

import {
  loadingReadinessSchema,
  LoadingReadinessInput,
  LOADING_STATUSES,
  LoadingStatus,
  LOADING_STATUS_CONFIG,
} from "@/src/types/loading-schema";
import { updateLoadingReadinessAction } from "@/src/server/actions/loading-actions";

export interface LoadingReadinessFormProps {
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
  onCancel?: () => void;
}

export function LoadingReadinessForm({
  availabilityId,
  lotNumber,
  commodityName,
  initialData,
  onSuccess,
  onCancel,
}: LoadingReadinessFormProps) {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Initialize form with existing lot data or clean defaults
  const form = useForm<LoadingReadinessInput>({
    resolver: zodResolver(loadingReadinessSchema) as any,
    defaultValues: {
      loading_status: (initialData?.loadingStatus as LoadingStatus) || "Not Ready",
      loading_duration: initialData?.loadingDuration ? Number(initialData.loadingDuration) : undefined,
      loading_start_date: initialData?.loadingStartDate ? new Date(initialData.loadingStartDate) : undefined,
      loading_capacity: initialData?.loadingCapacity ? Number(initialData.loadingCapacity) : undefined,
      loading_remarks: initialData?.loadingRemarks || "",
    },
  });

  const selectedStatus = form.watch("loading_status");
  const isRemarksRequired = selectedStatus === "Delayed" || selectedStatus === "Blocked";

  async function onSubmit(data: LoadingReadinessInput) {
    setIsSubmitting(true);
    try {
      const res = await updateLoadingReadinessAction(availabilityId, data);
      if (res.success) {
        toast.success("Loading readiness status updated successfully!");
        onSuccess?.();
        router.refresh();
      } else {
        toast.error(res.error || "Failed to update loading readiness");
      }
    } catch (error: any) {
      console.error("Submission error:", error);
      toast.error(error.message || "An unexpected error occurred while updating status");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-5">
        
        {/* CONTEXT STRIP: Lot Identifier */}
        {(lotNumber || commodityName) && (
          <div className="flex items-center gap-2 px-3.5 py-2.5 bg-slate-50 border border-slate-200/80 rounded-xl text-xs text-slate-600">
            <Layers className="h-4 w-4 text-slate-400 shrink-0" />
            <span className="font-semibold text-slate-800">
              {commodityName || "Inventory Lot"}
            </span>
            {lotNumber && (
              <span className="font-mono text-slate-500 bg-white px-1.5 py-0.5 rounded border border-slate-200">
                Lot #{lotNumber}
              </span>
            )}
          </div>
        )}

        {/* 1. LOADING STATUS DROPDOWN */}
        <FormField
          control={form.control}
          name="loading_status"
          render={({ field }) => (
            <FormItem>
              <FormLabel className="text-xs sm:text-sm font-bold text-slate-800 flex items-center justify-between">
                <span>Operational Loading Status <span className="text-rose-500">*</span></span>
                <span className="text-[11px] font-normal text-slate-400">Pre-deal readiness</span>
              </FormLabel>
              <Select
                value={field.value}
                onValueChange={(val) => field.onChange(val as LoadingStatus)}
              >
                <FormControl>
                  <SelectTrigger className="w-full min-h-[48px] h-12 bg-white rounded-xl border-slate-200 focus:border-emerald-500 text-sm font-medium px-3.5 shadow-2xs">
                    <SelectValue placeholder="Select loading status" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent className="max-h-[300px] rounded-xl shadow-lg border-slate-200">
                  {LOADING_STATUSES.map((status) => {
                    const cfg = LOADING_STATUS_CONFIG[status];
                    return (
                      <SelectItem
                        key={status}
                        value={status}
                        className="py-2.5 px-3 rounded-lg cursor-pointer focus:bg-slate-100"
                      >
                        <div className="flex items-center gap-2">
                          <span
                            className={cn(
                              "h-2 w-2 rounded-full shrink-0",
                              status === "Ready" || status === "Loaded"
                                ? "bg-emerald-500"
                                : status === "Scheduled" || status === "Loading"
                                ? "bg-sky-500"
                                : status === "Delayed"
                                ? "bg-amber-500"
                                : status === "Blocked"
                                ? "bg-rose-500"
                                : "bg-slate-400"
                            )}
                          />
                          <span className="font-semibold text-slate-900">{cfg.label}</span>
                        </div>
                      </SelectItem>
                    );
                  })}
                </SelectContent>
              </Select>
              <FormDescription className="text-[11px] text-slate-500 leading-tight">
                {LOADING_STATUS_CONFIG[selectedStatus]?.description}
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        {/* 2. DURATION & DAILY CAPACITY (GRID) */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          
          {/* Loading Duration (Days) */}
          <FormField
            control={form.control}
            name="loading_duration"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs sm:text-sm font-bold text-slate-800">
                  Loading Duration (Days)
                </FormLabel>
                <FormControl>
                  <div className="relative flex items-center">
                    <Input
                      type="number"
                      inputMode="numeric"
                      min={1}
                      max={365}
                      placeholder="e.g. 2"
                      value={field.value ?? ""}
                      onChange={(e) => field.onChange(e.target.value === "" ? undefined : Number(e.target.value))}
                      className="min-h-[48px] h-12 bg-white rounded-xl border-slate-200 focus:border-emerald-500 pr-14 text-sm font-medium shadow-2xs"
                    />
                    <span className="absolute right-3.5 text-xs font-semibold text-slate-400 pointer-events-none uppercase">
                      Days
                    </span>
                  </div>
                </FormControl>
                <FormDescription className="text-[11px] text-slate-500">
                  Estimated days to pack & load stock
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

          {/* Daily Loading Capacity (MT/Day) */}
          <FormField
            control={form.control}
            name="loading_capacity"
            render={({ field }) => (
              <FormItem>
                <FormLabel className="text-xs sm:text-sm font-bold text-slate-800">
                  Daily Capacity <span className="text-slate-400 font-normal text-xs">(Optional)</span>
                </FormLabel>
                <FormControl>
                  <div className="relative flex items-center">
                    <Input
                      type="number"
                      inputMode="decimal"
                      step="any"
                      min={0}
                      placeholder="e.g. 50"
                      value={field.value ?? ""}
                      onChange={(e) => field.onChange(e.target.value === "" ? undefined : Number(e.target.value))}
                      className="min-h-[48px] h-12 bg-white rounded-xl border-slate-200 focus:border-emerald-500 pr-16 text-sm font-medium shadow-2xs"
                    />
                    <span className="absolute right-3.5 text-xs font-semibold text-slate-400 pointer-events-none uppercase">
                      MT / Day
                    </span>
                  </div>
                </FormControl>
                <FormDescription className="text-[11px] text-slate-500">
                  Maximum throughput per operational day
                </FormDescription>
                <FormMessage />
              </FormItem>
            )}
          />

        </div>

        {/* 3. EXPECTED LOADING START DATE */}
        <FormField
          control={form.control}
          name="loading_start_date"
          render={({ field }) => (
            <FormItem className="flex flex-col">
              <FormLabel className="text-xs sm:text-sm font-bold text-slate-800">
                Expected Loading Start Date <span className="text-slate-400 font-normal text-xs">(Optional)</span>
              </FormLabel>
              <Popover>
                <FormControl>
                  <PopoverTrigger
                    className={cn(
                      "w-full min-h-[48px] h-12 inline-flex items-center justify-between text-left font-normal rounded-xl border border-slate-200 bg-white hover:bg-slate-50 px-3.5 shadow-2xs transition-colors cursor-pointer",
                      !field.value && "text-slate-400"
                    )}
                  >
                    <div className="flex items-center gap-2.5 truncate">
                      <CalendarIcon className="h-4 w-4 text-slate-500 shrink-0" />
                      {field.value ? (
                        <span className="font-semibold text-slate-900">
                          {format(field.value, "PPP")}
                        </span>
                      ) : (
                        <span>Pick an expected start date</span>
                      )}
                    </div>
                  </PopoverTrigger>
                </FormControl>
                <PopoverContent className="w-auto p-0 rounded-2xl shadow-xl border-slate-200" align="start">
                  <Calendar
                    mode="single"
                    selected={field.value ?? undefined}
                    onSelect={field.onChange}
                  />
                </PopoverContent>
              </Popover>
              <FormDescription className="text-[11px] text-slate-500">
                Date when warehouse will begin loading transport vehicles
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        {/* 4. LOADING REMARKS / CONSTRAINTS (MANDATORY IF DELAYED OR BLOCKED) */}
        <FormField
          control={form.control}
          name="loading_remarks"
          render={({ field }) => (
            <FormItem>
              <div className="flex items-center justify-between">
                <FormLabel className="text-xs sm:text-sm font-bold text-slate-800 flex items-center gap-1.5">
                  <span>Loading Remarks / Operational Notes</span>
                  {isRemarksRequired ? (
                    <span className="text-rose-600 font-bold text-xs bg-rose-50 px-1.5 py-0.5 rounded border border-rose-200">
                      * Required for {selectedStatus}
                    </span>
                  ) : (
                    <span className="text-slate-400 font-normal text-xs">(Optional)</span>
                  )}
                </FormLabel>
              </div>
              <FormControl>
                <Textarea
                  placeholder={
                    isRemarksRequired
                      ? `Please document the reason for ${selectedStatus.toLowerCase()} status (e.g., labor shortage, rain/monsoon delays, weighbridge maintenance)...`
                      : "Add any facility constraints, bay timings, or specialized loading instructions..."
                  }
                  value={field.value ?? ""}
                  onChange={field.onChange}
                  className={cn(
                    "min-h-[96px] bg-white rounded-xl border-slate-200 text-sm p-3.5 focus:border-emerald-500 shadow-2xs resize-none",
                    isRemarksRequired && !field.value && "border-rose-300 focus:border-rose-500"
                  )}
                />
              </FormControl>
              <FormDescription className="text-[11px] text-slate-500">
                {isRemarksRequired
                  ? "A clear explanation helps brokers coordinate delivery schedules without deal friction."
                  : "Visible to preferred brokers for operational dispatch planning."}
              </FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        {/* FORM ACTIONS */}
        <div className="pt-3 border-t border-slate-100 flex flex-col-reverse sm:flex-row items-center justify-end gap-3">
          {onCancel && (
            <Button
              type="button"
              variant="outline"
              size="lg"
              disabled={isSubmitting}
              onClick={onCancel}
              className="w-full sm:w-auto min-h-[48px] h-12 border-slate-200 text-slate-700 font-semibold rounded-xl px-6 cursor-pointer"
            >
              Cancel
            </Button>
          )}
          <Button
            type="submit"
            size="lg"
            disabled={isSubmitting}
            className="w-full sm:w-auto min-h-[48px] h-12 bg-[#059669] hover:bg-[#047857] text-white font-bold rounded-xl px-8 shadow-xs cursor-pointer flex items-center justify-center gap-2"
          >
            {isSubmitting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                <span>Updating Readiness...</span>
              </>
            ) : (
              <>
                <Truck className="h-4 w-4" />
                <span>Save Loading Status</span>
              </>
            )}
          </Button>
        </div>

      </form>
    </Form>
  );
}
