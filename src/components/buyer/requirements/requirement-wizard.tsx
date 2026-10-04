'use client'

import React, { useState, useTransition, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { 
  Loader2, 
  Check, 
  ChevronsUpDown, 
  CalendarIcon, 
  ArrowLeft, 
  ArrowRight,
  CheckCircle2,
  Package,
  Layers,
  MapPin,
  Calendar as CalendarIconLucide,
  CreditCard,
  Building2,
  ShieldCheck,
  CheckSquare,
  FileText
} from 'lucide-react'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'
import { format, addDays } from 'date-fns'

import { Button, buttonVariants } from '@/components/ui/button'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Calendar } from '@/components/ui/calendar'
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group'
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card'

import { 
  requirementWizardSchema, 
  RequirementWizardFormValues,
  step1WhatSchema,
  step2HowMuchSchema,
  step3WhereSchema,
  step4WhenSchema,
  step5CommercialsSchema
} from '@/src/lib/validations/requirement-schema'
import { createRequirementAction } from '@/src/server/actions/requirement-actions'
import { 
  updateRequirementAction, 
  saveDraftRequirementAction 
} from '@/src/server/actions/buyer-requirement-actions'
import { getActiveBrokersAction } from '@/src/server/actions/admin-actions'
import { 
  useIndustries, 
  useCategories, 
  useCommodities, 
  useGrades, 
  useUnits, 
  useStates, 
  useDistricts 
} from '@/src/hooks/use-master-data'
import { saveRequirementOffline } from '@/src/lib/offline-queue'

const PAYMENT_TERMS_OPTIONS = [
  '100% Advance',
  '50% Advance / 50% CAD (Cash Against Documents)',
  'LC at Sight (Irrevocable Letter of Credit)',
  'Net 15 Days after Delivery',
  'Net 30 Days after Delivery',
  'Pay on Delivery (Cash/UPI/NEFT)',
]

const PACKAGING_OPTIONS = [
  'Bulk / Loose',
  '50kg HDPE Bags',
  '25kg Paper Bags',
  'Jute Bags (50kg)',
  'Jumbo Bags (1 Ton)',
  'Custom / Packaging on Request',
]

const FREIGHT_TERMS_OPTIONS = [
  { id: 'EXW', label: 'EXW - Ex-Warehouse (Buyer Arranges Freight)' },
  { id: 'FOR', label: 'FOR - Delivered / Freight Included' },
  { id: 'FOB', label: 'FOB - Free on Board (Seller Loads Freight)' },
  { id: 'CIF', label: 'CIF - Cost, Insurance & Freight (Seller Delivers)' },
]

const WIZARD_STEPS = [
  { id: 1, name: 'What', description: 'Commodity & Grade', icon: Package },
  { id: 2, name: 'How Much', description: 'Quantity & Price', icon: Layers },
  { id: 3, name: 'Where', description: 'Delivery Location', icon: MapPin },
  { id: 4, name: 'When', description: 'Timeline & Window', icon: CalendarIconLucide },
  { id: 5, name: 'Commercials', description: 'Terms & Visibility', icon: CreditCard },
  { id: 6, name: 'Review', description: 'Confirm & Submit', icon: CheckSquare },
]

interface RequirementWizardProps {
  initialData?: any
  requirementId?: string
  isEditMode?: boolean
  onSuccess?: () => void
}

export function RequirementWizard({ 
  initialData, 
  requirementId, 
  isEditMode = false, 
  onSuccess 
}: RequirementWizardProps) {
  const router = useRouter()
  const [currentStep, setCurrentStep] = useState(1)
  const [isPending, startTransition] = useTransition()

  // Master Data cascading filters
  const [selectedIndustryId, setSelectedIndustryId] = useState<string>('')
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>('')

  // Combobox Popover states
  const [openCommodity, setOpenCommodity] = useState(false)
  const [openGrade, setOpenGrade] = useState(false)
  const [openUnit, setOpenUnit] = useState(false)
  const [openState, setOpenState] = useState(false)
  const [openDistrict, setOpenDistrict] = useState(false)

  // Preferred Brokers
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

  // Master Data Hooks
  const { data: industries = [], isLoading: loadingIndustries } = useIndustries()
  const { data: categories = [], isLoading: loadingCategories } = useCategories()
  const { data: commodities = [], isLoading: loadingCommodities } = useCommodities(selectedCategoryId || undefined)
  const { data: grades = [], isLoading: loadingGrades } = useGrades()
  const { data: units = [], isLoading: loadingUnits } = useUnits()
  const { data: states = [], isLoading: loadingStates } = useStates()
  const { data: districts = [], isLoading: loadingDistricts } = useDistricts()

  const form = useForm<RequirementWizardFormValues>({
    resolver: zodResolver(requirementWizardSchema) as any,
    mode: 'onChange',
    defaultValues: {
      commodity_id: initialData?.commodityId || initialData?.commodity_id || '',
      grade_id: initialData?.gradeId || initialData?.grade_id || '',
      quantity: initialData?.quantity ? Number(initialData.quantity) : 0,
      unit_id: initialData?.unitId || initialData?.unit_id || '',
      target_price: initialData?.targetPrice ? Number(initialData.targetPrice) : (initialData?.target_price ? Number(initialData.target_price) : 0),
      allow_partial_fulfillment: initialData?.allow_partial_fulfillment ?? true,
      delivery_state_id: initialData?.delivery_state_id || initialData?.stateId || '',
      delivery_district_id: initialData?.delivery_district_id || initialData?.districtId || '',
      delivery_city_id: initialData?.delivery_city_id || initialData?.city || '',
      delivery_window_start: initialData?.delivery_window_start ? new Date(initialData.delivery_window_start) : new Date(),
      delivery_window_end: initialData?.delivery_window_end ? new Date(initialData.delivery_window_end) : (initialData?.targetDate ? new Date(initialData.targetDate) : addDays(new Date(), 14)),
      target_date: initialData?.targetDate ? new Date(initialData.targetDate) : addDays(new Date(), 14),
      payment_terms: initialData?.payment_terms || PAYMENT_TERMS_OPTIONS[0],
      packaging_type: initialData?.packaging_type || PACKAGING_OPTIONS[1],
      freight_terms: initialData?.deliveryTermsId || initialData?.freight_terms || 'EXW',
      delivery_terms_id: initialData?.deliveryTermsId || initialData?.delivery_terms_id || 'EXW',
      visibility: initialData?.visibility || 'global',
      broker_id: initialData?.brokerId || initialData?.broker_id || '',
    },
  })

  // Cascading helpers
  const selectedCommodityId = form.watch('commodity_id')
  const selectedStateId = form.watch('delivery_state_id')
  const selectedDistrictId = form.watch('delivery_district_id')
  const deliveryWindowStart = form.watch('delivery_window_start')
  const visibility = form.watch('visibility')

  const filteredCategories = selectedIndustryId 
    ? categories.filter((c: any) => c.industryId === selectedIndustryId)
    : []

  const filteredCommodities = selectedCategoryId 
    ? commodities.filter((c: any) => c.categoryId === selectedCategoryId)
    : []

  const filteredGrades = grades.filter((g: any) => g.commodityId === selectedCommodityId)
  const filteredDistricts = selectedStateId
    ? districts.filter((d: any) => d.stateId === selectedStateId)
    : []

  // Step Validation logic before moving forward
  const validateCurrentStep = async (): Promise<boolean> => {
    const values = form.getValues()

    if (currentStep === 1) {
      const res = step1WhatSchema.safeParse({
        commodity_id: values.commodity_id,
        grade_id: values.grade_id,
      })
      if (!res.success) {
        res.error.issues.forEach((issue) => {
          form.setError(issue.path[0] as any, { message: issue.message })
        })
        toast.error('Please select both Commodity and Quality Grade')
        return false
      }
    } else if (currentStep === 2) {
      const res = step2HowMuchSchema.safeParse({
        quantity: Number(values.quantity),
        unit_id: values.unit_id,
        target_price: Number(values.target_price),
        allow_partial_fulfillment: values.allow_partial_fulfillment,
      })
      if (!res.success) {
        res.error.issues.forEach((issue) => {
          form.setError(issue.path[0] as any, { message: issue.message })
        })
        toast.error('Please enter valid Quantity, Unit, and Target Price')
        return false
      }
    } else if (currentStep === 3) {
      const res = step3WhereSchema.safeParse({
        delivery_state_id: values.delivery_state_id,
        delivery_district_id: values.delivery_district_id,
        delivery_city_id: values.delivery_city_id,
      })
      if (!res.success) {
        res.error.issues.forEach((issue) => {
          form.setError(issue.path[0] as any, { message: issue.message })
        })
        toast.error('Please select Destination State')
        return false
      }
    } else if (currentStep === 4) {
      const res = step4WhenSchema.safeParse({
        delivery_window_start: values.delivery_window_start,
        delivery_window_end: values.delivery_window_end,
        target_date: values.target_date || values.delivery_window_end,
      })
      if (!res.success) {
        res.error.issues.forEach((issue) => {
          form.setError(issue.path[0] as any, { message: issue.message })
        })
        if (values.delivery_window_start && values.delivery_window_end && values.delivery_window_end < values.delivery_window_start) {
          toast.error('Delivery end date cannot be earlier than start date')
        } else {
          toast.error('Please specify valid delivery timeline')
        }
        return false
      }
    } else if (currentStep === 5) {
      const res = step5CommercialsSchema.safeParse({
        payment_terms: values.payment_terms,
        packaging_type: values.packaging_type,
        freight_terms: values.freight_terms,
        delivery_terms_id: values.freight_terms,
        visibility: values.visibility,
        broker_id: values.broker_id,
      })
      if (!res.success) {
        res.error.issues.forEach((issue) => {
          form.setError(issue.path[0] as any, { message: issue.message })
        })
        if (values.visibility === 'restricted' && !values.broker_id) {
          toast.error('Preferred Broker is required for Private Network')
        } else {
          toast.error('Please complete all commercial terms')
        }
        return false
      }
    }
    return true
  }

  const handleNext = async () => {
    const isValid = await validateCurrentStep()
    if (isValid && currentStep < 6) {
      setCurrentStep((prev) => prev + 1)
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  const handleBack = () => {
    if (currentStep > 1) {
      setCurrentStep((prev) => prev - 1)
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  // Save as Draft Handler (Bypasses strict step validation for partial draft saves)
  const handleSaveDraft = async () => {
    const values = form.getValues()
    startTransition(async () => {
      try {
        const payload = {
          commodity_id: values.commodity_id,
          grade_id: values.grade_id,
          quantity: Number(values.quantity) || 1,
          unit_id: values.unit_id,
          target_price: Number(values.target_price) || 1,
          delivery_terms_id: values.freight_terms || 'EXW',
          target_date: values.delivery_window_end || values.target_date || addDays(new Date(), 14),
          visibility: values.visibility || 'global',
          broker_id: values.broker_id || undefined,
          delivery_state_id: values.delivery_state_id,
          delivery_district_id: values.delivery_district_id,
          delivery_city_id: values.delivery_city_id,
          delivery_window_start: values.delivery_window_start,
          delivery_window_end: values.delivery_window_end,
          payment_terms: values.payment_terms,
          packaging_type: values.packaging_type,
          freight_terms: values.freight_terms,
          allow_partial_fulfillment: values.allow_partial_fulfillment,
        }

        let result
        if (requirementId || isEditMode) {
          result = await updateRequirementAction(requirementId || initialData?.id, payload, true)
        } else {
          result = await saveDraftRequirementAction(payload)
        }

        if (result.success) {
          toast.success('Requirement saved as Draft successfully!')
          onSuccess?.()
          router.push('/buyer/requirements')
        } else {
          toast.error(result.error || 'Failed to save draft.')
        }
      } catch (err: any) {
        toast.error(err.message || 'An error occurred while saving draft.')
      }
    })
  }

  // Full Submission / Update handler
  const onSubmit = async (values: RequirementWizardFormValues) => {
    startTransition(async () => {
      try {
        const payload = {
          commodity_id: values.commodity_id,
          grade_id: values.grade_id,
          quantity: Number(values.quantity),
          unit_id: values.unit_id,
          target_price: Number(values.target_price),
          delivery_terms_id: values.freight_terms || 'EXW',
          target_date: values.delivery_window_end || values.target_date || addDays(new Date(), 14),
          visibility: values.visibility,
          broker_id: values.broker_id || undefined,
          // Extended fields
          delivery_state_id: values.delivery_state_id,
          delivery_district_id: values.delivery_district_id,
          delivery_city_id: values.delivery_city_id,
          delivery_window_start: values.delivery_window_start,
          delivery_window_end: values.delivery_window_end,
          payment_terms: values.payment_terms,
          packaging_type: values.packaging_type,
          freight_terms: values.freight_terms,
          allow_partial_fulfillment: values.allow_partial_fulfillment,
        }

        if (typeof window !== 'undefined' && !navigator.onLine) {
          await saveRequirementOffline(payload as any)
          toast.warning('Offline mode active. Requirement saved locally and will auto-sync once online.')
          onSuccess?.()
          router.push('/buyer/requirements')
          return
        }

        let result
        if (isEditMode || requirementId) {
          result = await updateRequirementAction(requirementId || initialData?.id, payload, false)
        } else {
          result = await createRequirementAction(payload)
        }

        if (result.success) {
          toast.success(isEditMode ? 'Requirement updated successfully!' : 'Procurement Requirement posted successfully!')
          onSuccess?.()
          router.push('/buyer/requirements')
        } else {
          toast.error(result.error || 'Failed to submit requirement.')
        }
      } catch (err: any) {
        toast.error(err.message || 'An unexpected error occurred during submission.')
      }
    })
  }

  // Lookup human-readable names for summary card
  const selectedCommodity = commodities.find((c: any) => c.id === form.watch('commodity_id'))
  const selectedGrade = grades.find((g: any) => g.id === form.watch('grade_id'))
  const selectedUnit = units.find((u: any) => u.id === form.watch('unit_id'))
  const selectedState = states.find((s: any) => s.id === form.watch('delivery_state_id'))
  const selectedDistrict = districts.find((d: any) => d.id === form.watch('delivery_district_id'))
  const selectedBroker = brokers.find((b: any) => b.id === (form.watch('broker_id') || ''))

  return (
    <div className="w-full max-w-full overflow-x-hidden pb-28 flex flex-col min-h-[calc(100vh-80px)] bg-slate-50/50">
      {/* STICKY TOP PROGRESS BAR */}
      <div className="sticky top-0 z-40 bg-white border-b border-slate-200 shadow-sm px-4 py-3">
        <div className="max-w-2xl mx-auto space-y-2">
          <div className="flex items-center justify-between text-xs font-semibold text-slate-700">
            <span className="flex items-center gap-1.5 text-[#0284C7]">
              Step {currentStep} of 6: <span className="font-bold">{WIZARD_STEPS[currentStep - 1].name}</span>
            </span>
            <span className="text-slate-500 font-normal">
              {WIZARD_STEPS[currentStep - 1].description}
            </span>
          </div>

          {/* Progress bar container */}
          <div className="w-full bg-slate-100 rounded-full h-2 overflow-hidden">
            <div 
              className="bg-[#0284C7] h-2 rounded-full transition-all duration-300 ease-in-out"
              style={{ width: `${(currentStep / 6) * 100}%` }}
            />
          </div>

          {/* Step Icon Pills */}
          <div className="flex justify-between items-center pt-1 px-1">
            {WIZARD_STEPS.map((step) => {
              const isCompleted = currentStep > step.id
              const isCurrent = currentStep === step.id

              return (
                <button
                  key={step.id}
                  type="button"
                  onClick={() => {
                    if (step.id < currentStep) setCurrentStep(step.id)
                  }}
                  className={cn(
                    "flex flex-col items-center justify-center space-y-1 transition-all",
                    isCompleted && "text-[#0284C7] cursor-pointer",
                    isCurrent && "text-[#0284C7] font-bold scale-105",
                    !isCompleted && !isCurrent && "text-slate-400 opacity-60"
                  )}
                >
                  <div className={cn(
                    "w-7 h-7 rounded-full flex items-center justify-center text-xs font-semibold border transition-all",
                    isCompleted && "bg-[#0284C7] text-white border-[#0284C7]",
                    isCurrent && "border-[#0284C7] text-[#0284C7] bg-sky-50 ring-2 ring-sky-200",
                    !isCompleted && !isCurrent && "border-slate-300 bg-white text-slate-500"
                  )}>
                    {isCompleted ? <Check className="w-3.5 h-3.5 stroke-[3]" /> : step.id}
                  </div>
                  <span className="text-[10px] hidden sm:block truncate max-w-[60px]">
                    {step.name}
                  </span>
                </button>
              )
            })}
          </div>
        </div>
      </div>

      {/* MIDDLE STEP CONTAINER */}
      <div className="flex-1 overflow-y-auto p-4 max-w-2xl mx-auto w-full">
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">

            {/* STEP 1: WHAT (Commodity & Grade) */}
            {currentStep === 1 && (
              <Card className="border-slate-200 shadow-sm">
                <CardHeader className="pb-4 border-b border-slate-100">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-lg bg-sky-50 text-[#0284C7]">
                      <Package className="w-5 h-5" />
                    </div>
                    <div>
                      <CardTitle className="text-base text-slate-900 font-bold">
                        Step 1: Select Commodity & Quality
                      </CardTitle>
                      <CardDescription className="text-xs text-slate-500">
                        Choose the master commodity and target quality parameters.
                      </CardDescription>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="pt-6 space-y-5">
                  {/* Industry Select */}
                  <div className="space-y-2">
                    <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                      1. Industry Category
                    </label>
                    <Select
                      value={selectedIndustryId}
                      onValueChange={(val: string | null) => {
                        const cleanVal = val || ""
                        setSelectedIndustryId(cleanVal)
                        setSelectedCategoryId("")
                        form.setValue("commodity_id", "")
                        form.setValue("grade_id", "")
                      }}
                    >
                      <SelectTrigger className="w-full min-h-[48px] bg-white border-slate-300">
                        <SelectValue placeholder={loadingIndustries ? "Loading industries..." : "Select Industry"}>
                          {selectedIndustryId ? industries.find((ind: any) => ind.id === selectedIndustryId)?.name : null}
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        {industries.map((ind: any) => (
                          <SelectItem key={ind.id} value={ind.id} className="min-h-[44px]">
                            {ind.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  {/* Category Select */}
                  <div className="space-y-2">
                    <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                      2. Sub-Category
                    </label>
                    <Select
                      disabled={!selectedIndustryId || loadingCategories}
                      value={selectedCategoryId}
                      onValueChange={(val: string | null) => {
                        const cleanVal = val || ""
                        setSelectedCategoryId(cleanVal)
                        form.setValue("commodity_id", "")
                        form.setValue("grade_id", "")
                      }}
                    >
                      <SelectTrigger className="w-full min-h-[48px] bg-white border-slate-300">
                        <SelectValue 
                          placeholder={
                            !selectedIndustryId 
                              ? "Select industry first" 
                              : loadingCategories 
                                ? "Loading categories..." 
                                : "Select Sub-Category"
                          } 
                        >
                          {selectedCategoryId ? filteredCategories.find((cat: any) => cat.id === selectedCategoryId)?.name : null}
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        {filteredCategories.map((cat: any) => (
                          <SelectItem key={cat.id} value={cat.id} className="min-h-[44px]">
                            {cat.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  {/* Commodity Combobox */}
                  <FormField
                    control={form.control}
                    name="commodity_id"
                    render={({ field }) => (
                      <FormItem className="flex flex-col">
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          3. Commodity <span className="text-rose-500">*</span>
                        </FormLabel>
                        <Popover open={openCommodity} onOpenChange={setOpenCommodity}>
                          <FormControl>
                            <PopoverTrigger
                              disabled={!selectedCategoryId && commodities.length === 0}
                              className={cn(
                                buttonVariants({ variant: "outline" }),
                                "w-full min-h-[48px] justify-between font-normal bg-white border-slate-300",
                                !field.value && "text-muted-foreground"
                              )}
                            >
                              {field.value
                                ? commodities.find((c: any) => c.id === field.value)?.name || "Select Commodity"
                                : loadingCommodities 
                                  ? "Loading commodities..." 
                                  : "Select Commodity"}
                              <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                            </PopoverTrigger>
                          </FormControl>
                          <PopoverContent className="w-[320px] p-0" align="start">
                            <Command>
                              <CommandInput placeholder="Search commodity..." />
                              <CommandList>
                                <CommandEmpty>No commodity found.</CommandEmpty>
                                <CommandGroup>
                                  {(selectedCategoryId ? filteredCommodities : commodities).map((c: any) => (
                                    <CommandItem
                                      key={c.id}
                                      value={c.name}
                                      onSelect={() => {
                                        form.setValue("commodity_id", c.id)
                                        form.setValue("grade_id", "")
                                        setOpenCommodity(false)
                                      }}
                                    >
                                      <Check
                                        className={cn(
                                          "mr-2 h-4 w-4 text-[#0284C7]",
                                          c.id === field.value ? "opacity-100" : "opacity-0"
                                        )}
                                      />
                                      {c.name}
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

                  {/* Grade Combobox */}
                  <FormField
                    control={form.control}
                    name="grade_id"
                    render={({ field }) => (
                      <FormItem className="flex flex-col">
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          4. Quality Grade / Specification <span className="text-rose-500">*</span>
                        </FormLabel>
                        <Popover open={openGrade} onOpenChange={setOpenGrade}>
                          <FormControl>
                            <PopoverTrigger
                              disabled={!selectedCommodityId}
                              className={cn(
                                buttonVariants({ variant: "outline" }),
                                "w-full min-h-[48px] justify-between font-normal bg-white border-slate-300",
                                !field.value && "text-muted-foreground"
                              )}
                            >
                              {field.value
                                ? filteredGrades.find((g: any) => g.id === field.value)?.gradeName || grades.find((g: any) => g.id === field.value)?.gradeName || "Select Grade"
                                : !selectedCommodityId 
                                  ? "Select commodity first"
                                  : loadingGrades 
                                    ? "Loading grades..." 
                                    : "Select Quality Grade"}
                              <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                            </PopoverTrigger>
                          </FormControl>
                          <PopoverContent className="w-[320px] p-0" align="start">
                            <Command>
                              <CommandInput placeholder="Search grade..." />
                              <CommandList>
                                <CommandEmpty>No quality grade found for this commodity.</CommandEmpty>
                                <CommandGroup>
                                  {filteredGrades.map((g: any) => (
                                    <CommandItem
                                      key={g.id}
                                      value={g.gradeName}
                                      onSelect={() => {
                                        form.setValue("grade_id", g.id)
                                        setOpenGrade(false)
                                      }}
                                    >
                                      <Check
                                        className={cn(
                                          "mr-2 h-4 w-4 text-[#0284C7]",
                                          g.id === field.value ? "opacity-100" : "opacity-0"
                                        )}
                                      />
                                      {g.gradeName}
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
                </CardContent>
              </Card>
            )}

            {/* STEP 2: HOW MUCH (Quantity & Target Price + Partial Toggle) */}
            {currentStep === 2 && (
              <Card className="border-slate-200 shadow-sm">
                <CardHeader className="pb-4 border-b border-slate-100">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-lg bg-sky-50 text-[#0284C7]">
                      <Layers className="w-5 h-5" />
                    </div>
                    <div>
                      <CardTitle className="text-base text-slate-900 font-bold">
                        Step 2: Quantity & Target Price
                      </CardTitle>
                      <CardDescription className="text-xs text-slate-500">
                        Specify required volume, target budget, and partial fulfillment rules.
                      </CardDescription>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="pt-6 space-y-5">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    {/* Quantity */}
                    <FormField
                      control={form.control}
                      name="quantity"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                            Required Quantity <span className="text-rose-500">*</span>
                          </FormLabel>
                          <FormControl>
                            <Input
                              type="number"
                              inputMode="decimal"
                              placeholder="e.g. 500"
                              className="min-h-[48px] bg-white text-base border-slate-300"
                              value={field.value || ''}
                              onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)}
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />

                    {/* Unit Combobox */}
                    <FormField
                      control={form.control}
                      name="unit_id"
                      render={({ field }) => (
                        <FormItem className="flex flex-col">
                          <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                            Unit <span className="text-rose-500">*</span>
                          </FormLabel>
                          <Popover open={openUnit} onOpenChange={setOpenUnit}>
                            <FormControl>
                              <PopoverTrigger
                                className={cn(
                                  buttonVariants({ variant: "outline" }),
                                  "w-full min-h-[48px] justify-between font-normal bg-white border-slate-300",
                                  !field.value && "text-muted-foreground"
                                )}
                              >
                                {field.value
                                  ? (() => {
                                      const u = units.find((u: any) => u.id === field.value);
                                      return u ? `${u.symbol} - ${u.name}` : "Select Unit";
                                    })()
                                  : loadingUnits ? "Loading units..." : "Select Unit"}
                                <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                              </PopoverTrigger>
                            </FormControl>
                            <PopoverContent className="w-[280px] p-0" align="start">
                              <Command>
                                <CommandInput placeholder="Search unit..." />
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
                                      >
                                        <Check
                                          className={cn(
                                            "mr-2 h-4 w-4 text-[#0284C7]",
                                            u.id === field.value ? "opacity-100" : "opacity-0"
                                          )}
                                        />
                                        {u.symbol} ({u.name})
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

                  {/* Target Price */}
                  <FormField
                    control={form.control}
                    name="target_price"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          Target Price (₹ per Unit) <span className="text-rose-500">*</span>
                        </FormLabel>
                        <FormControl>
                          <div className="relative">
                            <span className="absolute left-3.5 top-3.5 text-slate-400 font-semibold text-sm">
                              ₹
                            </span>
                            <Input
                              type="number"
                              inputMode="decimal"
                              placeholder="e.g. 4200"
                              className="min-h-[48px] pl-8 bg-white text-base border-slate-300"
                              value={field.value || ''}
                              onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)}
                            />
                          </div>
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  {/* Partial Fulfillment Visual Toggle */}
                  <FormField
                    control={form.control}
                    name="allow_partial_fulfillment"
                    render={({ field }) => (
                      <FormItem className="rounded-xl border border-sky-100 bg-sky-50/60 p-4 space-y-0">
                        <div className="flex items-center justify-between gap-4">
                          <div className="space-y-1">
                            <FormLabel className="text-sm font-bold text-slate-900 cursor-pointer">
                              Allow Partial Fulfillment
                            </FormLabel>
                            <p className="text-xs text-slate-600">
                              Brokers can fulfill your order using multiple smaller seller match lots.
                            </p>
                          </div>
                          <button
                            type="button"
                            role="switch"
                            aria-checked={field.value}
                            onClick={() => field.onChange(!field.value)}
                            className={cn(
                              "relative inline-flex h-7 w-12 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-[#0284C7] focus:ring-offset-2",
                              field.value ? "bg-[#0284C7]" : "bg-slate-300"
                            )}
                          >
                            <span
                              className={cn(
                                "pointer-events-none inline-block h-6 w-6 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                                field.value ? "translate-x-5" : "translate-x-0"
                              )}
                            />
                          </button>
                        </div>
                      </FormItem>
                    )}
                  />

                  {/* Estimated total card calculation */}
                  {Number(form.watch('quantity')) > 0 && Number(form.watch('target_price')) > 0 && (
                    <div className="p-3 bg-emerald-50/70 border border-emerald-200 rounded-lg flex items-center justify-between text-xs font-medium text-emerald-900">
                      <span>Estimated Indicative Budget:</span>
                      <span className="text-sm font-bold text-emerald-700">
                        ₹{(Number(form.watch('quantity')) * Number(form.watch('target_price'))).toLocaleString('en-IN')}
                      </span>
                    </div>
                  )}
                </CardContent>
              </Card>
            )}

            {/* STEP 3: WHERE (Cascading Delivery Location UI) */}
            {currentStep === 3 && (
              <Card className="border-slate-200 shadow-sm">
                <CardHeader className="pb-4 border-b border-slate-100">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-lg bg-sky-50 text-[#0284C7]">
                      <MapPin className="w-5 h-5" />
                    </div>
                    <div>
                      <CardTitle className="text-base text-slate-900 font-bold">
                        Step 3: Delivery Location (Cascading)
                      </CardTitle>
                      <CardDescription className="text-xs text-slate-500">
                        Select destination State → District → Warehouse City.
                      </CardDescription>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="pt-6 space-y-5">
                  {/* State Select */}
                  <FormField
                    control={form.control}
                    name="delivery_state_id"
                    render={({ field }) => (
                      <FormItem className="flex flex-col">
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          1. Destination State <span className="text-rose-500">*</span>
                        </FormLabel>
                        <Popover open={openState} onOpenChange={setOpenState}>
                          <FormControl>
                            <PopoverTrigger
                              className={cn(
                                buttonVariants({ variant: "outline" }),
                                "w-full min-h-[48px] justify-between font-normal bg-white border-slate-300",
                                !field.value && "text-muted-foreground"
                              )}
                            >
                              {field.value
                                ? states.find((s: any) => s.id === field.value)?.name || "Select State"
                                : loadingStates ? "Loading states..." : "Select Destination State"}
                              <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                            </PopoverTrigger>
                          </FormControl>
                          <PopoverContent className="w-[320px] p-0" align="start">
                            <Command>
                              <CommandInput placeholder="Search state..." />
                              <CommandList>
                                <CommandEmpty>No state found.</CommandEmpty>
                                <CommandGroup>
                                  {states.map((s: any) => (
                                    <CommandItem
                                      key={s.id}
                                      value={s.name}
                                      onSelect={() => {
                                        form.setValue("delivery_state_id", s.id)
                                        form.setValue("delivery_district_id", "")
                                        form.setValue("delivery_city_id", "")
                                        setOpenState(false)
                                      }}
                                    >
                                      <Check
                                        className={cn(
                                          "mr-2 h-4 w-4 text-[#0284C7]",
                                          s.id === field.value ? "opacity-100" : "opacity-0"
                                        )}
                                      />
                                      {s.name}
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

                  {/* District Select - Locked until State is selected */}
                  <FormField
                    control={form.control}
                    name="delivery_district_id"
                    render={({ field }) => (
                      <FormItem className="flex flex-col">
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          2. District {!selectedStateId && <span className="text-amber-600 font-normal ml-1">(Locked - Select State First)</span>}
                        </FormLabel>
                        <Popover open={openDistrict} onOpenChange={setOpenDistrict}>
                          <FormControl>
                            <PopoverTrigger
                              disabled={!selectedStateId}
                              className={cn(
                                buttonVariants({ variant: "outline" }),
                                "w-full min-h-[48px] justify-between font-normal bg-white border-slate-300",
                                (!field.value || !selectedStateId) && "text-muted-foreground",
                                !selectedStateId && "bg-slate-100/70 cursor-not-allowed border-dashed"
                              )}
                            >
                              {field.value
                                ? filteredDistricts.find((d: any) => d.id === field.value)?.name || "Select District"
                                : !selectedStateId 
                                  ? "🔒 Select State First" 
                                  : loadingDistricts 
                                    ? "Loading districts..." 
                                    : "Select District"}
                              <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                            </PopoverTrigger>
                          </FormControl>
                          <PopoverContent className="w-[320px] p-0" align="start">
                            <Command>
                              <CommandInput placeholder="Search district..." />
                              <CommandList>
                                <CommandEmpty>No district found for this state.</CommandEmpty>
                                <CommandGroup>
                                  {filteredDistricts.map((d: any) => (
                                    <CommandItem
                                      key={d.id}
                                      value={d.name}
                                      onSelect={() => {
                                        form.setValue("delivery_district_id", d.id)
                                        setOpenDistrict(false)
                                      }}
                                    >
                                      <Check
                                        className={cn(
                                          "mr-2 h-4 w-4 text-[#0284C7]",
                                          d.id === field.value ? "opacity-100" : "opacity-0"
                                        )}
                                      />
                                      {d.name}
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

                  {/* City / Specific Warehouse Location - Locked until District is selected */}
                  <FormField
                    control={form.control}
                    name="delivery_city_id"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          3. City / Warehouse Address {!selectedDistrictId && <span className="text-amber-600 font-normal ml-1">(Locked - Select District First)</span>}
                        </FormLabel>
                        <FormControl>
                          <Input
                            disabled={!selectedStateId || !selectedDistrictId}
                            placeholder={
                              !selectedStateId 
                                ? "🔒 Select State First" 
                                : !selectedDistrictId 
                                  ? "🔒 Select District First" 
                                  : "e.g. Industrial Area Phase 2, Central Warehouse"
                            }
                            className={cn(
                              "min-h-[48px] bg-white text-base border-slate-300",
                              (!selectedStateId || !selectedDistrictId) && "bg-slate-100/70 cursor-not-allowed border-dashed"
                            )}
                            {...field}
                            value={field.value || ''}
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </CardContent>
              </Card>
            )}

            {/* STEP 4: WHEN (Delivery Timelines & Ordering Rules) */}
            {currentStep === 4 && (
              <Card className="border-slate-200 shadow-sm">
                <CardHeader className="pb-4 border-b border-slate-100">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-lg bg-sky-50 text-[#0284C7]">
                      <CalendarIconLucide className="w-5 h-5" />
                    </div>
                    <div>
                      <CardTitle className="text-base text-slate-900 font-bold">
                        Step 4: Delivery Timelines
                      </CardTitle>
                      <CardDescription className="text-xs text-slate-500">
                        Specify dispatch window start and target completion deadline.
                      </CardDescription>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="pt-6 space-y-5">
                  {/* Quick Preset Buttons */}
                  <div className="space-y-2">
                    <label className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                      Quick Delivery Presets
                    </label>
                    <div className="grid grid-cols-3 gap-2">
                      {[
                        { label: 'In 7 Days', days: 7 },
                        { label: 'In 15 Days', days: 15 },
                        { label: 'In 30 Days', days: 30 },
                      ].map((preset) => (
                        <Button
                          key={preset.days}
                          type="button"
                          variant="outline"
                          className="min-h-[44px] text-xs font-semibold hover:border-[#0284C7] hover:text-[#0284C7]"
                          onClick={() => {
                            const startDate = new Date()
                            const endDate = addDays(startDate, preset.days)
                            form.setValue('delivery_window_start', startDate)
                            form.setValue('delivery_window_end', endDate)
                            form.setValue('target_date', endDate)
                          }}
                        >
                          {preset.label}
                        </Button>
                      ))}
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    {/* Delivery Window Start */}
                    <FormField
                      control={form.control}
                      name="delivery_window_start"
                      render={({ field }) => (
                        <FormItem className="flex flex-col">
                          <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                            Dispatch Ready Start Date
                          </FormLabel>
                          <Popover>
                            <FormControl>
                              <PopoverTrigger
                                className={cn(
                                  buttonVariants({ variant: "outline" }),
                                  "w-full min-h-[48px] pl-3 text-left font-normal flex items-center justify-between bg-white border-slate-300",
                                  !field.value && "text-muted-foreground"
                                )}
                              >
                                {field.value ? format(field.value, "PPP") : <span>Pick start date</span>}
                                <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                              </PopoverTrigger>
                            </FormControl>
                            <PopoverContent className="w-auto p-0" align="start">
                              <Calendar
                                mode="single"
                                selected={field.value}
                                onSelect={(d) => d && field.onChange(d)}
                              />
                            </PopoverContent>
                          </Popover>
                          <FormMessage />
                        </FormItem>
                      )}
                    />

                    {/* Delivery Window End / Target Date - Restricted to >= start date */}
                    <FormField
                      control={form.control}
                      name="delivery_window_end"
                      render={({ field }) => (
                        <FormItem className="flex flex-col">
                          <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                            Latest Target Date <span className="text-rose-500">*</span>
                          </FormLabel>
                          <Popover>
                            <FormControl>
                              <PopoverTrigger
                                className={cn(
                                  buttonVariants({ variant: "outline" }),
                                  "w-full min-h-[48px] pl-3 text-left font-normal flex items-center justify-between bg-white border-slate-300",
                                  !field.value && "text-muted-foreground"
                                )}
                              >
                                {field.value ? format(field.value, "PPP") : <span>Pick completion date</span>}
                                <CalendarIcon className="ml-auto h-4 w-4 opacity-50" />
                              </PopoverTrigger>
                            </FormControl>
                            <PopoverContent className="w-auto p-0" align="start">
                              <Calendar
                                mode="single"
                                selected={field.value}
                                disabled={(date: Date) => 
                                  deliveryWindowStart ? date < deliveryWindowStart : date < new Date()
                                }
                                onSelect={(d) => {
                                  if (d) {
                                    field.onChange(d)
                                    form.setValue('target_date', d)
                                  }
                                }}
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
            )}

            {/* STEP 5: COMMERCIAL TERMS & VISIBILITY */}
            {currentStep === 5 && (
              <Card className="border-slate-200 shadow-sm">
                <CardHeader className="pb-4 border-b border-slate-100">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-lg bg-sky-50 text-[#0284C7]">
                      <CreditCard className="w-5 h-5" />
                    </div>
                    <div>
                      <CardTitle className="text-base text-slate-900 font-bold">
                        Step 5: Commercial Terms & Visibility
                      </CardTitle>
                      <CardDescription className="text-xs text-slate-500">
                        Configure payment, freight, packaging, and broker privacy options.
                      </CardDescription>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="pt-6 space-y-5">
                  {/* Payment Terms */}
                  <FormField
                    control={form.control}
                    name="payment_terms"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          Payment Terms <span className="text-rose-500">*</span>
                        </FormLabel>
                        <Select value={field.value} onValueChange={(val: string | null) => field.onChange(val || '')}>
                          <FormControl>
                            <SelectTrigger className="w-full min-h-[48px] bg-white border-slate-300">
                              <SelectValue placeholder="Select Payment Terms" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            {PAYMENT_TERMS_OPTIONS.map((opt) => (
                              <SelectItem key={opt} value={opt} className="min-h-[44px]">
                                {opt}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  {/* Packaging Type */}
                  <FormField
                    control={form.control}
                    name="packaging_type"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          Packaging Standard <span className="text-rose-500">*</span>
                        </FormLabel>
                        <Select value={field.value} onValueChange={(val: string | null) => field.onChange(val || '')}>
                          <FormControl>
                            <SelectTrigger className="w-full min-h-[48px] bg-white border-slate-300">
                              <SelectValue placeholder="Select Packaging Standard" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            {PACKAGING_OPTIONS.map((opt) => (
                              <SelectItem key={opt} value={opt} className="min-h-[44px]">
                                {opt}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  {/* Freight Terms */}
                  <FormField
                    control={form.control}
                    name="freight_terms"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          Freight / Logistics Model <span className="text-rose-500">*</span>
                        </FormLabel>
                        <Select 
                          value={field.value} 
                          onValueChange={(val: string | null) => {
                            const cleanVal = val || 'EXW'
                            field.onChange(cleanVal)
                            form.setValue('delivery_terms_id', cleanVal)
                          }}
                        >
                          <FormControl>
                            <SelectTrigger className="w-full min-h-[48px] bg-white border-slate-300">
                              <SelectValue placeholder="Select Freight Terms" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            {FREIGHT_TERMS_OPTIONS.map((opt) => (
                              <SelectItem key={opt.id} value={opt.id} className="min-h-[44px]">
                                {opt.label}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  {/* Search Visibility */}
                  <FormField
                    control={form.control}
                    name="visibility"
                    render={({ field }) => (
                      <FormItem className="space-y-2 pt-2">
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          Broker Network Visibility
                        </FormLabel>
                        <FormControl>
                          <RadioGroup
                            onValueChange={field.onChange}
                            value={field.value}
                            className="grid grid-cols-1 sm:grid-cols-2 gap-3"
                          >
                            <label className={cn(
                              "flex items-start space-x-3 rounded-xl border p-3.5 cursor-pointer transition-all min-h-[48px]",
                              field.value === 'global' ? "border-[#0284C7] bg-sky-50/50 ring-1 ring-[#0284C7]" : "border-slate-200 bg-white"
                            )}>
                              <RadioGroupItem value="global" className="mt-0.5" />
                              <div className="space-y-1 text-xs">
                                <span className="font-bold text-slate-900 block">Global Pool</span>
                                <span className="text-slate-500 leading-snug block">
                                  Broadcast to all verified brokers for maximum match speed.
                                </span>
                              </div>
                            </label>

                            <label className={cn(
                              "flex items-start space-x-3 rounded-xl border p-3.5 cursor-pointer transition-all min-h-[48px]",
                              field.value === 'restricted' ? "border-[#0284C7] bg-sky-50/50 ring-1 ring-[#0284C7]" : "border-slate-200 bg-white"
                            )}>
                              <RadioGroupItem value="restricted" className="mt-0.5" />
                              <div className="space-y-1 text-xs">
                                <span className="font-bold text-slate-900 block">Private Network</span>
                                <span className="text-slate-500 leading-snug block">
                                  Limit deal matching strictly to your assigned broker.
                                </span>
                              </div>
                            </label>
                          </RadioGroup>
                        </FormControl>
                      </FormItem>
                    )}
                  />

                  {/* Preferred Broker Select */}
                  <FormField
                    control={form.control}
                    name="broker_id"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs font-semibold text-slate-700 uppercase tracking-wider">
                          Preferred Broker {visibility === 'restricted' && <span className="text-rose-500">*</span>}
                        </FormLabel>
                        <Select 
                          value={field.value || 'none'} 
                          onValueChange={(val: string | null) => field.onChange(val === 'none' ? '' : (val || ''))}
                        >
                          <FormControl>
                            <SelectTrigger className="w-full min-h-[48px] bg-white border-slate-300">
                              <SelectValue placeholder={loadingBrokers ? "Loading brokers..." : "Select Preferred Broker"}>
                                {field.value && field.value !== 'none' 
                                  ? brokers.find((b) => b.id === (field.value || ''))?.name || brokers.find((b) => b.id === (field.value || ''))?.mobile
                                  : "None (Auto-assign via Deal Desk)"}
                              </SelectValue>
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            <SelectItem value="none">None (Auto-assign via Deal Desk)</SelectItem>
                            {brokers.map((b) => (
                              <SelectItem key={b.id} value={b.id} className="min-h-[44px]">
                                {b.name || b.mobile}
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
            )}

            {/* STEP 6: FINAL REVIEW & SUBMISSION */}
            {currentStep === 6 && (
              <Card className="border-slate-200 shadow-md">
                <CardHeader className="pb-4 border-b border-slate-100 bg-sky-50/50">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-lg bg-[#0284C7] text-white">
                      <ShieldCheck className="w-5 h-5" />
                    </div>
                    <div>
                      <CardTitle className="text-base text-slate-900 font-bold">
                        Step 6: Review & Final Submission
                      </CardTitle>
                      <CardDescription className="text-xs text-slate-500">
                        Verify all procurement inputs before publishing to BrokerBridge Deal Desk.
                      </CardDescription>
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="pt-6 space-y-4">
                  {/* Summary Grid */}
                  <div className="rounded-xl border border-slate-200 divide-y divide-slate-100 bg-white overflow-hidden text-xs">
                    {/* What */}
                    <div className="p-3.5 flex items-center justify-between">
                      <span className="text-slate-500 font-medium">Commodity & Grade</span>
                      <span className="font-bold text-slate-900 text-right">
                        {selectedCommodity?.name || '—'} ({selectedGrade?.gradeName || '—'})
                      </span>
                    </div>

                    {/* How Much */}
                    <div className="p-3.5 flex items-center justify-between">
                      <span className="text-slate-500 font-medium">Quantity & Target Price</span>
                      <span className="font-bold text-slate-900 text-right">
                        {form.watch('quantity')} {selectedUnit?.symbol || 'Units'} @ ₹{form.watch('target_price')}/unit
                      </span>
                    </div>

                    {/* Total Budget */}
                    <div className="p-3.5 flex items-center justify-between bg-sky-50/50">
                      <span className="text-[#0284C7] font-semibold">Total Indicative Budget</span>
                      <span className="font-extrabold text-[#0284C7] text-sm">
                        ₹{(Number(form.watch('quantity')) * Number(form.watch('target_price'))).toLocaleString('en-IN')}
                      </span>
                    </div>

                    {/* Partial Fulfillment */}
                    <div className="p-3.5 flex items-center justify-between">
                      <span className="text-slate-500 font-medium">Partial Fulfillment</span>
                      <span className={cn(
                        "font-bold px-2 py-0.5 rounded-full text-[11px]",
                        form.watch('allow_partial_fulfillment') ? "bg-emerald-100 text-emerald-800" : "bg-slate-100 text-slate-700"
                      )}>
                        {form.watch('allow_partial_fulfillment') ? 'Allowed' : 'Strict Full Lot'}
                      </span>
                    </div>

                    {/* Where */}
                    <div className="p-3.5 flex items-center justify-between">
                      <span className="text-slate-500 font-medium">Delivery Destination</span>
                      <span className="font-bold text-slate-900 text-right">
                        {selectedState?.name || '—'}
                        {selectedDistrict ? `, ${selectedDistrict.name}` : ''}
                        {form.watch('delivery_city_id') ? ` (${form.watch('delivery_city_id')})` : ''}
                      </span>
                    </div>

                    {/* When */}
                    <div className="p-3.5 flex items-center justify-between">
                      <span className="text-slate-500 font-medium">Target Completion Date</span>
                      <span className="font-bold text-slate-900 text-right">
                        {form.watch('delivery_window_end') 
                          ? format(new Date(form.watch('delivery_window_end')!), 'PPP')
                          : 'Not specified'}
                      </span>
                    </div>

                    {/* Commercial Terms */}
                    <div className="p-3.5 flex items-center justify-between">
                      <span className="text-slate-500 font-medium">Commercial Terms</span>
                      <span className="font-bold text-slate-900 text-right">
                        {form.watch('freight_terms')} • {form.watch('packaging_type')}
                      </span>
                    </div>

                    {/* Payment Terms */}
                    <div className="p-3.5 flex items-center justify-between">
                      <span className="text-slate-500 font-medium">Payment Terms</span>
                      <span className="font-bold text-slate-900 text-right truncate max-w-[200px]">
                        {form.watch('payment_terms')}
                      </span>
                    </div>

                    {/* Visibility & Broker */}
                    <div className="p-3.5 flex items-center justify-between">
                      <span className="text-slate-500 font-medium">Network Visibility</span>
                      <span className="font-bold text-slate-900 text-right">
                        {form.watch('visibility') === 'global' ? 'Global Pool' : `Private (${selectedBroker?.name || 'Broker Assigned'})`}
                      </span>
                    </div>
                  </div>

                  <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-900 space-y-1">
                    <span className="font-bold block">🔒 Broker-Mediated Privacy Guarantee</span>
                    <p className="text-[11px] text-amber-800 leading-snug">
                      Your direct company contact details remain scrubbed. Only verified matching brokers on BrokerBridge will manage negotiations.
                    </p>
                  </div>
                </CardContent>
              </Card>
            )}
          </form>
        </Form>
      </div>

      {/* FIXED ACTION BAR AT BOTTOM */}
      <div className="fixed bottom-0 left-0 w-full p-4 bg-white border-t border-slate-200 z-50 flex items-center justify-between shadow-lg">
        <div className="max-w-2xl mx-auto w-full flex items-center justify-between gap-2.5">
          {/* BACK BUTTON */}
          <Button
            type="button"
            variant="outline"
            onClick={handleBack}
            disabled={currentStep === 1 || isPending}
            className={cn(
              "min-h-[48px] px-4 text-xs sm:text-sm font-semibold border-slate-300 min-w-[70px] sm:min-w-[90px]",
              currentStep === 1 && "invisible"
            )}
          >
            <ArrowLeft className="w-4 h-4 mr-1 sm:mr-2" />
            Back
          </Button>

          <div className="flex items-center gap-2 ml-auto">
            {/* SAVE AS DRAFT BUTTON */}
            <Button
              type="button"
              variant="outline"
              disabled={isPending}
              onClick={handleSaveDraft}
              className="min-h-[48px] px-3.5 sm:px-4 text-xs sm:text-sm font-semibold border-[#0284C7] text-[#0284C7] hover:bg-sky-50 shadow-xs"
            >
              {isPending ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <>
                  <FileText className="w-4 h-4 mr-1 sm:mr-1.5" />
                  Save Draft
                </>
              )}
            </Button>

            {/* NEXT / SUBMIT BUTTON */}
            {currentStep < 6 ? (
              <Button
                type="button"
                onClick={handleNext}
                disabled={isPending}
                className="min-h-[48px] px-4 sm:px-6 text-xs sm:text-sm font-semibold bg-[#0284C7] hover:bg-[#0369A1] text-white shadow-sm"
              >
                Next
                <ArrowRight className="w-4 h-4 ml-1.5" />
              </Button>
            ) : (
              <Button
                type="button"
                onClick={form.handleSubmit(onSubmit)}
                disabled={isPending}
                className="min-h-[48px] px-4 sm:px-6 text-xs sm:text-sm font-semibold bg-[#0284C7] hover:bg-[#0369A1] text-white shadow-md"
              >
                {isPending ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Saving...
                  </>
                ) : (
                  <>
                    <CheckCircle2 className="w-4 h-4 mr-1.5" />
                    {isEditMode ? 'Update Requirement' : 'Submit Requirement'}
                  </>
                )}
              </Button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
