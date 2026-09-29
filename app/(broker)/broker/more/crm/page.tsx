import React from 'react';
import Link from 'next/link';
import { ArrowLeft, Users, Sparkles } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { getBrokerAggregatedContactsListAction } from '@/src/server/actions/broker-crm-actions';
import { BrokerCrmWorkspace } from '@/src/components/broker/crm/broker-crm-workspace';

export const dynamic = 'force-dynamic';

export default async function BrokerCrmPage() {
  const res = await getBrokerAggregatedContactsListAction();
  const contacts = res.data || [];

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* Top Header & Navigation */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <Link
            href="/broker/more"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-700 hover:text-teal-900 transition-colors mb-2"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Additional Tools
          </Link>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
              <Users className="w-7 h-7 text-[#0D9488]" />
              CRM & Relationship Cards
            </h1>
            <Badge className="bg-[#0D9488] text-white font-mono text-xs px-2.5 py-0.5">
              SPRINT 28.3
            </Badge>
          </div>
          <p className="text-xs sm:text-sm text-slate-500 mt-1">
            360-degree buyer/seller contact cards, open mandate telemetry, and 1-tap follow-up logging.
          </p>
        </div>
      </div>

      {/* CRM WORKSPACE CONTAINER */}
      <BrokerCrmWorkspace initialContacts={contacts} />
    </div>
  );
}
