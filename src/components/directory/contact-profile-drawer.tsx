'use client';

import React, { useState, useEffect } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import {
  Phone,
  MessageSquare,
  Edit2,
  Building2,
  User,
  ShieldCheck,
  MapPin,
  Mail,
  Calendar,
  Layers,
  Package,
  Handshake,
  Activity,
  CheckCircle2,
  XCircle,
  Clock,
  Loader2,
  Power,
} from 'lucide-react';
import { useLanguage } from '@/src/lib/i18n/language-context';
import {
  getBrokerContactDetailsAction,
  toggleContactStatusAction,
  ContactDetailsPayload,
  DirectoryContactItem,
} from '@/src/server/actions/broker-directory-actions';
import { getSafeTelUri, getSafeWhatsAppUri } from '@/src/lib/phone-utils';

interface ContactProfileDrawerProps {
  contactId: string | null;
  onClose: () => void;
  onEdit: (contact: DirectoryContactItem) => void;
  onStatusChanged: () => void;
}

export function ContactProfileDrawer({
  contactId,
  onClose,
  onEdit,
  onStatusChanged,
}: ContactProfileDrawerProps) {
  const { t, formatCurrency, formatNumber, formatDate } = useLanguage();

  const [loading, setLoading] = useState(false);
  const [details, setDetails] = useState<ContactDetailsPayload | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'overview' | 'requirements' | 'offers' | 'deals' | 'activity'>('overview');
  const [togglingStatus, setTogglingStatus] = useState(false);

  useEffect(() => {
    if (!contactId) {
      setDetails(null);
      return;
    }

    setLoading(true);
    setError(null);

    getBrokerContactDetailsAction(contactId)
      .then((res) => {
        if (res.success && res.data) {
          setDetails(res.data);
          // Set sensible default tab based on role
          if (res.data.contact.role === 'Buyer' && res.data.associatedRequirements.length > 0) {
            setActiveTab('requirements');
          } else if (res.data.contact.role === 'Seller' && res.data.associatedOffers.length > 0) {
            setActiveTab('offers');
          } else {
            setActiveTab('overview');
          }
        } else {
          setError(res.error || 'Failed to load contact details');
        }
      })
      .catch((err) => {
        setError(err.message || 'An unexpected error occurred');
      })
      .finally(() => {
        setLoading(false);
      });
  }, [contactId]);

  if (!contactId) return null;

  const handleToggleStatus = async () => {
    if (!details) return;
    setTogglingStatus(true);
    try {
      const res = await toggleContactStatusAction(details.contact.id);
      if (res.success && res.newStatus !== undefined) {
        setDetails((prev) =>
          prev
            ? {
                ...prev,
                contact: { ...prev.contact, status: res.newStatus! },
              }
            : null
        );
        onStatusChanged();
      }
    } catch {
      // Ignored
    } finally {
      setTogglingStatus(false);
    }
  };

  const contact = details?.contact;
  const telUri = contact ? getSafeTelUri(contact.mobile) : null;
  const waUri = contact ? getSafeWhatsAppUri(contact.mobile, `Hello ${contact.name}, reaching out from BrokerBridge workstation.`) : null;

  return (
    <Dialog open={!!contactId} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-w-2xl w-full p-4 sm:p-6 rounded-2xl max-h-[92vh] overflow-y-auto">
        <DialogHeader className="border-b border-slate-100 pb-4">
          <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-3">
            <div className="min-w-0 flex-1 space-y-1">
              <div className="flex items-center gap-2 flex-wrap">
                <Badge
                  className={`text-[10px] font-bold uppercase tracking-wider py-0.5 px-2 ${
                    contact?.role === 'Buyer'
                      ? 'bg-blue-100 text-blue-800 border-blue-200'
                      : 'bg-emerald-100 text-emerald-800 border-emerald-200'
                  }`}
                >
                  {contact?.role === 'Buyer' ? t('badgeBuyer') : t('badgeSeller')}
                </Badge>

                {contact?.isVerified && (
                  <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                    <ShieldCheck className="w-3 h-3" />
                    <span>{t('fieldVerified')}</span>
                  </span>
                )}

                <span
                  className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${
                    contact?.status
                      ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                      : 'bg-slate-100 text-slate-500 border-slate-200'
                  }`}
                >
                  {contact?.status ? t('statusActive') : t('statusInactive')}
                </span>
              </div>

              <DialogTitle className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight truncate">
                {contact?.companyName || 'Loading...'}
              </DialogTitle>

              <div className="flex items-center gap-2 text-xs text-slate-500 flex-wrap">
                <span className="font-semibold text-slate-700 flex items-center gap-1">
                  <User className="w-3.5 h-3.5 text-slate-400" />
                  {contact?.name}
                </span>
                {contact?.city && (
                  <>
                    <span>•</span>
                    <span className="flex items-center gap-1">
                      <MapPin className="w-3.5 h-3.5 text-slate-400" />
                      {contact.city}
                    </span>
                  </>
                )}
              </div>
            </div>

            {/* Quick Action Buttons (Min 48px ergonomic touch target) */}
            {contact && (
              <div className="flex items-center gap-2 shrink-0 pt-1 sm:pt-0">
                {telUri ? (
                  <a
                    href={telUri}
                    className="h-10 px-3 rounded-xl bg-teal-50 hover:bg-[#0D9488] text-[#0D9488] hover:text-white border border-teal-200/80 transition-all text-xs font-semibold inline-flex items-center gap-1.5 shadow-2xs"
                  >
                    <Phone className="w-4 h-4" />
                    <span className="hidden sm:inline">{t('actionCallContact')}</span>
                  </a>
                ) : (
                  <button
                    disabled
                    className="h-10 px-3 rounded-xl bg-slate-100 text-slate-400 border border-slate-200 text-xs font-semibold inline-flex items-center gap-1.5 cursor-not-allowed"
                  >
                    <Phone className="w-4 h-4" />
                    <span className="hidden sm:inline">{t('phoneMissing')}</span>
                  </button>
                )}

                {waUri ? (
                  <a
                    href={waUri}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="h-10 px-3 rounded-xl bg-emerald-50 hover:bg-emerald-600 text-emerald-700 hover:text-white border border-emerald-200/80 transition-all text-xs font-semibold inline-flex items-center gap-1.5 shadow-2xs"
                  >
                    <MessageSquare className="w-4 h-4" />
                    <span className="hidden sm:inline">{t('actionWhatsApp')}</span>
                  </a>
                ) : null}

                <Button
                  type="button"
                  variant="outline"
                  onClick={() => onEdit(contact)}
                  className="h-10 px-3 rounded-xl text-xs font-semibold"
                >
                  <Edit2 className="w-3.5 h-3.5 mr-1" />
                  <span>{t('actionEditContact')}</span>
                </Button>

                <Button
                  type="button"
                  variant="outline"
                  onClick={handleToggleStatus}
                  disabled={togglingStatus}
                  className={`h-10 px-3 rounded-xl text-xs font-semibold ${
                    contact.status
                      ? 'text-rose-600 hover:bg-rose-50 border-rose-200'
                      : 'text-emerald-600 hover:bg-emerald-50 border-emerald-200'
                  }`}
                >
                  <Power className="w-3.5 h-3.5 mr-1" />
                  <span>{contact.status ? t('actionArchiveContact') : t('actionActivateContact')}</span>
                </Button>
              </div>
            )}
          </div>
        </DialogHeader>

        {loading ? (
          <div className="py-12 flex flex-col items-center justify-center space-y-3">
            <Loader2 className="w-8 h-8 text-[#0D9488] animate-spin" />
            <p className="text-xs text-slate-500 font-medium">{t('loadingText')}</p>
          </div>
        ) : error ? (
          <div className="p-6 text-center space-y-2">
            <XCircle className="w-8 h-8 text-rose-500 mx-auto" />
            <h4 className="text-sm font-bold text-slate-800">{t('errorTitle')}</h4>
            <p className="text-xs text-slate-500">{error}</p>
          </div>
        ) : details ? (
          <div className="space-y-4 pt-2">
            {/* Tab Navigation */}
            <div className="flex items-center gap-1.5 border-b border-slate-100 pb-2 overflow-x-auto scrollbar-none">
              <button
                type="button"
                onClick={() => setActiveTab('overview')}
                className={`text-xs font-bold px-3 py-1.5 rounded-lg transition-all ${
                  activeTab === 'overview'
                    ? 'bg-slate-900 text-white shadow-2xs'
                    : 'text-slate-600 hover:bg-slate-100'
                }`}
              >
                {t('profileOverview')}
              </button>

              {details.contact.role === 'Buyer' && (
                <button
                  type="button"
                  onClick={() => setActiveTab('requirements')}
                  className={`text-xs font-bold px-3 py-1.5 rounded-lg transition-all flex items-center gap-1.5 ${
                    activeTab === 'requirements'
                      ? 'bg-blue-600 text-white shadow-2xs'
                      : 'text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <Layers className="w-3.5 h-3.5" />
                  <span>{t('profileRequirements')}</span>
                  <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-white/20">
                    {details.associatedRequirements.length}
                  </span>
                </button>
              )}

              {details.contact.role === 'Seller' && (
                <button
                  type="button"
                  onClick={() => setActiveTab('offers')}
                  className={`text-xs font-bold px-3 py-1.5 rounded-lg transition-all flex items-center gap-1.5 ${
                    activeTab === 'offers'
                      ? 'bg-indigo-600 text-white shadow-2xs'
                      : 'text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <Package className="w-3.5 h-3.5" />
                  <span>{t('profileOffers')}</span>
                  <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-white/20">
                    {details.associatedOffers.length}
                  </span>
                </button>
              )}

              <button
                type="button"
                onClick={() => setActiveTab('deals')}
                className={`text-xs font-bold px-3 py-1.5 rounded-lg transition-all flex items-center gap-1.5 ${
                  activeTab === 'deals'
                    ? 'bg-[#0D9488] text-white shadow-2xs'
                    : 'text-slate-600 hover:bg-slate-100'
                }`}
              >
                <Handshake className="w-3.5 h-3.5" />
                <span>{t('profileDeals')}</span>
                <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-white/20">
                  {details.linkedDeals.length}
                </span>
              </button>

              <button
                type="button"
                onClick={() => setActiveTab('activity')}
                className={`text-xs font-bold px-3 py-1.5 rounded-lg transition-all flex items-center gap-1.5 ${
                  activeTab === 'activity'
                    ? 'bg-slate-800 text-white shadow-2xs'
                    : 'text-slate-600 hover:bg-slate-100'
                }`}
              >
                <Activity className="w-3.5 h-3.5" />
                <span>{t('profileActivity')}</span>
              </button>
            </div>

            {/* TAB: OVERVIEW */}
            {activeTab === 'overview' && (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                <Card className="p-3.5 border-slate-200/80 bg-slate-50/50 space-y-2">
                  <div className="font-bold text-slate-800 flex items-center gap-1.5">
                    <Building2 className="w-4 h-4 text-[#0D9488]" />
                    <span>Company & Mandate Details</span>
                  </div>
                  <div className="space-y-1 text-slate-600">
                    <p><span className="text-slate-400">Company:</span> <span className="font-semibold text-slate-900">{details.contact.companyName}</span></p>
                    <p><span className="text-slate-400">Location:</span> {details.contact.city || 'Unspecified'}, {details.contact.state || ''}</p>
                    <p><span className="text-slate-400">Trust Score:</span> <span className="font-bold text-[#0D9488]">{details.contact.trustScore}/100</span></p>
                    <p><span className="text-slate-400">Added to Desk:</span> {formatDate(new Date(details.contact.createdAt))}</p>
                  </div>
                </Card>

                <Card className="p-3.5 border-slate-200/80 bg-slate-50/50 space-y-2">
                  <div className="font-bold text-slate-800 flex items-center gap-1.5">
                    <User className="w-4 h-4 text-[#0D9488]" />
                    <span>Representative Contact</span>
                  </div>
                  <div className="space-y-1 text-slate-600">
                    <p><span className="text-slate-400">Contact Person:</span> <span className="font-semibold text-slate-900">{details.contact.name}</span></p>
                    <p><span className="text-slate-400">Mobile Phone:</span> <span className="font-mono font-medium text-slate-900">{details.contact.mobile}</span></p>
                    <p><span className="text-slate-400">Email:</span> {details.contact.email || 'None on record'}</p>
                    <p><span className="text-slate-400">Role:</span> {details.contact.role}</p>
                  </div>
                </Card>
              </div>
            )}

            {/* TAB: REQUIREMENTS (BUYER) */}
            {activeTab === 'requirements' && (
              <div className="space-y-2.5">
                {details.associatedRequirements.length === 0 ? (
                  <div className="p-6 rounded-xl border border-dashed border-slate-200 text-center text-xs text-slate-500">
                    {t('noRequirementsLinked')}
                  </div>
                ) : (
                  details.associatedRequirements.map((req) => (
                    <div
                      key={req.id}
                      className="p-3 rounded-xl border border-slate-200/80 bg-white flex items-center justify-between gap-3 text-xs"
                    >
                      <div>
                        <div className="font-bold text-slate-900">{req.commodityName}</div>
                        <div className="text-slate-500 text-[11px] mt-0.5">
                          {formatNumber(req.quantity)} MT • Target: <span className="font-semibold text-slate-800">{formatCurrency(req.targetPrice)}</span>/MT
                        </div>
                      </div>
                      <Badge variant="outline" className="text-[10px] font-semibold bg-blue-50 text-blue-700 border-blue-200">
                        {req.status}
                      </Badge>
                    </div>
                  ))
                )}
              </div>
            )}

            {/* TAB: OFFERS (SELLER) */}
            {activeTab === 'offers' && (
              <div className="space-y-2.5">
                {details.associatedOffers.length === 0 ? (
                  <div className="p-6 rounded-xl border border-dashed border-slate-200 text-center text-xs text-slate-500">
                    {t('noOffersLinked')}
                  </div>
                ) : (
                  details.associatedOffers.map((off) => (
                    <div
                      key={off.id}
                      className="p-3 rounded-xl border border-slate-200/80 bg-white flex items-center justify-between gap-3 text-xs"
                    >
                      <div>
                        <div className="font-bold text-slate-900">{off.commodityName}</div>
                        <div className="text-slate-500 text-[11px] mt-0.5">
                          {formatNumber(off.quantity)} MT • Asking: <span className="font-semibold text-slate-800">{formatCurrency(Number(off.price))}</span>/Qtl
                        </div>
                      </div>
                      <Badge variant="outline" className="text-[10px] font-semibold bg-indigo-50 text-indigo-700 border-indigo-200">
                        {off.status}
                      </Badge>
                    </div>
                  ))
                )}
              </div>
            )}

            {/* TAB: DEALS */}
            {activeTab === 'deals' && (
              <div className="space-y-2.5">
                {details.linkedDeals.length === 0 ? (
                  <div className="p-6 rounded-xl border border-dashed border-slate-200 text-center text-xs text-slate-500">
                    {t('noDealsLinked')}
                  </div>
                ) : (
                  details.linkedDeals.map((deal) => (
                    <div
                      key={deal.id}
                      className="p-3 rounded-xl border border-slate-200/80 bg-white flex items-center justify-between gap-3 text-xs"
                    >
                      <div>
                        <div className="flex items-center gap-1.5">
                          <span className="font-mono font-bold text-slate-400 text-[11px]">
                            #DL-{deal.id.slice(0, 4).toUpperCase()}
                          </span>
                          <span className="font-bold text-slate-900">{deal.commodityName}</span>
                        </div>
                        <div className="text-slate-500 text-[11px] mt-0.5">
                          {formatNumber(deal.agreedQuantity)} MT @ {formatCurrency(Number(deal.agreedPrice))}/Qtl
                        </div>
                      </div>
                      <Badge variant="outline" className="text-[10px] font-semibold bg-emerald-50 text-emerald-700 border-emerald-200">
                        {deal.status}
                      </Badge>
                    </div>
                  ))
                )}
              </div>
            )}

            {/* TAB: ACTIVITY */}
            {activeTab === 'activity' && (
              <div className="space-y-2.5">
                {details.activities.length === 0 ? (
                  <div className="p-6 rounded-xl border border-dashed border-slate-200 text-center text-xs text-slate-500">
                    {t('noActivityLogged')}
                  </div>
                ) : (
                  details.activities.map((act) => (
                    <div
                      key={act.id}
                      className="p-3 rounded-xl border border-slate-200/80 bg-white text-xs space-y-1"
                    >
                      <div className="flex items-center justify-between text-[11px]">
                        <span className="font-bold text-slate-800">{act.type}</span>
                        <span className="text-slate-400">{formatDate(new Date(act.createdAt))}</span>
                      </div>
                      <p className="text-slate-600 leading-relaxed">{act.notes}</p>
                    </div>
                  ))
                )}
              </div>
            )}
          </div>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}
