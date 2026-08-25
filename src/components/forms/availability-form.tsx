"use client"

import { useState, useEffect } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { Loader2, Check, ChevronsUpDown, CalendarIcon } from "lucide-react"
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

import { availabilitySchema, AvailabilitySchema } from "@/src/types/availability-schema"
import { createAvailabilityAction } from "@/src/server/actions/availability-actions"
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
      quantity: 0,
      unit_id: "",
      price: 0,
      state_id: "",
      district_id: "",
      valid_until: undefined,
      visibility: "global",
      broker_id: "",
    },
  })

  const selectedCommodityId = form.watch("commodity_id")
  const visibility = form.watch("visibility")

  const filteredCategories = selectedIndustryId 
    ? categories.filter((c: any) => c.industryId === selectedIndustryId)
    : []

  const filteredCommodities = selectedCategoryId 
    ? commodities.filter((c: any) => c.categoryId === selectedCategoryId)
    : []

  const filteredGrades = grades.filter((g: any) => g.commodityId === selectedCommodityId)

  const selectedStateId = form.watch("state_id")
  const filteredDistricts = districts.filter((d: any) => d.stateId === selectedStateId)

  async function onSubmit(data: AvailabilitySchema) {
    setIsSubmitting(true)
    try {
      const result = await createAvailabilityAction(data)
      
      if (result.success) {
        toast.success("Availability posted successfully!")
        form.reset({
          commodity_id: "",
          grade_id: "",
          quantity: 0,
          unit_id: "",
          price: 0,
          state_id: "",
          district_id: "",
          valid_until: undefined,
        })
        setSelectedIndustryId("")
        setSelectedCategoryId("")
        onSuccess?.()
      } else {
        toast.error(result.error || "Failed to post availability.")
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
        
        {/* ROW 1: Industry & Category (Cascading Selects) */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Industry Select */}
          <div className="flex flex-col space-y-2">
            <label className="text-sm font-medium leading-none text-slate-800">
              Industry
            </label>
            <Select
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
                  <SelectItem key={ind.id} value={ind.id} className="min-h-[44px]">
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
              disabled={!selectedIndustryId || loadingCategories}
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
                  <SelectItem key={cat.id} value={cat.id} className="min-h-[44px]">
                    {cat.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        {/* ROW 2: Commodity & Quality Parameter */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Commodity Combobox */}
          <FormField
            control={form.control}
            name="commodity_id"
            render={({ field }) => (
              <FormItem className="flex flex-col">
                <FormLabel>Commodity</FormLabel>
                <Popover open={openCommodity} onOpenChange={setOpenCommodity}>
                  <FormControl>
                    <PopoverTrigger
                      disabled={!selectedCategoryId || loadingCommodities}
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
                      <CommandInput placeholder="Search commodity..." />
                      <CommandList>
                        <CommandEmpty>No commodity found.</CommandEmpty>
                        <CommandGroup>
                          {filteredCommodities.map((commodity: any) => (
                            <CommandItem
                              key={commodity.id}
                              value={commodity.name}
                              onSelect={() => {
                                form.setValue("commodity_id", commodity.id)
                                form.setValue("grade_id", "") // reset grade
                                setOpenCommodity(false)
                              }}
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

          {/* Quality Parameter (Grade) Combobox */}
          <FormField
            control={form.control}
            name="grade_id"
            render={({ field }) => (
              <FormItem className="flex flex-col">
                <FormLabel>Quality Parameter</FormLabel>
                <Popover open={openGrade} onOpenChange={setOpenGrade}>
                  <FormControl>
                    <PopoverTrigger
                      disabled={!selectedCommodityId || loadingGrades}
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
                      <CommandInput placeholder="Search quality parameter..." />
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

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Quantity Input */}
          <FormField
            control={form.control}
            name="quantity"
            render={({ field }) => (
              <FormItem>
                <FormLabel>Quantity</FormLabel>
                <FormControl>
                  <Input 
                    type="number" 
                    inputMode="decimal"
                    placeholder="Enter quantity" 
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

          {/* Unit Combobox */}
          <FormField
            control={form.control}
            name="unit_id"
            render={({ field }) => (
              <FormItem className="flex flex-col">
                <FormLabel>Unit</FormLabel>
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

        {/* Price */}
        <FormField
          control={form.control}
          name="price"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Price (per unit)</FormLabel>
              <FormControl>
                <Input 
                  type="number"
                  inputMode="decimal"
                  placeholder="Enter price" 
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

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* State Combobox */}
          <FormField
            control={form.control}
            name="state_id"
            render={({ field }) => (
              <FormItem className="flex flex-col">
                <FormLabel>Warehouse State</FormLabel>
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
                                form.setValue("district_id", "") // reset district
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

          {/* District Combobox */}
          <FormField
            control={form.control}
            name="district_id"
            render={({ field }) => (
              <FormItem className="flex flex-col">
                <FormLabel>Warehouse District</FormLabel>
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

        {/* Valid Until Calendar Picker */}
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
                    disabled={(date: Date) => date <= new Date()}
                  />
                </PopoverContent>
              </Popover>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="visibility"
          render={({ field }) => (
            <FormItem className="space-y-3">
              <FormLabel>Search Visibility</FormLabel>
              <FormControl>
                <RadioGroup
                  onValueChange={field.onChange}
                  value={field.value}
                  className="flex flex-col space-y-2"
                >
                  <FormItem className="flex items-center space-x-3 space-y-0 rounded-md border p-4">
                    <FormControl>
                      <RadioGroupItem value="global" />
                    </FormControl>
                    <div className="space-y-1 leading-none">
                      <FormLabel className="font-normal cursor-pointer">
                        <span className="font-medium">Global Pool</span> (Allow any broker on the platform to match this deal)
                      </FormLabel>
                    </div>
                  </FormItem>
                  <FormItem className="flex items-center space-x-3 space-y-0 rounded-md border p-4">
                    <FormControl>
                      <RadioGroupItem value="restricted" />
                    </FormControl>
                    <div className="space-y-1 leading-none">
                      <FormLabel className="font-normal cursor-pointer">
                        <span className="font-medium">Private Network</span> (Only allow my Preferred Broker to see and match this)
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
                  <SelectItem value="none">None (Auto-assign via Deal Desk)</SelectItem>
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

        <Button type="submit" className="w-full min-h-[48px] text-lg" disabled={isSubmitting}>
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
