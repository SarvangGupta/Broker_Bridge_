"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { format } from "date-fns";
import {
  Loader2,
  CalendarIcon,
  FlaskConical,
  Building2,
  Calendar as CalendarIconLucide,
  AlertTriangle,
  CheckCircle2,
  Clock,
  ShieldCheck,
  AlertCircle,
  FileCheck,
} from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

import { Button, buttonVariants } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

import {
  labTestFormSchema,
  LabTestFormInput,
  checkIsWithinBounds,
  LabFreshnessStatus,
} from "@/src/types/lab-schema";
import {
  saveLabTestRecordAction,
  getLabTestByAvailabilityAction,
} from "@/src/server/actions/lab-actions";
import { getQualityTemplateByCommodityAction } from "@/src/server/actions/quality-actions";
import { QualityTemplateParameter } from "@/src/types/quality-schema";
import { LabDocumentUpload } from "@/src/components/forms/lab-document-upload";

interface LabTestFormProps {
  availabilityId: string;
  commodityId: string;
  onSuccess?: () => void;
  onCancel?: () => void;
}

export function LabTestForm({
  availabilityId,
  commodityId,
  onSuccess,
  onCancel,
}: LabTestFormProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [loadingData, setLoadingData] = useState(true);
  const [templateParams, setTemplateParams] = useState<QualityTemplateParameter[]>([]);
  const [existingStatus, setExistingStatus] = useState<string | null>(null);
  const [freshnessStatus, setFreshnessStatus] = useState<LabFreshnessStatus | null>(null);
  const [currentFileUrl, setCurrentFileUrl] = useState<string | null>(null);

  const form = useForm<LabTestFormInput>({
    resolver: zodResolver(labTestFormSchema) as any,
    defaultValues: {
      availability_id: availabilityId,
      laboratory_name: "",
      laboratory_location: "",
      sample_id: "",
      sample_date: undefined,
      test_date: new Date(),
      report_number: "",
      report_date: new Date(),
      valid_until: undefined,
      file_url: undefined,
      results: [],
    },
  });

  // Load Quality Template and Existing Lab Test Data
  useEffect(() => {
    let isMounted = true;

    async function loadFormData() {
      setLoadingData(true);
      try {
        // 1. Fetch Commodity Quality Template
        const templateRes = await getQualityTemplateByCommodityAction(commodityId);
        let params: QualityTemplateParameter[] = [];
        if (templateRes.success && templateRes.data) {
          params = templateRes.data.map((p) => ({
            id: p.id,
            commodityId: p.commodityId,
            name: p.name,
            type: p.type,
            unit: p.unit,
            minValue: p.minValue,
            maxValue: p.maxValue,
            targetValue: p.targetValue,
            isRequired: p.isRequired,
            isActive: p.isActive,
          }));
          if (isMounted) setTemplateParams(params);
        }

        // 2. Fetch existing lab test record if any
        const existingRes = await getLabTestByAvailabilityAction(availabilityId);
        if (isMounted && existingRes.success && existingRes.data) {
          const d = existingRes.data;
          setExistingStatus(d.effectiveStatus || d.status);
          setFreshnessStatus(d.freshness);
          setCurrentFileUrl(d.fileUrl || null);

          // Build results map
          const existingResultsMap: Record<string, string> = {};
          d.results.forEach((r: any) => {
            existingResultsMap[r.parameterId] = r.measuredValue;
          });

          // Pre-populate form
          form.reset({
            availability_id: availabilityId,
            laboratory_name: d.laboratoryName || "",
            laboratory_location: d.laboratoryLocation || "",
            sample_id: d.sampleId || "",
            sample_date: d.sampleDate ? new Date(d.sampleDate) : undefined,
            test_date: new Date(d.testDate),
            report_number: d.reportNumber || "",
            report_date: new Date(d.reportDate),
            valid_until: d.validUntil ? new Date(d.validUntil) : undefined,
            file_url: d.fileUrl || undefined,
            results: params.map((p) => ({
              parameter_id: p.id,
              measured_value: existingResultsMap[p.id] || "",
            })),
          });
        } else if (isMounted) {
          // Initialize empty results based on template
          form.setValue(
            "results",
            params.map((p) => ({
              parameter_id: p.id,
              measured_value: "",
            }))
          );
        }
      } catch (err: any) {
        toast.error("Failed to load laboratory specifications.");
      } finally {
        if (isMounted) setLoadingData(false);
      }
    }

    loadFormData();

    return () => {
      isMounted = false;
    };
  }, [availabilityId, commodityId, form]);

  const watchedResults = form.watch("results") || [];

  const handleResultChange = (parameterId: string, value: string) => {
    const current = form.getValues("results") || [];
    const index = current.findIndex((r) => r.parameter_id === parameterId);
    if (index >= 0) {
      current[index].measured_value = value;
      form.setValue("results", [...current], { shouldValidate: true });
    } else {
      form.setValue(
        "results",
        [...current, { parameter_id: parameterId, measured_value: value }],
        { shouldValidate: true }
      );
    }
  };

  async function onSubmit(data: LabTestFormInput) {
    setIsSubmitting(true);
    try {
      const res = await saveLabTestRecordAction(data);
      if (res.success) {
        toast.success("Laboratory test record saved successfully!");
        onSuccess?.();
      } else {
        toast.error(res.error || "Failed to save lab test record.");
      }
    } catch (err: any) {
      toast.error(err.message || "An unexpected error occurred while saving lab record.");
    } finally {
      setIsSubmitting(false);
    }
  }

  if (loadingData) {
    return (
      <div className="flex flex-col items-center justify-center p-12 space-y-3">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="text-sm font-medium text-slate-600">
          Loading structured laboratory specifications...
        </p>
      </div>
    );
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
        {/* Existing Status & Freshness Header Banner if recorded */}
        {existingStatus && (
          <div className="p-4 rounded-lg border bg-slate-50 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex items-center space-x-2">
              <ShieldCheck className="h-5 w-5 text-primary" />
              <div>
                <p className="text-sm font-semibold text-slate-800">
                  Lab Test Record on File
                </p>
                <p className="text-xs text-muted-foreground">
                  Official third-party laboratory analysis linked to this supply lot.
                </p>
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <Badge
                variant={
                  existingStatus === "Verified"
                    ? "default"
                    : existingStatus === "Under Review"
                    ? "secondary"
                    : "destructive"
                }
                className="text-xs"
              >
                {existingStatus}
              </Badge>
              {freshnessStatus && (
                <Badge
                  variant="outline"
                  className={cn(
                    "text-xs font-medium",
                    freshnessStatus === "Valid" && "text-emerald-700 bg-emerald-50 border-emerald-200",
                    freshnessStatus === "Expiring Soon" && "text-amber-700 bg-amber-50 border-amber-200",
                    freshnessStatus === "Expired" && "text-rose-700 bg-rose-50 border-rose-200"
                  )}
                >
                  <Clock className="w-3 h-3 mr-1" />
                  {freshnessStatus}
                </Badge>
              )}
            </div>
          </div>
        )}

        {/* CARD 1: Laboratory Information */}
        <Card className="border-slate-200">
          <CardHeader className="pb-4">
            <CardTitle className="text-base text-slate-800 flex items-center gap-2">
              <Building2 className="h-4 w-4 text-primary" />
              1. Laboratory & Identification
            </CardTitle>
            <CardDescription className="text-xs">
              Enter official third-party analytical testing agency details.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="laboratory_name"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-sm font-medium">
                      Laboratory Name <span className="text-destructive">*</span>
                    </FormLabel>
                    <FormControl>
                      <Input
                        placeholder="e.g. SGS India, Farelabs, NCML"
                        className="min-h-[48px] h-12 text-base"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="laboratory_location"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-sm font-medium">
                      Laboratory Location (City / State)
                    </FormLabel>
                    <FormControl>
                      <Input
                        placeholder="e.g. Gurugram, Haryana"
                        className="min-h-[48px] h-12 text-base"
                        {...field}
                        value={field.value || ""}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
              <FormField
                control={form.control}
                name="report_number"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-sm font-medium">
                      Report / Certificate Number <span className="text-destructive">*</span>
                    </FormLabel>
                    <FormControl>
                      <Input
                        placeholder="e.g. COA-2026-98741"
                        className="min-h-[48px] h-12 text-base font-mono"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="sample_id"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-sm font-medium">
                      Sample ID / Reference (Optional)
                    </FormLabel>
                    <FormControl>
                      <Input
                        placeholder="e.g. SMP-LOT-04"
                        className="min-h-[48px] h-12 text-base font-mono"
                        {...field}
                        value={field.value || ""}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
          </CardContent>
        </Card>

        {/* CARD 2: Dates & Validity */}
        <Card className="border-slate-200">
          <CardHeader className="pb-4">
            <CardTitle className="text-base text-slate-800 flex items-center gap-2">
              <CalendarIconLucide className="h-4 w-4 text-primary" />
              2. Sampling, Testing & Validity Dates
            </CardTitle>
            <CardDescription className="text-xs">
              Dates establish quality freshness and automated expiry tracking.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="sample_date"
                render={({ field }) => (
                  <FormItem className="flex flex-col">
                    <FormLabel className="text-sm font-medium">
                      Sample Collection Date (Optional)
                    </FormLabel>
                    <Popover>
                      <FormControl>
                        <PopoverTrigger
                          className={cn(
                            buttonVariants({ variant: "outline" }),
                            "w-full min-h-[48px] h-12 pl-3 text-left font-normal flex items-center justify-between",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value ? format(field.value, "PPP") : <span>Pick sample date</span>}
                          <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                        </PopoverTrigger>
                      </FormControl>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={field.value || undefined}
                          onSelect={field.onChange}
                          disabled={(date) => date > new Date()}
                        />
                      </PopoverContent>
                    </Popover>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="test_date"
                render={({ field }) => (
                  <FormItem className="flex flex-col">
                    <FormLabel className="text-sm font-medium">
                      Date of Analysis / Test <span className="text-destructive">*</span>
                    </FormLabel>
                    <Popover>
                      <FormControl>
                        <PopoverTrigger
                          className={cn(
                            buttonVariants({ variant: "outline" }),
                            "w-full min-h-[48px] h-12 pl-3 text-left font-normal flex items-center justify-between",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value ? format(field.value, "PPP") : <span>Pick test date</span>}
                          <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                        </PopoverTrigger>
                      </FormControl>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={field.value}
                          onSelect={field.onChange}
                          disabled={(date) => date > new Date()}
                        />
                      </PopoverContent>
                    </Popover>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="report_date"
                render={({ field }) => (
                  <FormItem className="flex flex-col">
                    <FormLabel className="text-sm font-medium">
                      Report Issuance Date <span className="text-destructive">*</span>
                    </FormLabel>
                    <Popover>
                      <FormControl>
                        <PopoverTrigger
                          className={cn(
                            buttonVariants({ variant: "outline" }),
                            "w-full min-h-[48px] h-12 pl-3 text-left font-normal flex items-center justify-between",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value ? format(field.value, "PPP") : <span>Pick report date</span>}
                          <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                        </PopoverTrigger>
                      </FormControl>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={field.value}
                          onSelect={field.onChange}
                          disabled={(date) => date > new Date()}
                        />
                      </PopoverContent>
                    </Popover>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="valid_until"
                render={({ field }) => (
                  <FormItem className="flex flex-col">
                    <FormLabel className="text-sm font-medium">
                      Lab Certificate Expiry Date (Optional)
                    </FormLabel>
                    <Popover>
                      <FormControl>
                        <PopoverTrigger
                          className={cn(
                            buttonVariants({ variant: "outline" }),
                            "w-full min-h-[48px] h-12 pl-3 text-left font-normal flex items-center justify-between",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value ? format(field.value, "PPP") : <span>Pick expiry date</span>}
                          <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                        </PopoverTrigger>
                      </FormControl>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={field.value || undefined}
                          onSelect={field.onChange}
                          disabled={(date) => date <= (form.watch("report_date") || new Date())}
                        />
                      </PopoverContent>
                    </Popover>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
          </CardContent>
        </Card>

        {/* CARD 3: Measured Results Grid */}
        <Card className="border-slate-200">
          <CardHeader className="pb-4">
            <CardTitle className="text-base text-slate-800 flex items-center gap-2">
              <FlaskConical className="h-4 w-4 text-primary" />
              3. Laboratory Analytical Results
            </CardTitle>
            <CardDescription className="text-xs">
              Measured parameter values verified by the laboratory report.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {templateParams.length === 0 ? (
              <div className="p-6 text-center text-sm text-muted-foreground border border-dashed rounded-lg">
                No quality parameters defined for this commodity.
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {templateParams.map((param) => {
                  const resultItem = watchedResults.find((r) => r.parameter_id === param.id);
                  const measuredVal = resultItem?.measured_value || "";
                  const isWithin = checkIsWithinBounds(measuredVal, param);

                  return (
                    <div
                      key={param.id}
                      className={cn(
                        "flex flex-col space-y-1.5 p-3.5 rounded-lg border bg-card transition-colors",
                        !isWithin && measuredVal.trim() !== ""
                          ? "border-amber-300 bg-amber-50/20"
                          : "border-slate-200 hover:border-slate-300"
                      )}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <label
                          htmlFor={`lab-param-${param.id}`}
                          className="text-sm font-medium text-slate-800 flex items-center gap-1 cursor-pointer"
                        >
                          {param.name}
                          {param.unit && (
                            <span className="text-xs font-normal text-muted-foreground">
                              ({param.unit})
                            </span>
                          )}
                        </label>
                        <div className="flex items-center gap-1 flex-wrap justify-end">
                          {param.minValue !== null && param.minValue !== undefined && (
                            <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 border border-slate-200/60">
                              Min: {param.minValue}{param.unit ? ` ${param.unit}` : ""}
                            </span>
                          )}
                          {param.maxValue !== null && param.maxValue !== undefined && (
                            <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 border border-slate-200/60">
                              Max: {param.maxValue}{param.unit ? ` ${param.unit}` : ""}
                            </span>
                          )}
                        </div>
                      </div>

                      <div className="relative">
                        <Input
                          id={`lab-param-${param.id}`}
                          type="text"
                          inputMode={param.type === "numeric" ? "decimal" : "text"}
                          placeholder={
                            param.targetValue
                              ? `e.g. ${param.targetValue}`
                              : "Enter lab measured value"
                          }
                          value={measuredVal}
                          onChange={(e) => handleResultChange(param.id, e.target.value)}
                          className={cn(
                            "min-h-[48px] h-12 text-base",
                            param.unit ? "pr-12" : "",
                            !isWithin && measuredVal.trim() !== "" && "border-amber-400 focus-visible:ring-amber-400"
                          )}
                        />
                        {param.unit && (
                          <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
                            <span className="text-xs text-muted-foreground font-mono">
                              {param.unit}
                            </span>
                          </div>
                        )}
                      </div>

                      {!isWithin && measuredVal.trim() !== "" && (
                        <p className="text-xs font-medium text-amber-700 flex items-center gap-1 mt-1">
                          <AlertTriangle className="h-3.5 w-3.5 shrink-0 text-amber-600" />
                          <span>
                            Value falls outside recommended standard range ({param.minValue ?? "—"} to {param.maxValue ?? "—"}{param.unit ? ` ${param.unit}` : ""}).
                          </span>
                        </p>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>

        {/* CARD 4: Physical Evidence / COA Attachment */}
        <Card className="border-slate-200">
          <CardHeader className="pb-4">
            <CardTitle className="text-base text-slate-800 flex items-center gap-2">
              <FileCheck className="h-4 w-4 text-primary" />
              4. Physical Certificate (COA) / Evidence File
            </CardTitle>
            <CardDescription className="text-xs">
              Upload official stamped PDF or high-resolution test report image to secure evidence vault.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <LabDocumentUpload
              availabilityId={availabilityId}
              existingFileUrl={currentFileUrl || form.watch("file_url")}
              onUploadComplete={(uploadedUrl) => {
                form.setValue("file_url", uploadedUrl, { shouldValidate: true });
                setCurrentFileUrl(uploadedUrl);
              }}
              disabled={isSubmitting}
            />
          </CardContent>
        </Card>

        {/* Action Buttons */}
        <div className="flex items-center justify-end space-x-3 pt-2">
          {onCancel && (
            <Button
              type="button"
              variant="outline"
              onClick={onCancel}
              disabled={isSubmitting}
              className="min-h-[48px] h-12 px-6"
            >
              Cancel
            </Button>
          )}
          <Button
            type="submit"
            disabled={isSubmitting}
            className="min-h-[48px] h-12 px-8 text-base font-medium"
          >
            {isSubmitting ? (
              <>
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                Saving Record...
              </>
            ) : (
              "Save Lab Test Record"
            )}
          </Button>
        </div>
      </form>
    </Form>
  );
}
