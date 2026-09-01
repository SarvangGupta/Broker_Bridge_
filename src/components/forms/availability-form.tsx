"use client"

import { useState, useEffect } from "react"
import { useForm } from "react-hook-form"
import { useSearchParams, useRouter } from "next/navigation"
import { zodResolver } from "@hookform/resolvers/zod"
import { Loader2, Check, ChevronsUpDown, CalendarIcon, Lock, Info } from "lucide-react"
import { toast } from "sonner"
import { cn } from "@/lib/utils"
import { format } from "date-fns"

import { Button, buttonVariants } from "@/components/ui/button"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command"
import { Calendar } from "@/components/ui/calendar"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

import { availabilitySchema, AvailabilitySchema } from "@/src/types/availability-schema"
import { createAvailabilityAction, getAvailabilityForRenewalAction, updateAvailabilityAction, getAvailabilityForEditAction } from "@/src/server/actions/availability-actions"
import { getActiveBrokersAction } from "@/src/server/actions/admin-actions"
import {
  useIndustries,
  useCategories,
  useCommodities,
  useGrades,
  useUnits,
  useStates,
  useDistricts
} from "@/src/hooks/use-master-data"

export function AvailabilityForm({ onSuccess }: { onSuccess?: () => void } = {}) {
  const [isSubmitting, setIsSubmitting] = useState(false)

  const [selectedIndustryId, setSelectedIndustryId] = useState<string>("")
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>("")

  const [openCommodity, setOpenCommodity] = useState(false)
  const [openGrade, setOpenGrade] = useState(false)
  const [openUnit, setOpenUnit] = useState(false)
  const [openState, setOpenState] = useState(false)
  const [openDistrict, setOpenDistrict] = useState(false)

  const { data: industries = [], isLoading: loadingIndustries } = useIndustries()
  const { data: categories = [], isLoading: loadingCategories } = useCategories()
  const { data: commodities = [], isLoading: loadingCommodities } = useCommodities(selectedCategoryId || undefined)
  const { data: grades = [], isLoading: loadingGrades } = useGrades()
  const { data: units = [], isLoading: loadingUnits } = useUnits()
  const { data: states = [], isLoading: loadingStates } = useStates()
  const { data: districts = [], isLoading: loadingDistricts } = useDistricts()

  const [brokers, setBrokers] = useState<any[]>([])
  const [loadingBrokers, setLoadingBrokers] = useState(false)

  useEffect(() => {
    async function fetchBrokers() {
      setLoadingBrokers(true)
      const res = await getActiveBrokersAction()
      if (res.success && res.data) {
        setBrokers(res.data)
      }
      setLoadingBrokers(false)
    }
    fetchBrokers()
  }, [])

  const form = useForm<AvailabilitySchema>({
    resolver: zodResolver(availabilitySchema) as any,
    defaultValues: {
      commodity_id: "",
      grade_id: "",
      lot_number: "",
      total_quantity: 0,
      minimum_order_quantity: undefined,
      unit_id: "",
      asking_price: 0,
      confidential_minimum_price: undefined,
      state_id: "",
      district_id: "",
      city_id: "",
      warehouse_name: "",
      available_from: new Date(),
      valid_until: undefined,
      visibility: "global",
      broker_id: "",
      version: 1,
    },
  })

  const searchParams = useSearchParams()
  const router = useRouter()
  const renewId = searchParams.get("renew")
  const editId = searchParams.get("edit")
  const [isRenewing, setIsRenewing] = useState(false)

  useEffect(() => {
    if (!renewId && !editId) return
    setIsRenewing(true)
    async function fetchData() {
      if (renewId) {
        const res = await getAvailabilityForRenewalAction(renewId)
        if (res.success && res.data) {
          const d = res.data
          setSelectedIndustryId(d.industryId || "")
          setSelectedCategoryId(d.categoryId || "")
          form.reset({
            commodity_id: d.commodityId,
            grade_id: d.gradeId,
            lot_number: d.lotNumber || "",
            total_quantity: Number(d.totalQuantity),
            minimum_order_quantity: d.minimumOrderQuantity ? Number(d.minimumOrderQuantity) : undefined,
            unit_id: d.unitId,
            asking_price: Number(d.askingPrice),
            confidential_minimum_price: d.confidentialMinimumPrice ? Number(d.confidentialMinimumPrice) : undefined,
            state_id: d.stateId,
            district_id: d.districtId,
            city_id: "",
            warehouse_name: "",
            available_from: new Date(),
            valid_until: undefined,
            visibility: d.visibility as "global" | "restricted",
            broker_id: d.brokerId || "",
            version: 1,
          })
          toast.info("Quick Renew: Review your asking price and set a new expiry date.", { id: "renew-toast" })
        } else {
          toast.error(res.error || "Failed to load renew data")
          router.replace('/seller')
        }
      } else if (editId) {
        const res = await getAvailabilityForEditAction(editId)
        if (res.success && res.data) {
          const d = res.data
          setSelectedIndustryId(d.industryId || "")
          setSelectedCategoryId(d.categoryId || "")
          form.reset({
            id: d.id,
            commodity_id: d.commodityId,
            grade_id: d.gradeId,
            lot_number: d.lotNumber || "",
            total_quantity: Number(d.totalQuantity),
            minimum_order_quantity: d.minimumOrderQuantity ? Number(d.minimumOrderQuantity) : undefined,
            unit_id: d.unitId,
            asking_price: Number(d.askingPrice),
            confidential_minimum_price: d.confidentialMinimumPrice ? Number(d.confidentialMinimumPrice) : undefined,
            state_id: d.stateId,
            district_id: d.districtId,
            city_id: "", 
            warehouse_name: "", 
            available_from: new Date(d.availableFrom || new Date()),
            valid_until: new Date(d.validUntil),
            visibility: d.visibility as "global" | "restricted",
            broker_id: d.brokerId || "",
            version: d.version,
          })
        } else {
          toast.error(res.error || "Failed to load edit data")
          router.replace('/seller')
        }
      }
      setIsRenewing(false)
    }
    fetchData()
  }, [renewId, editId, form, router])

  const isQuickRenew = !!renewId
  const selectedCommodityId = form.watch("commodity_id")
  const visibility = form.watch("visibility")
  const selectedStateId = form.watch("state_id")

  const filteredCategories = selectedIndustryId
    ? categories.filter((c: any) => c.industryId === selectedIndustryId)
    : []

  const filteredCommodities = selectedCategoryId
    ? commodities.filter((c: any) => c.categoryId === selectedCategoryId)
    : []

  const filteredGrades = grades.filter((g: any) => g.commodityId === selectedCommodityId)
  const filteredDistricts = districts.filter((d: any) => d.stateId === selectedStateId)

  async function onSubmit(data: AvailabilitySchema) {
    setIsSubmitting(true)
    try {
      const result = data.id
        ? await updateAvailabilityAction(data)
        : await createAvailabilityAction(data)

      if (result.success) {
        toast.success(data.id ? "Availability updated successfully!" : "Availability posted successfully!")
        form.reset({
          commodity_id: "",
          grade_id: "",
          lot_number: "",
          total_quantity: 0,
          minimum_order_quantity: undefined,
          unit_id: "",
          asking_price: 0,
          confidential_minimum_price: undefined,
          state_id: "",
          district_id: "",
          city_id: "",
          warehouse_name: "",
          available_from: new Date(),
          valid_until: undefined,
          visibility: "global",
          broker_id: "",
          version: 1,
        })
        setSelectedIndustryId("")
        setSelectedCategoryId("")
        onSuccess?.()
        router.push("/seller")
      } else {
        if (result.error && result.error.includes("Stale data")) {
          toast.error("Stale data detected. This inventory was modified by another user or deal. Please refresh to see the latest quantities.", { duration: 8000 })
        } else {
          toast.error(result.error || "Failed to post availability.")
        }
      }
    } catch (error: any) {
      if (error.message && error.message.includes("Stale data")) {
        toast.error("Stale data detected. This inventory was modified by another user or deal. Please refresh to see the latest quantities.", { duration: 8000 })
      } else {
        toast.error("An unexpected error occurred.")
      }
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
        <input type="hidden" {...form.register("version", { valueAsNumber: true })} />
        <input type="hidden" {...form.register("id")} />

        {/* SECTION 1: Product Details */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg text-slate-800">1. Product Details</CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Industry Select */}
              <div className="flex flex-col space-y-2">
                <label className="text-sm font-medium leading-none text-slate-800">
                  Industry
                </label>
                <Select
                  disabled={isQuickRenew}
                  value={selectedIndustryId}
                  onValueChange={(val) => {
                    setSelectedIndustryId(val || "")
                    setSelectedCategoryId("")
                    form.setValue("commodity_id", "")
                    form.setValue("grade_id", "")
                  }}
                >
                  <SelectTrigger className="w-full min-h-[48px] bg-white">
                    <SelectValue placeholder={loadingIndustries ? "Loading..." : "Select industry"}>
                      {selectedIndustryId ? industries.find((ind: any) => ind.id === selectedIndustryId)?.name : null}
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent alignItemWithTrigger={false}>
                    {industries.map((ind: any) => (
                      <SelectItem key={ind.id} value={ind.id} className="min-h-[48px]">
                        {ind.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* Category Select */}
              <div className="flex flex-col space-y-2">
                <label className="text-sm font-medium leading-none text-slate-800">
                  Category
                </label>
                <Select
                  disabled={isQuickRenew || !selectedIndustryId || loadingCategories}
                  value={selectedCategoryId}
                  onValueChange={(val) => {
                    setSelectedCategoryId(val || "")
                    form.setValue("commodity_id", "")
                    form.setValue("grade_id", "")
                  }}
                >
                  <SelectTrigger className="w-full min-h-[48px] bg-white">
                    <SelectValue
                      placeholder={
                        !selectedIndustryId
                          ? "Select industry first"
                          : loadingCategories
                            ? "Loading..."
                            : "Select category"
                      }
                    >
                      {selectedCategoryId ? filteredCategories.find((cat: any) => cat.id === selectedCategoryId)?.name : null}
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent alignItemWithTrigger={false}>
                    {filteredCategories.map((cat: any) => (
                      <SelectItem key={cat.id} value={cat.id} className="min-h-[48px]">
                        {cat.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <FormField
                control={form.control}
                name="commodity_id"
                render={({ field }) => (
                  <FormItem className="flex flex-col">
                    <FormLabel>Commodity</FormLabel>
                    <Popover open={openCommodity} onOpenChange={setOpenCommodity}>
                      <FormControl>
                        <PopoverTrigger
                          disabled={isQuickRenew || !selectedCategoryId || loadingCommodities}
                          className={cn(
                            buttonVariants({ variant: "outline" }),
                            "w-full min-h-[48px] justify-between font-normal",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value
                            ? filteredCommodities.find((c: any) => c.id === field.value)?.name || commodities.find((c: any) => c.id === field.value)?.name
                            : !selectedCategoryId
                              ? "Select category first"
                              : loadingCommodities
                                ? "Loading..."
                                : "Select commodity"}
                          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                        </PopoverTrigger>
                      </FormControl>
                      <PopoverContent className="w-[300px] p-0" align="start">
                        <Command>
                          <CommandInput placeholder="Search commodity..." className="min-h-[48px]" />
                          <CommandList>
                            <CommandEmpty>No commodity found.</CommandEmpty>
                            <CommandGroup>
                              {filteredCommodities.map((commodity: any) => (
                                <CommandItem
                                  key={commodity.id}
                                  value={commodity.name}
                                  onSelect={() => {
                                    form.setValue("commodity_id", commodity.id)
                                    form.setValue("grade_id", "")
                                    setOpenCommodity(false)
                                  }}
                                  className="min-h-[48px]"
                                >
                                  <Check
                                    className={cn(
                                      "mr-2 h-4 w-4",
                                      commodity.id === field.value ? "opacity-100" : "opacity-0"
                                    )}
                                  />
                                  {commodity.name}
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
                name="grade_id"
                render={({ field }) => (
                  <FormItem className="flex flex-col">
                    <FormLabel>Quality Parameter</FormLabel>
                    <Popover open={openGrade} onOpenChange={setOpenGrade}>
                      <FormControl>
                        <PopoverTrigger
                          disabled={isQuickRenew || !selectedCommodityId || loadingGrades}
                          className={cn(
                            buttonVariants({ variant: "outline" }),
                            "w-full min-h-[48px] justify-between font-normal",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value
                            ? filteredGrades.find((g: any) => g.id === field.value)?.gradeName
                            : !selectedCommodityId
                              ? "Select commodity first"
                              : "Select quality parameter"}
                          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                        </PopoverTrigger>
                      </FormControl>
                      <PopoverContent className="w-[300px] p-0" align="start">
                        <Command>
                          <CommandInput placeholder="Search quality parameter..." className="min-h-[48px]" />
                          <CommandList>
                            <CommandEmpty>No quality parameter found.</CommandEmpty>
                            <CommandGroup>
                              {filteredGrades.map((grade: any) => (
                                <CommandItem
                                  key={grade.id}
                                  value={grade.gradeName}
                                  onSelect={() => {
                                    form.setValue("grade_id", grade.id)
                                    setOpenGrade(false)
                                  }}
                                  className="min-h-[48px]"
                                >
                                  <Check
                                    className={cn(
                                      "mr-2 h-4 w-4",
                                      grade.id === field.value ? "opacity-100" : "opacity-0"
                                    )}
                                  />
                                  {grade.gradeName}
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

            <FormField
              control={form.control}
              name="lot_number"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Lot / Batch Number (Optional)</FormLabel>
                  <FormControl>
                    <Input
                      placeholder="e.g. BATCH-2024-001"
                      className="min-h-[48px]"
                      {...field}
                      value={field.value || ""}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* SECTION 2: Quantity & Location */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg text-slate-800">2. Quantity & Location</CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <FormField
                control={form.control}
                name="total_quantity"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Total Quantity</FormLabel>
                    <FormControl>
                      <Input
                        type="number"
                        inputMode="decimal"
                        placeholder="Total available quantity"
                        className="min-h-[48px]"
                        {...field}
                        onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)}
                        value={field.value || ""}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="minimum_order_quantity"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Minimum Order Quantity (Optional)</FormLabel>
                    <FormControl>
                      <Input
                        type="number"
                        inputMode="decimal"
                        placeholder="MOQ (optional)"
                        className="min-h-[48px]"
                        {...field}
                        onChange={(e) => field.onChange(e.target.value ? parseFloat(e.target.value) : undefined)}
                        value={field.value || ""}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="unit_id"
                render={({ field }) => (
                  <FormItem className="flex flex-col">
                    <FormLabel>Unit of Measurement</FormLabel>
                    <Popover open={openUnit} onOpenChange={setOpenUnit}>
                      <FormControl>
                        <PopoverTrigger
                          className={cn(
                            buttonVariants({ variant: "outline" }),
                            "w-full min-h-[48px] justify-between font-normal",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value
                            ? (() => {
                              const u = units.find((u: any) => u.id === field.value);
                              return u ? `${u.symbol} - ${u.name}` : "Select unit";
                            })()
                            : loadingUnits ? "Loading..." : "Select unit"}
                          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                        </PopoverTrigger>
                      </FormControl>
                      <PopoverContent className="w-[300px] p-0" align="start">
                        <Command>
                          <CommandInput placeholder="Search unit..." className="min-h-[48px]" />
                          <CommandList>
                            <CommandEmpty>No unit found.</CommandEmpty>
                            <CommandGroup>
                              {units.map((u: any) => (
                                <CommandItem
                                  key={u.id}
                                  value={`${u.symbol} ${u.name}`}
                                  onSelect={() => {
                                    form.setValue("unit_id", u.id)
                                    setOpenUnit(false)
                                  }}
                                  className="min-h-[48px]"
                                >
                                  <Check
                                    className={cn(
                                      "mr-2 h-4 w-4",
                                      u.id === field.value ? "opacity-100" : "opacity-0"
                                    )}
                                  />
                                  {u.symbol} - {u.name}
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

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-4 border-t">
              <FormField
                control={form.control}
                name="state_id"
                render={({ field }) => (
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
                          <CommandInput placeholder="Search state..." className="min-h-[48px]" />
                          <CommandList>
                            <CommandEmpty>No state found.</CommandEmpty>
                            <CommandGroup>
                              {states.map((state: any) => (
                                <CommandItem
                                  key={state.id}
                                  value={state.name}
                                  onSelect={() => {
                                    form.setValue("state_id", state.id)
                                    form.setValue("district_id", "")
                                    setOpenState(false)
                                  }}
                                  className="min-h-[48px]"
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
                render={({ field }) => (
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
                          <CommandInput placeholder="Search district..." className="min-h-[48px]" />
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
                                  className="min-h-[48px]"
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

              <FormField
                control={form.control}
                name="city_id"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>City</FormLabel>
                    <FormControl>
                      <Input
                        placeholder="Enter city"
                        className="min-h-[48px]"
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
                name="warehouse_name"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Warehouse Name (Optional)</FormLabel>
                    <FormControl>
                      <Input
                        placeholder="e.g. Central Hub"
                        className="min-h-[48px]"
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

        {/* SECTION 3: Commercial Terms */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg text-slate-800">3. Commercial Terms</CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <FormField
                control={form.control}
                name="asking_price"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="flex items-center space-x-1.5">
                      <span>Asking Price (per unit)</span>
                      {isRenewing && (
                        <div className="flex items-center text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded text-xs">
                          <Info className="w-3.5 h-3.5 mr-1" />
                          Review for new listing
                        </div>
                      )}
                    </FormLabel>
                    <FormControl>
                      <Input
                        type="number"
                        inputMode="decimal"
                        placeholder="Enter asking price"
                        className={cn("min-h-[48px]", isRenewing && "border-amber-400 ring-2 ring-amber-400/20")}
                        {...field}
                        onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)}
                        value={field.value || ""}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="confidential_minimum_price"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel className="flex items-center space-x-1.5">
                      <span>Confidential Minimum Price</span>
                      <Lock className="w-3.5 h-3.5 text-muted-foreground" />
                      <span className="text-[10px] text-muted-foreground font-normal tracking-tight uppercase px-1.5 py-0.5 bg-slate-100 rounded">Hidden</span>
                    </FormLabel>
                    <FormControl>
                      <Input
                        type="number"
                        inputMode="decimal"
                        placeholder="Lowest acceptable price (optional)"
                        className="min-h-[48px]"
                        {...field}
                        onChange={(e) => field.onChange(e.target.value ? parseFloat(e.target.value) : undefined)}
                        value={field.value || ""}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="available_from"
                render={({ field }) => (
                  <FormItem className="flex flex-col">
                    <FormLabel>Available From</FormLabel>
                    <Popover>
                      <FormControl>
                        <PopoverTrigger
                          className={cn(
                            buttonVariants({ variant: "outline" }),
                            "w-full min-h-[48px] pl-3 text-left font-normal flex items-center justify-between",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value ? (
                            format(field.value, "PPP")
                          ) : (
                            <span>Pick a date</span>
                          )}
                          <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                        </PopoverTrigger>
                      </FormControl>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={field.value}
                          onSelect={field.onChange}
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
                    <FormLabel>Valid Until</FormLabel>
                    <Popover>
                      <FormControl>
                        <PopoverTrigger
                          className={cn(
                            buttonVariants({ variant: "outline" }),
                            "w-full min-h-[48px] pl-3 text-left font-normal flex items-center justify-between",
                            !field.value && "text-muted-foreground"
                          )}
                        >
                          {field.value ? (
                            format(field.value, "PPP")
                          ) : (
                            <span>Pick a date</span>
                          )}
                          <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                        </PopoverTrigger>
                      </FormControl>
                      <PopoverContent className="w-auto p-0" align="start">
                        <Calendar
                          mode="single"
                          selected={field.value}
                          onSelect={field.onChange}
                          disabled={(date: Date) => date <= form.watch("available_from")}
                        />
                      </PopoverContent>
                    </Popover>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <FormField
              control={form.control}
              name="visibility"
              render={({ field }) => (
                <FormItem className="space-y-3 pt-4 border-t">
                  <FormLabel>Search Visibility</FormLabel>
                  <FormControl>
                    <RadioGroup
                      onValueChange={field.onChange}
                      value={field.value}
                      className="flex flex-col space-y-2"
                    >
                      <FormItem className="flex items-center space-x-3 space-y-0 rounded-md border p-4 bg-slate-50/50">
                        <FormControl>
                          <RadioGroupItem value="global" className="h-5 w-5" />
                        </FormControl>
                        <div className="space-y-1 leading-none">
                          <FormLabel className="font-normal cursor-pointer text-sm">
                            <span className="font-medium text-slate-800">Global Pool</span> (Allow any broker on the platform to match this deal)
                          </FormLabel>
                        </div>
                      </FormItem>
                      <FormItem className="flex items-center space-x-3 space-y-0 rounded-md border p-4 bg-slate-50/50">
                        <FormControl>
                          <RadioGroupItem value="restricted" className="h-5 w-5" />
                        </FormControl>
                        <div className="space-y-1 leading-none">
                          <FormLabel className="font-normal cursor-pointer text-sm">
                            <span className="font-medium text-slate-800">Private Network</span> (Only allow my Preferred Broker to see and match this)
                          </FormLabel>
                        </div>
                      </FormItem>
                    </RadioGroup>
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="broker_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>
                    Preferred Broker {visibility === 'restricted' ? <span className="text-destructive">*</span> : "(Optional)"}
                  </FormLabel>
                  <Select onValueChange={(val) => field.onChange(val === 'none' ? '' : val)} value={field.value || 'none'}>
                    <FormControl>
                      <SelectTrigger className="min-h-[48px] w-full">
                        <SelectValue placeholder={loadingBrokers ? "Loading brokers..." : "Select a preferred broker"}>
                          {field.value && field.value !== 'none'
                            ? brokers.find((b) => b.id === field.value)?.name || brokers.find((b) => b.id === field.value)?.mobile
                            : field.value === 'none' ? "None (Auto-assign via Deal Desk)" : undefined}
                        </SelectValue>
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent alignItemWithTrigger={false}>
                      <SelectItem value="none" className="min-h-[48px]">None (Auto-assign via Deal Desk)</SelectItem>
                      {brokers.map((broker) => (
                        <SelectItem key={broker.id} value={broker.id} className="min-h-[48px]">
                          {broker.name || broker.mobile}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

          </CardContent>
        </Card>

        <Button type="submit" className="w-full min-h-[48px] text-lg font-medium" disabled={isSubmitting}>
          {isSubmitting ? (
            <>
              <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              Posting...
            </>
          ) : (
            "Post Availability"
          )}
        </Button>
      </form>
    </Form>
  )
}
