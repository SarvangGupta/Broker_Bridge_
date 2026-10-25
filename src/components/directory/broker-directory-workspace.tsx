'use client';

import React, { useState, useMemo } from 'react';
import {
  Users2,
  Building2,
  User,
  Phone,
  MessageSquare,
  Search,
  Plus,
  ShieldCheck,
  MapPin,
  Layers,
  Package,
  Handshake,
  ArrowRight,
  Filter,
  CheckCircle2,
  XCircle,
  Inbox,
  Edit2,
  UserCheck,
  TrendingUp,
} from 'lucide-react';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useLanguage } from '@/src/lib/i18n/language-context';
import {
  DirectoryContactItem,
  DirectorySummaryStats,
  getBrokerDirectoryContactsAction,
} from '@/src/server/actions/broker-directory-actions';
import { ContactFormDialog } from '@/src/components/directory/contact-form-dialog';
import { ContactProfileDrawer } from '@/src/components/directory/contact-profile-drawer';
import { getSafeTelUri, getSafeWhatsAppUri } from '@/src/lib/phone-utils';

interface BrokerDirectoryWorkspaceProps {
  initialContacts: DirectoryContactItem[];
  initialStats: DirectorySummaryStats;
}

export function BrokerDirectoryWorkspace({
  initialContacts,
  initialStats,
}: BrokerDirectoryWorkspaceProps) {
  const { t, formatNumber } = useLanguage();

  const [contacts, setContacts] = useState<DirectoryContactItem[]>(initialContacts);
  const [stats, setStats] = useState<DirectorySummaryStats>(initialStats);

  // Filter States
  const [activeTab, setActiveTab] = useState<'all' | 'buyer' | 'seller'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive'>('all');

  // Modal / Drawer States
  const [isFormOpen, setIsFormOpen] = useState(false);
  const [formDefaultRole, setFormDefaultRole] = useState<'buyer' | 'seller'>('buyer');
  const [editingContact, setEditingContact] = useState<DirectoryContactItem | null>(null);
  const [selectedProfileId, setSelectedProfileId] = useState<string | null>(null);

  // Refresh Directory Data
  const refreshDirectory = async () => {
    try {
      const res = await getBrokerDirectoryContactsAction();
      if (res.success && res.data) {
        setContacts(res.data.contacts);
        if (res.data.stats) setStats(res.data.stats);
      }
    } catch {
      // Ignored
    }
  };

  // Client-filtered list
  const filteredContacts = useMemo(() => {
    return contacts.filter((c) => {
      // Role Tab Filter
      if (activeTab === 'buyer' && c.role !== 'Buyer') return false;
      if (activeTab === 'seller' && c.role !== 'Seller') return false;

      // Status Filter
      if (statusFilter === 'active' && !c.status) return false;
      if (statusFilter === 'inactive' && c.status) return false;

      // Search Filter
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim();
        const digits = q.replace(/\D/g, '');

        const matchesName = c.name.toLowerCase().includes(q);
        const matchesComp = c.companyName.toLowerCase().includes(q);
        const matchesEmail = c.email ? c.email.toLowerCase().includes(q) : false;
        const matchesCity = c.city ? c.city.toLowerCase().includes(q) : false;
        const matchesPhone = digits.length >= 3 && c.mobile.replace(/\D/g, '').includes(digits);

        return matchesName || matchesComp || matchesEmail || matchesCity || matchesPhone;
      }

      return true;
    });
  }, [contacts, activeTab, statusFilter, searchQuery]);

  const handleOpenAdd = (role: 'buyer' | 'seller') => {
    setEditingContact(null);
    setFormDefaultRole(role);
    setIsFormOpen(true);
  };

  const handleEdit = (contact: DirectoryContactItem) => {
    setEditingContact(contact);
    setIsFormOpen(true);
  };

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* --- 1. DIRECTORY STATS RIBBON --- */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <Card className="p-3.5 bg-white border border-slate-200/80 shadow-2xs rounded-xl flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold text-slate-500">{t('statTotalContacts')}</div>
            <div className="text-xl sm:text-2xl font-black text-slate-900 mt-0.5">
              {formatNumber(stats.totalContacts)}
            </div>
          </div>
          <div className="w-9 h-9 rounded-xl bg-slate-100 text-slate-700 flex items-center justify-center shrink-0 border border-slate-200">
            <Users2 className="w-4 h-4" />
          </div>
        </Card>

        <Card className="p-3.5 bg-white border border-slate-200/80 shadow-2xs rounded-xl flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold text-slate-500">{t('statBuyersCount')}</div>
            <div className="text-xl sm:text-2xl font-black text-blue-600 mt-0.5">
              {formatNumber(stats.buyersCount)}
            </div>
          </div>
          <div className="w-9 h-9 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center shrink-0 border border-blue-200">
            <UserCheck className="w-4 h-4" />
          </div>
        </Card>

        <Card className="p-3.5 bg-white border border-slate-200/80 shadow-2xs rounded-xl flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold text-slate-500">{t('statSellersCount')}</div>
            <div className="text-xl sm:text-2xl font-black text-emerald-600 mt-0.5">
              {formatNumber(stats.sellersCount)}
            </div>
          </div>
          <div className="w-9 h-9 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center shrink-0 border border-emerald-200">
            <Building2 className="w-4 h-4" />
          </div>
        </Card>

        <Card className="p-3.5 bg-white border border-slate-200/80 shadow-2xs rounded-xl flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold text-slate-500">{t('statActiveMandates')}</div>
            <div className="text-xl sm:text-2xl font-black text-[#0D9488] mt-0.5">
              {formatNumber(stats.activeMandatesCount)}
            </div>
          </div>
          <div className="w-9 h-9 rounded-xl bg-teal-50 text-[#0D9488] flex items-center justify-center shrink-0 border border-teal-200">
            <TrendingUp className="w-4 h-4" />
          </div>
        </Card>
      </div>

      {/* --- 2. FILTER & ACTION CONTROL BAR --- */}
      <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-3 bg-white p-3.5 rounded-2xl border border-slate-200/80 shadow-2xs">
        {/* Role Tab Selector */}
        <div className="flex items-center gap-1.5 p-1 bg-slate-100 rounded-xl shrink-0">
          <button
            type="button"
            onClick={() => setActiveTab('all')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${
              activeTab === 'all'
                ? 'bg-white text-slate-900 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            {t('tabAllContacts')}
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('buyer')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 ${
              activeTab === 'buyer'
                ? 'bg-white text-blue-700 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <span>{t('tabBuyers')}</span>
            <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-blue-100 text-blue-800">
              {stats.buyersCount}
            </span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('seller')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 ${
              activeTab === 'seller'
                ? 'bg-white text-emerald-700 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <span>{t('tabSellers')}</span>
            <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-emerald-100 text-emerald-800">
              {stats.sellersCount}
            </span>
          </button>
        </div>

        {/* Search & Status Filter */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2.5 flex-1 max-w-xl">
          <div className="relative flex-1">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <Input
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={t('filterSearchPlaceholder')}
              className="pl-9 text-xs h-9 rounded-xl border-slate-200"
            />
          </div>

          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as any)}
            className="h-9 px-3 rounded-xl border border-slate-200 text-xs font-semibold text-slate-700 bg-white focus:outline-none focus:border-[#0D9488]"
          >
            <option value="all">{t('filterAllStatuses')}</option>
            <option value="active">{t('statusActive')}</option>
            <option value="inactive">{t('statusInactive')}</option>
          </select>
        </div>

        {/* Add Contact CTA Buttons */}
        <div className="flex items-center gap-2 shrink-0">
          <Button
            type="button"
            onClick={() => handleOpenAdd('buyer')}
            className="text-xs h-9 px-3 rounded-xl bg-blue-600 hover:bg-blue-700 text-white shadow-2xs"
          >
            <Plus className="w-3.5 h-3.5 mr-1" />
            <span>{t('actionAddBuyer')}</span>
          </Button>

          <Button
            type="button"
            onClick={() => handleOpenAdd('seller')}
            className="text-xs h-9 px-3 rounded-xl bg-[#0D9488] hover:bg-[#0F766E] text-white shadow-2xs"
          >
            <Plus className="w-3.5 h-3.5 mr-1" />
            <span>{t('actionAddSeller')}</span>
          </Button>
        </div>
      </div>

      {/* --- 3. CONTACTS LIST / CARDS --- */}
      {filteredContacts.length === 0 ? (
        <Card className="p-8 sm:p-12 text-center bg-white border border-dashed border-slate-200 rounded-2xl space-y-3">
          <div className="w-12 h-12 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center mx-auto">
            <Inbox className="w-6 h-6" />
          </div>
          <h3 className="text-sm sm:text-base font-bold text-slate-800">
            {t('noContactsFound')}
          </h3>
          <p className="text-xs text-slate-500 max-w-md mx-auto">
            {searchQuery || statusFilter !== 'all' || activeTab !== 'all'
              ? 'Try adjusting your search query, role selection, or status filters.'
              : t('createFirstContact')}
          </p>
          <div className="pt-2 flex items-center justify-center gap-2">
            <Button
              type="button"
              onClick={() => handleOpenAdd('buyer')}
              variant="outline"
              className="text-xs h-9 rounded-xl text-blue-600 border-blue-200 hover:bg-blue-50"
            >
              <Plus className="w-3.5 h-3.5 mr-1" />
              <span>{t('actionAddBuyer')}</span>
            </Button>
            <Button
              type="button"
              onClick={() => handleOpenAdd('seller')}
              className="text-xs h-9 rounded-xl bg-[#0D9488] hover:bg-[#0F766E] text-white"
            >
              <Plus className="w-3.5 h-3.5 mr-1" />
              <span>{t('actionAddSeller')}</span>
            </Button>
          </div>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3.5">
          {filteredContacts.map((c) => {
            const isBuyer = c.role === 'Buyer';
            const telUri = getSafeTelUri(c.mobile);
            const waUri = getSafeWhatsAppUri(c.mobile);

            return (
              <Card
                key={c.id}
                className={`bg-white border transition-all rounded-2xl overflow-hidden p-4 flex flex-col justify-between space-y-3 shadow-2xs hover:shadow-xs hover:border-[#0D9488]/40 ${
                  !c.status ? 'opacity-70 bg-slate-50/50' : ''
                }`}
              >
                {/* Top Row: Badges & Status */}
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <Badge
                      className={`text-[9px] font-bold uppercase tracking-wider py-0.2 px-1.5 border ${
                        isBuyer
                          ? 'bg-blue-50 text-blue-700 border-blue-200'
                          : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                      }`}
                    >
                      {isBuyer ? t('badgeBuyer') : t('badgeSeller')}
                    </Badge>

                    {c.isVerified && (
                      <span className="inline-flex items-center gap-0.5 text-[9px] font-bold text-emerald-700 bg-emerald-50 px-1.5 py-0.2 rounded-full border border-emerald-200">
                        <ShieldCheck className="w-3 h-3" />
                        <span>Verified</span>
                      </span>
                    )}

                    {!c.status && (
                      <span className="text-[9px] font-bold text-slate-500 bg-slate-100 px-1.5 py-0.2 rounded-full border border-slate-200">
                        {t('statusInactive')}
                      </span>
                    )}
                  </div>

                  <div className="text-[10px] font-bold text-slate-400">
                    Score: <span className="text-[#0D9488] font-bold">{c.trustScore}</span>
                  </div>
                </div>

                {/* Main Identity Info */}
                <div className="space-y-1">
                  <h3
                    onClick={() => setSelectedProfileId(c.id)}
                    className="text-base font-bold text-slate-900 tracking-tight hover:text-[#0D9488] transition-colors cursor-pointer truncate"
                  >
                    {c.companyName}
                  </h3>

                  <div className="flex items-center gap-1.5 text-xs text-slate-600 truncate">
                    <User className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span className="font-semibold text-slate-800">{c.name}</span>
                    {c.city && (
                      <>
                        <span className="text-slate-300">•</span>
                        <span className="text-slate-500 truncate">{c.city}</span>
                      </>
                    )}
                  </div>

                  <div className="flex items-center gap-1.5 text-xs text-slate-500 font-mono pt-0.5">
                    <Phone className="w-3 h-3 text-slate-400 shrink-0" />
                    <span>{c.mobile || t('phoneMissing')}</span>
                  </div>
                </div>

                {/* Mandate Counts Badge Row */}
                <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-500">
                  <div className="flex items-center gap-3">
                    {isBuyer ? (
                      <span className="flex items-center gap-1 font-medium">
                        <Layers className="w-3.5 h-3.5 text-blue-500" />
                        <span>{c.openRequirementsCount} Reqs</span>
                      </span>
                    ) : (
                      <span className="flex items-center gap-1 font-medium">
                        <Package className="w-3.5 h-3.5 text-emerald-500" />
                        <span>{c.availableOffersCount} Offers</span>
                      </span>
                    )}

                    <span className="flex items-center gap-1 font-medium">
                      <Handshake className="w-3.5 h-3.5 text-[#0D9488]" />
                      <span>{c.activeDealsCount} Deals</span>
                    </span>
                  </div>

                  <button
                    type="button"
                    onClick={() => handleEdit(c)}
                    className="p-1 text-slate-400 hover:text-[#0D9488] transition-colors rounded-md hover:bg-slate-50"
                    title={t('actionEditContact')}
                  >
                    <Edit2 className="w-3.5 h-3.5" />
                  </button>
                </div>

                {/* 1-Tap Action Buttons (≥ 44px ergonomic touch targets) */}
                <div className="grid grid-cols-3 gap-1.5 pt-1">
                  {telUri ? (
                    <a
                      href={telUri}
                      className="min-h-[40px] px-2 rounded-xl bg-teal-50/80 hover:bg-[#0D9488] text-[#0D9488] hover:text-white border border-teal-200/70 transition-all text-xs font-semibold inline-flex items-center justify-center gap-1"
                    >
                      <Phone className="w-3.5 h-3.5" />
                      <span>{t('actionCallContact')}</span>
                    </a>
                  ) : (
                    <button
                      disabled
                      className="min-h-[40px] px-2 rounded-xl bg-slate-50 text-slate-400 border border-slate-200 text-xs font-semibold inline-flex items-center justify-center gap-1 cursor-not-allowed"
                    >
                      <Phone className="w-3.5 h-3.5" />
                      <span>{t('actionCallContact')}</span>
                    </button>
                  )}

                  {waUri ? (
                    <a
                      href={waUri}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="min-h-[40px] px-2 rounded-xl bg-emerald-50/80 hover:bg-emerald-600 text-emerald-700 hover:text-white border border-emerald-200/70 transition-all text-xs font-semibold inline-flex items-center justify-center gap-1"
                    >
                      <MessageSquare className="w-3.5 h-3.5" />
                      <span>WhatsApp</span>
                    </a>
                  ) : (
                    <button
                      disabled
                      className="min-h-[40px] px-2 rounded-xl bg-slate-50 text-slate-400 border border-slate-200 text-xs font-semibold inline-flex items-center justify-center gap-1 cursor-not-allowed"
                    >
                      <MessageSquare className="w-3.5 h-3.5" />
                      <span>WhatsApp</span>
                    </button>
                  )}

                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => setSelectedProfileId(c.id)}
                    className="min-h-[40px] text-xs font-semibold rounded-xl border-slate-200 text-slate-700 hover:text-[#0D9488] hover:border-[#0D9488]"
                  >
                    <span>{t('actionViewProfile')}</span>
                    <ArrowRight className="w-3 h-3 ml-0.5" />
                  </Button>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* --- MODALS & DRAWERS --- */}

      {/* Contact Form Dialog (Add / Edit) */}
      <ContactFormDialog
        isOpen={isFormOpen}
        onClose={() => setIsFormOpen(false)}
        onSuccess={() => {
          refreshDirectory();
        }}
        onSelectExisting={(existingId) => {
          setSelectedProfileId(existingId);
        }}
        initialData={editingContact}
        defaultRole={formDefaultRole}
      />

      {/* Contact Profile Drawer */}
      <ContactProfileDrawer
        contactId={selectedProfileId}
        onClose={() => setSelectedProfileId(null)}
        onEdit={(contact) => {
          setSelectedProfileId(null);
          handleEdit(contact);
        }}
        onStatusChanged={() => {
          refreshDirectory();
        }}
      />
    </div>
  );
}
