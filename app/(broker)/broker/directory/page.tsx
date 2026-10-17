import React from 'react';
import { getBrokerDirectoryContactsAction } from '@/src/server/actions/broker-directory-actions';
import { BrokerDirectoryWorkspace } from '@/src/components/directory/broker-directory-workspace';

export const dynamic = 'force-dynamic';

export const metadata = {
  title: 'Directory | RMBroker Workstation',
  description: 'Verified Buyer & Seller Counterparty Directory for Commodity Brokers',
};

export default async function BrokerDirectoryPage() {
  const res = await getBrokerDirectoryContactsAction();

  const contacts = res.data?.contacts ?? [];
  const stats = res.data?.stats ?? {
    totalContacts: 0,
    buyersCount: 0,
    sellersCount: 0,
    activeMandatesCount: 0,
  };

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* Page Header */}
      <div>
        <div className="flex items-center gap-2">
          <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">
            Buyer & Seller Directory
          </h1>
          <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase tracking-wider bg-teal-100 text-[#0D9488] border border-teal-200">
            RB-06
          </span>
        </div>
        <p className="text-xs sm:text-sm text-slate-500 mt-1">
          Authorized counterparty directory, verified mandates, contact profiles, and direct communication desk.
        </p>
      </div>

      {/* Main Directory Workspace */}
      <BrokerDirectoryWorkspace initialContacts={contacts} initialStats={stats} />
    </div>
  );
}
