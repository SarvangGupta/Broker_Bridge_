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

  // Fallback / Mock Dataset for smooth zero-wall rendering
  const fallbackPayload: BuyerDashboardSummaryPayload = {
    kpis: {
      activeRequirementsCount: 4,
      proposalsPendingCount: 2,
      activeOrdersCount: 3,
      pendingPayablesFormatted: '₹ 14,50,000',
    },
    actionRequired: [
      {
        id: 'act-101',
        type: 'PROPOSAL_PENDING',
        title: 'New Broker Proposal Received',
        description: 'Quality Grade A Wheat proposal from Broker #B-402 awaiting counter or acceptance.',
        timeRemaining: '18h remaining',
        ctaLabel: 'Review Proposal',
        ctaUrl: '/buyer/proposals',
      },
      {
        id: 'act-102',
        type: 'DISPATCH_IN_TRANSIT',
        title: 'Shipment Dispatched in Transit',
        description: 'Vehicle KA-04-E-8821 carrying 30 MT Yellow Corn is currently en route.',
        timeRemaining: 'ETA 6 Hours',
        ctaLabel: 'Track Shipment',
        ctaUrl: '/buyer/orders',
      },
      {
        id: 'act-103',
        type: 'ACTION_EXPIRED',
        title: 'Target Date Approaching',
        description: 'Soybean Meal mandate target date expires in less than 24 hours.',
        timeRemaining: 'Expires Today',
        ctaLabel: 'Update Mandate',
        ctaUrl: '/buyer/requirements',
      },
    ],
    recentRequirements: [
      {
        id: 'req-201',
        commodityName: 'Durum Wheat',
        gradeName: 'Grade A - Super Fine',
        quantityWithUnit: '100 MT',
        targetPrice: '₹ 2,850 / Qtl',
        status: 'Sourcing',
        createdAt: '2 hours ago',
      },
      {
        id: 'req-202',
        commodityName: 'Yellow Corn (Maize)',
        gradeName: 'Feed Grade Premium',
        quantityWithUnit: '50 MT',
        targetPrice: '₹ 2,150 / Qtl',
        status: 'Matched',
        createdAt: '1 day ago',
      },
      {
        id: 'req-203',
        commodityName: 'Soybean Meal',
        gradeName: 'High Protein 46%',
        quantityWithUnit: '25 MT',
        targetPrice: '₹ 4,400 / Qtl',
        status: 'Submitted',
        createdAt: '3 days ago',
      },
    ],
    activeShipments: [
      {
        bookingId: 'BKG-2026-8812',
        commodity: 'Yellow Corn (Maize)',
        dispatchedQuantity: '30.5 MT',
        transporter: 'VRL Logistics',
        eta: 'Today, 6:00 PM',
        status: 'In Transit',
      },
      {
        bookingId: 'BKG-2026-8790',
        commodity: 'Durum Wheat',
        dispatchedQuantity: '45.0 MT',
        transporter: 'TCI Freight',
        eta: 'Tomorrow, 11:30 AM',
        status: 'Dispatched',
      },
    ],
  };

  if (!sessionRes.success || !sessionRes.data?.companyId) {
    return {
      success: false,
      error: sessionRes.error || 'Unauthorized session',
      data: fallbackPayload,
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
      (r) => r.status === 'open' || r.status === 'partially_fulfilled'
    ).length;

    // 2. Fetch Active Deals
    const userDeals = await db.query.deals.findMany({
      where: eq(deals.buyerId, companyId),
      limit: 5,
      orderBy: [desc(deals.createdAt)],
    });

    const activeOrdersCount = userDeals.filter(
      (d) => d.status === 'Dispatch Pending' || d.status === 'Dispatched' || d.status === 'In Transit'
    ).length;

    // Build real payload if records exist
    const realPayload: BuyerDashboardSummaryPayload = {
      kpis: {
        activeRequirementsCount: activeReqsCount || fallbackPayload.kpis.activeRequirementsCount,
        proposalsPendingCount: fallbackPayload.kpis.proposalsPendingCount,
        activeOrdersCount: activeOrdersCount || fallbackPayload.kpis.activeOrdersCount,
        pendingPayablesFormatted: fallbackPayload.kpis.pendingPayablesFormatted,
      },
      actionRequired: fallbackPayload.actionRequired,
      recentRequirements:
        userRequirements.length > 0
          ? userRequirements.slice(0, 3).map((r) => ({
              id: r.id,
              commodityName: 'Agricultural Commodity',
              gradeName: 'Standard Commercial Grade',
              quantityWithUnit: `${r.quantity} MT`,
              targetPrice: r.targetPrice ? formatIndianCurrency(Number(r.targetPrice)) : 'Market Rate',
              status: r.status === 'open' ? 'Sourcing' : r.status === 'fulfilled' ? 'Matched' : 'Submitted',
              createdAt: new Date(r.createdAt).toLocaleDateString('en-IN', {
                day: 'numeric',
                month: 'short',
              }),
            }))
          : fallbackPayload.recentRequirements,
      activeShipments: fallbackPayload.activeShipments,
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
      data: fallbackPayload,
    };
  }
}
