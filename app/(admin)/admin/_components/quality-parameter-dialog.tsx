"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  masterQualityParameterFormSchema,
  MasterQualityParameterFormValues,
} from "@/src/types/quality-schema";
import {
  addQualityParameterAction,
  updateQualityParameterAction,
} from "@/src/server/actions/master-data-actions";
import { toast } from "sonner";
import { Loader2, Sparkles, SlidersHorizontal } from "lucide-react";

interface QualityParameterDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  commodities: Array<{ id: string; name: string }>;
  editingParameter?: any | null;
  onSuccess: () => void;
}

export function QualityParameterDialog({
  open,
  onOpenChange,
  commodities,
  editingParameter,
  onSuccess,
}: QualityParameterDialogProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<MasterQualityParameterFormValues>({
    resolver: zodResolver(masterQualityParameterFormSchema) as any,
    defaultValues: {
      commodity_id: "",
      name: "",
      type: "numeric",
      unit: "",
      min_value: undefined,
      max_value: undefined,
      target_value: undefined,
      is_required: false,
    },
  });

  const selectedType = form.watch("type");

  useEffect(() => {
    if (open) {
      if (editingParameter) {
        form.reset({
          id: editingParameter.id,
          commodity_id: editingParameter.commodityId || "",
          name: editingParameter.name || "",
          type: (editingParameter.type as any) || "numeric",
          unit: editingParameter.unit || "",
          min_value: editingParameter.minValue !== null && editingParameter.minValue !== undefined ? Number(editingParameter.minValue) : undefined,
          max_value: editingParameter.maxValue !== null && editingParameter.maxValue !== undefined ? Number(editingParameter.maxValue) : undefined,
          target_value: editingParameter.targetValue !== null && editingParameter.targetValue !== undefined ? Number(editingParameter.targetValue) : undefined,
          is_required: Boolean(editingParameter.isRequired),
        });
      } else {
        form.reset({
          commodity_id: commodities[0]?.id || "",
          name: "",
          type: "numeric",
          unit: "",
          min_value: undefined,
          max_value: undefined,
          target_value: undefined,
          is_required: false,
        });
      }
    }
  }, [open, editingParameter, commodities, form]);

  const handleSubmit = async (values: MasterQualityParameterFormValues) => {
    setIsSubmitting(true);
    try {
      const isEditing = Boolean(editingParameter?.id);
      const res = isEditing
        ? await updateQualityParameterAction(editingParameter.id, values)
        : await addQualityParameterAction(values);

      if (res.success) {
        toast.success(
          isEditing
            ? "Quality parameter updated successfully"
            : "Quality parameter added successfully"
        );
        onOpenChange(false);
        onSuccess();
      } else {
        toast.error(res.error || "Failed to save quality parameter");
      }
    } catch (err: any) {
      toast.error(err.message || "An unexpected error occurred");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[640px] max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <div className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-lg bg-slate-100 flex items-center justify-center text-[#334155]">
              <SlidersHorizontal className="h-4 w-4" />
            </div>
            <div>
              <DialogTitle className="text-xl font-bold text-slate-800">
                {editingParameter ? "Edit Quality Parameter" : "Add New Quality Parameter"}
              </DialogTitle>
              <DialogDescription className="text-xs text-slate-500">
                Configure commodity-specific lab tests, mathematical tolerances, and specification bounds.
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4 pt-2">
            {/* Main Fields Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Commodity Selector */}
              <FormField
                control={form.control}
                name="commodity_id"
                render={({ field }) => (
                  <FormItem className="sm:col-span-2">
                    <FormLabel className="text-xs font-semibold text-slate-700">
                      Target Commodity <span className="text-destructive">*</span>
                    </FormLabel>
                    <Select
                      value={field.value}
                      onValueChange={field.onChange}
                      disabled={isSubmitting}
                    >
                      <FormControl>
                        <SelectTrigger className="h-10 text-sm">
                          <SelectValue placeholder="Select a commodity">
                            {field.value
                              ? commodities.find((c) => c.id === field.value)?.name
                              : null}
                          </SelectValue>
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        {commodities.map((c) => (
                          <SelectItem key={c.id} value={c.id}>
                            {c.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Parameter Name */}
              <FormField
                control={form.control}
                name="name"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs font-semibold text-slate-700">
                      Parameter Name <span className="text-destructive">*</span>
                    </FormLabel>
                    <FormControl>
                      <Input
                        placeholder="e.g. Moisture, Protein, Broken Grains"
                        className="h-10 text-sm"
                        disabled={isSubmitting}
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Parameter Type */}
              <FormField
                control={form.control}
                name="type"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs font-semibold text-slate-700">
                      Data Type <span className="text-destructive">*</span>
                    </FormLabel>
                    <Select
                      value={field.value}
                      onValueChange={field.onChange}
                      disabled={isSubmitting}
                    >
                      <FormControl>
                        <SelectTrigger className="h-10 text-sm">
                          <SelectValue placeholder="Select data type">
                            {field.value === "numeric"
                              ? "Numeric (Quantitative)"
                              : field.value === "text"
                              ? "Text (Descriptive)"
                              : field.value === "boolean"
                              ? "Boolean (Conforming / Non-Conforming)"
                              : null}
                          </SelectValue>
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="numeric">Numeric (Quantitative)</SelectItem>
                        <SelectItem value="text">Text (Descriptive)</SelectItem>
                        <SelectItem value="boolean">Boolean (Conforming / Non-Conforming)</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Unit (e.g. %, mg/kg) */}
              <FormField
                control={form.control}
                name="unit"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="text-xs font-semibold text-slate-700">
                      Unit of Measurement
                    </FormLabel>
                    <FormControl>
                      <Input
                        placeholder="e.g. %, mg/kg, count, mm"
                        className="h-10 text-sm"
                        disabled={isSubmitting}
                        value={field.value || ""}
                        onChange={field.onChange}
                      />
                    </FormControl>
                    <FormDescription className="text-[11px] text-slate-400">
                      Optional unit suffix displayed on forms and reports.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Is Required Toggle / Checkbox */}
              <FormField
                control={form.control}
                name="is_required"
                render={({ field }) => (
                  <FormItem className="flex flex-row items-center justify-between rounded-lg border border-slate-200 p-3 bg-slate-50/50 mt-1">
                    <div className="space-y-0.5">
                      <FormLabel className="text-xs font-semibold text-slate-800 cursor-pointer">
                        Mandatory QC Parameter
                      </FormLabel>
                      <FormDescription className="text-[11px] text-slate-500">
                        Require sellers to fill this parameter when posting inventory.
                      </FormDescription>
                    </div>
                    <FormControl>
                      <input
                        type="checkbox"
                        checked={field.value}
                        onChange={(e) => field.onChange(e.target.checked)}
                        disabled={isSubmitting}
                        className="h-4 w-4 rounded border-slate-300 text-slate-900 focus:ring-slate-900 cursor-pointer"
                      />
                    </FormControl>
                  </FormItem>
                )}
              />
            </div>

            {/* Dynamic Numeric Rules (Min, Max, Target) */}
            {selectedType === "numeric" && (
              <div className="rounded-lg border border-slate-200 bg-slate-50/60 p-3.5 space-y-3">
                <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-700">
                  <Sparkles className="h-3.5 w-3.5 text-amber-500" />
                  <span>Mathematical Validation Rules & Targets</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  {/* Min Value */}
                  <FormField
                    control={form.control}
                    name="min_value"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-[11px] font-medium text-slate-600">
                          Min Allowed Value
                        </FormLabel>
                        <FormControl>
                          <Input
                            type="number"
                            step="any"
                            placeholder="e.g. 8"
                            className="h-9 text-sm bg-white"
                            disabled={isSubmitting}
                            value={field.value ?? ""}
                            onChange={(e) => field.onChange(e.target.value)}
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  {/* Max Value */}
                  <FormField
                    control={form.control}
                    name="max_value"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-[11px] font-medium text-slate-600">
                          Max Allowed Value
                        </FormLabel>
                        <FormControl>
                          <Input
                            type="number"
                            step="any"
                            placeholder="e.g. 14"
                            className="h-9 text-sm bg-white"
                            disabled={isSubmitting}
                            value={field.value ?? ""}
                            onChange={(e) => field.onChange(e.target.value)}
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  {/* Target Value */}
                  <FormField
                    control={form.control}
                    name="target_value"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-[11px] font-medium text-slate-600">
                          Ideal Target
                        </FormLabel>
                        <FormControl>
                          <Input
                            type="number"
                            step="any"
                            placeholder="e.g. 12"
                            className="h-9 text-sm bg-white"
                            disabled={isSubmitting}
                            value={field.value ?? ""}
                            onChange={(e) => field.onChange(e.target.value)}
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </div>
              </div>
            )}

            <DialogFooter className="pt-2">
              <Button
                type="button"
                variant="outline"
                onClick={() => onOpenChange(false)}
                disabled={isSubmitting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isSubmitting}
                className="bg-[#334155] hover:bg-[#1e293b] text-white"
              >
                {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                {editingParameter ? "Update Parameter" : "Save Parameter"}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
