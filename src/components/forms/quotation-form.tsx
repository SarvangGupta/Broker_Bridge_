"use client"

import { useState, useEffect } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { toast } from "sonner"
import { Loader2 } from "lucide-react"

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

import { quotationSchema } from "@/src/types/quotation-schema"
import { createQuotationAction } from "@/src/server/actions/quotation-actions"
import { getBrokerAssignmentsAction } from "@/src/server/actions/broker-actions"

import { useRouter } from "next/navigation"

export function QuotationForm({ onSuccess }: { onSuccess?: () => void }) {
  const [requirements, setRequirements] = useState<any[]>([])
  const [availabilities, setAvailabilities] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const router = useRouter()

  const form = useForm<z.infer<typeof quotationSchema>>({
    resolver: zodResolver(quotationSchema),
    defaultValues: {
      requirement_id: "",
      seller_availability_id: "",
      offered_price: 0,
    }
  })

  useEffect(() => {
    async function loadOptions() {
      const res = await getBrokerAssignmentsAction()
      if (res.success && res.data) {
        setRequirements(res.data.filter(d => d.type === 'Buyer Requirement'))
        setAvailabilities(res.data.filter(d => d.type === 'Seller Availability'))
      }
      setLoading(false)
    }
    loadOptions()
  }, [])

  async function onSubmit(values: z.infer<typeof quotationSchema>) {
    try {
      const res = await createQuotationAction(values)
      if (res.success) {
        toast.success("Quotation drafted successfully!")
        form.reset()
        router.refresh()
        if (onSuccess) onSuccess()
      } else {
        toast.error(res.error || "Failed to create quotation")
      }
    } catch (e: any) {
      toast.error("Unexpected error occurred")
    }
  }

  if (loading) {
    return <div className="flex justify-center p-8"><Loader2 className="animate-spin text-muted-foreground w-6 h-6" /></div>
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
        <FormField
          control={form.control}
          name="requirement_id"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Buyer Requirement</FormLabel>
              <Select onValueChange={field.onChange} value={field.value}>
                <FormControl>
                  <SelectTrigger className="min-h-[48px] w-full">
                    <SelectValue placeholder="Select a buyer requirement">
                      {field.value && requirements.find(r => r.id === field.value) ? (
                        <span className="truncate max-w-[250px] inline-block align-bottom">
                          {requirements.find(r => r.id === field.value)?.companyName} - {requirements.find(r => r.id === field.value)?.commodityName} ({requirements.find(r => r.id === field.value)?.quantity})
                        </span>
                      ) : undefined}
                    </SelectValue>
                  </SelectTrigger>
                </FormControl>
                <SelectContent alignItemWithTrigger={false}>
                  {requirements.map((req) => (
                    <SelectItem key={req.id} value={req.id} className="min-h-[48px]">
                      {req.companyName} - {req.commodityName} ({req.quantity})
                    </SelectItem>
                  ))}
                  {requirements.length === 0 && (
                    <SelectItem value="none" disabled className="min-h-[48px]">No requirements assigned</SelectItem>
                  )}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="seller_availability_id"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Seller Availability</FormLabel>
              <Select onValueChange={field.onChange} value={field.value}>
                <FormControl>
                  <SelectTrigger className="min-h-[48px] w-full">
                    <SelectValue placeholder="Select a seller availability">
                      {field.value && availabilities.find(a => a.id === field.value) ? (
                        <span className="truncate max-w-[250px] inline-block align-bottom">
                          {availabilities.find(a => a.id === field.value)?.companyName} - {availabilities.find(a => a.id === field.value)?.commodityName} ({availabilities.find(a => a.id === field.value)?.quantity} @ ₹{availabilities.find(a => a.id === field.value)?.targetPrice})
                        </span>
                      ) : undefined}
                    </SelectValue>
                  </SelectTrigger>
                </FormControl>
                <SelectContent alignItemWithTrigger={false}>
                  {availabilities.map((av) => (
                    <SelectItem key={av.id} value={av.id} className="min-h-[48px]">
                      {av.companyName} - {av.commodityName} ({av.quantity} @ ₹{av.targetPrice})
                    </SelectItem>
                  ))}
                  {availabilities.length === 0 && (
                    <SelectItem value="none" disabled className="min-h-[48px]">No availabilities assigned</SelectItem>
                  )}
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="offered_price"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Offered Price</FormLabel>
              <FormControl>
                <Input 
                  type="number" 
                  inputMode="numeric"
                  className="min-h-[48px]"
                  placeholder="Enter quoted price" 
                  {...field} 
                  onChange={(e) => field.onChange(parseFloat(e.target.value) || 0)} 
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="valid_until"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Valid Until</FormLabel>
              <FormControl>
                <Input 
                  type="date" 
                  className="min-h-[48px]"
                  value={field.value ? new Date(field.value).toISOString().split('T')[0] : ""}
                  onChange={(e) => field.onChange(e.target.value ? new Date(e.target.value) : undefined)}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button type="submit" className="w-full min-h-[48px]" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
          Draft Quotation
        </Button>
      </form>
    </Form>
  )
}
