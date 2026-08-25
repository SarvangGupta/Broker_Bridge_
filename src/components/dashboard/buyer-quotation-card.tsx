'use client';

import { useState } from 'react';
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { toast } from 'sonner';
import { format } from 'date-fns';
import { Loader2 } from 'lucide-react';
import { acceptQuotationAction, rejectQuotationAction, counterQuotationAction } from '@/src/server/actions/deal-actions';

import { TableRow, TableCell } from '@/components/ui/table';
import { VerificationBadge, TrustScore } from '@/src/components/ui/trust-badge';
import { SlaCountdown } from '@/src/components/ui/sla-badge';

interface QuotationCardProps {
  quotationData: any;
  onActionComplete: () => void;
  variant?: 'desktop' | 'mobile';
}

export function BuyerQuotationCard({ quotationData, onActionComplete, variant = 'mobile' }: QuotationCardProps) {
  const { quotation, requirement, commodity, grade, sellerCompany } = quotationData;

  const [isLoading, setIsLoading] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [counterPrice, setCounterPrice] = useState('');
  const [counterNotes, setCounterNotes] = useState('');

  const [isRejectOpen, setIsRejectOpen] = useState(false);
  const [isCounterOpen, setIsCounterOpen] = useState(false);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Accepted': return 'bg-green-500/10 text-green-700 hover:bg-green-500/20';
      case 'Rejected': return 'bg-red-500/10 text-red-700 hover:bg-red-500/20';
      case 'Countered': return 'bg-amber-500/10 text-amber-700 hover:bg-amber-500/20';
      default: return 'bg-blue-500/10 text-blue-700 hover:bg-blue-500/20';
    }
  };

  const handleAccept = async () => {
    setIsLoading(true);
    const result = await acceptQuotationAction({ quotation_id: quotation.id });
    setIsLoading(false);
    
    if (result.success) {
      toast.success("Deal booked successfully!");
      onActionComplete();
    } else {
      toast.error(result.error || "Failed to accept deal");
    }
  };

  const handleReject = async () => {
    if (rejectReason.length < 3) {
      toast.error("Rejection reason must be at least 3 characters");
      return;
    }
    setIsLoading(true);
    const result = await rejectQuotationAction({ quotation_id: quotation.id, reason: rejectReason });
    setIsLoading(false);

    if (result.success) {
      toast.success("Quotation rejected.");
      setIsRejectOpen(false);
      onActionComplete();
    } else {
      toast.error(result.error || "Failed to reject quotation");
    }
  };

  const handleCounter = async () => {
    const price = parseFloat(counterPrice);
    if (isNaN(price) || price <= 0) {
      toast.error("Please enter a valid positive price");
      return;
    }

    setIsLoading(true);
    const result = await counterQuotationAction({ 
      quotation_id: quotation.id, 
      counter_price: price,
      counter_notes: counterNotes
    });
    setIsLoading(false);

    if (result.success) {
      toast.success("Counter offer submitted.");
      setIsCounterOpen(false);
      onActionComplete();
    } else {
      toast.error(result.error || "Failed to counter quotation");
    }
  };

  const canAction = quotation.status === 'Sent' || quotation.status === 'Revised Sent';

  const actionButtons = (
    <div className="flex gap-2 w-full">
      {canAction ? (
        <>
          <Button 
            className="flex-1 min-h-[44px] bg-green-600 hover:bg-green-700 text-white font-semibold cursor-pointer" 
            onClick={handleAccept}
            disabled={isLoading}
            size="sm"
          >
            {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Accept
          </Button>

          <Button 
            variant="outline" 
            className="flex-1 min-h-[44px] border-amber-500 text-amber-600 hover:bg-amber-50 cursor-pointer" 
            disabled={isLoading}
            onClick={() => setIsCounterOpen(true)}
            size="sm"
          >
            Counter
          </Button>

          <Button 
            variant="destructive" 
            className="flex-1 min-h-[44px] cursor-pointer" 
            disabled={isLoading}
            onClick={() => setIsRejectOpen(true)}
            size="sm"
          >
            Reject
          </Button>
        </>
      ) : (
        <span className="text-muted-foreground text-sm flex-1 text-center py-2">No actions available</span>
      )}
    </div>
  );

  const dialogs = (
    <>
      <Dialog open={isCounterOpen} onOpenChange={setIsCounterOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Counter Offer</DialogTitle>
            <DialogDescription>
              Propose a new price for {commodity.name}. This will be sent back to the broker/seller.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor={`price-${quotation.id}`}>Counter Price (₹)</Label>
              <Input 
                id={`price-${quotation.id}`} 
                type="number" 
                placeholder="e.g. 5200" 
                value={counterPrice}
                onChange={(e) => setCounterPrice(e.target.value)}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor={`notes-${quotation.id}`}>Notes (Optional)</Label>
              <Textarea 
                id={`notes-${quotation.id}`} 
                placeholder="Add any terms or conditions..." 
                value={counterNotes}
                onChange={(e) => setCounterNotes(e.target.value)}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsCounterOpen(false)}>Cancel</Button>
            <Button onClick={handleCounter} disabled={isLoading}>
              {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Submit Counter
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={isRejectOpen} onOpenChange={setIsRejectOpen}>
        <DialogContent className="sm:max-w-[425px]">
          <DialogHeader>
            <DialogTitle>Reject Quotation</DialogTitle>
            <DialogDescription>
              Please provide a reason for rejecting this quotation.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor={`reason-${quotation.id}`}>Rejection Reason</Label>
              <Textarea 
                id={`reason-${quotation.id}`} 
                placeholder="e.g. Price is too high, quality issues..." 
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsRejectOpen(false)}>Cancel</Button>
            <Button variant="destructive" onClick={handleReject} disabled={isLoading}>
              {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Confirm Reject
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );

  if (variant === 'desktop') {
    return (
      <TableRow>
        <TableCell className="font-medium">
          {commodity.name} <span className="text-muted-foreground font-normal ml-1">• {grade.gradeName}</span>
        </TableCell>
        <TableCell>
          <div className="flex flex-col gap-1">
            <span className="font-semibold text-slate-900">{sellerCompany?.name || 'Unknown Supplier'}</span>
            <div className="flex items-center gap-1.5 flex-wrap">
              {sellerCompany?.isVerified && <VerificationBadge compact />}
              <TrustScore score={sellerCompany?.trustScore} compact />
            </div>
          </div>
        </TableCell>
        <TableCell className="text-right font-bold text-primary">₹{quotation.offeredPrice}</TableCell>
        <TableCell className="text-right">{requirement.quantity} units</TableCell>
        <TableCell className="text-center">
          <Badge variant="secondary" className={getStatusColor(quotation.status)}>
            {quotation.status === 'Revised Sent' ? 'New Revised Offer' : quotation.status}
          </Badge>
          {quotation.counterPrice && (
            <div className="text-[10px] text-amber-600 mt-1">Counter: ₹{quotation.counterPrice}</div>
          )}
          <div className="mt-1.5 flex justify-center">
            <SlaCountdown targetDate={quotation.validUntil} compact />
          </div>
        </TableCell>
        <TableCell className="text-right min-w-[200px]">
          {actionButtons}
          {dialogs}
        </TableCell>
      </TableRow>
    );
  }

  return (
    <Card className="w-full flex flex-col justify-between shadow-sm hover:shadow-md transition-shadow bg-white rounded-xl overflow-hidden border-slate-200">
      <CardHeader className="pb-3 border-b border-slate-100 p-4">
        <div className="flex justify-between items-start">
          <div>
            <CardTitle className="text-lg text-primary">{commodity.name} - {grade.gradeName}</CardTitle>
            <p className="text-sm text-muted-foreground mt-1">Target: ₹{requirement.targetPrice}/unit</p>
          </div>
          <Badge variant="secondary" className={getStatusColor(quotation.status)}>
            {quotation.status === 'Revised Sent' ? 'New Revised Offer' : quotation.status}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="py-4 space-y-3">
        <div className="flex justify-between items-center bg-muted/20 p-3 rounded-lg border">
          <div className="flex flex-col">
            <span className="text-xs text-muted-foreground">Offered Price</span>
            <span className="text-xl font-bold text-primary">₹{quotation.offeredPrice}</span>
          </div>
          <div className="flex flex-col items-end">
            <span className="text-xs text-muted-foreground">Quantity Required</span>
            <span className="text-base font-semibold">{requirement.quantity} units</span>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
          <div className="flex flex-col">
            <span className="text-muted-foreground text-xs">Seller</span>
            <span className="font-semibold text-slate-900 line-clamp-1">{sellerCompany.name}</span>
            <div className="flex items-center gap-1.5 mt-1 flex-wrap">
              {sellerCompany?.isVerified && <VerificationBadge compact />}
              <TrustScore score={sellerCompany?.trustScore} compact />
            </div>
          </div>
          <div className="flex flex-col">
            <span className="text-muted-foreground text-xs">Offer Deadline</span>
            <span className="font-medium text-xs text-slate-700">{format(new Date(quotation.validUntil), 'MMM dd, yyyy h:mm a')}</span>
            <div className="mt-1">
              <SlaCountdown targetDate={quotation.validUntil} />
            </div>
          </div>
        </div>
        
        {quotation.counterPrice && (
          <div className="mt-2 text-sm p-2 bg-amber-50 rounded text-amber-800 border border-amber-200">
            <strong>Your Counter: </strong> ₹{quotation.counterPrice}
            {quotation.counterNotes && <span className="block text-xs mt-1 italic">"{quotation.counterNotes}"</span>}
          </div>
        )}
      </CardContent>

      {canAction && (
        <div className="border-t border-slate-100 bg-slate-50 p-2">
          {actionButtons}
        </div>
      )}
      {dialogs}
    </Card>
  );
}
