'use client';

import React, { useState, useTransition } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { DollarSign, Loader2, CreditCard, ArrowRightLeft, Calendar, FileText } from 'lucide-react';
import { toast } from 'sonner';
import { logBrokerPaymentAction } from '@/src/server/actions/broker-finance-actions';

interface LogPaymentModalProps {
  isOpen: boolean;
  onClose: () => void;
  bookingId: string;
  dealId: string;
  onSuccess?: () => void;
}

export function LogPaymentModal({
  isOpen,
  onClose,
  bookingId,
  dealId,
  onSuccess,
}: LogPaymentModalProps) {
  const [isPending, startTransition] = useTransition();

  const [amount, setAmount] = useState<string>('');
  const [referenceNumber, setReferenceNumber] = useState<string>('');
  const [direction, setDirection] = useState<'Buyer to Broker' | 'Broker to Seller' | 'Direct Settlement'>('Buyer to Broker');
  const [paymentDate, setPaymentDate] = useState<string>(
    new Date().toISOString().split('T')[0]
  );
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    const numAmount = parseFloat(amount);
    if (isNaN(numAmount) || numAmount <= 0) {
      setErrorMsg('Please enter a valid positive payment amount.');
      return;
    }

    if (!referenceNumber.trim()) {
      setErrorMsg('Please enter a valid UTR or reference number.');
      return;
    }

    startTransition(async () => {
      try {
        const res = await logBrokerPaymentAction({
          bookingId,
          dealId,
          amount: numAmount,
          referenceNumber: referenceNumber.trim(),
          direction,
          paymentDate,
        });

        if (res.success) {
          toast.success('Payment Recorded Successfully', {
            description: `Logged ₹${numAmount.toLocaleString('en-IN')} (${direction}) under UTR: ${referenceNumber.trim()}`,
          });
          setAmount('');
          setReferenceNumber('');
          setErrorMsg(null);
          onClose();
          if (onSuccess) {
            onSuccess();
          }
        } else {
          setErrorMsg(res.error || 'Failed to log payment transaction.');
          toast.error('Payment Entry Failed', {
            description: res.error || 'An unexpected error occurred.',
          });
        }
      } catch (err: any) {
        setErrorMsg(err.message || 'Error executing payment logger.');
        toast.error('Payment Entry Failed', {
          description: err.message || 'Network error occurred.',
        });
      }
    });
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md bg-white border-slate-200 shadow-xl rounded-2xl p-0 overflow-hidden">
        {/* Header */}
        <div className="bg-slate-900 text-white p-5 space-y-1">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-[#0D9488]/20 flex items-center justify-center text-[#0D9488]">
              <CreditCard className="w-4 h-4" />
            </div>
            <DialogTitle className="text-lg font-bold tracking-tight text-white">
              Log Financial Transaction
            </DialogTitle>
          </div>
          <DialogDescription className="text-xs text-slate-300">
            Record a verified buyer payment or seller disbursement for this order.
          </DialogDescription>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-5 space-y-4 text-xs">
          {errorMsg && (
            <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-red-700 text-xs font-medium">
              {errorMsg}
            </div>
          )}

          {/* Payment Direction */}
          <div className="space-y-1.5">
            <Label className="text-slate-700 font-semibold text-xs flex items-center gap-1.5">
              <ArrowRightLeft className="w-3.5 h-3.5 text-teal-600" />
              Transaction Direction
            </Label>
            <Select
              value={direction}
              onValueChange={(val: any) => setDirection(val)}
            >
              <SelectTrigger className="w-full h-10 border-slate-300 focus:ring-teal-500 text-xs">
                <SelectValue placeholder="Select direction" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="Buyer to Broker">
                  Buyer to Broker (Escrow / Payable)
                </SelectItem>
                <SelectItem value="Broker to Seller">
                  Broker to Seller (Settlement / Transfer)
                </SelectItem>
                <SelectItem value="Direct Settlement">
                  Direct Settlement (Buyer to Seller)
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Amount */}
          <div className="space-y-1.5">
            <Label className="text-slate-700 font-semibold text-xs flex items-center gap-1.5">
              <DollarSign className="w-3.5 h-3.5 text-teal-600" />
              Amount Received / Disbursed (₹)
            </Label>
            <div className="relative">
              <span className="absolute left-3 top-2.5 text-slate-400 font-bold text-xs">₹</span>
              <Input
                type="number"
                step="0.01"
                placeholder="e.g. 250000"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="pl-7 h-10 border-slate-300 focus:border-teal-500 font-mono text-sm font-semibold"
                required
              />
            </div>
          </div>

          {/* UTR / Reference Number */}
          <div className="space-y-1.5">
            <Label className="text-slate-700 font-semibold text-xs flex items-center gap-1.5">
              <FileText className="w-3.5 h-3.5 text-teal-600" />
              UTR / Bank Reference Number
            </Label>
            <Input
              type="text"
              placeholder="e.g. UTR1984729102948"
              value={referenceNumber}
              onChange={(e) => setReferenceNumber(e.target.value)}
              className="h-10 border-slate-300 focus:border-teal-500 font-mono uppercase text-xs"
              required
            />
          </div>

          {/* Payment Date */}
          <div className="space-y-1.5">
            <Label className="text-slate-700 font-semibold text-xs flex items-center gap-1.5">
              <Calendar className="w-3.5 h-3.5 text-teal-600" />
              Transaction Date
            </Label>
            <Input
              type="date"
              value={paymentDate}
              onChange={(e) => setPaymentDate(e.target.value)}
              className="h-10 border-slate-300 focus:border-teal-500 text-xs"
              required
            />
          </div>

          {/* Footer Actions */}
          <DialogFooter className="pt-4 border-t border-slate-100 flex flex-col-reverse sm:flex-row sm:justify-end gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={onClose}
              disabled={isPending}
              className="border-slate-300 text-slate-700 hover:bg-slate-100 text-xs h-10 font-semibold"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={isPending}
              className="bg-[#0D9488] hover:bg-teal-700 text-white text-xs h-10 font-semibold px-5 cursor-pointer"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Recording...
                </>
              ) : (
                'Log Payment Transaction'
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
