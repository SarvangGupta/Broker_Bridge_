'use client';

import React, { useState, useTransition } from 'react';
import { VetKindProductItem, submitVetKindInquiryAction } from '@/src/server/actions/vetkind-actions';
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
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { toast } from 'sonner';
import { Stethoscope, CheckCircle, Loader2, Send } from 'lucide-react';

interface InquiryModalProps {
  isOpen: boolean;
  onClose: () => void;
  preselectedProduct?: VetKindProductItem;
}

export function VetKindInquiryModal({
  isOpen,
  onClose,
  preselectedProduct,
}: InquiryModalProps) {
  const [isPending, startTransition] = useTransition();
  const [submittedRef, setSubmittedRef] = useState<string | null>(null);

  const [formData, setFormData] = useState({
    name: '',
    mobile: '',
    email: '',
    city: '',
    state: 'Haryana',
    inquiryType: preselectedProduct ? 'Farmer Product Enquiry' : 'Dealer Application',
    dairyHerdSize: '11-30 Animals',
    message: preselectedProduct
      ? `Interested in technical guidance and commercial procurement for ${preselectedProduct.name} (${preselectedProduct.sku}).`
      : 'Interested in becoming an authorized VetKind dealer/stockist in our territory.',
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    startTransition(async () => {
      const res = await submitVetKindInquiryAction({
        ...formData,
        productId: preselectedProduct?.id,
      });

      if (res.success) {
        toast.success('Inquiry Submitted Successfully!', {
          description: res.message,
        });
        setSubmittedRef(res.inquiryReference || 'VK-INQ-SUCCESS');
      } else {
        toast.error('Submission Failed', {
          description: res.error || 'Please check your inputs and try again.',
        });
      }
    });
  };

  const handleReset = () => {
    setSubmittedRef(null);
    onClose();
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && handleReset()}>
      <DialogContent className="sm:max-w-lg rounded-2xl max-h-[90vh] overflow-y-auto">
        {submittedRef ? (
          <div className="py-8 text-center space-y-4">
            <div className="w-14 h-14 bg-emerald-100 text-emerald-700 rounded-full flex items-center justify-center mx-auto">
              <CheckCircle className="w-8 h-8" />
            </div>
            <DialogTitle className="text-2xl font-bold text-slate-900">
              Enquiry Submitted!
            </DialogTitle>
            <p className="text-sm text-slate-600 max-w-sm mx-auto">
              Your inquiry has been logged under reference{' '}
              <strong className="text-emerald-800 font-mono">{submittedRef}</strong>.
              Our veterinary medical affairs specialist will contact you shortly.
            </p>
            <Button
              onClick={handleReset}
              className="bg-emerald-700 hover:bg-emerald-800 text-white font-semibold"
            >
              Done
            </Button>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <DialogHeader>
              <div className="flex items-center gap-2 text-emerald-700 font-semibold text-xs mb-1">
                <Stethoscope className="w-4 h-4" />
                <span>VETKIND ANIMAL HEALTH INDIA</span>
              </div>
              <DialogTitle className="text-xl font-bold text-slate-900">
                {preselectedProduct
                  ? `Consult on ${preselectedProduct.name}`
                  : 'Submit Veterinary Inquiry / Dealership'}
              </DialogTitle>
              <DialogDescription className="text-xs text-slate-500">
                Connect with our veterinary formulations team or apply for territory dealership.
              </DialogDescription>
            </DialogHeader>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-left">
              <div className="space-y-1.5">
                <Label htmlFor="vk-name" className="text-xs font-semibold text-slate-700">
                  Full Name *
                </Label>
                <Input
                  id="vk-name"
                  required
                  placeholder="e.g. Dr. Harpreet Singh"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="text-xs h-9"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="vk-mobile" className="text-xs font-semibold text-slate-700">
                  Mobile Number *
                </Label>
                <Input
                  id="vk-mobile"
                  required
                  type="tel"
                  placeholder="10-digit mobile"
                  value={formData.mobile}
                  onChange={(e) => setFormData({ ...formData, mobile: e.target.value })}
                  className="text-xs h-9"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="vk-city" className="text-xs font-semibold text-slate-700">
                  City / Town *
                </Label>
                <Input
                  id="vk-city"
                  required
                  placeholder="e.g. Karnal"
                  value={formData.city}
                  onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                  className="text-xs h-9"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="vk-state" className="text-xs font-semibold text-slate-700">
                  State *
                </Label>
                <Select
                  value={formData.state}
                  onValueChange={(val) => val && setFormData({ ...formData, state: val })}
                >
                  <SelectTrigger id="vk-state" className="text-xs h-9">
                    <SelectValue placeholder="Select State" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Haryana">Haryana</SelectItem>
                    <SelectItem value="Punjab">Punjab</SelectItem>
                    <SelectItem value="Gujarat">Gujarat</SelectItem>
                    <SelectItem value="Rajasthan">Rajasthan</SelectItem>
                    <SelectItem value="Uttar Pradesh">Uttar Pradesh</SelectItem>
                    <SelectItem value="Maharashtra">Maharashtra</SelectItem>
                    <SelectItem value="Madhya Pradesh">Madhya Pradesh</SelectItem>
                    <SelectItem value="Other">Other States</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5 sm:col-span-2">
                <Label htmlFor="vk-type" className="text-xs font-semibold text-slate-700">
                  Inquiry Purpose
                </Label>
                <Select
                  value={formData.inquiryType}
                  onValueChange={(val) => val && setFormData({ ...formData, inquiryType: val })}
                >
                  <SelectTrigger id="vk-type" className="text-xs h-9">
                    <SelectValue placeholder="Select purpose" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="Farmer Product Enquiry">Dairy Farmer Technical / Product Advice</SelectItem>
                    <SelectItem value="Veterinary Advisory">Practicing Veterinarian Prescription Supply</SelectItem>
                    <SelectItem value="Dealer Application">Authorized Territory Dealer / Stockist Application</SelectItem>
                    <SelectItem value="Bulk Dairy Order">Commercial Dairy Herd Institutional Order</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5 sm:col-span-2">
                <Label htmlFor="vk-herd" className="text-xs font-semibold text-slate-700">
                  Dairy Herd / Clinic Scale
                </Label>
                <Select
                  value={formData.dairyHerdSize}
                  onValueChange={(val) => val && setFormData({ ...formData, dairyHerdSize: val })}
                >
                  <SelectTrigger id="vk-herd" className="text-xs h-9">
                    <SelectValue placeholder="Scale" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1-10 Animals">Smallholder Dairy (1-10 Cattle/Buffalo)</SelectItem>
                    <SelectItem value="11-30 Animals">Progressive Dairy Farm (11-30 Bovines)</SelectItem>
                    <SelectItem value="30+ Commercial Dairy">Commercial Enterprise Dairy (30+ High Yielders)</SelectItem>
                    <SelectItem value="Veterinary Clinic / Hospital">Veterinary Clinic / Hospital Pharmacy</SelectItem>
                    <SelectItem value="Agrovet Retail Store">Agrovet Retail / Chemist Store</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5 sm:col-span-2">
                <Label htmlFor="vk-msg" className="text-xs font-semibold text-slate-700">
                  Message / Clinical Symptoms / Requirements *
                </Label>
                <Textarea
                  id="vk-msg"
                  required
                  rows={3}
                  value={formData.message}
                  onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                  placeholder="Detail your requirements, current herd symptoms, or dealership location..."
                  className="text-xs resize-none"
                />
              </div>
            </div>

            <DialogFooter className="pt-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={onClose}
                disabled={isPending}
                className="text-xs"
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={isPending}
                className="bg-emerald-700 hover:bg-emerald-800 text-white text-xs font-semibold"
              >
                {isPending ? (
                  <>
                    <Loader2 className="w-3.5 h-3.5 mr-1 animate-spin" />
                    Submitting...
                  </>
                ) : (
                  <>
                    <Send className="w-3.5 h-3.5 mr-1" />
                    Submit Enquiry
                  </>
                )}
              </Button>
            </DialogFooter>
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
}
