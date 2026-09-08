"use client";

import React, { useState, useEffect, useTransition } from "react";
import { useForm, useWatch } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import {
  Truck,
  Check,
  CheckCircle2,
  ChevronsUpDown,
  Calendar,
  MapPin,
  Building2,
  User,
  Phone,
  Layers,
  Sparkles,
  AlertCircle,
  Loader2,
  Scale,
  FileText,
  Clock,
  ArrowRight,
  ShieldCheck,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import {
  sellerDispatchSchema,
  SellerDispatchFormData,
} from "@/src/types/dispatch-schema";
import { submitDispatchAction } from "@/src/server/actions/dispatch-actions";
import { FulfillmentDocumentUpload } from "@/src/components/forms/fulfillment-document-upload";
import { useRouter } from "next/navigation";

export interface SellerDispatchFormProps {
  bookingId?: string;
  bookingReference?: string;
  dealId: string;
  vehicleTypes?: Array<{ id: string; name: string }>;
  bookedQuantity?: number;
  remainingQuantity?: number;
  unitSymbol?: string;
  defaultLoadingLocation?: string;
  onSuccess?: (data?: any) => void;
}

export function SellerDispatchForm({
  bookingId = "",
  bookingReference = "",
  dealId,
  vehicleTypes = [],
  bookedQuantity,
  remainingQuantity,
  unitSymbol = "",
  defaultLoadingLocation = "",
  onSuccess,
}: SellerDispatchFormProps) {
  const router = useRouter();
  const [popoverOpen, setPopoverOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  // Local state for seamless Dispatch -> Document Upload handoff
  const [createdDispatchId, setCreatedDispatchId] = useState<string | null>(null);
  const [submittedDispatchInfo, setSubmittedDispatchInfo] = useState<{
    vehicleNumber?: string;
    transportCompany?: string;
    driverName?: string;
    driverMobile?: string;
    dispatchQuantity?: number;
    remainingQuantity?: number;
    unitSymbol?: string;
    bookingReference?: string;
    loadingLocation?: string;
  } | null>(null);

  // Determine exact remaining balance and dynamic unit from database props without hardcoded fallback
  const effectiveRemaining =
    typeof remainingQuantity === "number"
      ? remainingQuantity
      : typeof bookedQuantity === "number"
      ? bookedQuantity
      : 0;

  const displayUnit = unitSymbol ? unitSymbol.trim() : "";

  const todayStr = new Date().toISOString().substring(0, 10);
  const nextWeek = new Date();
  nextWeek.setDate(nextWeek.getDate() + 3);
  const defaultEtaStr = nextWeek.toISOString().substring(0, 10);

  const form = useForm<SellerDispatchFormData>({
    resolver: zodResolver(sellerDispatchSchema) as any,
    defaultValues: {
      booking_id: bookingReference || bookingId || dealId,
      dispatch_quantity: effectiveRemaining > 0 ? effectiveRemaining : ("" as any),
      dispatch_date: new Date() as any,
      vehicle_type_id: "",
      vehicle_type: "",
      vehicle_number: "",
      driver_name: "",
      driver_mobile: "",
      transport_company: "",
      loading_location: defaultLoadingLocation || "",
      eta: nextWeek as any,
      remarks: "",
    },
    mode: "onChange",
  });

  // Keep form values in sync when server props dynamically resolve
  useEffect(() => {
    if (effectiveRemaining > 0 && !form.formState.isDirty) {
      form.setValue("dispatch_quantity", effectiveRemaining, { shouldValidate: true });
    }
    if (defaultLoadingLocation && !form.formState.isDirty) {
      form.setValue("loading_location", defaultLoadingLocation);
    }
    if (bookingReference || bookingId) {
      form.setValue("booking_id", bookingReference || bookingId || dealId);
    }
  }, [effectiveRemaining, defaultLoadingLocation, bookingReference, bookingId, dealId, form]);

  const watchedQuantity = useWatch({
    control: form.control,
    name: "dispatch_quantity",
  });

  const isQuantityExceeded =
    typeof watchedQuantity === "number" &&
    effectiveRemaining > 0 &&
    watchedQuantity > effectiveRemaining;

  const handleFillAllRemaining = () => {
    if (effectiveRemaining <= 0) return;
    form.setValue("dispatch_quantity", effectiveRemaining, {
      shouldValidate: true,
      shouldDirty: true,
    });
    toast.info(
      `Dispatch quantity set to remaining balance: ${effectiveRemaining} ${displayUnit}`.trim()
    );
  };

  async function onSubmit(values: SellerDispatchFormData) {
    if (effectiveRemaining > 0 && values.dispatch_quantity > effectiveRemaining) {
      form.setError("dispatch_quantity", {
        type: "manual",
        message: `Quantity cannot exceed remaining booked volume of ${effectiveRemaining} ${displayUnit}.`.trim(),
      });
      toast.error(
        `Dispatch quantity exceeds the remaining contract balance of ${effectiveRemaining} ${displayUnit}.`.trim()
      );
      return;
    }

    startTransition(async () => {
      try {
        const payload: SellerDispatchFormData = {
          ...values,
          booking_id: bookingReference || bookingId || dealId,
        };

        const res = await submitDispatchAction(payload);

        if (res.success && res.dispatchId) {
          // Seamless Step Transition: Capture created dispatch ID and stay inside component for document upload
          setCreatedDispatchId(res.dispatchId);
          setSubmittedDispatchInfo({
            vehicleNumber: values.vehicle_number,
            transportCompany: values.transport_company,
            driverName: values.driver_name,
            driverMobile: values.driver_mobile,
            dispatchQuantity: values.dispatch_quantity,
            remainingQuantity: res.remainingQuantity,
            unitSymbol: displayUnit,
            bookingReference: res.bookingReference || bookingReference || bookingId,
            loadingLocation: values.loading_location,
          });

          toast.success(
            res.message ||
              `Dispatch of ${values.dispatch_quantity} ${displayUnit} successfully submitted!`.trim()
          );
          router.refresh();
        } else {
          toast.error(res.error || "Failed to submit dispatch record.");
        }
      } catch (err: any) {
        toast.error(err.message || "An unexpected error occurred during dispatch submission.");
      }
    });
  }

  // =========================================================================
  // TASK 2: SEAMLESS SUCCESS & DOCUMENT UPLOAD NEXT-STEP VIEW
  // =========================================================================
  if (createdDispatchId) {
    const targetBookingRef =
      submittedDispatchInfo?.bookingReference || bookingReference || bookingId || "BOOKING";

    const handleSkipOrFinish = () => {
      if (onSuccess) {
        onSuccess({ dispatchId: createdDispatchId, bookingReference: targetBookingRef });
      } else {
        router.push(bookingReference ? `/seller/dispatch/${bookingReference}` : `/seller/dispatch`);
      }
      router.refresh();
    };

    return (
      <div className="space-y-6 font-sans animate-in fade-in zoom-in-95 duration-200">
        {/* SUCCESS HERO BANNER */}
        <div className="p-6 sm:p-7 rounded-3xl bg-gradient-to-br from-emerald-500/10 via-emerald-50/70 to-teal-500/10 border border-emerald-200 shadow-2xs space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-start sm:items-center gap-3.5">
              <div className="w-12 h-12 rounded-2xl bg-emerald-100 flex items-center justify-center text-[#047857] shrink-0 shadow-2xs">
                <CheckCircle2 className="w-7 h-7" />
              </div>
              <div className="space-y-0.5">
                <div className="flex items-center gap-2">
                  <Badge className="bg-[#059669] text-white font-bold text-[10px] uppercase tracking-wider px-2.5 py-0.5 shadow-2xs">
                    Dispatch Logged
                  </Badge>
                  {targetBookingRef && (
                    <Badge
                      variant="outline"
                      className="font-mono text-xs border-emerald-300 text-emerald-900 bg-white font-bold"
                    >
                      #{targetBookingRef}
                    </Badge>
                  )}
                </div>
                <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                  Vehicle Assigned Successfully!
                </h2>
              </div>
            </div>
          </div>

          <div className="space-y-1.5 pt-1">
            <h3 className="text-sm sm:text-base font-bold text-emerald-950 flex items-center gap-2">
              <span>Do you have the Lorry Receipt (Bilty) or E-Way Bill ready?</span>
            </h3>
            <p className="text-xs sm:text-sm text-slate-600 leading-relaxed">
              Upload your transport fulfillment documents now to expedite broker verification and carrier settlement, or skip and upload them later from the orders dashboard.
            </p>
          </div>

          {/* SHIPMENT SNAPSHOT TILES */}
          {submittedDispatchInfo && (
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-2 border-t border-emerald-100/80">
              <div className="p-2.5 bg-white/95 rounded-xl border border-emerald-100/90 shadow-2xs">
                <div className="text-[10px] uppercase font-bold text-slate-400">Vehicle</div>
                <div className="text-xs font-mono font-bold text-slate-900 truncate">
                  {submittedDispatchInfo.vehicleNumber || "Assigned"}
                </div>
              </div>
              <div className="p-2.5 bg-white/95 rounded-xl border border-emerald-100/90 shadow-2xs">
                <div className="text-[10px] uppercase font-bold text-slate-400">Transporter</div>
                <div className="text-xs font-semibold text-slate-800 truncate">
                  {submittedDispatchInfo.transportCompany || "Logistics"}
                </div>
              </div>
              <div className="p-2.5 bg-white/95 rounded-xl border border-emerald-100/90 shadow-2xs">
                <div className="text-[10px] uppercase font-bold text-slate-400">Dispatched Vol</div>
                <div className="text-xs font-bold text-[#047857] truncate">
                  {submittedDispatchInfo.dispatchQuantity} {submittedDispatchInfo.unitSymbol}
                </div>
              </div>
              <div className="p-2.5 bg-white/95 rounded-xl border border-emerald-100/90 shadow-2xs">
                <div className="text-[10px] uppercase font-bold text-slate-400">Driver Contact</div>
                <div className="text-xs font-medium text-slate-700 truncate">
                  {submittedDispatchInfo.driverName || "Driver Assigned"}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* MOUNT FULFILLMENT DOCUMENT UPLOAD COMPONENT */}
        <div className="bg-white rounded-3xl border border-slate-200/90 p-5 sm:p-6 shadow-2xs space-y-4">
          <FulfillmentDocumentUpload
            dispatchId={createdDispatchId}
            bookingId={bookingId || bookingReference || dealId}
          />
        </div>

        {/* ACTIONS FOOTER */}
        <div className="pt-2 flex flex-col-reverse sm:flex-row items-center justify-between gap-3 border-t border-slate-200/80">
          <Button
            type="button"
            variant="outline"
            onClick={handleSkipOrFinish}
            className="w-full sm:w-auto min-h-[48px] h-12 px-6 rounded-xl font-bold text-xs text-slate-600 hover:text-slate-900 border-slate-300 hover:bg-slate-50 cursor-pointer"
          >
            Skip & Upload Later
          </Button>

          <Button
            type="button"
            onClick={handleSkipOrFinish}
            className="w-full sm:w-auto min-h-[48px] h-12 px-8 rounded-xl font-bold text-xs bg-[#059669] hover:bg-[#047857] text-white shadow-md flex items-center justify-center gap-2 cursor-pointer transition-all hover:scale-[1.01] active:scale-[0.99]"
          >
            <Check className="w-4 h-4 text-white" />
            <span>Done & Return to Orders</span>
          </Button>
        </div>
      </div>
    );
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8 font-sans">
        {/* ========================================================================= */}
        {/* SECTION 1: DISPATCH VOLUME (PROMINENT HERO INPUT)                         */}
        {/* ========================================================================= */}
        <div className="p-6 sm:p-7 rounded-3xl bg-gradient-to-br from-emerald-50/50 via-slate-50/80 to-teal-50/30 border border-emerald-100/90 shadow-2xs space-y-5">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-emerald-100/60">
            <div className="flex items-center gap-2.5">
              <div className="w-9 h-9 rounded-xl bg-emerald-100/90 flex items-center justify-center text-[#047857] shadow-2xs">
                <Scale className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-900 tracking-tight">
                  Section 1: Dispatch Volume & Allocation
                </h3>
                <p className="text-xs text-slate-500">
                  Declare the precise commodity volume allocated to this transport vehicle.
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 flex-wrap">
              {typeof bookedQuantity === "number" && bookedQuantity > 0 && (
                <Badge
                  variant="outline"
                  className="bg-white text-slate-600 border-slate-200 font-mono text-xs px-2.5 py-1"
                >
                  Booked: <span className="font-semibold ml-1">{bookedQuantity} {displayUnit}</span>
                </Badge>
              )}
              <Badge
                variant="outline"
                className="bg-emerald-50 text-[#047857] border-emerald-200 font-mono text-xs px-3 py-1 font-bold shadow-2xs"
              >
                Remaining: <span className="ml-1 text-emerald-900">{effectiveRemaining} {displayUnit}</span>
              </Badge>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-12 gap-4 items-start pt-1">
            <div className="sm:col-span-8">
              <FormField
                control={form.control}
                name="dispatch_quantity"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                      <span>Dispatched Quantity</span>
                      {displayUnit && (
                        <span className="text-emerald-700 font-normal">({displayUnit})</span>
                      )}
                      <span className="text-rose-500">*</span>
                    </FormLabel>
                    <FormControl>
                      <div className="relative flex items-center">
                        <Input
                          type="number"
                          step="any"
                          min={0.01}
                          max={effectiveRemaining > 0 ? effectiveRemaining : undefined}
                          placeholder={effectiveRemaining > 0 ? `e.g. ${effectiveRemaining}` : "Enter quantity"}
                          className={cn(
                            "h-14 text-lg font-black pl-4 pr-16 bg-white rounded-2xl border-slate-200/90 shadow-2xs focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:border-emerald-500 transition-all",
                            isQuantityExceeded &&
                              "border-rose-500 focus-visible:ring-rose-500 text-rose-700 bg-rose-50/20"
                          )}
                          {...field}
                          value={field.value ?? ""}
                          onChange={(e) => field.onChange(e.target.valueAsNumber || "")}
                        />
                        {displayUnit && (
                          <div className="absolute right-4 top-1/2 -translate-y-1/2 px-2.5 py-1 bg-slate-100 text-slate-700 font-mono font-bold text-xs rounded-lg pointer-events-none border border-slate-200/80">
                            {displayUnit}
                          </div>
                        )}
                      </div>
                    </FormControl>
                    {isQuantityExceeded && (
                      <p className="text-xs font-semibold text-rose-600 flex items-center gap-1 mt-1.5 animate-in fade-in">
                        <AlertCircle className="w-3.5 h-3.5 shrink-0" />
                        <span>
                          Quantity exceeds the available remaining balance ({effectiveRemaining} {displayUnit})
                        </span>
                      </p>
                    )}
                    <FormMessage className="text-xs" />
                  </FormItem>
                )}
              />
            </div>

            <div className="sm:col-span-4 pt-0 sm:pt-6">
              <Button
                type="button"
                onClick={handleFillAllRemaining}
                disabled={effectiveRemaining <= 0}
                variant="outline"
                className="w-full h-14 rounded-2xl font-bold text-xs border-emerald-300 bg-white hover:bg-emerald-50 text-[#047857] hover:text-emerald-900 transition-all shadow-2xs gap-2 flex items-center justify-center cursor-pointer hover:scale-[1.01] active:scale-[0.99] disabled:opacity-50"
              >
                <Sparkles className="w-4 h-4 text-emerald-600 shrink-0" />
                <span className="truncate">
                  Fill All Remaining {effectiveRemaining > 0 ? `(${effectiveRemaining} ${displayUnit})` : ""}
                </span>
              </Button>
            </div>
          </div>
        </div>

        {/* ========================================================================= */}
        {/* SECTION 2: VEHICLE & TRANSPORTER CREDENTIALS (2-COLUMN GRID)              */}
        {/* ========================================================================= */}
        <div className="p-6 sm:p-7 rounded-3xl bg-white border border-slate-200/90 shadow-2xs space-y-5">
          <div className="flex items-center gap-2.5 pb-3 border-b border-slate-100">
            <div className="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-slate-700">
              <Truck className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900 tracking-tight">
                Section 2: Vehicle & Transporter Credentials
              </h3>
              <p className="text-xs text-slate-500">
                Logistics carrier specifications and physical loading point.
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
            {/* Vehicle Type Combobox */}
            <FormField
              control={form.control}
              name="vehicle_type"
              render={({ field }) => (
                <FormItem className="flex flex-col">
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Vehicle Body / Type <span className="text-rose-500">*</span>
                  </FormLabel>
                  <Popover open={popoverOpen} onOpenChange={setPopoverOpen}>
                    <FormControl>
                      <PopoverTrigger
                        type="button"
                        className={cn(
                          "flex w-full items-center justify-between rounded-xl border border-slate-200 bg-white px-3.5 py-2 text-sm shadow-2xs focus:outline-none focus:ring-2 focus:ring-emerald-500 h-12 font-medium text-slate-900 transition-colors hover:border-slate-300",
                          !field.value && "text-slate-400"
                        )}
                      >
                        <span className="truncate text-left flex-1 pr-2">
                          {field.value || "Select vehicle body/capacity"}
                        </span>
                        <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 text-slate-400" />
                      </PopoverTrigger>
                    </FormControl>
                    <PopoverContent className="w-[340px] p-0" align="start">
                      <Command>
                        <CommandInput placeholder="Search vehicle type..." />
                        <CommandList className="max-h-[260px] overflow-y-auto">
                          <CommandEmpty>No vehicle type found.</CommandEmpty>
                          <CommandGroup heading="Standard Transport Vehicles">
                            {vehicleTypes.length > 0 ? (
                              vehicleTypes.map((vt) => (
                                <CommandItem
                                  key={vt.id}
                                  value={vt.name}
                                  onSelect={() => {
                                    form.setValue("vehicle_type", vt.name, { shouldValidate: true });
                                    form.setValue("vehicle_type_id", vt.id);
                                    setPopoverOpen(false);
                                  }}
                                  className="cursor-pointer py-2.5"
                                >
                                  <Check
                                    className={cn(
                                      "mr-2 h-4 w-4 text-emerald-600",
                                      vt.name === field.value ? "opacity-100" : "opacity-0"
                                    )}
                                  />
                                  <span className="font-medium text-sm">{vt.name}</span>
                                </CommandItem>
                              ))
                            ) : (
                              <>
                                {[
                                  "10-Wheeler Truck (20-22 MT)",
                                  "12-Wheeler Truck (25-28 MT)",
                                  "14-Wheeler Heavy Truck (30-35 MT)",
                                  "Tractor Trailer (35-40 MT)",
                                  "Mini Truck / Eicher (5-10 MT)",
                                  "Open Body Commercial Vehicle",
                                  "Containerized Closed Body Vehicle",
                                  "Other Commercial Vehicle",
                                ].map((type) => (
                                  <CommandItem
                                    key={type}
                                    value={type}
                                    onSelect={() => {
                                      form.setValue("vehicle_type", type, { shouldValidate: true });
                                      setPopoverOpen(false);
                                    }}
                                    className="cursor-pointer py-2.5"
                                  >
                                    <Check
                                      className={cn(
                                        "mr-2 h-4 w-4 text-emerald-600",
                                        type === field.value ? "opacity-100" : "opacity-0"
                                      )}
                                    />
                                    <span className="font-medium text-sm">{type}</span>
                                  </CommandItem>
                                ))}
                              </>
                            )}
                          </CommandGroup>
                        </CommandList>
                      </Command>
                    </PopoverContent>
                  </Popover>
                  <FormMessage className="text-xs" />
                </FormItem>
              )}
            />

            {/* Vehicle Plate Number */}
            <FormField
              control={form.control}
              name="vehicle_number"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Vehicle Plate Number <span className="text-rose-500">*</span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      placeholder="e.g. RJ14GC5511"
                      className="h-12 uppercase font-mono font-bold bg-white rounded-xl border-slate-200 shadow-2xs focus-visible:ring-2 focus-visible:ring-emerald-500 tracking-wider text-sm"
                      maxLength={16}
                      {...field}
                    />
                  </FormControl>
                  <FormMessage className="text-xs" />
                </FormItem>
              )}
            />

            {/* Transport / Logistics Company */}
            <FormField
              control={form.control}
              name="transport_company"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                    <Building2 className="w-3.5 h-3.5 text-slate-400" />
                    <span>Transporter / Agency <span className="text-rose-500">*</span></span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      placeholder="e.g. VRL Logistics / TCI Express / Self"
                      className="h-12 bg-white rounded-xl border-slate-200 shadow-2xs focus-visible:ring-2 focus-visible:ring-emerald-500 text-sm"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage className="text-xs" />
                </FormItem>
              )}
            />

            {/* Loading Location */}
            <FormField
              control={form.control}
              name="loading_location"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                    <MapPin className="w-3.5 h-3.5 text-slate-400" />
                    <span>Loading Warehouse / Mill <span className="text-rose-500">*</span></span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      placeholder="e.g. Warehouse Bay 3, Kota Mandi Yard"
                      className="h-12 bg-white rounded-xl border-slate-200 shadow-2xs focus-visible:ring-2 focus-visible:ring-emerald-500 text-sm"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage className="text-xs" />
                </FormItem>
              )}
            />
          </div>
        </div>

        {/* ========================================================================= */}
        {/* SECTION 3: DRIVER DETAILS & TRANSIT SCHEDULE (2-COLUMN GRID)              */}
        {/* ========================================================================= */}
        <div className="p-6 sm:p-7 rounded-3xl bg-white border border-slate-200/90 shadow-2xs space-y-5">
          <div className="flex items-center gap-2.5 pb-3 border-b border-slate-100">
            <div className="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-slate-700">
              <User className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-slate-900 tracking-tight">
                Section 3: Driver Details & Transit Schedule
              </h3>
              <p className="text-xs text-slate-500">
                Driver identity contact credentials and expected delivery ETA.
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
            {/* Driver Name */}
            <FormField
              control={form.control}
              name="driver_name"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Driver Full Name <span className="text-rose-500">*</span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      placeholder="e.g. Ramesh Kumar"
                      className="h-12 bg-white rounded-xl border-slate-200 shadow-2xs focus-visible:ring-2 focus-visible:ring-emerald-500 text-sm"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage className="text-xs" />
                </FormItem>
              )}
            />

            {/* Driver Mobile */}
            <FormField
              control={form.control}
              name="driver_mobile"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                    <Phone className="w-3.5 h-3.5 text-slate-400" />
                    <span>Driver Mobile (10-Digit) <span className="text-rose-500">*</span></span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      type="tel"
                      maxLength={10}
                      placeholder="e.g. 9876543210"
                      className="h-12 font-mono font-semibold bg-white rounded-xl border-slate-200 shadow-2xs focus-visible:ring-2 focus-visible:ring-emerald-500 text-sm"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage className="text-xs" />
                </FormItem>
              )}
            />

            {/* Gate Dispatch Date */}
            <FormField
              control={form.control}
              name="dispatch_date"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                    <Calendar className="w-3.5 h-3.5 text-slate-400" />
                    <span>Gate Dispatch Date <span className="text-rose-500">*</span></span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      type="date"
                      className="h-12 bg-white rounded-xl border-slate-200 shadow-2xs focus-visible:ring-2 focus-visible:ring-emerald-500 font-medium text-sm"
                      value={
                        field.value instanceof Date
                          ? field.value.toISOString().substring(0, 10)
                          : field.value || todayStr
                      }
                      onChange={(e) => field.onChange(new Date(e.target.value))}
                    />
                  </FormControl>
                  <FormMessage className="text-xs" />
                </FormItem>
              )}
            />

            {/* Expected Delivery ETA */}
            <FormField
              control={form.control}
              name="eta"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5 text-slate-400" />
                    <span>Expected Delivery ETA <span className="text-rose-500">*</span></span>
                  </FormLabel>
                  <FormControl>
                    <Input
                      type="date"
                      className="h-12 bg-white rounded-xl border-slate-200 shadow-2xs focus-visible:ring-2 focus-visible:ring-emerald-500 font-medium text-sm"
                      value={
                        field.value instanceof Date
                          ? field.value.toISOString().substring(0, 10)
                          : field.value || defaultEtaStr
                      }
                      onChange={(e) => field.onChange(new Date(e.target.value))}
                    />
                  </FormControl>
                  <FormMessage className="text-xs" />
                </FormItem>
              )}
            />
          </div>

          {/* Remarks */}
          <FormField
            control={form.control}
            name="remarks"
            render={({ field }) => (
              <FormItem className="pt-2">
                <FormLabel className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                  <FileText className="w-3.5 h-3.5 text-slate-400" />
                  <span>Logistics Remarks / Gate Pass Notes (Optional)</span>
                </FormLabel>
                <FormControl>
                  <Textarea
                    placeholder="Enter any driver instructions, gate pass serial numbers, container seal numbers, or warehouse notes..."
                    className="min-h-[90px] bg-white rounded-2xl border-slate-200 shadow-2xs focus-visible:ring-2 focus-visible:ring-emerald-500 text-sm p-3.5 resize-y"
                    {...field}
                    value={field.value || ""}
                  />
                </FormControl>
                <FormMessage className="text-xs" />
              </FormItem>
            )}
          />
        </div>

        {/* ========================================================================= */}
        {/* SUBMIT ACTION BAR (48px Touch Target + useTransition Lockout)            */}
        {/* ========================================================================= */}
        <div className="pt-2 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 border-t border-slate-200/80">
          <div className="text-xs text-slate-500 font-medium flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-emerald-500" />
            <span>All 3 sections will be committed atomically to the shipment ledger.</span>
          </div>

          <Button
            type="submit"
            disabled={isPending || isQuantityExceeded}
            className="min-h-[48px] h-12 px-8 bg-[#059669] hover:bg-[#047857] text-white font-bold rounded-xl shadow-md flex items-center justify-center gap-2.5 cursor-pointer transition-all hover:scale-[1.01] active:scale-[0.99] disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isPending ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin text-white" />
                <span>Recording Shipment Dispatch...</span>
              </>
            ) : (
              <>
                <Truck className="w-4 h-4 text-white" />
                <span>Confirm & Record Dispatch</span>
              </>
            )}
          </Button>
        </div>
      </form>
    </Form>
  );
}
