import React from 'react';
import { getBuyerPayableLedgerAction } from '@/src/server/actions/buyer-payment-actions';
import { GlobalPayablesHub } from '@/src/components/buyer/payments/global-payables-hub';
import { BuyerPayableLedgerData } from '@/src/types/buyer-payment-types';

export const dynamic = 'force-dynamic';

/**
 * Task 4 (Micro-Sprint 39.3): Global Payables Hub Page.
 * 
 * Async Server Component fetching consolidated payables across active orders
 * without a specific booking ID. Renders the master Shadcn table and mobile-optimized
 * 360px card list with deep links to individual order views.
 */
export default async function BuyerMorePage() {
  const response = await getBuyerPayableLedgerAction();

  const fallbackData: BuyerPayableLedgerData = {
    payables: [],
    overview: {
      totalActiveOrders: 0,
      totalGrossPayable: 0,
      formattedTotalGrossPayable: '₹0.00',
      totalAmountPaid: 0,
      formattedTotalAmountPaid: '₹0.00',
      totalOutstandingBalance: 0,
      formattedTotalOutstandingBalance: '₹0.00',
      overdueCount: 0,
    },
    lastUpdated: new Date().toISOString(),
  };

  const ledgerData = response.success && response.data ? response.data : fallbackData;

  return (
    <div className="w-full max-w-full overflow-x-hidden min-h-full p-4 sm:p-6 lg:p-8 space-y-6">
      <GlobalPayablesHub initialData={ledgerData} />
    </div>
  );
}
