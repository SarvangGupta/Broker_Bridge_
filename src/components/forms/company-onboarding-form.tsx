'use client'

import { useState } from "react"
import { useRouter } from "next/navigation"
import { zodResolver } from "@hookform/resolvers/zod"
import { useForm } from "react-hook-form"
import { Loader2, Check, ChevronsUpDown, ArrowRight } from "lucide-react"
import { toast } from "sonner"
import { cn } from "@/lib/utils"

import { Button } from "@/components/ui/button"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command"

import { companyOnboardingSchema, CompanyOnboardingFormValues } from "@/src/types/company-schema"
import { createCompanyProfile } from "@/src/server/actions/company-actions"
import { useStates, useDistricts } from "@/src/hooks/use-master-data"

export function CompanyOnboardingForm() {
  const router = useRouter()
  const [isSubmitting, setIsSubmitting] = useState(false)
  
  // Popover states for comboboxes
  const [openState, setOpenState] = useState(false)
  const [openDistrict, setOpenDistrict] = useState(false)
  
  // Master data queries
  const { data: states = [], isLoading: loadingStates } = useStates()
  const { data: districts = [], isLoading: loadingDistricts } = useDistricts()
  
  // Business types
  const businessTypes = [
    { id: "1", name: "Proprietorship" },
    { id: "2", name: "Partnership" },
    { id: "3", name: "Private Limited" },
    { id: "4", name: "Public Limited" }
  ]

  const form = useForm<CompanyOnboardingFormValues>({
    resolver: zodResolver(companyOnboardingSchema),
    defaultValues: {
      name: "",
      gst: "",
      business_type_id: "",
      state_id: "",
      district_id: "",
      mobile: "",
    },
  })

  // Watch state to filter districts
  const selectedStateId = form.watch("state_id")
  const filteredDistricts = districts.filter((d: any) => d.stateId === selectedStateId)

  async function onSubmit(data: CompanyOnboardingFormValues) {
    setIsSubmitting(true)
    try {
      const result = await createCompanyProfile(data)
      
      if (result.success) {
        toast.success("Company profile submitted! Verification in progress.")
        window.location.reload()
      } else {
        toast.error(result.error || "Failed to create company profile.")
      }
    } catch (error) {
      toast.error("An unexpected error occurred.")
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-5">
        <FormField
          control={form.control}
          name="name"
          render={({ field }: { field: any }) => (
            <FormItem className="space-y-1.5">
              <FormLabel className="text-sm font-semibold text-slate-800">Company Name</FormLabel>
              <FormControl>
                <Input 
                  placeholder="Enter registered company name" 
                  className="h-12 rounded-xl bg-white border-slate-200 hover:border-slate-300 focus:bg-white focus:border-slate-900 focus:ring-4 focus:ring-slate-100 text-sm font-medium text-slate-900 placeholder:text-slate-400 shadow-xs transition-all" 
                  {...field} 
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="gst"
          render={({ field }: { field: any }) => (
            <FormItem className="space-y-1.5">
              <div className="flex items-center justify-between">
                <FormLabel className="text-sm font-semibold text-slate-800">GST Number</FormLabel>
                <span className="text-[11px] font-medium text-slate-400 bg-slate-100 px-2 py-0.5 rounded-md">Optional</span>
              </div>
              <FormControl>
                <Input 
                  placeholder="e.g. 22AAAAA0000A1Z5" 
                  className="h-12 rounded-xl bg-white border-slate-200 hover:border-slate-300 focus:bg-white focus:border-slate-900 focus:ring-4 focus:ring-slate-100 text-sm font-medium text-slate-900 placeholder:text-slate-400 uppercase tracking-wide shadow-xs transition-all" 
                  {...field} 
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="mobile"
          render={({ field }: { field: any }) => (
            <FormItem className="space-y-1.5">
              <FormLabel className="text-sm font-semibold text-slate-800">WhatsApp / Mobile Number</FormLabel>
              <FormControl>
                <Input 
                  type="tel" 
                  inputMode="numeric" 
                  maxLength={10} 
                  placeholder="e.g. 9876543210" 
                  className="h-12 rounded-xl bg-white border-slate-200 hover:border-slate-300 focus:bg-white focus:border-slate-900 focus:ring-4 focus:ring-slate-100 text-sm font-medium text-slate-900 placeholder:text-slate-400 shadow-xs transition-all" 
                  {...field}
                  onChange={(e) => {
                    const value = e.target.value.replace(/\D/g, "").slice(0, 10)
                    field.onChange(value)
                  }}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="business_type_id"
          render={({ field }: { field: any }) => (
            <FormItem className="space-y-1.5">
              <FormLabel className="text-sm font-semibold text-slate-800">Business Type</FormLabel>
              <Select onValueChange={field.onChange} value={field.value}>
                <FormControl>
                  <SelectTrigger className="h-12 w-full rounded-xl bg-white border-slate-200 hover:border-slate-300 hover:bg-slate-50/50 focus:bg-white focus:border-slate-900 focus:ring-4 focus:ring-slate-100 text-sm font-medium text-slate-900 shadow-xs transition-all cursor-pointer">
                    <SelectValue placeholder="Select business type">
                      {field.value ? businessTypes.find(bt => bt.id === field.value)?.name : "Select business type"}
                    </SelectValue>
                  </SelectTrigger>
                </FormControl>
                <SelectContent className="rounded-xl border-slate-200 shadow-lg bg-white">
                  {businessTypes.map((bt) => (
                    <SelectItem key={bt.id} value={bt.id} className="cursor-pointer rounded-lg text-sm font-medium">{bt.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
          <FormField
            control={form.control}
            name="state_id"
            render={({ field }: { field: any }) => (
              <FormItem className="flex flex-col space-y-1.5">
                <FormLabel className="text-sm font-semibold text-slate-800">State</FormLabel>
                <Popover open={openState} onOpenChange={setOpenState}>
                  <FormControl>
                    <PopoverTrigger
                      className={cn(
                        "flex h-12 w-full items-center justify-between rounded-xl bg-white border border-slate-200 px-3.5 py-2 text-sm font-medium shadow-xs hover:bg-slate-50/50 hover:border-slate-300 focus:outline-hidden focus:ring-4 focus:ring-slate-100 focus:border-slate-900 transition-all cursor-pointer",
                        !field.value ? "text-slate-400" : "text-slate-900"
                      )}
                    >
                      <span className="truncate">
                        {field.value
                          ? states.find((s: any) => s.id === field.value)?.name
                          : loadingStates ? "Loading states..." : "Select state"}
                      </span>
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 text-slate-400" />
                    </PopoverTrigger>
                  </FormControl>
                  <PopoverContent className="w-[--radix-popover-trigger-width] min-w-[240px] p-0 rounded-xl shadow-xl border-slate-200 bg-white" align="start">
                    <Command className="rounded-xl">
                      <CommandInput placeholder="Search state..." className="h-10 text-sm" />
                      <CommandList className="max-h-60 p-1">
                        <CommandEmpty className="p-3 text-xs text-slate-500">No state found.</CommandEmpty>
                        <CommandGroup>
                          {states.map((state: any) => (
                            <CommandItem
                              key={state.id}
                              value={state.name}
                              className="rounded-lg text-sm font-medium cursor-pointer"
                              onSelect={() => {
                                form.setValue("state_id", state.id)
                                form.setValue("district_id", "")
                                setOpenState(false)
                              }}
                            >
                              <Check
                                className={cn(
                                  "mr-2 h-4 w-4 text-slate-900",
                                  state.id === field.value ? "opacity-100" : "opacity-0"
                                )}
                              />
                              {state.name}
                            </CommandItem>
                          ))}
                        </CommandGroup>
                      </CommandList>
                    </Command>
                  </PopoverContent>
                </Popover>
                <FormMessage />
              </FormItem>
            )}
          />

          <FormField
            control={form.control}
            name="district_id"
            render={({ field }: { field: any }) => (
              <FormItem className="flex flex-col space-y-1.5">
                <FormLabel className="text-sm font-semibold text-slate-800">District</FormLabel>
                <Popover open={openDistrict} onOpenChange={setOpenDistrict}>
                  <FormControl>
                    <PopoverTrigger
                      disabled={!selectedStateId || loadingDistricts}
                      className={cn(
                        "flex h-12 w-full items-center justify-between rounded-xl bg-white border border-slate-200 px-3.5 py-2 text-sm font-medium shadow-xs hover:bg-slate-50/50 hover:border-slate-300 focus:outline-hidden focus:ring-4 focus:ring-slate-100 focus:border-slate-900 transition-all cursor-pointer disabled:opacity-50 disabled:bg-slate-100 disabled:cursor-not-allowed",
                        !field.value ? "text-slate-400" : "text-slate-900"
                      )}
                    >
                      <span className="truncate">
                        {field.value
                          ? filteredDistricts.find((d: any) => d.id === field.value)?.name
                          : "Select district"}
                      </span>
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 text-slate-400" />
                    </PopoverTrigger>
                  </FormControl>
                  <PopoverContent className="w-[--radix-popover-trigger-width] min-w-[240px] p-0 rounded-xl shadow-xl border-slate-200 bg-white" align="end">
                    <Command className="rounded-xl">
                      <CommandInput placeholder="Search district..." className="h-10 text-sm" />
                      <CommandList className="max-h-60 p-1">
                        <CommandEmpty className="p-3 text-xs text-slate-500">No district found.</CommandEmpty>
                        <CommandGroup>
                          {filteredDistricts.map((district: any) => (
                            <CommandItem
                              key={district.id}
                              value={district.name}
                              className="rounded-lg text-sm font-medium cursor-pointer"
                              onSelect={() => {
                                form.setValue("district_id", district.id)
                                setOpenDistrict(false)
                              }}
                            >
                              <Check
                                className={cn(
                                  "mr-2 h-4 w-4 text-slate-900",
                                  district.id === field.value ? "opacity-100" : "opacity-0"
                                )}
                              />
                              {district.name}
                            </CommandItem>
                          ))}
                        </CommandGroup>
                      </CommandList>
                    </Command>
                  </PopoverContent>
                </Popover>
                <FormMessage />
              </FormItem>
            )}
          />
        </div>

        <Button 
          type="submit" 
          className="w-full h-13 rounded-xl bg-slate-900 hover:bg-slate-800 text-white font-semibold text-base shadow-sm hover:shadow-md transition-all active:scale-[0.99] flex items-center justify-center gap-2 cursor-pointer mt-3" 
          disabled={isSubmitting}
        >
          {isSubmitting ? (
            <>
              <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              Saving Profile...
            </>
          ) : (
            <>
              Complete Onboarding
              <ArrowRight className="ml-1 h-5 w-5" />
            </>
          )}
        </Button>
      </form>
    </Form>
  )
}
