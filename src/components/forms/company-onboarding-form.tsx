'use client'

import { useState } from "react"
import { useRouter } from "next/navigation"
import { zodResolver } from "@hookform/resolvers/zod"
import { useForm } from "react-hook-form"
import { Loader2, Check, ChevronsUpDown } from "lucide-react"
import { toast } from "sonner"
import { cn } from "@/lib/utils"

import { Button, buttonVariants } from "@/components/ui/button"
import {
  Form,
  FormControl,
  FormDescription,
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
  
  // Using static list as business type hooks weren't requested in the sprint, 
  // but they are required by the schema.
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
        toast.success("Company profile created successfully!")
        router.refresh() // Refresh to update layout guards
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
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
        <FormField
          control={form.control}
          name="name"
          render={({ field }: { field: any }) => (
            <FormItem>
              <FormLabel>Company Name</FormLabel>
              <FormControl>
                <Input placeholder="Enter company name" className="min-h-[48px]" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="gst"
          render={({ field }: { field: any }) => (
            <FormItem>
              <FormLabel>GST Number (Optional)</FormLabel>
              <FormControl>
                <Input placeholder="e.g. 22AAAAA0000A1Z5" className="min-h-[48px]" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="mobile"
          render={({ field }: { field: any }) => (
            <FormItem>
              <FormLabel>WhatsApp / Mobile Number</FormLabel>
              <FormControl>
                <Input type="tel" inputMode="tel" placeholder="e.g. 9876543210" className="min-h-[48px]" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="business_type_id"
          render={({ field }: { field: any }) => (
            <FormItem>
              <FormLabel>Business Type</FormLabel>
              <Select onValueChange={field.onChange} value={field.value}>
                <FormControl>
                  <SelectTrigger className="min-h-[48px]">
                    <SelectValue placeholder="Select business type">
                      {field.value ? businessTypes.find(bt => bt.id === field.value)?.name : "Select business type"}
                    </SelectValue>
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  {businessTypes.map((bt) => (
                    <SelectItem key={bt.id} value={bt.id}>{bt.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <FormField
            control={form.control}
            name="state_id"
            render={({ field }: { field: any }) => (
              <FormItem className="flex flex-col">
                <FormLabel>State</FormLabel>
                <Popover open={openState} onOpenChange={setOpenState}>
                  <FormControl>
                    <PopoverTrigger
                      className={cn(
                        buttonVariants({ variant: "outline" }),
                        "w-full min-h-[48px] justify-between font-normal",
                        !field.value && "text-muted-foreground"
                      )}
                    >
                      {field.value
                        ? states.find((s: any) => s.id === field.value)?.name
                        : loadingStates ? "Loading..." : "Select state"}
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                    </PopoverTrigger>
                  </FormControl>
                  <PopoverContent className="w-[300px] p-0" align="start">
                    <Command>
                      <CommandInput placeholder="Search state..." />
                      <CommandList>
                        <CommandEmpty>No state found.</CommandEmpty>
                        <CommandGroup>
                          {states.map((state: any) => (
                            <CommandItem
                              key={state.id}
                              value={state.name}
                              onSelect={() => {
                                form.setValue("state_id", state.id)
                                // Reset district when state changes
                                form.setValue("district_id", "")
                                setOpenState(false)
                              }}
                            >
                              <Check
                                className={cn(
                                  "mr-2 h-4 w-4",
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
              <FormItem className="flex flex-col">
                <FormLabel>District</FormLabel>
                <Popover open={openDistrict} onOpenChange={setOpenDistrict}>
                  <FormControl>
                    <PopoverTrigger
                      disabled={!selectedStateId || loadingDistricts}
                      className={cn(
                        buttonVariants({ variant: "outline" }),
                        "w-full min-h-[48px] justify-between font-normal",
                        !field.value && "text-muted-foreground"
                      )}
                    >
                      {field.value
                        ? filteredDistricts.find((d: any) => d.id === field.value)?.name
                        : "Select district"}
                      <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                    </PopoverTrigger>
                  </FormControl>
                  <PopoverContent className="w-[300px] p-0" align="start">
                    <Command>
                      <CommandInput placeholder="Search district..." />
                      <CommandList>
                        <CommandEmpty>No district found.</CommandEmpty>
                        <CommandGroup>
                          {filteredDistricts.map((district: any) => (
                            <CommandItem
                              key={district.id}
                              value={district.name}
                              onSelect={() => {
                                form.setValue("district_id", district.id)
                                setOpenDistrict(false)
                              }}
                            >
                              <Check
                                className={cn(
                                  "mr-2 h-4 w-4",
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

        <Button type="submit" className="w-full min-h-[48px] text-lg" disabled={isSubmitting}>
          {isSubmitting ? (
            <>
              <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              Saving Profile...
            </>
          ) : (
            "Complete Onboarding"
          )}
        </Button>
      </form>
    </Form>
  )
}
