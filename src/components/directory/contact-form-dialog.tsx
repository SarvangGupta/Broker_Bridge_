'use client';

import React, { useState, useEffect } from 'react';
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
import { Badge } from '@/components/ui/badge';
import { AlertCircle, CheckCircle2, User, Building2, Phone, Mail, MapPin, Loader2, ExternalLink } from 'lucide-react';
import { useLanguage } from '@/src/lib/i18n/language-context';
import {
  createBrokerContactAction,
  updateBrokerContactAction,
  checkContactDuplicateAction,
  DirectoryContactItem,
  DuplicateCheckResult,
} from '@/src/server/actions/broker-directory-actions';
import { validateAndNormalizePhone } from '@/src/lib/phone-utils';

interface ContactFormDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: (contactId?: string) => void;
  onSelectExisting?: (contactId: string) => void;
  initialData?: DirectoryContactItem | null;
  defaultRole?: 'buyer' | 'seller';
}

export function ContactFormDialog({
  isOpen,
  onClose,
  onSuccess,
  onSelectExisting,
  initialData,
  defaultRole = 'buyer',
}: ContactFormDialogProps) {
  const { t } = useLanguage();
  const isEditing = !!initialData;

  const [name, setName] = useState('');
  const [companyName, setCompanyName] = useState('');
  const [mobile, setMobile] = useState('');
  const [whatsapp, setWhatsapp] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState<'buyer' | 'seller'>('buyer');
  const [city, setCity] = useState('');
  const [state, setState] = useState('');
  const [notes, setNotes] = useState('');

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [duplicateWarning, setDuplicateWarning] = useState<DuplicateCheckResult | null>(null);

  // Initialize or reset form state
  useEffect(() => {
    if (initialData) {
      setName(initialData.name);
      setCompanyName(initialData.companyName);
      setMobile(initialData.mobile);
      setEmail(initialData.email || '');
      setRole(initialData.role.toLowerCase() === 'seller' ? 'seller' : 'buyer');
      setCity(initialData.city || '');
      setState(initialData.state || '');
      setNotes('');
    } else {
      setName('');
      setCompanyName('');
      setMobile('');
      setWhatsapp('');
      setEmail('');
      setRole(defaultRole);
      setCity('');
      setState('');
      setNotes('');
    }
    setFormError(null);
    setDuplicateWarning(null);
  }, [initialData, defaultRole, isOpen]);

  // Live duplicate checking on phone blur
  const handlePhoneBlur = async () => {
    if (isEditing || !mobile.trim()) return;

    const phoneRes = validateAndNormalizePhone(mobile);
    if (!phoneRes.isValid) return;

    try {
      const dup = await checkContactDuplicateAction({
        mobile: phoneRes.normalized,
        companyName,
      });

      if (dup.isDuplicate) {
        setDuplicateWarning(dup);
      } else {
        setDuplicateWarning(null);
      }
    } catch {
      // Non-blocking duplicate check
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    // Basic Validation
    if (!name.trim()) {
      setFormError(t('valNameRequired'));
      return;
    }
    if (!companyName.trim()) {
      setFormError(t('valCompanyRequired'));
      return;
    }

    const phoneRes = validateAndNormalizePhone(mobile);
    if (!phoneRes.isValid) {
      setFormError(phoneRes.error || t('valMobileRequired'));
      return;
    }

    setIsSubmitting(true);

    try {
      if (isEditing && initialData) {
        const res = await updateBrokerContactAction(initialData.id, {
          name: name.trim(),
          companyName: companyName.trim(),
          mobile: phoneRes.normalized,
          email: email.trim() || undefined,
          role,
          city: city.trim() || undefined,
          state: state.trim() || undefined,
          notes: notes.trim() || undefined,
        });

        if (!res.success) {
          setFormError(res.error || 'Failed to update contact');
          setIsSubmitting(false);
          return;
        }

        onSuccess(initialData.id);
      } else {
        const res = await createBrokerContactAction({
          name: name.trim(),
          companyName: companyName.trim(),
          mobile: phoneRes.normalized,
          whatsapp: whatsapp.trim() || undefined,
          email: email.trim() || undefined,
          role,
          city: city.trim() || undefined,
          state: state.trim() || undefined,
          notes: notes.trim() || undefined,
        });

        if (!res.success) {
          if (res.isDuplicate) {
            setDuplicateWarning({
              isDuplicate: true,
              matchType: 'exact_mobile',
            });
          }
          setFormError(res.error || 'Failed to create contact');
          setIsSubmitting(false);
          return;
        }

        onSuccess(res.contactId);
      }

      onClose();
    } catch (err: any) {
      setFormError(err.message || 'An unexpected error occurred');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-lg w-full p-4 sm:p-6 rounded-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="text-lg sm:text-xl font-bold text-slate-900 flex items-center gap-2">
            {isEditing ? t('actionEditContact') : role === 'buyer' ? t('actionAddBuyer') : t('actionAddSeller')}
          </DialogTitle>
          <DialogDescription className="text-xs text-slate-500">
            {isEditing
              ? 'Update verified counterparty details in your broker workspace.'
              : 'Add an authorized trading mandate contact. Strict duplicate prevention is enforced.'}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 pt-2">
          {/* Error Banner */}
          {formError && (
            <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs flex items-start gap-2">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 text-rose-600" />
              <span>{formError}</span>
            </div>
          )}

          {/* Duplicate Warning Callout */}
          {duplicateWarning?.isDuplicate && (
            <div className="p-3.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-900 text-xs space-y-2">
              <div className="flex items-center gap-2 font-bold text-amber-800">
                <AlertCircle className="w-4 h-4 text-amber-600 shrink-0" />
                <span>{t('duplicateWarningTitle')}</span>
              </div>
              <p className="text-amber-700 leading-relaxed">
                {t('duplicateWarningDesc')}
              </p>
              {duplicateWarning.existingContact && (
                <div className="bg-white/80 p-2.5 rounded-lg border border-amber-200/70 flex items-center justify-between gap-2">
                  <div>
                    <div className="font-bold text-slate-900">
                      {duplicateWarning.existingContact.companyName}
                    </div>
                    <div className="text-[11px] text-slate-500">
                      {duplicateWarning.existingContact.name} • {duplicateWarning.existingContact.mobile} ({duplicateWarning.existingContact.role})
                    </div>
                  </div>
                  {onSelectExisting && (
                    <Button
                      type="button"
                      size="sm"
                      variant="outline"
                      onClick={() => {
                        onClose();
                        onSelectExisting(duplicateWarning.existingContact!.id);
                      }}
                      className="text-xs h-7 text-[#0D9488] border-teal-200 hover:bg-teal-50"
                    >
                      <span>{t('viewExistingContact')}</span>
                      <ExternalLink className="w-3 h-3 ml-1" />
                    </Button>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Contact Role Switcher */}
          <div>
            <Label className="text-xs font-bold text-slate-700 mb-1.5 block">
              {t('fieldRole')} <span className="text-rose-500">*</span>
            </Label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setRole('buyer')}
                className={`py-2 px-3 text-xs font-bold rounded-xl border transition-all flex items-center justify-center gap-2 ${
                  role === 'buyer'
                    ? 'bg-blue-50 text-blue-700 border-blue-300 shadow-2xs'
                    : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
                }`}
              >
                <span>{t('tabBuyers')}</span>
                {role === 'buyer' && <CheckCircle2 className="w-3.5 h-3.5" />}
              </button>

              <button
                type="button"
                onClick={() => setRole('seller')}
                className={`py-2 px-3 text-xs font-bold rounded-xl border transition-all flex items-center justify-center gap-2 ${
                  role === 'seller'
                    ? 'bg-emerald-50 text-emerald-700 border-emerald-300 shadow-2xs'
                    : 'bg-white text-slate-600 border-slate-200 hover:bg-slate-50'
                }`}
              >
                <span>{t('tabSellers')}</span>
                {role === 'seller' && <CheckCircle2 className="w-3.5 h-3.5" />}
              </button>
            </div>
          </div>

          {/* Contact Name & Company Name */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <Label className="text-xs font-semibold text-slate-700 mb-1 block">
                {t('fieldContactName')} <span className="text-rose-500">*</span>
              </Label>
              <div className="relative">
                <User className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <Input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Ramesh Agrawal"
                  className="pl-9 text-xs h-9 rounded-xl"
                  required
                />
              </div>
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700 mb-1 block">
                {t('fieldCompanyName')} <span className="text-rose-500">*</span>
              </Label>
              <div className="relative">
                <Building2 className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <Input
                  value={companyName}
                  onChange={(e) => setCompanyName(e.target.value)}
                  placeholder="e.g. Malwa Agro Traders"
                  className="pl-9 text-xs h-9 rounded-xl"
                  required
                />
              </div>
            </div>
          </div>

          {/* Mobile Phone & WhatsApp */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <Label className="text-xs font-semibold text-slate-700 mb-1 block">
                {t('fieldMobile')} <span className="text-rose-500">*</span>
              </Label>
              <div className="relative">
                <Phone className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <Input
                  type="tel"
                  value={mobile}
                  onChange={(e) => setMobile(e.target.value)}
                  onBlur={handlePhoneBlur}
                  placeholder="98765 43210"
                  className="pl-9 text-xs h-9 rounded-xl font-mono"
                  required
                />
              </div>
              <span className="text-[10px] text-slate-400 mt-0.5 block">10-digit Indian mobile</span>
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700 mb-1 block">
                {t('fieldWhatsApp')}
              </Label>
              <div className="relative">
                <Phone className="w-3.5 h-3.5 text-emerald-500 absolute left-3 top-1/2 -translate-y-1/2" />
                <Input
                  type="tel"
                  value={whatsapp}
                  onChange={(e) => setWhatsapp(e.target.value)}
                  placeholder="Same as mobile if blank"
                  className="pl-9 text-xs h-9 rounded-xl font-mono"
                />
              </div>
            </div>
          </div>

          {/* Email & Mandi/City */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <Label className="text-xs font-semibold text-slate-700 mb-1 block">
                {t('fieldEmail')}
              </Label>
              <div className="relative">
                <Mail className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <Input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="contact@enterprise.com"
                  className="pl-9 text-xs h-9 rounded-xl"
                />
              </div>
            </div>

            <div>
              <Label className="text-xs font-semibold text-slate-700 mb-1 block">
                {t('fieldCity')}
              </Label>
              <div className="relative">
                <MapPin className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <Input
                  value={city}
                  onChange={(e) => setCity(e.target.value)}
                  placeholder="e.g. Jaipur, Kota, Indore"
                  className="pl-9 text-xs h-9 rounded-xl"
                />
              </div>
            </div>
          </div>

          {/* Business Notes */}
          <div>
            <Label className="text-xs font-semibold text-slate-700 mb-1 block">
              {t('fieldNotes')}
            </Label>
            <Textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="e.g. Preferred commodities, typical lot sizes, payment terms..."
              className="text-xs rounded-xl min-h-[70px] resize-none"
            />
          </div>

          <DialogFooter className="pt-2 gap-2 sm:gap-0">
            <Button
              type="button"
              variant="outline"
              onClick={onClose}
              disabled={isSubmitting}
              className="text-xs h-9 rounded-xl"
            >
              {t('actionCancel')}
            </Button>
            <Button
              type="submit"
              disabled={isSubmitting}
              className="text-xs h-9 rounded-xl bg-[#0D9488] hover:bg-[#0F766E] text-white shadow-2xs"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="w-3.5 h-3.5 mr-1.5 animate-spin" />
                  <span>{t('actionSave')}...</span>
                </>
              ) : (
                <span>{t('actionSave')}</span>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
