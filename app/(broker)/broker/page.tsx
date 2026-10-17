import React from 'react';
import { getBrokerDashboardDataAction } from '@/src/server/actions/broker-dashboard-actions';
import { BrokerDashboardClient } from '@/src/components/dashboard/broker-dashboard-client';

export const dynamic = 'force-dynamic';

export const metadata = {
  title: 'Dashboard | RMBroker Command Center',
  description: 'Enterprise broker command center and commodity trading desk',
};

export default async function BrokerDashboardPage() {
  // Fetch real authoritative broker data from server action (Strict Assignment Model)
  const res = await getBrokerDashboardDataAction();

  const kpis = res.data?.kpis ?? {
    activeDealsCount: 0,
    openRequirementsCount: 0,
    partiallyAllocatedCount: 0,
    availableOffersCount: 0,
    awaitingConfirmationCount: 0,
    dispatchDueCount: 0,
    deliveriesAwaitingConfirmationCount: 0,
    openDisputesCount: 0,
    commissionThisMonth: '₹0',
    commissionPendingInvoicesCount: 0,
  };

  const pendingActions = res.data?.pendingActions ?? res.data?.alerts ?? [];
  const recentActivity = res.data?.recentActivity ?? [];
  const pipeline = res.data?.pipeline ?? [];
  const tasks = res.data?.tasks ?? [];

  return (
    <BrokerDashboardClient
      kpis={kpis}
      alerts={pendingActions}
      pendingActions={pendingActions}
      recentActivity={recentActivity}
      pipeline={pipeline}
      tasks={tasks}
    />
  );
}
