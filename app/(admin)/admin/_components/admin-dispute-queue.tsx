'use client';

import { useEffect, useState } from "react"
import { format } from "date-fns"
import { toast } from "sonner"
import { Loader2, ShieldCheck } from "lucide-react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
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
import { Textarea } from "@/components/ui/textarea"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"

import { getOpenDisputesAction, resolveDisputeAction } from "@/src/server/actions/transaction-actions"
import { resolveDisputeSchema } from "@/src/types/transaction-schema"
import { RoleBadge } from "./role-badge"

export function AdminDisputeQueue() {
  const [disputes, setDisputes] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [resolvingDispute, setResolvingDispute] = useState<any>(null)

  const loadDisputes = async () => {
    setIsLoading(true)
    const res = await getOpenDisputesAction()
    if (res.success && res.data) {
      setDisputes(res.data)
    } else {
      toast.error(res.error || "Failed to load disputes.")
    }
    setIsLoading(false)
  }

  useEffect(() => {
    loadDisputes()
  }, [])

  return (
    <div className="space-y-4">
      {isLoading ? (
        <div className="flex justify-center p-12 bg-white border border-slate-200 rounded-xl shadow-sm">
          <Loader2 className="h-8 w-8 animate-spin text-[#475569]" />
        </div>
      ) : disputes.length === 0 ? (
        <div className="flex flex-col justify-center items-center h-48 border border-slate-200 rounded-xl bg-white shadow-sm gap-2">
          <p className="text-slate-500 font-medium">No open disputes found.</p>
          <p className="text-sm text-slate-400">All clear!</p>
        </div>
      ) : (
        <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
          <Table>
            <TableHeader className="bg-slate-50 border-b border-slate-200">
              <TableRow>
                <TableHead className="text-slate-600 font-semibold">Dispute Info</TableHead>
                <TableHead className="text-slate-600 font-semibold">Deal Info</TableHead>
                <TableHead className="text-slate-600 font-semibold">Parties Involved</TableHead>
                <TableHead className="text-slate-600 font-semibold">Reason</TableHead>
                <TableHead className="text-center text-slate-600 font-semibold">Status</TableHead>
                <TableHead className="text-right text-slate-600 font-semibold">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {disputes.map((row) => (
                <TableRow key={row.dispute.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                  <TableCell>
                    <div className="font-mono text-xs text-slate-500 mb-1">{row.dispute.id.split('-')[0]}...</div>
                    <div className="text-sm font-medium text-[#334155]">{format(new Date(row.dispute.createdAt), "MMM d, yyyy")}</div>
                  </TableCell>
                  <TableCell>
                    <div className="text-sm font-medium text-[#334155] mb-1">Deal: {row.deal.id.split('-')[0]}...</div>
                    <div className="text-xs font-semibold text-slate-600">{row.commodity.name} - ₹{row.deal.agreedPrice}</div>
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-col gap-1.5 mt-1">
                      <div className="flex items-center gap-2">
                        <RoleBadge role="buyer" />
                        <span className="text-xs font-medium text-slate-700">{row.buyerCompany.name}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        <RoleBadge role="seller" />
                        <span className="text-xs font-medium text-slate-700">{row.sellerCompany.name}</span>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell>
                    <Badge variant="outline" className="bg-slate-100 text-slate-700 border-slate-200">{row.dispute.reason}</Badge>
                    {row.dispute.description && (
                      <div className="mt-2 text-xs text-slate-500 truncate w-48" title={row.dispute.description}>
                        {row.dispute.description}
                      </div>
                    )}
                  </TableCell>
                  <TableCell className="text-center">
                    <Badge variant="destructive" className="bg-red-50 text-red-700 border border-red-200 shadow-none hover:bg-red-50">{row.dispute.status}</Badge>
                  </TableCell>
                  <TableCell className="text-right">
                    <Button 
                      size="sm" 
                      onClick={() => setResolvingDispute(row)}
                      className="gap-2 h-9 bg-[#334155] hover:bg-[#1e293b] text-white"
                    >
                      <ShieldCheck className="h-4 w-4" />
                      Resolve
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}

      {resolvingDispute && (
        <ResolveDisputeDialog 
          disputeData={resolvingDispute} 
          open={!!resolvingDispute} 
          onOpenChange={(open) => {
            if (!open) setResolvingDispute(null)
          }}
          onSuccess={loadDisputes}
        />
      )}
    </div>
  )
}

interface ResolveDisputeDialogProps {
  disputeData: any;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess?: () => void;
}

function ResolveDisputeDialog({ disputeData, open, onOpenChange, onSuccess }: ResolveDisputeDialogProps) {
  const [isSubmitting, setIsSubmitting] = useState(false)

  const form = useForm<z.infer<typeof resolveDisputeSchema>>({
    resolver: zodResolver(resolveDisputeSchema),
    defaultValues: {
      dispute_id: disputeData.dispute.id,
      deal_id: disputeData.deal.id,
      resolution_notes: '',
      final_deal_status: 'Cancelled',
    },
  })

  async function onSubmit(values: z.infer<typeof resolveDisputeSchema>) {
    setIsSubmitting(true)
    try {
      const res = await resolveDisputeAction(values)
      if (res.success) {
        toast.success("Dispute resolved successfully.")
        onOpenChange(false)
        if (onSuccess) onSuccess()
      } else {
        toast.error(res.error || "Failed to resolve dispute.")
      }
    } catch (error: any) {
      toast.error(error.message || "An unexpected error occurred.")
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>Admin Dispute Resolution</DialogTitle>
          <DialogDescription>
            You are acting as Tier 0 Admin. Decide the outcome of this dispute.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 pt-4">
            <div className="rounded-md border p-4 bg-slate-50 border-slate-200 mb-4">
              <h4 className="text-sm font-semibold mb-2 text-[#334155]">Dispute Details</h4>
              <p className="text-sm text-slate-600"><strong>Reason:</strong> {disputeData.dispute.reason}</p>
              <p className="text-sm text-slate-600"><strong>Description:</strong> {disputeData.dispute.description || 'None'}</p>
            </div>

            <FormField
              control={form.control}
              name="resolution_notes"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Resolution Notes</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Explain your decision..."
                      {...field}
                      className="min-h-[100px]"
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="final_deal_status"
              render={({ field }) => (
                <FormItem className="space-y-3">
                  <FormLabel>Final Deal Status</FormLabel>
                  <FormControl>
                    <RadioGroup
                      onValueChange={field.onChange}
                      value={field.value}
                      className="flex flex-col space-y-1"
                    >
                      <FormItem className="flex items-center space-x-3 space-y-0">
                        <FormControl>
                          <RadioGroupItem value="Cancelled" className="h-6 w-6" />
                        </FormControl>
                        <FormLabel className="font-normal text-base cursor-pointer">
                          Cancel Deal (Rollback)
                        </FormLabel>
                      </FormItem>
                      <FormItem className="flex items-center space-x-3 space-y-0">
                        <FormControl>
                          <RadioGroupItem value="Closed" className="h-6 w-6" />
                        </FormControl>
                        <FormLabel className="font-normal text-base cursor-pointer">
                          Close Deal (Settle)
                        </FormLabel>
                      </FormItem>
                    </RadioGroup>
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="flex justify-end pt-4">
              <Button 
                type="submit" 
                className="w-full sm:w-auto h-12 min-h-[48px] bg-[#334155] hover:bg-[#1e293b]"
                disabled={isSubmitting}
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Resolving...
                  </>
                ) : (
                  "Finalize Resolution"
                )}
              </Button>
            </div>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}
