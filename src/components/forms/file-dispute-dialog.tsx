'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { toast } from 'sonner';
import { Loader2 } from 'lucide-react';

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

import { fileDisputeSchema } from '@/src/types/transaction-schema';
import { fileDisputeAction } from '@/src/server/actions/transaction-actions';

interface FileDisputeDialogProps {
  dealId: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess?: () => void;
}

export function FileDisputeDialog({
  dealId,
  open,
  onOpenChange,
  onSuccess,
}: FileDisputeDialogProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<z.infer<typeof fileDisputeSchema>>({
    resolver: zodResolver(fileDisputeSchema),
    defaultValues: {
      deal_id: dealId,
      reason: '',
      description: '',
    },
  });

  async function onSubmit(values: z.infer<typeof fileDisputeSchema>) {
    setIsSubmitting(true);
    try {
      const res = await fileDisputeAction(values);
      if (res.success) {
        toast.success("Dispute raised successfully. Admins will review it.");
        onOpenChange(false);
        form.reset();
        if (onSuccess) onSuccess();
      } else {
        toast.error(res.error || "Failed to raise dispute.");
      }
    } catch (error: any) {
      toast.error(error.message || "An unexpected error occurred.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <DialogHeader>
          <DialogTitle className="text-destructive">Raise Formal Dispute</DialogTitle>
          <DialogDescription>
            Please provide details about the issue. This will escalate the deal to Tier 0 Admins.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 pt-4">
            <FormField
              control={form.control}
              name="reason"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Reason</FormLabel>
                  <Select onValueChange={field.onChange} value={field.value || ""}>
                    <FormControl>
                      <SelectTrigger className="h-12 min-h-[48px]">
                        <SelectValue placeholder="Select a reason" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="Quality Mismatch">Quality Mismatch</SelectItem>
                      <SelectItem value="Quantity Shortage">Quantity Shortage</SelectItem>
                      <SelectItem value="Delivery Delay">Delivery Delay</SelectItem>
                      <SelectItem value="Payment Default">Payment Default</SelectItem>
                      <SelectItem value="Other">Other</SelectItem>
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
                  <FormLabel>Description / Evidence Notes (Optional)</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Provide additional details..."
                      {...field}
                      className="min-h-[100px]"
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="flex justify-end pt-4">
              <Button 
                type="submit" 
                variant="destructive"
                className="w-full sm:w-auto h-12 min-h-[48px]"
                disabled={isSubmitting}
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Raising Dispute...
                  </>
                ) : (
                  "Raise Formal Dispute"
                )}
              </Button>
            </div>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
