"use client";

import React, { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import {
  Loader2,
  Plus,
  Building2,
  Store,
  ShieldCheck,
  User,
  Mail,
  Lock,
  Phone,
  FileText,
  MapPin,
  Layers,
  UserCheck,
} from "lucide-react";
import { cn } from "@/lib/utils";
import {
  useIndustries,
  useCategories,
  useStates,
  useDistricts,
} from "@/src/hooks/use-master-data";
import {
  createBuyerSellerByAdminAction,
  type CreateBuyerSellerInput,
} from "@/src/server/actions/admin-user-actions";

const addClientSchema = z.object({
  role: z.enum(["buyer", "seller"], {
    required_error: "Please select an account role.",
  }),
  userFullName: z
    .string()
    .min(2, "Full name must be at least 2 characters")
    .max(100, "Full name cannot exceed 100 characters"),
  email: z
    .string()
    .email("Please enter a valid email address")
    .max(120, "Email cannot exceed 120 characters"),
  password: z
    .string()
    .min(6, "Temporary password must be at least 6 characters")
    .max(100, "Password cannot exceed 100 characters"),
  phone: z
    .string()
    .max(15, "Phone number cannot exceed 15 characters")
    .optional()
    .or(z.literal("")),
  companyName: z
    .string()
    .min(2, "Company name must be at least 2 characters")
    .max(150, "Company name cannot exceed 150 characters"),
  gst: z
    .string()
    .max(15, "GST number cannot exceed 15 characters")
    .optional()
    .or(z.literal("")),
  industryId: z.string().optional().or(z.literal("")),
  categoryId: z.string().optional().or(z.literal("")),
  stateId: z.string().optional().or(z.literal("")),
  districtId: z.string().optional().or(z.literal("")),
});

export type AddClientFormValues = z.infer<typeof addClientSchema>;

interface AddClientDialogProps {
  trigger?: React.ReactNode;
  onSuccess?: () => void;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
}

export function AddClientDialog({
  trigger,
  onSuccess,
  open: externalOpen,
  onOpenChange: setExternalOpen,
}: AddClientDialogProps) {
  const [internalOpen, setInternalOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const isControlled = externalOpen !== undefined;
  const isOpen = isControlled ? externalOpen : internalOpen;
  const setIsOpen = isControlled ? setExternalOpen! : setInternalOpen;

  // Master Data Queries
  const { data: industries = [], isLoading: loadingIndustries } = useIndustries();
  const { data: categories = [], isLoading: loadingCategories } = useCategories();
  const { data: states = [], isLoading: loadingStates } = useStates();
  const { data: districts = [], isLoading: loadingDistricts } = useDistricts();

  const form = useForm<AddClientFormValues>({
    resolver: zodResolver(addClientSchema),
    defaultValues: {
      role: "buyer",
      userFullName: "",
      email: "",
      password: "",
      phone: "",
      companyName: "",
      gst: "",
      industryId: "",
      categoryId: "",
      stateId: "",
      districtId: "",
    },
  });

  const selectedRole = form.watch("role");
  const selectedIndustryId = form.watch("industryId");
  const selectedStateId = form.watch("stateId");

  // Cascading filters
  const filteredCategories = React.useMemo(() => {
    if (!selectedIndustryId) return [];
    return categories.filter((c: any) => c.industryId === selectedIndustryId);
  }, [categories, selectedIndustryId]);

  const filteredDistricts = React.useMemo(() => {
    if (!selectedStateId) return [];
    return districts.filter((d: any) => d.stateId === selectedStateId);
  }, [districts, selectedStateId]);

  const onSubmit = async (values: AddClientFormValues) => {
    setIsSubmitting(true);
    try {
      const payload: CreateBuyerSellerInput = {
        role: values.role,
        userFullName: values.userFullName,
        email: values.email,
        password: values.password,
        phone: values.phone || undefined,
        companyName: values.companyName,
        gst: values.gst ? values.gst.trim().toUpperCase() : undefined,
        industryId: values.industryId || undefined,
        categoryId: values.categoryId || undefined,
        stateId: values.stateId || undefined,
        districtId: values.districtId || undefined,
      };

      const result = await createBuyerSellerByAdminAction(payload);

      if (result.success) {
        toast.success("Account & Company Provisioned Successfully", {
          description: `${values.role.toUpperCase()} account created for ${values.userFullName} (${values.companyName}).`,
        });
        form.reset({
          role: "buyer",
          userFullName: "",
          email: "",
          password: "",
          phone: "",
          companyName: "",
          gst: "",
          industryId: "",
          categoryId: "",
          stateId: "",
          districtId: "",
        });
        setIsOpen(false);
        onSuccess?.();
      } else {
        toast.error(result.error || "Failed to provision account");
      }
    } catch (err: any) {
      console.error("AddClientDialog error:", err);
      toast.error(err.message || "An unexpected error occurred.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={setIsOpen}>
      <DialogTrigger
        render={
          trigger ? (
            (trigger as React.ReactElement)
          ) : (
            <Button
              type="button"
              className="bg-slate-900 hover:bg-slate-800 text-white font-medium shadow-sm flex items-center gap-2 h-10 px-4 min-h-[40px] cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>Add Buyer / Seller</span>
            </Button>
          )
        }
      />

      <DialogContent className="w-[95vw] sm:max-w-3xl max-h-[90vh] overflow-y-auto p-0 rounded-xl border-slate-200 shadow-2xl bg-white">
        <DialogHeader className="px-6 pt-6 pb-4 border-b border-slate-100 bg-slate-50/50 sticky top-0 z-10 backdrop-blur-sm">
          <div className="flex items-center gap-2">
            <div className="p-2 bg-slate-900 text-white rounded-lg shadow-sm">
              <ShieldCheck className="w-5 h-5 text-emerald-400" />
            </div>
            <div>
              <DialogTitle className="text-xl font-bold text-slate-900">
                Provision New Buyer/Seller
              </DialogTitle>
              <DialogDescription className="text-xs text-slate-500 mt-0.5">
                Direct Tier 0 provisioning with pre-approved company status and instant bypass of public onboarding.
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6 p-6">
            {/* SECTION 1: USER CREDENTIALS & ROLE */}
            <div className="space-y-4 rounded-lg border border-slate-200/80 p-4 bg-slate-50/30">
              <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-slate-600 border-b border-slate-200/60 pb-2">
                <User className="w-3.5 h-3.5 text-blue-600" />
                <span>Section 1: User Credentials & Role Selection</span>
              </div>

              {/* Role Toggle */}
              <div className="space-y-2">
                <FormLabel className="text-xs font-semibold text-slate-700">Account Type</FormLabel>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => form.setValue("role", "buyer", { shouldValidate: true })}
                    className={cn(
                      "flex items-center justify-center gap-2.5 h-12 min-h-[48px] rounded-lg border text-sm font-semibold transition-all cursor-pointer",
                      selectedRole === "buyer"
                        ? "bg-slate-900 text-white border-slate-900 shadow-sm ring-2 ring-slate-900/10"
                        : "bg-white text-slate-700 border-slate-200 hover:bg-slate-100/70"
                    )}
                  >
                    <Building2 className={cn("w-4 h-4", selectedRole === "buyer" ? "text-emerald-400" : "text-slate-500")} />
                    <span>Buyer Account</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => form.setValue("role", "seller", { shouldValidate: true })}
                    className={cn(
                      "flex items-center justify-center gap-2.5 h-12 min-h-[48px] rounded-lg border text-sm font-semibold transition-all cursor-pointer",
                      selectedRole === "seller"
                        ? "bg-slate-900 text-white border-slate-900 shadow-sm ring-2 ring-slate-900/10"
                        : "bg-white text-slate-700 border-slate-200 hover:bg-slate-100/70"
                    )}
                  >
                    <Store className={cn("w-4 h-4", selectedRole === "seller" ? "text-emerald-400" : "text-slate-500")} />
                    <span>Seller Account</span>
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {/* Full Name */}
                <FormField
                  control={form.control}
                  name="userFullName"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">Full Name *</FormLabel>
                      <FormControl>
                        <div className="relative">
                          <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                          <Input
                            placeholder="e.g. Ramesh Patel"
                            {...field}
                            className="pl-9 h-12 min-h-[48px] text-sm bg-white"
                          />
                        </div>
                      </FormControl>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />

                {/* Email */}
                <FormField
                  control={form.control}
                  name="email"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">Email Address *</FormLabel>
                      <FormControl>
                        <div className="relative">
                          <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                          <Input
                            type="email"
                            placeholder="user@company.com"
                            {...field}
                            className="pl-9 h-12 min-h-[48px] text-sm bg-white"
                          />
                        </div>
                      </FormControl>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {/* Temporary Password */}
                <FormField
                  control={form.control}
                  name="password"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">Temporary Password *</FormLabel>
                      <FormControl>
                        <div className="relative">
                          <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                          <Input
                            type="password"
                            placeholder="Min 6 characters"
                            {...field}
                            className="pl-9 h-12 min-h-[48px] text-sm bg-white"
                          />
                        </div>
                      </FormControl>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />

                {/* Phone */}
                <FormField
                  control={form.control}
                  name="phone"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">Phone (Optional)</FormLabel>
                      <FormControl>
                        <div className="relative">
                          <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                          <Input
                            placeholder="e.g. +91 9876543210"
                            {...field}
                            className="pl-9 h-12 min-h-[48px] text-sm bg-white"
                          />
                        </div>
                      </FormControl>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />
              </div>
            </div>

            {/* SECTION 2: COMPANY DETAILS */}
            <div className="space-y-4 rounded-lg border border-slate-200/80 p-4 bg-slate-50/30">
              <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-slate-600 border-b border-slate-200/60 pb-2">
                <Building2 className="w-3.5 h-3.5 text-emerald-600" />
                <span>Section 2: Company Details</span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {/* Company Name */}
                <FormField
                  control={form.control}
                  name="companyName"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">Company Name *</FormLabel>
                      <FormControl>
                        <div className="relative">
                          <Building2 className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                          <Input
                            placeholder="e.g. Apex Agri Solutions Pvt Ltd"
                            {...field}
                            className="pl-9 h-12 min-h-[48px] text-sm bg-white"
                          />
                        </div>
                      </FormControl>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />

                {/* GST */}
                <FormField
                  control={form.control}
                  name="gst"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">
                        GSTIN (15-char limit)
                      </FormLabel>
                      <FormControl>
                        <div className="relative">
                          <FileText className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                          <Input
                            placeholder="27AAAAA0000A1Z5"
                            maxLength={15}
                            value={field.value || ""}
                            onChange={(e) => field.onChange(e.target.value.toUpperCase())}
                            className="pl-9 h-12 min-h-[48px] text-sm font-mono tracking-wider bg-white uppercase"
                          />
                        </div>
                      </FormControl>
                      <FormDescription className="text-[11px] text-slate-500">
                        Indian GST registration format (Optional for direct provisioning).
                      </FormDescription>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />
              </div>
            </div>

            {/* SECTION 3: MASTER DATA DROPDOWNS */}
            <div className="space-y-4 rounded-lg border border-slate-200/80 p-4 bg-slate-50/30">
              <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-slate-600 border-b border-slate-200/60 pb-2">
                <Layers className="w-3.5 h-3.5 text-indigo-600" />
                <span>Section 3: Master Data Cascading Dropdowns</span>
              </div>

              {/* Taxonomy: Industry -> Category */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {/* Industry */}
                <FormField
                  control={form.control}
                  name="industryId"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">Industry</FormLabel>
                      <Select
                        value={field.value || undefined}
                        onValueChange={(val) => {
                          field.onChange(val);
                          form.setValue("categoryId", ""); // Reset dependent category
                        }}
                        disabled={loadingIndustries}
                      >
                        <FormControl>
                          <SelectTrigger className="h-12 min-h-[48px] text-sm bg-white border-slate-200">
                            <SelectValue placeholder={loadingIndustries ? "Loading industries..." : "Select Industry"} />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent className="max-h-60">
                          {industries.map((ind: any) => (
                            <SelectItem key={ind.id} value={ind.id} className="min-h-[40px] text-sm">
                              {ind.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />

                {/* Category */}
                <FormField
                  control={form.control}
                  name="categoryId"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">Category</FormLabel>
                      <Select
                        value={field.value || undefined}
                        onValueChange={field.onChange}
                        disabled={!selectedIndustryId || loadingCategories || filteredCategories.length === 0}
                      >
                        <FormControl>
                          <SelectTrigger className="h-12 min-h-[48px] text-sm bg-white border-slate-200">
                            <SelectValue
                              placeholder={
                                !selectedIndustryId
                                  ? "Select Industry first"
                                  : loadingCategories
                                  ? "Loading categories..."
                                  : filteredCategories.length === 0
                                  ? "No categories in this industry"
                                  : "Select Category"
                              }
                            />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent className="max-h-60">
                          {filteredCategories.map((cat: any) => (
                            <SelectItem key={cat.id} value={cat.id} className="min-h-[40px] text-sm">
                              {cat.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />
              </div>

              {/* Location: State -> District */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {/* State */}
                <FormField
                  control={form.control}
                  name="stateId"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">State</FormLabel>
                      <Select
                        value={field.value || undefined}
                        onValueChange={(val) => {
                          field.onChange(val);
                          form.setValue("districtId", ""); // Reset dependent district
                        }}
                        disabled={loadingStates}
                      >
                        <FormControl>
                          <SelectTrigger className="h-12 min-h-[48px] text-sm bg-white border-slate-200">
                            <SelectValue placeholder={loadingStates ? "Loading states..." : "Select State"} />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent className="max-h-60">
                          {states.map((st: any) => (
                            <SelectItem key={st.id} value={st.id} className="min-h-[40px] text-sm">
                              {st.name} {st.code ? `(${st.code})` : ""}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />

                {/* District */}
                <FormField
                  control={form.control}
                  name="districtId"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-xs font-semibold text-slate-700">District</FormLabel>
                      <Select
                        value={field.value || undefined}
                        onValueChange={field.onChange}
                        disabled={!selectedStateId || loadingDistricts || filteredDistricts.length === 0}
                      >
                        <FormControl>
                          <SelectTrigger className="h-12 min-h-[48px] text-sm bg-white border-slate-200">
                            <SelectValue
                              placeholder={
                                !selectedStateId
                                  ? "Select State first"
                                  : loadingDistricts
                                  ? "Loading districts..."
                                  : filteredDistricts.length === 0
                                  ? "No districts found for state"
                                  : "Select District"
                              }
                            />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent className="max-h-60">
                          {filteredDistricts.map((dst: any) => (
                            <SelectItem key={dst.id} value={dst.id} className="min-h-[40px] text-sm">
                              {dst.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <FormMessage className="text-xs" />
                    </FormItem>
                  )}
                />
              </div>
            </div>

            {/* Sticky Action Footer */}
            <DialogFooter className="pt-4 border-t border-slate-100 flex flex-col-reverse sm:flex-row sm:justify-end gap-3">
              <Button
                type="button"
                variant="outline"
                onClick={() => setIsOpen(false)}
                disabled={isSubmitting}
                className="h-12 min-h-[48px] px-5 text-sm font-medium border-slate-300 hover:bg-slate-100"
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isSubmitting}
                className="h-12 min-h-[48px] px-6 text-sm font-semibold bg-slate-900 hover:bg-slate-800 text-white shadow-md flex items-center justify-center gap-2 min-w-[210px] cursor-pointer"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin text-white" />
                    <span>Provisioning Account...</span>
                  </>
                ) : (
                  <>
                    <UserCheck className="w-4 h-4 text-emerald-400" />
                    <span>Complete Provisioning</span>
                  </>
                )}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
