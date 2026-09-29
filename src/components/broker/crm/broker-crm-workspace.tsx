'use client';

import React, { useState, useEffect, useTransition } from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  Users,
  Search,
  RefreshCw,
  Plus,
  Building,
  Building2,
  Filter,
  User,
} from 'lucide-react';
import {
  getBrokerAggregatedContactsListAction,
  ContactAggregatedProfilePayload,
} from '@/src/server/actions/broker-crm-actions';
import { ContactCard } from './contact-card';
import { CrmActivityDialog } from '@/src/components/forms/crm-activity-dialog';

interface BrokerCrmWorkspaceProps {
  initialContacts?: ContactAggregatedProfilePayload[];
}

export function BrokerCrmWorkspace({ initialContacts }: BrokerCrmWorkspaceProps) {
  const [contacts, setContacts] = useState<ContactAggregatedProfilePayload[]>(
    initialContacts || []
  );
  const [isLoading, setIsLoading] = useState<boolean>(!initialContacts);
  const [error, setError] = useState<string | null>(null);

  const [searchQuery, setSearchQuery] = useState<string>('');
  const [roleFilter, setRoleFilter] = useState<'ALL' | 'BUYER' | 'SELLER'>('ALL');

  const [isPending, startTransition] = useTransition();

  const fetchContacts = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await getBrokerAggregatedContactsListAction();
      if (res.success && res.data) {
        setContacts(res.data);
      } else {
        setError(res.error || 'Failed to load CRM contacts.');
      }
    } catch (err: any) {
      setError(err.message || 'Error loading CRM contacts.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!initialContacts) {
      fetchContacts();
    }
  }, []);

  const handleLogged = () => {
    startTransition(() => {
      fetchContacts();
    });
  };

  // Filter contacts by search query & role
  const filteredContacts = contacts.filter((c) => {
    const matchesSearch =
      c.companyName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      c.userName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (c.userMobile && c.userMobile.includes(searchQuery));

    if (!matchesSearch) return false;

    if (roleFilter === 'BUYER') return c.role === 'Buyer';
    if (roleFilter === 'SELLER') return c.role === 'Seller';
    return true;
  });

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* FILTER & CONTROL BAR */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 bg-white p-4 rounded-xl border border-slate-200/80 shadow-xs">
        {/* Search Input */}
        <div className="relative min-w-0 flex-1">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
          <Input
            type="text"
            placeholder="Search company or contact person..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9 h-10 border-slate-300 focus:border-teal-500 text-xs rounded-lg"
          />
        </div>

        {/* Role Filter Tabs */}
        <div className="flex items-center gap-1 bg-slate-100 p-1 rounded-lg shrink-0 self-start sm:self-auto">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setRoleFilter('ALL')}
            className={`text-xs h-8 px-3 font-semibold rounded-md ${
              roleFilter === 'ALL'
                ? 'bg-white text-slate-900 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            All ({contacts.length})
          </Button>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setRoleFilter('BUYER')}
            className={`text-xs h-8 px-3 font-semibold rounded-md ${
              roleFilter === 'BUYER'
                ? 'bg-white text-blue-700 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Building className="w-3.5 h-3.5 mr-1 text-blue-600" />
            Buyers
          </Button>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setRoleFilter('SELLER')}
            className={`text-xs h-8 px-3 font-semibold rounded-md ${
              roleFilter === 'SELLER'
                ? 'bg-white text-teal-700 shadow-2xs'
                : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            <Building2 className="w-3.5 h-3.5 mr-1 text-teal-600" />
            Sellers
          </Button>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center gap-2 shrink-0">
          <Button
            onClick={fetchContacts}
            variant="outline"
            size="sm"
            disabled={isLoading || isPending}
            className="border-slate-200 text-slate-600 hover:bg-slate-50 text-xs h-10 px-3"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isLoading || isPending ? 'animate-spin' : ''}`} />
          </Button>

          <CrmActivityDialog onLogged={handleLogged} />
        </div>
      </div>

      {/* CONTACT CARDS GRID */}
      {isLoading ? (
        <Card className="border-slate-200/80 bg-white p-8 text-center">
          <div className="flex items-center justify-center space-x-3 text-slate-500 py-6">
            <RefreshCw className="w-5 h-5 animate-spin text-[#0D9488]" />
            <span className="text-xs font-semibold">Aggregating CRM Contact Telemetry...</span>
          </div>
        </Card>
      ) : filteredContacts.length === 0 ? (
        <Card className="border-slate-200/80 bg-white p-8 text-center">
          <div className="mx-auto w-12 h-12 rounded-full bg-slate-100 flex items-center justify-center text-slate-400 mb-3">
            <Users className="w-6 h-6" />
          </div>
          <h4 className="font-bold text-slate-900 text-base">No Contacts Found</h4>
          <p className="text-xs text-slate-500 max-w-md mx-auto mt-1">
            {searchQuery
              ? `No contacts match your query "${searchQuery}".`
              : 'No client contacts assigned yet. Click "Log Activity" to start.'}
          </p>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 lg:gap-6">
          {filteredContacts.map((profile) => (
            <ContactCard
              key={profile.contactId}
              profile={profile}
              onActivityLogged={handleLogged}
            />
          ))}
        </div>
      )}
    </div>
  );
}
