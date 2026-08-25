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

import { paymentSchema } from '@/src/types/transaction-schema';
import { confirmPaymentAction } from '@/src/server/actions/transaction-actions';

interface PaymentConfirmationDialogProps {
  dealId: string;
  amount: number | string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess?: () => void;
}

export function PaymentConfirmationDialog({
  dealId,
  amount,
  open,
  onOpenChange,
  onSuccess,
}: PaymentConfirmationDialogProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<z.infer<typeof paymentSchema>>({
    resolver: zodResolver(paymentSchema),
    defaultValues: {
      deal_id: dealId,
      amount: Number(amount),
      reference_number: '',
    },
  });

  async function onSubmit(values: z.infer<typeof paymentSchema>) {
    setIsSubmitting(true);
    try {
      const res = await confirmPaymentAction(values);
      if (res.success) {
        toast.success("Payment confirmed successfully!");
        onOpenChange(false);
        form.reset();
        if (onSuccess) onSuccess();
      } else {
        toast.error(res.error || "Failed to confirm payment.");
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
          <DialogTitle>Confirm Payment</DialogTitle>
          <DialogDescription>
            Enter payment reference details to mark this deal as closed.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 pt-4">
            <FormField
              control={form.control}
              name="amount"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Amount (₹)</FormLabel>
                  <FormControl>
                    <Input
                      type="number"
                      placeholder="Enter amount"
                      {...field}
                      className="h-12 min-h-[48px]"
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="reference_number"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Reference Number / UTR</FormLabel>
                  <FormControl>
                    <Input
                      placeholder="e.g. UTR123456789"
                      {...field}
                      className="h-12 min-h-[48px]"
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="flex justify-end pt-4">
              <Button 
                type="submit" 
                className="w-full sm:w-auto h-12 min-h-[48px]"
                disabled={isSubmitting}
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Confirming...
                  </>
                ) : (
                  "Confirm Payment & Close Deal"
                )}
              </Button>
            </div>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}
