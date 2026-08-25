"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { toast } from "sonner"
import { Loader2, Headphones, Send } from "lucide-react"

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { Button } from "@/components/ui/button"

import { supportTicketSchema } from "@/src/types/support-schema"
import { createSupportTicketAction } from "@/src/server/actions/support-actions"

interface SupportDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

const ISSUE_TYPES = [
  "Technical Bug",
  "Deal Issue",
  "Master Data Request",
  "Account & KYC",
  "Other",
]

export function SupportDialog({ open, onOpenChange }: SupportDialogProps) {
  const form = useForm<z.infer<typeof supportTicketSchema>>({
    resolver: zodResolver(supportTicketSchema),
    defaultValues: {
      issue_type: "",
      description: "",
    },
  })

  async function onSubmit(values: z.infer<typeof supportTicketSchema>) {
    try {
      const res = await createSupportTicketAction(values)
      if (res.success) {
        toast.success("Ticket sent to Admin.")
        form.reset()
        onOpenChange(false)
      } else {
        toast.error(res.error || "Failed to submit ticket")
      }
    } catch (e) {
      toast.error("Unexpected error occurred. Please try again.")
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[480px] p-6 bg-white rounded-2xl">
        <DialogHeader className="text-left pb-2">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-slate-800 shrink-0">
              <Headphones className="w-5 h-5" />
            </div>
            <div>
              <DialogTitle className="text-xl font-bold text-slate-900">Contact Admin Support</DialogTitle>
              <DialogDescription className="text-xs text-slate-500 mt-0.5">
                Report a technical bug, deal dispute, or request assistance from Tier 0 Admin.
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 pt-2">
            <FormField
              control={form.control}
              name="issue_type"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-semibold text-slate-700">Issue Category</FormLabel>
                  <Select onValueChange={field.onChange} value={field.value || ""}>
                    <FormControl>
                      <SelectTrigger className="w-full min-h-[48px] rounded-xl border-slate-200 text-sm">
                        <SelectValue placeholder="Select issue category" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {ISSUE_TYPES.map((type) => (
                        <SelectItem key={type} value={type} className="min-h-[44px] cursor-pointer">
                          {type}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-semibold text-slate-700">
                    Describe your issue / request
                  </FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Please provide details about what happened or what you need help with (min 10 characters)..."
                      className="min-h-[110px] rounded-xl border-slate-200 resize-y text-sm leading-relaxed"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="pt-2">
              <Button
                type="submit"
                className="w-full min-h-[48px] bg-slate-900 hover:bg-slate-800 text-white font-semibold rounded-xl text-sm shadow-sm flex items-center justify-center gap-2 cursor-pointer transition-all"
                disabled={form.formState.isSubmitting}
              >
                {form.formState.isSubmitting ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Send className="h-4 w-4" />
                )}
                Submit Support Ticket
              </Button>
            </div>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}
