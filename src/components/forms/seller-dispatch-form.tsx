'use client'

import { useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { toast } from 'sonner'
import { Check, ChevronsUpDown, UploadCloud } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command'
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from '@/components/ui/popover'
import { cn } from '@/lib/utils'
import { uploadDocument } from '@/src/lib/storage-utils'
import { createDispatchAction, createInvoiceAction } from '@/src/server/actions/logistics-actions'

const MAX_FILE_SIZE = 5 * 1024 * 1024 // 5MB
const ACCEPTED_FILE_TYPES = ['application/pdf', 'image/jpeg', 'image/png']

const formSchema = z.object({
  vehicle_type_id: z.string().min(1, "Vehicle type is required"),
  vehicle_type_name: z.string().optional(),
  other_vehicle_type: z.string().optional(),
  vehicle_number: z.string().regex(/^[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}$/, "E.g., RJ14GC5511"),
  driver_name: z.string().min(2, "Driver name is required"),
  driver_mobile: z.string().regex(/^[6-9]\d{9}$/, "10-digit mobile number"),
  expected_delivery_date: z.coerce.date(),
  invoice_no: z.string().min(3, "Invoice number is required"),
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  document: z.any()
    .refine((files) => files?.length == 1, "File is required.")
    .refine((files) => files?.[0]?.size <= MAX_FILE_SIZE, `Max file size is 5MB.`)
    .refine(
      (files) => ACCEPTED_FILE_TYPES.includes(files?.[0]?.type),
      "Only .pdf, .jpg, and .png formats are supported."
    ),
}).superRefine((data, ctx) => {
  if (data.vehicle_type_name === 'Other Commercial Vehicle') {
    if (!data.other_vehicle_type || data.other_vehicle_type.length < 2) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['other_vehicle_type'],
        message: 'Please specify the vehicle type',
      });
    }
  }
})

export function SellerDispatchForm({ 
  dealId, 
  vehicleTypes, 
  onSuccess 
}: { 
  dealId: string; 
  vehicleTypes: any[];
  onSuccess?: () => void;
}) {
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [popoverOpen, setPopoverOpen] = useState(false)

  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      vehicle_type_id: "",
      vehicle_type_name: "",
      other_vehicle_type: "",
      vehicle_number: "",
      driver_name: "",
      driver_mobile: "",
      invoice_no: "",
      amount: 0,
    },
  })

  const selectedVehicleTypeName = useWatch({
    control: form.control,
    name: 'vehicle_type_name',
  })

  async function onSubmit(values: z.infer<typeof formSchema>) {
    setIsSubmitting(true)
    try {
      const file = values.document[0] as File
      
      // 1. Upload Document
      toast.info("Uploading document...")
      const fileUrl = await uploadDocument(file, dealId)

      // 2. Create Dispatch
      toast.info("Updating dispatch details...")
      const dispatchRes = await createDispatchAction({
        deal_id: dealId,
        vehicle_type_id: values.vehicle_type_id,
        vehicle_type_name: values.vehicle_type_name,
        other_vehicle_type: values.other_vehicle_type,
        vehicle_number: values.vehicle_number,
        driver_name: values.driver_name,
        driver_mobile: values.driver_mobile,
        dispatch_date: new Date(),
        expected_delivery_date: values.expected_delivery_date,
      })

      if (!dispatchRes.success) throw new Error(dispatchRes.error)

      // 3. Create Invoice
      toast.info("Saving invoice...")
      const invoiceRes = await createInvoiceAction({
        deal_id: dealId,
        invoice_no: values.invoice_no,
        amount: values.amount,
        file_url: fileUrl,
      })

      if (!invoiceRes.success) throw new Error(invoiceRes.error)

      toast.success("Deal marked as dispatched successfully!")
      onSuccess?.()
    } catch (error: any) {
      console.error(error)
      toast.error(error.message || "An error occurred during submission.")
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
        
        {/* GROUP 1: Logistics Details */}
        <div className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <FormField
              control={form.control}
              name="vehicle_type_id"
              render={({ field }) => (
                <FormItem className="flex flex-col mt-2">
                  <FormLabel className="mb-1">Vehicle Type</FormLabel>
                  <Popover open={popoverOpen} onOpenChange={setPopoverOpen}>
                    <FormControl>
                      <PopoverTrigger
                        className={cn(
                          "flex w-full items-center justify-between rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm ring-offset-background placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-ring disabled:cursor-not-allowed disabled:opacity-50 min-h-[48px] font-normal",
                          !field.value && "text-muted-foreground"
                        )}
                      >
                        <span className="truncate text-left flex-1 pr-2">
                          {field.value
                            ? vehicleTypes.find((vt) => vt.id === field.value)?.name
                            : "Select vehicle type"}
                        </span>
                        <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                      </PopoverTrigger>
                    </FormControl>
                    <PopoverContent className="w-[300px] p-0" align="start">
                      <Command>
                        <CommandInput placeholder="Search vehicle type..." />
                        <CommandList className="max-h-[300px] overflow-y-auto">
                          <CommandEmpty>No vehicle type found.</CommandEmpty>
                          <CommandGroup>
                            {[...vehicleTypes]
                              .sort((a, b) => {
                                if (a.name === 'Other Commercial Vehicle') return 1;
                                if (b.name === 'Other Commercial Vehicle') return -1;
                                return a.name.localeCompare(b.name);
                              })
                              .map((vt) => (
                              <CommandItem
                                value={vt.name}
                                key={vt.id}
                                onSelect={() => {
                                  field.onChange(vt.id)
                                  form.setValue('vehicle_type_name', vt.name)
                                  if (vt.name !== 'Other Commercial Vehicle') {
                                    form.setValue('other_vehicle_type', '')
                                    form.clearErrors('other_vehicle_type')
                                  }
                                  setPopoverOpen(false)
                                }}
                              >
                                <Check
                                  className={cn(
                                    "mr-2 h-4 w-4",
                                    vt.id === field.value ? "opacity-100" : "opacity-0"
                                  )}
                                />
                                {vt.name}
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

            {selectedVehicleTypeName === 'Other Commercial Vehicle' && (
              <FormField
                control={form.control}
                name="other_vehicle_type"
                render={({ field }) => (
                  <FormItem className="mt-2">
                    <FormLabel className="mb-1">Specify Vehicle Type *</FormLabel>
                    <FormControl>
                      <Input placeholder="e.g., Tractor Trolley, etc." className="min-h-[48px]" maxLength={20} {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            )}

            <FormField
              control={form.control}
              name="vehicle_number"
              render={({ field }) => (
                <FormItem className="mt-2">
                  <FormLabel className="mb-1">Vehicle Number</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g., RJ14GC5511" className="min-h-[48px]" maxLength={15} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="driver_name"
              render={({ field }) => (
                <FormItem className="mt-2">
                  <FormLabel className="mb-1">Driver Name</FormLabel>
                  <FormControl>
                    <Input placeholder="Driver full name" className="min-h-[48px]" maxLength={25} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="driver_mobile"
              render={({ field }) => (
                <FormItem className="mt-2">
                  <FormLabel className="mb-1">Driver Mobile</FormLabel>
                  <FormControl>
                    <Input 
                      type="tel" 
                      inputMode="numeric"
                      placeholder="10-digit number" 
                      className="min-h-[48px]" 
                      maxLength={10}
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="expected_delivery_date"
              render={({ field }) => (
                <FormItem className="mt-2">
                  <FormLabel className="mb-1">Expected Delivery Date (ETA)</FormLabel>
                  <FormControl>
                    <Input 
                      type="date" 
                      className="min-h-[48px]" 
                      {...field}
                      value={field.value ? new Date(field.value).toISOString().split('T')[0] : ''}
                      onChange={(e) => field.onChange(e.target.value)}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </div>
        </div>
        
        <div className="border-t border-border pt-6 mt-6">
          <h3 className="text-sm font-semibold text-muted-foreground mb-4">Billing & Documents</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            
            <FormField
              control={form.control}
              name="invoice_no"
              render={({ field }) => (
                <FormItem className="mt-2">
                  <FormLabel className="mb-1">Invoice Number</FormLabel>
                  <FormControl>
                    <Input placeholder="Invoice No." className="min-h-[48px]" maxLength={25} {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="amount"
              render={({ field }) => (
                <FormItem className="mt-2">
                  <FormLabel className="mb-1">Invoice Amount (₹)</FormLabel>
                  <FormControl>
                    <Input 
                      type="number" 
                      inputMode="decimal"
                      placeholder="0.00" 
                      className="min-h-[48px]" 
                      max={1000000}
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="document"
              render={({ field: { value, onChange, ...fieldProps } }) => (
                <FormItem className="col-span-full mt-2">
                  <FormLabel className="mb-1">Upload Invoice / LR (Max 5MB)</FormLabel>
                  <FormControl>
                    <div className="border-2 border-dashed rounded-lg p-6 flex flex-col items-center justify-center text-muted-foreground hover:bg-muted/50 transition-colors relative min-h-[140px]">
                      <Input 
                        type="file" 
                        accept=".pdf,.jpg,.jpeg,.png"
                        className="absolute inset-0 opacity-0 cursor-pointer h-full w-full" 
                        onChange={(event) => onChange(event.target.files)}
                        {...fieldProps} 
                      />
                      <UploadCloud className="w-10 h-10 mb-3" />
                      {value && value.length > 0 ? (
                        <div className="flex flex-col items-center text-center">
                          <span className="font-medium text-foreground break-all px-4">{value[0].name}</span>
                          <span className="text-sm mt-1 text-primary cursor-pointer relative z-10 hover:underline">Change File</span>
                        </div>
                      ) : (
                        <div className="flex flex-col items-center text-center px-4">
                          <span className="font-medium text-foreground">Click or drag file to upload</span>
                          <span className="text-sm mt-1">PDF, JPG, PNG up to 5MB</span>
                        </div>
                      )}
                    </div>
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

          </div>
        </div>

        <Button type="submit" disabled={isSubmitting} className="w-full min-h-[48px]">
          {isSubmitting ? "Uploading..." : "Submit Dispatch"}
        </Button>
      </form>
    </Form>
  )
}
