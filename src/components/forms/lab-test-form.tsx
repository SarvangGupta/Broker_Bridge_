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
  AlertTriangle,
  CheckCircle2,
  Clock,
  ShieldCheck,
  Check,
  FileText,
  ChevronDown,
  ChevronUp,
} from "lucide-react";
import { useRouter } from "next/navigation";
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
import { getMasterLaboratoriesAction } from "@/src/server/actions/master-data-actions";
import { extractLabDataOcrAction } from "@/src/server/actions/ocr-actions";
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
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [loadingData, setLoadingData] = useState(true);
  const [templateParams, setTemplateParams] = useState<QualityTemplateParameter[]>([]);
  const [masterLabs, setMasterLabs] = useState<Array<{ id: string; name: string; location?: string | null }>>([]);
  const [selectedLabId, setSelectedLabId] = useState<string>("");
  const [isCustomLab, setIsCustomLab] = useState(false);

  // Step 1: Decision toggle (Yes / No)
  const [isTestingNeeded, setIsTestingNeeded] = useState<"yes" | "no">("yes");

  // Progressive Disclosure: Collapsible state for full report details
  const [showFullDetails, setShowFullDetails] = useState(false);

  // OCR Extraction States
  const [isOcrExtracting, setIsOcrExtracting] = useState(false);
  const [ocrExtracted, setOcrExtracted] = useState(false);

  const [existingStatus, setExistingStatus] = useState<string | null>(null);
  const [freshnessStatus, setFreshnessStatus] = useState<LabFreshnessStatus | null>(null);
  const [currentFileUrl, setCurrentFileUrl] = useState<string | null>(null);

  const form = useForm<LabTestFormInput>({
    resolver: zodResolver(labTestFormSchema) as any,
    defaultValues: {
      availability_id: availabilityId,
      is_lab_required: true,
      laboratory_name: "",
      laboratory_location: "",
      sample_id: "",
      sample_date: undefined,
      test_date: undefined,
      report_number: "",
      report_date: undefined,
      valid_until: undefined,
      file_url: undefined,
      results: [],
    },
  });

  // Load Master Labs, Quality Template and Existing Lab Test Data
  useEffect(() => {
    let isMounted = true;

    async function loadFormData() {
      setLoadingData(true);
      try {
        const [templateRes, labsRes, existingRes] = await Promise.all([
          getQualityTemplateByCommodityAction(commodityId),
          getMasterLaboratoriesAction(),
          getLabTestByAvailabilityAction(availabilityId),
        ]);

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

        if (labsRes.success && labsRes.data && isMounted) {
          setMasterLabs(labsRes.data);
        }

        if (isMounted && existingRes.success && existingRes.data) {
          const d = existingRes.data;
          const isNotRequired = (d.effectiveStatus || d.status) === "Not Required";
          setExistingStatus(d.effectiveStatus || d.status);
          setFreshnessStatus(d.freshness);
          setCurrentFileUrl(d.fileUrl || null);
          setIsTestingNeeded(isNotRequired ? "no" : "yes");

          // Match with master labs
          const matchedLab = labsRes.data?.find(
            (l: any) => l.name.toLowerCase() === (d.laboratoryName || "").toLowerCase()
          );
          if (matchedLab) {
            setSelectedLabId(matchedLab.id);
            setIsCustomLab(false);
          } else if (d.laboratoryName && d.laboratoryName !== "Not Required") {
            setSelectedLabId("other");
            setIsCustomLab(true);
          }

          // Build results map
          const existingResultsMap: Record<string, string> = {};
          d.results.forEach((r: any) => {
            existingResultsMap[r.parameterId] = r.measuredValue;
          });

          // Pre-populate form
          form.reset({
            availability_id: availabilityId,
            is_lab_required: !isNotRequired,
            laboratory_name: d.laboratoryName && d.laboratoryName !== "Not Required" ? d.laboratoryName : "",
            laboratory_location: d.laboratoryLocation || "",
            sample_id: d.sampleId || "",
            sample_date: d.sampleDate ? new Date(d.sampleDate) : undefined,
            test_date: d.testDate ? new Date(d.testDate) : undefined,
            report_number: d.reportNumber && d.reportNumber !== "NOT-REQUIRED" ? d.reportNumber : "",
            report_date: d.reportDate ? new Date(d.reportDate) : undefined,
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

  const handleLabSelect = (labId: string) => {
    setSelectedLabId(labId);
    if (labId === "other") {
      setIsCustomLab(true);
      form.setValue("laboratory_name", "", { shouldValidate: true });
      form.setValue("laboratory_location", "");
    } else {
      setIsCustomLab(false);
      const lab = masterLabs.find((l) => l.id === labId);
      if (lab) {
        form.setValue("laboratory_name", lab.name, { shouldValidate: true });
        form.setValue("laboratory_location", lab.location || "");
      }
    }
  };

  const handleToggleTestingNeeded = (needed: "yes" | "no") => {
    setIsTestingNeeded(needed);
    const isRequired = needed === "yes";
    form.setValue("is_lab_required", isRequired, { shouldValidate: true });
    if (!isRequired) {
      form.clearErrors();
    }
  };

  // OCR Extraction on file selection
  const handleFileSelectedForOcr = async (file: File) => {
    setIsOcrExtracting(true);
    toast.info("Reading report...", {
      duration: 3500,
    });

    try {
      const formData = new FormData();
      formData.append("file", file);

      const ocrRes = await extractLabDataOcrAction(formData, commodityId);

      if (ocrRes.success && ocrRes.data) {
        const ocrData = ocrRes.data;

        // 1. Auto-fill Laboratory Name
        if (ocrData.laboratory_name && typeof ocrData.laboratory_name === "string") {
          const labNameTrimmed = ocrData.laboratory_name.trim();
          if (labNameTrimmed && labNameTrimmed.toLowerCase() !== "null") {
            const labNameLower = labNameTrimmed.toLowerCase();
            const matchedLab = masterLabs.find(
              (l) => l.name.toLowerCase().includes(labNameLower) || labNameLower.includes(l.name.toLowerCase())
            );

            if (matchedLab) {
              setSelectedLabId(matchedLab.id);
              setIsCustomLab(false);
              form.setValue("laboratory_name", matchedLab.name);
              if (matchedLab.location) {
                form.setValue("laboratory_location", matchedLab.location);
              }
            } else {
              setSelectedLabId("other");
              setIsCustomLab(true);
              form.setValue("laboratory_name", labNameTrimmed);
            }
          }
        }

        // 2. Auto-fill Laboratory Location
        if (ocrData.laboratory_location && typeof ocrData.laboratory_location === "string") {
          const locTrimmed = ocrData.laboratory_location.trim();
          if (locTrimmed && locTrimmed.toLowerCase() !== "null") {
            form.setValue("laboratory_location", locTrimmed);
          }
        }

        // 3. Auto-fill Report Number
        if (ocrData.report_number && typeof ocrData.report_number === "string") {
          const reportNo = ocrData.report_number.trim();
          if (reportNo && reportNo.toLowerCase() !== "null") {
            form.setValue("report_number", reportNo);
          }
        }

        // 4. Auto-fill Sample ID / Batch Reference
        if (ocrData.sample_id && typeof ocrData.sample_id === "string") {
          const sampleIdTrimmed = ocrData.sample_id.trim();
          if (sampleIdTrimmed && sampleIdTrimmed.toLowerCase() !== "null") {
            form.setValue("sample_id", sampleIdTrimmed);
          }
        }

        // 5. Parse and assign dates synchronously to avoid intermediate validation race condition
        let parsedReportDate: Date | null = null;
        let parsedTestDate: Date | null = null;

        if (ocrData.report_date && typeof ocrData.report_date === "string") {
          const d = new Date(ocrData.report_date.trim());
          if (!isNaN(d.getTime())) {
            parsedReportDate = d;
          }
        }

        if (ocrData.test_date && typeof ocrData.test_date === "string") {
          const d = new Date(ocrData.test_date.trim());
          if (!isNaN(d.getTime())) {
            parsedTestDate = d;
          }
        } else if (parsedReportDate) {
          parsedTestDate = parsedReportDate;
        }

        if (parsedReportDate) {
          form.setValue("report_date", parsedReportDate);
        }
        if (parsedTestDate) {
          form.setValue("test_date", parsedTestDate);
        }

        // 6. Auto-fill Quality Parameters
        if (Array.isArray(ocrData.results) && ocrData.results.length > 0) {
          const currentResults = form.getValues("results") || [];
          const updatedResults = templateParams.map((param) => {
            const matchedResult = ocrData.results.find(
              (r) =>
                r.parameter_id === param.id ||
                r.parameter_id?.toLowerCase() === param.name.toLowerCase() ||
                param.name.toLowerCase().includes(r.parameter_id?.toLowerCase() || "___")
            );

            if (matchedResult && matchedResult.measured_value !== undefined && matchedResult.measured_value !== "") {
              return {
                parameter_id: param.id,
                measured_value: String(matchedResult.measured_value),
              };
            }

            const existing = currentResults.find((r) => r.parameter_id === param.id);
            return existing || { parameter_id: param.id, measured_value: "" };
          });

          form.setValue("results", updatedResults);
        }

        // 7. Clear all errors and trigger comprehensive holistic re-validation
        form.clearErrors();
        await form.trigger();

        setOcrExtracted(true);
        toast.success("Report read successfully. Please review the summary.");
      } else {
        console.warn("OCR response error:", ocrRes?.error);
        toast.error(ocrRes?.error || "Could not read report automatically. Please enter details manually.");
      }
    } catch (err: any) {
      console.error("OCR extraction error:", err);
      toast.error("Could not read report automatically. Please enter details manually.");
    } finally {
      setIsOcrExtracting(false);
    }
  };

  // Storage Upload Handler
  const handleDocumentUploaded = (uploadedUrl: string) => {
    form.setValue("file_url", uploadedUrl, { shouldValidate: true });
    setCurrentFileUrl(uploadedUrl);
  };

  async function onSubmit(data: LabTestFormInput) {
    setIsSubmitting(true);
    try {
      const payload: LabTestFormInput = {
        ...data,
        is_lab_required: isTestingNeeded === "yes",
      };
      const res = await saveLabTestRecordAction(payload);
      if (res.success) {
        if (payload.is_lab_required === false) {
          toast.success("Self-declared quality status saved (No Lab Required).");
        } else {
          toast.success("Laboratory test record saved successfully!");
        }
        router.refresh();
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

  const onInvalid = () => {
    setShowFullDetails(true);
    toast.error("Please check the required fields before submitting.");
  };

  // Watched summary fields
  const laboratoryName = form.watch("laboratory_name");
  const reportNumber = form.watch("report_number");
  const testDate = form.watch("test_date");
  const sampleId = form.watch("sample_id");
  const fileUrl = form.watch("file_url") || currentFileUrl;

  const hasSummaryData = Boolean(fileUrl || ocrExtracted || reportNumber || laboratoryName || existingStatus);

  // Form Validation Errors
  const formErrors = form.formState.errors;
  const errorCount = Object.keys(formErrors).length;

  if (loadingData) {
    return (
      <div className="flex flex-col items-center justify-center p-10 space-y-3">
        <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
        <p className="text-sm font-medium text-slate-600">
          Loading laboratory specifications...
        </p>
      </div>
    );
  }

  return (
    <Form {...form}>
      <form
        onSubmit={form.handleSubmit(onSubmit, onInvalid)}
        className="flex-1 flex flex-col min-h-0 overflow-hidden"
      >
        <div className="flex-1 overflow-y-auto px-6 py-4 space-y-5">
          {/* Existing Status Banner if already recorded */}
          {existingStatus && (
          <div className="p-3.5 rounded-xl border border-slate-200 bg-slate-50 flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 shadow-2xs">
            <div className="flex items-center space-x-2.5">
              <div className="p-2 rounded-lg bg-emerald-100 text-emerald-800 shrink-0">
                <ShieldCheck className="h-5 w-5 stroke-[2.25]" />
              </div>
              <div>
                <p className="text-sm font-bold text-slate-900">
                  Lab Test Record on File
                </p>
                <p className="text-xs text-slate-500">
                  Official laboratory certificate attached to this lot.
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
                className="text-xs font-bold"
              >
                {existingStatus}
              </Badge>
              {freshnessStatus && (
                <Badge
                  variant="outline"
                  className={cn(
                    "text-xs font-bold",
                    freshnessStatus === "Valid" && "text-emerald-700 bg-emerald-50 border-emerald-200",
                    freshnessStatus === "Expiring Soon" && "text-amber-700 bg-amber-50 border-amber-200",
                    freshnessStatus === "Expired" && "text-rose-700 bg-rose-50 border-rose-200"
                  )}
                >
                  <Clock className="w-3.5 h-3.5 mr-1" />
                  {freshnessStatus}
                </Badge>
              )}
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TASK 1: Step 1 - Simple Decision Toggle (Yes / No)                        */}
        {/* ========================================================================= */}
        <div className="space-y-2">
          <label className="text-sm font-bold text-slate-900 block">
            Lab test required?
          </label>
          <div className="grid grid-cols-2 gap-3">
            <button
              type="button"
              onClick={() => handleToggleTestingNeeded("yes")}
              className={cn(
                "min-h-[48px] h-12 rounded-xl border-2 text-sm font-bold flex items-center justify-center gap-2 transition-all cursor-pointer",
                isTestingNeeded === "yes"
                  ? "border-emerald-600 bg-emerald-50 text-emerald-900 shadow-xs"
                  : "border-slate-200 hover:border-slate-300 bg-white text-slate-700"
              )}
            >
              {isTestingNeeded === "yes" && <Check className="w-4 h-4 text-emerald-600 stroke-[3]" />}
              <span>Yes</span>
            </button>
            <button
              type="button"
              onClick={() => handleToggleTestingNeeded("no")}
              className={cn(
                "min-h-[48px] h-12 rounded-xl border-2 text-sm font-bold flex items-center justify-center gap-2 transition-all cursor-pointer",
                isTestingNeeded === "no"
                  ? "border-slate-800 bg-slate-100 text-slate-900 shadow-xs"
                  : "border-slate-200 hover:border-slate-300 bg-white text-slate-700"
              )}
            >
              {isTestingNeeded === "no" && <Check className="w-4 h-4 text-slate-800 stroke-[3]" />}
              <span>No</span>
            </button>
          </div>
        </div>

        {/* If NO: Informational Callout & Fast-track confirmation */}
        {isTestingNeeded === "no" && (
          <div className="p-4 rounded-xl bg-slate-50 border border-slate-200 flex items-start gap-3 animate-in fade-in-50 duration-200">
            <CheckCircle2 className="h-5 w-5 text-slate-600 shrink-0 mt-0.5" />
            <div className="space-y-1 text-sm text-slate-600">
              <p className="font-bold text-slate-900">Self-Declared Quality Mode</p>
              <p className="text-xs text-slate-500 leading-relaxed">
                No third-party lab test report is needed for this lot. Standard specifications declared at creation will be applied.
              </p>
            </div>
          </div>
        )}

        {/* If YES: Show Simplified Upload & Progressive Disclosure Flow */}
        {isTestingNeeded === "yes" && (
          <div className="space-y-5 animate-in fade-in-50 duration-200">
            
            {/* TASK 1 (Step 2): Upload Dropzone as Primary Focus */}
            <div className="space-y-1.5">
              <LabDocumentUpload
                availabilityId={availabilityId}
                existingFileUrl={currentFileUrl || form.watch("file_url")}
                onFileSelect={handleFileSelectedForOcr}
                onUploadComplete={handleDocumentUploaded}
                disabled={isSubmitting || isOcrExtracting}
              />
            </div>

            {/* TASK 2: Compact Report Summary Card */}
            {hasSummaryData && (
              <div className="p-4 rounded-xl border border-slate-200 bg-white shadow-2xs space-y-3 animate-in fade-in-50">
                <div className="flex items-center justify-between pb-2 border-b border-slate-100">
                  <div className="flex items-center gap-2">
                    <FileText className="h-4 w-4 text-emerald-600 shrink-0" />
                    <span className="text-xs font-bold uppercase tracking-wider text-slate-600">
                      Report Summary
                    </span>
                  </div>
                  <Badge variant="outline" className="bg-emerald-50 text-emerald-700 border-emerald-200 text-[11px] font-bold">
                    Extracted
                  </Badge>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 text-xs sm:text-sm">
                  <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-100/80">
                    <span className="text-[11px] font-semibold text-slate-500 block">Laboratory</span>
                    <span className="font-bold text-slate-900 truncate block mt-0.5">
                      {laboratoryName || "—"}
                    </span>
                  </div>

                  <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-100/80">
                    <span className="text-[11px] font-semibold text-slate-500 block">Report No.</span>
                    <span className="font-bold font-mono text-slate-900 truncate block mt-0.5">
                      {reportNumber || "—"}
                    </span>
                  </div>

                  <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-100/80">
                    <span className="text-[11px] font-semibold text-slate-500 block">Test Date</span>
                    <span className="font-bold text-slate-900 truncate block mt-0.5">
                      {testDate ? format(new Date(testDate), "dd MMM yyyy") : "—"}
                    </span>
                  </div>

                  <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-100/80">
                    <span className="text-[11px] font-semibold text-slate-500 block">Sample / Batch</span>
                    <span className="font-bold font-mono text-slate-900 truncate block mt-0.5">
                      {sampleId || "—"}
                    </span>
                  </div>
                </div>
              </div>
            )}

            {/* TASK 2: Exception-Based Review Warning Banner */}
            {errorCount > 0 && (
              <div className="p-3.5 sm:p-4 rounded-xl bg-amber-50 border-2 border-amber-300 flex items-center justify-between gap-3 text-amber-900 animate-in fade-in-50">
                <div className="flex items-center gap-2.5 min-w-0">
                  <AlertTriangle className="h-5 w-5 text-amber-600 shrink-0" />
                  <div className="min-w-0">
                    <p className="text-sm font-bold truncate">
                      ⚠ {errorCount} {errorCount === 1 ? "item needs" : "items need"} checking
                    </p>
                    <p className="text-xs text-amber-700 hidden sm:block">
                      Please verify the highlighted fields before submitting.
                    </p>
                  </div>
                </div>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => setShowFullDetails(true)}
                  className="min-h-[48px] h-12 px-5 bg-amber-100 hover:bg-amber-200 border-amber-300 text-amber-900 font-bold rounded-xl shrink-0 cursor-pointer text-sm"
                >
                  Fix
                </Button>
              </div>
            )}

            {/* TASK 3: Progressive Disclosure Accordion Toggle */}
            <div className="pt-1">
              <button
                type="button"
                onClick={() => setShowFullDetails((prev) => !prev)}
                className="w-full min-h-[48px] h-12 flex items-center justify-between px-4 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 text-slate-800 text-sm font-bold transition-all cursor-pointer"
              >
                <span>{showFullDetails ? "Hide report details" : "View full report details"}</span>
                {showFullDetails ? (
                  <ChevronUp className="h-4 w-4 text-slate-500 shrink-0" />
                ) : (
                  <ChevronDown className="h-4 w-4 text-slate-500 shrink-0" />
                )}
              </button>
            </div>

            {/* Collapsible Section — Remains mounted in DOM for react-hook-form */}
            <div className={cn("space-y-5 pt-1", !showFullDetails && "hidden")}>
              
              {/* 1. Laboratory Agency Selection */}
              <div className="p-4 rounded-xl border border-slate-200 bg-white space-y-4 shadow-2xs">
                <div className="flex items-center gap-2 pb-2 border-b border-slate-100">
                  <Building2 className="h-4 w-4 text-emerald-600 shrink-0" />
                  <span className="text-sm font-bold text-slate-900">
                    Laboratory Agency
                  </span>
                </div>

                <div className="space-y-2">
                  <label className="text-xs font-bold text-slate-700 block">
                    Select Accredited Lab <span className="text-destructive">*</span>
                  </label>
                  <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2">
                    {masterLabs.map((lab) => {
                      const isSelected = selectedLabId === lab.id;
                      return (
                        <button
                          key={lab.id}
                          type="button"
                          onClick={() => handleLabSelect(lab.id)}
                          className={cn(
                            "flex flex-col text-left p-3 rounded-xl border text-xs transition-all min-h-[48px] cursor-pointer",
                            isSelected
                              ? "border-emerald-600 bg-emerald-50/80 font-bold text-emerald-900 ring-2 ring-emerald-500/20"
                              : "border-slate-200 hover:border-slate-300 hover:bg-slate-50 text-slate-700 font-medium"
                          )}
                        >
                          <div className="flex items-center justify-between">
                            <span className="truncate">{lab.name}</span>
                            {isSelected && <Check className="w-3.5 h-3.5 text-emerald-600 shrink-0" />}
                          </div>
                          {lab.location && (
                            <span className="text-[11px] text-slate-400 font-normal truncate mt-0.5">
                              {lab.location}
                            </span>
                          )}
                        </button>
                      );
                    })}

                    <button
                      type="button"
                      onClick={() => handleLabSelect("other")}
                      className={cn(
                        "flex items-center justify-between p-3 rounded-xl border text-xs transition-all min-h-[48px] cursor-pointer",
                        selectedLabId === "other"
                          ? "border-emerald-600 bg-emerald-50/80 font-bold text-emerald-900 ring-2 ring-emerald-500/20"
                          : "border-dashed border-slate-300 hover:border-slate-400 text-slate-600 font-medium"
                      )}
                    >
                      <span>+ Other Lab</span>
                      {selectedLabId === "other" && <Check className="w-3.5 h-3.5 text-emerald-600 shrink-0" />}
                    </button>
                  </div>
                </div>

                {isCustomLab && (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-2 p-3 bg-slate-50 rounded-xl border border-slate-200 animate-in fade-in-50">
                    <FormField
                      control={form.control}
                      name="laboratory_name"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-xs font-bold text-slate-700">
                            Custom Lab Name <span className="text-destructive">*</span>
                          </FormLabel>
                          <FormControl>
                            <Input
                              placeholder="e.g. Regional Agri Testing Lab"
                              className="min-h-[48px] h-12 text-base bg-white"
                              {...field}
                              value={field.value || ""}
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
                          <FormLabel className="text-xs font-bold text-slate-700">
                            Lab Address / Location
                          </FormLabel>
                          <FormControl>
                            <Input
                              placeholder="e.g. Indore, Madhya Pradesh"
                              className="min-h-[48px] h-12 text-base bg-white"
                              {...field}
                              value={field.value || ""}
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>
                )}
              </div>

              {/* 2. Certificate Details & Dates */}
              <div className="p-4 rounded-xl border border-slate-200 bg-white space-y-4 shadow-2xs">
                <div className="flex items-center gap-2 pb-2 border-b border-slate-100">
                  <CalendarIcon className="h-4 w-4 text-emerald-600 shrink-0" />
                  <span className="text-sm font-bold text-slate-900">
                    Certificate Details & Dates
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <FormField
                    control={form.control}
                    name="report_number"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs font-bold text-slate-700">
                          Report / Certificate No. <span className="text-destructive">*</span>
                        </FormLabel>
                        <FormControl>
                          <Input
                            placeholder="e.g. COA-2026-98741"
                            className="min-h-[48px] h-12 text-base font-mono"
                            {...field}
                            value={field.value || ""}
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
                        <FormLabel className="text-xs font-bold text-slate-700">
                          Sample ID / Batch (Optional)
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

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <FormField
                    control={form.control}
                    name="test_date"
                    render={({ field }) => (
                      <FormItem className="flex flex-col">
                        <FormLabel className="text-xs font-bold text-slate-700">
                          Test Date <span className="text-destructive">*</span>
                        </FormLabel>
                        <Popover>
                          <FormControl>
                            <PopoverTrigger
                              className={cn(
                                buttonVariants({ variant: "outline" }),
                                "w-full min-h-[48px] h-12 pl-3 text-left font-normal flex items-center justify-between rounded-xl",
                                !field.value && "text-muted-foreground"
                              )}
                            >
                              {field.value ? format(field.value, "dd MMM yyyy") : <span>Pick test date</span>}
                              <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                            </PopoverTrigger>
                          </FormControl>
                          <PopoverContent className="w-auto p-0" align="start">
                            <Calendar
                              mode="single"
                              selected={field.value || undefined}
                              onSelect={(date) => {
                                field.onChange(date);
                                form.trigger(["test_date", "report_date"]);
                              }}
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
                        <FormLabel className="text-xs font-bold text-slate-700">
                          Report Date <span className="text-destructive">*</span>
                        </FormLabel>
                        <Popover>
                          <FormControl>
                            <PopoverTrigger
                              className={cn(
                                buttonVariants({ variant: "outline" }),
                                "w-full min-h-[48px] h-12 pl-3 text-left font-normal flex items-center justify-between rounded-xl",
                                !field.value && "text-muted-foreground"
                              )}
                            >
                              {field.value ? format(field.value, "dd MMM yyyy") : <span>Pick report date</span>}
                              <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                            </PopoverTrigger>
                          </FormControl>
                          <PopoverContent className="w-auto p-0" align="start">
                            <Calendar
                              mode="single"
                              selected={field.value || undefined}
                              onSelect={(date) => {
                                field.onChange(date);
                                form.trigger(["test_date", "report_date", "valid_until"]);
                              }}
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
                        <FormLabel className="text-xs font-bold text-slate-700">
                          Expiry Date (Optional)
                        </FormLabel>
                        <Popover>
                          <FormControl>
                            <PopoverTrigger
                              className={cn(
                                buttonVariants({ variant: "outline" }),
                                "w-full min-h-[48px] h-12 pl-3 text-left font-normal flex items-center justify-between rounded-xl",
                                !field.value && "text-muted-foreground"
                              )}
                            >
                              {field.value ? format(field.value, "dd MMM yyyy") : <span>Pick expiry date</span>}
                              <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                            </PopoverTrigger>
                          </FormControl>
                          <PopoverContent className="w-auto p-0" align="start">
                            <Calendar
                              mode="single"
                              selected={field.value || undefined}
                              onSelect={(date) => {
                                field.onChange(date);
                                form.trigger(["valid_until"]);
                              }}
                              disabled={(date) => {
                                const rDate = form.watch("report_date");
                                if (!rDate) return false;
                                const normalizedRDate = new Date(rDate);
                                normalizedRDate.setHours(0, 0, 0, 0);
                                const normalizedDate = new Date(date);
                                normalizedDate.setHours(0, 0, 0, 0);
                                return normalizedDate.getTime() <= normalizedRDate.getTime();
                              }}
                            />
                          </PopoverContent>
                        </Popover>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </div>
              </div>

              {/* 3. Analytical Results Parameters (Empty State Rule: Hide if templateParams has 0 items) */}
              {templateParams.length > 0 && (
                <div className="p-4 rounded-xl border border-slate-200 bg-white space-y-4 shadow-2xs">
                  <div className="flex items-center justify-between pb-2 border-b border-slate-100">
                    <div className="flex items-center gap-2">
                      <FlaskConical className="h-4 w-4 text-emerald-600 shrink-0" />
                      <span className="text-sm font-bold text-slate-900">
                        Measured Quality Parameters
                      </span>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    {templateParams.map((param) => {
                      const resultItem = watchedResults.find((r) => r.parameter_id === param.id);
                      const measuredVal = resultItem?.measured_value || "";
                      const isWithin = checkIsWithinBounds(measuredVal, param);

                      return (
                        <div
                          key={param.id}
                          className={cn(
                            "flex flex-col space-y-2 p-3.5 rounded-xl border transition-all",
                            !isWithin && measuredVal.trim() !== ""
                              ? "border-amber-300 bg-amber-50/20"
                              : "border-slate-200 bg-white"
                          )}
                        >
                          <div className="flex items-center justify-between gap-2">
                            <label
                              htmlFor={`lab-param-${param.id}`}
                              className="text-xs font-bold text-slate-800 flex items-center gap-1 cursor-pointer"
                            >
                              <span>{param.name}</span>
                              {param.unit && (
                                <span className="text-[11px] font-semibold text-slate-500">
                                  ({param.unit})
                                </span>
                              )}
                            </label>

                            <div className="flex items-center gap-1 flex-wrap justify-end">
                              {param.minValue !== null && param.minValue !== undefined && (
                                <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 border border-slate-200">
                                  Min: {param.minValue}
                                </span>
                              )}
                              {param.maxValue !== null && param.maxValue !== undefined && (
                                <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 border border-slate-200">
                                  Max: {param.maxValue}
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
                                  : "Enter value"
                              }
                              value={measuredVal}
                              onChange={(e) => handleResultChange(param.id, e.target.value)}
                              className={cn(
                                "min-h-[48px] h-12 text-base font-semibold",
                                param.unit ? "pr-12" : "",
                                !isWithin && measuredVal.trim() !== "" && "border-amber-400 focus-visible:ring-amber-400"
                              )}
                            />
                            {param.unit && (
                              <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
                                <span className="text-xs text-slate-500 font-bold font-mono">
                                  {param.unit}
                                </span>
                              </div>
                            )}
                          </div>

                          {!isWithin && measuredVal.trim() !== "" && (
                            <p className="text-xs font-semibold text-amber-700 flex items-center gap-1 mt-1">
                              <AlertTriangle className="h-3.5 w-3.5 shrink-0 text-amber-600" />
                              <span>
                                Outside bounds ({param.minValue ?? "—"} to {param.maxValue ?? "—"}{param.unit ? ` ${param.unit}` : ""}).
                              </span>
                            </p>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

            </div>
          </div>
        )}

        </div>

        {/* Dialog Footer Actions (Always visible at bottom) */}
        <div className="p-6 pt-4 border-t border-slate-200 bg-white shrink-0">
          <div className="grid grid-cols-2 gap-3 max-w-full">
            <Button
              type="button"
              variant="outline"
              onClick={() => {
                if (onCancel) onCancel();
              }}
              disabled={isSubmitting}
              className="w-full min-h-[48px] h-12 rounded-xl font-bold border-slate-300 hover:bg-slate-100 text-slate-700 cursor-pointer text-sm sm:text-base"
            >
              Cancel
            </Button>

            {isTestingNeeded === "no" ? (
              <Button
                type="submit"
                disabled={isSubmitting}
                className="w-full min-h-[48px] h-12 rounded-xl font-bold bg-slate-900 hover:bg-slate-800 text-white shadow-xs cursor-pointer text-sm sm:text-base flex items-center justify-center gap-1.5"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin shrink-0" />
                    <span>Saving...</span>
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="w-4 h-4 shrink-0" />
                    <span>Confirm & Save</span>
                  </>
                )}
              </Button>
            ) : (
              <Button
                type="submit"
                disabled={isSubmitting || isOcrExtracting}
                className="w-full min-h-[48px] h-12 rounded-xl font-bold bg-[#047857] hover:bg-[#065f46] text-white shadow-xs cursor-pointer text-sm sm:text-base flex items-center justify-center gap-2"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin shrink-0" />
                    <span>Saving...</span>
                  </>
                ) : (
                  <>
                    <ShieldCheck className="w-4 h-4 shrink-0" />
                    <span>Confirm & Submit</span>
                  </>
                )}
              </Button>
            )}
          </div>
        </div>

      </form>
    </Form>
  );
}
