'use server';

import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';
import { db } from '@/src/server/db';
import { requirements, deals } from '@/src/server/db/schema';
import { eq, desc } from 'drizzle-orm';
import { formatIndianCurrency } from '@/lib/utils';

export type BuyerDashboardKpis = {
  activeRequirementsCount: number;
  proposalsPendingCount: number;
  activeOrdersCount: number;
  pendingPayablesFormatted: string;
};

export type BuyerActionItem = {
  id: string;
  type: 'PROPOSAL_PENDING' | 'DISPATCH_IN_TRANSIT' | 'ACTION_EXPIRED';
  title: string;
  description: string;
  timeRemaining?: string;
  ctaLabel: string;
  ctaUrl: string;
};

export type BuyerRecentRequirement = {
  id: string;
  commodityName: string;
  gradeName: string;
  quantityWithUnit: string;
  targetPrice: string;
  status: 'Draft' | 'Submitted' | 'Sourcing' | 'Matched';
  createdAt: string;
};

export type BuyerActiveShipment = {
  bookingId: string;
  commodity: string;
  dispatchedQuantity: string;
  transporter: string;
  eta: string;
  status: 'Booked' | 'Dispatched' | 'In Transit';
};

export type BuyerDashboardSummaryPayload = {
  kpis: BuyerDashboardKpis;
  actionRequired: BuyerActionItem[];
  recentRequirements: BuyerRecentRequirement[];
  activeShipments: BuyerActiveShipment[];
};

export type BuyerDashboardSummaryResponse =
  | { success: true; data: BuyerDashboardSummaryPayload }
  | { success: false; error: string; data: BuyerDashboardSummaryPayload };

/**
 * Retrieves the unified Procurement Command Center summary payload for the authenticated Buyer.
 */
export async function getBuyerDashboardSummaryAction(): Promise<BuyerDashboardSummaryResponse> {
  const sessionRes = await verifyBuyerSession();

  const emptyPayload: BuyerDashboardSummaryPayload = {
    kpis: {
      activeRequirementsCount: 0,
      proposalsPendingCount: 0,
      activeOrdersCount: 0,
      pendingPayablesFormatted: '₹ 0',
    },
    actionRequired: [],
    recentRequirements: [],
    activeShipments: [],
  };

  if (!sessionRes.success || !sessionRes.data?.companyId) {
    return {
      success: false,
      error: sessionRes.error || 'Unauthorized session',
      data: emptyPayload,
    };
  }

  const companyId = sessionRes.data.companyId;

  try {
    // 1. Fetch Requirement KPIs
    const userRequirements = await db.query.requirements.findMany({
      where: eq(requirements.companyId, companyId),
      limit: 10,
      orderBy: [desc(requirements.createdAt)],
    });

    const activeReqsCount = userRequirements.filter(
      (r) => r.status === 'open' || r.status === 'partially_fulfilled' || r.status === 'Open'
    ).length;

    // 2. Fetch Active Deals
    const userDeals = await db.query.deals.findMany({
      where: eq(deals.buyerId, companyId),
      limit: 10,
      orderBy: [desc(deals.createdAt)],
    });

    const activeOrdersCount = userDeals.filter(
      (d) => d.status === 'Dispatch Pending' || d.status === 'Dispatched' || d.status === 'In Transit' || d.status === 'Confirmed'
    ).length;

    // 3. Calculate pending payables from real deals
    let pendingPayables = 0;
    for (const d of userDeals) {
      if (d.status !== 'Cancelled' && d.status !== 'Rejected') {
        const agreedQty = Number(d.agreedQuantity || 0);
        const agreedRate = Number(d.agreedPrice || 0);
        pendingPayables += agreedQty * agreedRate;
      }
    }

    // Build real payload (0 counts & empty lists when user has no data)
    const realPayload: BuyerDashboardSummaryPayload = {
      kpis: {
        activeRequirementsCount: activeReqsCount,
        proposalsPendingCount: 0,
        activeOrdersCount: activeOrdersCount,
        pendingPayablesFormatted: pendingPayables > 0 ? formatIndianCurrency(pendingPayables) : '₹ 0',
      },
      actionRequired: [],
      recentRequirements:
        userRequirements.length > 0
          ? userRequirements.slice(0, 5).map((r) => ({
              id: r.id,
              commodityName: 'Agricultural Commodity',
              gradeName: 'Standard Commercial Grade',
              quantityWithUnit: `${r.quantity} MT`,
              targetPrice: r.targetPrice ? formatIndianCurrency(Number(r.targetPrice)) : 'Market Rate',
              status: r.status === 'open' || r.status === 'Open' ? 'Sourcing' : r.status === 'fulfilled' ? 'Matched' : 'Submitted',
              createdAt: new Date(r.createdAt).toLocaleDateString('en-IN', {
                day: 'numeric',
                month: 'short',
              }),
            }))
          : [],
      activeShipments: [],
    };

    return {
      success: true,
      data: realPayload,
    };
  } catch (err) {
    console.error('getBuyerDashboardSummaryAction error:', err);
    return {
      success: false,
      error: 'Failed to query database',
      data: emptyPayload,
    };
  }
}
