"use client"

import { useState, useEffect } from "react"
import { useForm } from "react-hook-form"
import { useSearchParams, useRouter } from "next/navigation"
import { zodResolver } from "@hookform/resolvers/zod"
import { Loader2, Check, ChevronsUpDown, CalendarIcon, Lock, Info, ChevronDown } from "lucide-react"
import { toast } from "sonner"
import { cn } from "@/lib/utils"
import { format } from "date-fns"

import { Button, buttonVariants } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
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
  saveAvailabilityQualityValuesAction,
  getAvailabilityQualityValuesAction,
} from "@/src/server/actions/quality-actions"
import {
  validateQualityEntries,
  QualityTemplateParameter,
} from "@/src/types/quality-schema"
import { DynamicQualityFields } from "@/src/components/forms/dynamic-quality-fields"
import {
  useIndustries,
  useCategories,
  useCommodities,
  useUnits,
  useStates,
  useDistricts
} from "@/src/hooks/use-master-data"

export function AvailabilityForm({ onSuccess }: { onSuccess?: () => void } = {}) {
  const [isSubmitting, setIsSubmitting] = useState(false)

  const [selectedIndustryId, setSelectedIndustryId] = useState<string>("")
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>("")

  // Dynamic Quality Parameter States
  const [qualityValues, setQualityValues] = useState<Record<string, string>>({})
  const [qualityErrors, setQualityErrors] = useState<Record<string, string>>({})
  const [qualityTemplate, setQualityTemplate] = useState<QualityTemplateParameter[]>([])
  const [isQualitySectionOpen, setIsQualitySectionOpen] = useState(true)

  const [openCommodity, setOpenCommodity] = useState(false)
  const [openUnit, setOpenUnit] = useState(false)
  const [openState, setOpenState] = useState(false)
  const [openDistrict, setOpenDistrict] = useState(false)
  const [openCity, setOpenCity] = useState(false)
  const [citySearch, setCitySearch] = useState("")

  const { data: industries = [], isLoading: loadingIndustries } = useIndustries()
  const { data: categories = [], isLoading: loadingCategories } = useCategories()
  const { data: commodities = [], isLoading: loadingCommodities } = useCommodities(selectedCategoryId || undefined)
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
      valid_until: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
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

        // Fetch existing lot quality values for renewal pre-fill
        const qRes = await getAvailabilityQualityValuesAction(renewId)
        if (qRes.success && qRes.data) {
          const qMap: Record<string, string> = {}
          qRes.data.forEach((item: any) => {
            if (item.parameterId && item.value) {
              qMap[item.parameterId] = item.value
            }
          })
          setQualityValues(qMap)
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

        // Fetch existing lot quality values for edit
        const qRes = await getAvailabilityQualityValuesAction(editId)
        if (qRes.success && qRes.data) {
          const qMap: Record<string, string> = {}
          qRes.data.forEach((item: any) => {
            if (item.parameterId && item.value) {
              qMap[item.parameterId] = item.value
            }
          })
          setQualityValues(qMap)
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

  // Reset quality errors when commodity changes
  useEffect(() => {
    setQualityErrors({})
  }, [selectedCommodityId])

  const filteredCategories = selectedIndustryId
    ? categories.filter((c: any) => c.industryId === selectedIndustryId)
    : []

  const filteredCommodities = selectedCategoryId
    ? commodities.filter((c: any) => c.categoryId === selectedCategoryId)
    : []

  const filteredDistricts = districts.filter((d: any) => d.stateId === selectedStateId)

  function getCitiesForDistrict(districtName?: string): string[] {
    if (!districtName) return []
    const d = districtName.toLowerCase().trim()
    
    const knownCityMap: Record<string, string[]> = {
      'bharatpur': ['Bharatpur City', 'Bayana', 'Deeg', 'Nadbai', 'Kaman', 'Weir', 'Rupbas', 'Kumher'],
      'bikaner': ['Bikaner City', 'Nokha', 'Lunkaransar', 'Dungargarh', 'Khajuwala', 'Kolayat', 'Deshnoke'],
      'jaipur': ['Jaipur City', 'Chomu', 'Kotputli', 'Shahpura', 'Bagru', 'Phulera', 'Dudu', 'Jobner'],
      'kota': ['Kota City', 'Ramganj Mandi', 'Sangod', 'Itawa', 'Sultanpur'],
      'jodhpur': ['Jodhpur City', 'Piparcity', 'Bilara', 'Osian', 'Phalodi', 'Bhaleri'],
      'guntur': ['Guntur City', 'Tenali', 'Narasaraopet', 'Bapatla', 'Mangalagiri', 'Sattenapalle'],
      'indore': ['Indore City', 'Sanwer', 'Depalpur', 'Mhow', 'Gautampura'],
      'rajkot': ['Rajkot City', 'Gondal', 'Jetpur', 'Dhoraji', 'Morbi', 'Jasdan'],
      'ludhiana': ['Ludhiana City', 'Khanna', 'Jagraon', 'Samrala', 'Raikot'],
      'ahmedabad': ['Ahmedabad City', 'Sanand', 'Bavla', 'Dholka', 'Viramgam'],
      'nagpur': ['Nagpur City', 'Katol', 'Kalameshwar', 'Saoner', 'Umred', 'Kamptee'],
      'nashik': ['Nashik City', 'Lasalgaon', 'Pimplegaon', 'Malegaon', 'Sinnar', 'Yevala'],
      'karnal': ['Karnal City', 'Gharaunda', 'Taraori', 'Assandh', 'Nissing'],
      'amritsar': ['Amritsar City', 'Ajnala', 'Baba Bakala', 'Attari', 'Majitha'],
      'surat': ['Surat City', 'Bardoli', 'Olpad', 'Vyara', 'Mahuva'],
      'pune': ['Pune City', 'Baramati', 'Junnar', 'Manchar', 'Indapur', 'Shirur'],
    }

    if (knownCityMap[d]) {
      return knownCityMap[d]
    }

    return [
      `${districtName} City`,
      `${districtName} Main Mandi`,
      `${districtName} Central Hub`,
      `${districtName} Industrial Town`,
      `${districtName} North Tehsil`,
      `${districtName} South Tehsil`,
    ]
  }

  async function onSubmit(data: AvailabilitySchema) {
    // 1. Pre-validate quality parameters if template parameters exist
    if (qualityTemplate.length > 0) {
      const validation = validateQualityEntries(qualityValues, qualityTemplate)
      if (!validation.isValid) {
        setQualityErrors(validation.errors)
        setIsQualitySectionOpen(true)
        const firstError = Object.values(validation.errors)[0] || "Please check required quality parameters."
        toast.error(firstError)
        return
      }
      setQualityErrors({})
    }

    setIsSubmitting(true)
    try {
      const payload = {
        ...data,
        id: editId || data.id,
        version: data.version ?? 1,
      }

      const result = payload.id
        ? await updateAvailabilityAction(payload)
        : await createAvailabilityAction(payload)

      if (result.success && result.data?.id) {
        const availabilityId = result.data.id

        // 2. Persist lot-scoped quality values
        const formattedQualityValues = Object.entries(qualityValues)
          .filter(([_, val]) => val !== undefined && val !== null && String(val).trim() !== '')
          .map(([parameter_id, value]) => ({
            parameter_id,
            value: String(value).trim(),
          }))

        if (formattedQualityValues.length > 0 || qualityTemplate.length > 0) {
          const qSaveRes = await saveAvailabilityQualityValuesAction({
            availability_id: availabilityId,
            values: formattedQualityValues,
          })

          if (!qSaveRes.success) {
            if (qSaveRes.validationErrors) {
              setQualityErrors(qSaveRes.validationErrors)
              setIsQualitySectionOpen(true)
            }
            toast.error(qSaveRes.error || "Availability saved, but quality parameters could not be updated.")
            setIsSubmitting(false)
            return
          }
        }

        toast.success(data.id ? "Availability and quality specifications updated!" : "Availability and quality specifications posted successfully!")
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
        setQualityValues({})
        setQualityErrors({})
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

  function onInvalid(errors: any) {
    console.error("AvailabilityForm validation errors:", errors)
    const currentValues = form.getValues()
    const parseResult = availabilitySchema.safeParse(currentValues)
    if (!parseResult.success && parseResult.error.issues.length > 0) {
      toast.error(parseResult.error.issues[0].message)
      return
    }

    const errorEntries = Object.entries(errors)
    if (errorEntries.length > 0) {
      const [firstField, firstErr] = errorEntries[0] as [string, any]
      const msg = firstErr?.message || `Please check the ${firstField} field.`
      toast.error(msg)
    } else {
      toast.error("Please fill in all required fields before posting.")
    }
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit, onInvalid)} className="space-y-6">
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
                      <PopoverContent className="w-[--radix-popover-trigger-width] min-w-[240px] p-0" align="start">
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
                                    form.setValue("commodity_id", commodity.id, { shouldValidate: true })
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
            </div>
          </CardContent>
        </Card>

        {/* SECTION 2: Quality Parameters & Specifications */}
        <Card className="overflow-hidden border-slate-200">
          <CardHeader
            className="cursor-pointer hover:bg-slate-50/80 transition-colors select-none flex flex-row items-center justify-between space-y-0 py-4"
            onClick={() => setIsQualitySectionOpen(!isQualitySectionOpen)}
          >
            <div className="space-y-1">
              <CardTitle className="text-lg text-slate-800 flex items-center gap-2">
                <span>2. Quality Parameters & Specifications</span>
                {Object.keys(qualityErrors).length > 0 && (
                  <Badge variant="destructive" className="text-xs">
                    {Object.keys(qualityErrors).length} Error(s)
                  </Badge>
                )}
              </CardTitle>
              <p className="text-xs text-slate-500">
                Dynamic commodity-specific laboratory & QC measurement specifications.
              </p>
            </div>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="h-8 w-8 p-0"
              onClick={(e) => {
                e.stopPropagation()
                setIsQualitySectionOpen(!isQualitySectionOpen)
              }}
            >
              <ChevronDown
                className={cn(
                  "h-4 w-4 transition-transform duration-200",
                  isQualitySectionOpen && "rotate-180"
                )}
              />
            </Button>
          </CardHeader>
          {isQualitySectionOpen && (
            <CardContent className="pt-2 pb-6 border-t bg-slate-50/25">
              <DynamicQualityFields
                commodityId={selectedCommodityId}
                values={qualityValues}
                onChange={(newValues) => {
                  setQualityValues(newValues)
                  setQualityErrors((prev) => {
                    const next = { ...prev }
                    Object.keys(newValues).forEach((k) => delete next[k])
                    return next
                  })
                }}
                errors={qualityErrors}
                disabled={isSubmitting}
                onTemplateLoaded={(t) => setQualityTemplate(t)}
              />
            </CardContent>
          )}
        </Card>

        {/* SECTION 3: Quantity & Location */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg text-slate-800">3. Quantity & Location</CardTitle>
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
                      <PopoverContent className="w-[--radix-popover-trigger-width] min-w-[240px] p-0" align="start">
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
                      <PopoverContent className="w-[--radix-popover-trigger-width] min-w-[240px] p-0" align="start">
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
                      <PopoverContent className="w-[--radix-popover-trigger-width] min-w-[240px] p-0" align="end">
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
                render={({ field }) => {
                  const selectedDistrictObj = filteredDistricts.find((d: any) => d.id === form.watch("district_id"))
                  const selectedDistrictName = selectedDistrictObj?.name
                  const cityOptions = getCitiesForDistrict(selectedDistrictName)

                  return (
                    <FormItem className="flex flex-col">
                      <FormLabel>City</FormLabel>
                      <Popover open={openCity} onOpenChange={setOpenCity}>
                        <FormControl>
                          <PopoverTrigger
                            disabled={!form.watch("district_id")}
                            className={cn(
                              buttonVariants({ variant: "outline" }),
                              "w-full min-h-[48px] justify-between font-normal",
                              !field.value && "text-muted-foreground"
                            )}
                          >
                            {field.value || (!form.watch("district_id") ? "Select district first" : "Select city")}
                            <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                          </PopoverTrigger>
                        </FormControl>
                        <PopoverContent className="w-[--radix-popover-trigger-width] min-w-[240px] p-0" align="start">
                          <Command>
                            <CommandInput 
                              placeholder="Search city..." 
                              className="min-h-[48px]" 
                              value={citySearch}
                              onValueChange={setCitySearch}
                            />
                            <CommandList className="max-h-[220px] overflow-y-auto">
                              <CommandEmpty className="p-3 text-center text-xs text-slate-500">
                                <p>No matching city found.</p>
                                {citySearch.trim().length > 0 && (
                                  <Button
                                    type="button"
                                    variant="ghost"
                                    size="sm"
                                    className="mt-2 w-full text-emerald-700 hover:text-emerald-800 hover:bg-emerald-50 font-semibold text-xs cursor-pointer"
                                    onClick={() => {
                                      form.setValue("city_id", citySearch.trim(), { shouldValidate: true })
                                      setOpenCity(false)
                                      setCitySearch("")
                                    }}
                                  >
                                    Use "{citySearch.trim()}"
                                  </Button>
                                )}
                              </CommandEmpty>
                              <CommandGroup>
                                {cityOptions.map((cityName: string) => (
                                  <CommandItem
                                    key={cityName}
                                    value={cityName}
                                    onSelect={() => {
                                      form.setValue("city_id", cityName, { shouldValidate: true })
                                      setOpenCity(false)
                                      setCitySearch("")
                                    }}
                                    className="min-h-[48px] cursor-pointer"
                                  >
                                    <Check
                                      className={cn(
                                        "mr-2 h-4 w-4",
                                        field.value === cityName ? "opacity-100" : "opacity-0"
                                      )}
                                    />
                                    {cityName}
                                  </CommandItem>
                                ))}
                              </CommandGroup>
                            </CommandList>
                          </Command>
                        </PopoverContent>
                      </Popover>
                      <FormMessage />
                    </FormItem>
                  )
                }}
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

        {/* SECTION 4: Commercial Terms & Validity */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg text-slate-800">4. Commercial Terms & Validity</CardTitle>
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
