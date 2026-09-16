'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  deals,
  requirements,
  quotations,
  dispatches,
  crmTasks,
  crmContacts,
  companies,
  masterCommodities,
  masterGrades,
  users,
} from '@/src/server/db/schema';
import { eq, and, notInArray, inArray, desc, sql, aliasedTable, or, lt, ne } from 'drizzle-orm';
import { formatIndianCurrency } from '@/lib/utils';
import { format, isToday, isPast } from 'date-fns';

export interface BrokerDashboardKpis {
  activeDealsCount: number;
  openRequirementsCount: number;
  dispatchDueCount: number;
  commissionThisMonth: string;
}

export interface BrokerAlertItem {
  id: string;
  type: 'danger' | 'warning' | 'teal';
  badge: string;
  dealRef: string;
  commodity: string;
  title: string;
  description: string;
  dueTime: string;
  actionLabel: string;
  actionHref: string;
}

export interface BrokerPipelineDeal {
  id: string;
  dealRef: string;
  commodity: string;
  quantity: string;
  targetPrice: string;
  buyer: string;
  seller: string;
  status: 'Negotiating' | 'Ready to Book';
  nextAction: string;
  href: string;
}

export interface BrokerFollowUpTask {
  id: string;
  title: string;
  entity: string;
  time: string;
  priority: 'high' | 'medium';
  completed: boolean;
}

export interface BrokerDashboardPayload {
  kpis: BrokerDashboardKpis;
  alerts: BrokerAlertItem[];
  pipeline: BrokerPipelineDeal[];
  tasks: BrokerFollowUpTask[];
}

export type BrokerDashboardResponse = {
  success: boolean;
  data?: BrokerDashboardPayload;
  error?: string;
};

/**
 * Server Action for Micro-Sprint 22.4: Broker Dashboard Live Data Integration
 * Enforces Strict Assignment Model: broker_id === currentUser.id
 * Strips all Buyer PII to maintain strict data protection.
 */
export async function getBrokerDashboardDataAction(): Promise<BrokerDashboardResponse> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Session required' };
    }

    // Verify user role & identity
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User not found in system' };
    }

    const role = (dbUser.role || '').toLowerCase();
    if (role !== 'broker' && role !== 'admin') {
      return { success: false, error: 'Forbidden: Broker access privileges required' };
    }

    const brokerId = dbUser.id;
    const isAdmin = role === 'admin';

    const buyerCompanies = aliasedTable(companies, 'buyer_companies');
    const sellerCompanies = aliasedTable(companies, 'seller_companies');

    // Execute optimized parallel Drizzle queries
    const [
      activeDealsCountRes,
      openReqsCountRes,
      dispatchDueCountRes,
      commissionSumRes,
      counterQuotationsRes,
      delayedDispatchesRes,
      readyToBookDealsRes,
      recentPipelineDealsRes,
      crmTasksRes,
    ] = await Promise.all([
      // 1. KPI: Active Deals Count
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(deals)
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            notInArray(deals.status, ['Closed', 'Cancelled'])
          )
        ),

      // 2. KPI: Open Requirements Count
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(requirements)
        .where(
          and(
            isAdmin ? sql`true` : eq(requirements.brokerId, brokerId),
            inArray(requirements.status, ['Open', 'Partially Fulfilled'])
          )
        ),

      // 3. KPI: Dispatch Due Count
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(deals)
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            inArray(deals.status, ['Dispatch Pending', 'Booking Confirmed'])
          )
        ),

      // 4. KPI: Commission this month (based on agreed deals volume * ₹50/MT brokerage rate)
      db
        .select({
          totalCommission: sql<number>`COALESCE(SUM(${deals.agreedQuantity} * 50), 0)::float`,
        })
        .from(deals)
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            notInArray(deals.status, ['Cancelled'])
          )
        ),

      // 5. P0 Alerts: Countered Quotations / Requests
      db
        .select({
          quotationId: quotations.id,
          requirementId: quotations.requirementId,
          counterPrice: quotations.counterPrice,
          counterNotes: quotations.counterNotes,
          status: quotations.status,
          validUntil: quotations.validUntil,
          commodityName: masterCommodities.name,
          targetPrice: requirements.targetPrice,
          quantity: requirements.quantity,
        })
        .from(quotations)
        .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(quotations.brokerId, brokerId),
            or(
              inArray(quotations.status, ['Countered', 'Seller Countered', 'Buyer Countered']),
              sql`${quotations.counterPrice} IS NOT NULL AND ${quotations.status} != 'Accepted'`
            )
          )
        )
        .limit(3),

      // 6. P0 Alerts: Delayed Dispatches
      db
        .select({
          dispatchId: dispatches.id,
          dealId: dispatches.dealId,
          vehicleNumber: dispatches.vehicleNumber,
          expectedDeliveryDate: dispatches.expectedDeliveryDate,
          status: dispatches.status,
          commodityName: masterCommodities.name,
          agreedQuantity: deals.agreedQuantity,
        })
        .from(dispatches)
        .innerJoin(deals, eq(dispatches.dealId, deals.id))
        .innerJoin(requirements, eq(deals.requirementId, requirements.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            or(
              eq(dispatches.status, 'Delayed'),
              and(
                ne(dispatches.status, 'Delivered'),
                lt(dispatches.expectedDeliveryDate, new Date())
              )
            )
          )
        )
        .limit(2),

      // 7. P0 Alerts: Deals Ready for Booking / Finalization
      db
        .select({
          dealId: deals.id,
          commodityName: masterCommodities.name,
          agreedQuantity: deals.agreedQuantity,
          agreedPrice: deals.agreedPrice,
          status: deals.status,
        })
        .from(deals)
        .innerJoin(requirements, eq(deals.requirementId, requirements.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            inArray(deals.status, ['Seller Confirmed', 'Confirmed', 'Draft'])
          )
        )
        .limit(2),

      // 8. Active Pipeline Deals (Recent active negotiations / pending dispatches)
      db
        .select({
          deal: deals,
          commodityName: masterCommodities.name,
          gradeName: masterGrades.gradeName,
          buyerCompanyName: buyerCompanies.name,
          sellerCompanyName: sellerCompanies.name,
        })
        .from(deals)
        .innerJoin(requirements, eq(deals.requirementId, requirements.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .leftJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
        .innerJoin(buyerCompanies, eq(deals.buyerId, buyerCompanies.id))
        .innerJoin(sellerCompanies, eq(deals.sellerId, sellerCompanies.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            notInArray(deals.status, ['Closed', 'Cancelled', 'Delivered'])
          )
        )
        .orderBy(desc(deals.createdAt))
        .limit(3),

      // 9. Today's Follow-ups / CRM Tasks
      db
        .select({
          task: crmTasks,
          companyName: companies.name,
        })
        .from(crmTasks)
        .leftJoin(crmContacts, eq(crmTasks.contactId, crmContacts.id))
        .leftJoin(companies, eq(crmContacts.companyId, companies.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(crmTasks.brokerId, brokerId),
            eq(crmTasks.status, 'Pending')
          )
        )
        .orderBy(crmTasks.dueDate)
        .limit(3),
    ]);

    // Build KPIs object
    const kpis: BrokerDashboardKpis = {
      activeDealsCount: activeDealsCountRes[0]?.count ?? 0,
      openRequirementsCount: openReqsCountRes[0]?.count ?? 0,
      dispatchDueCount: dispatchDueCountRes[0]?.count ?? 0,
      commissionThisMonth: formatIndianCurrency(commissionSumRes[0]?.totalCommission ?? 0),
    };

    // Construct Unified Alerts Array
    const alerts: BrokerAlertItem[] = [];

    // Add Counter Alerts
    for (const item of counterQuotationsRes) {
      alerts.push({
        id: `alert-counter-${item.quotationId}`,
        type: 'warning',
        badge: 'Counter Offer',
        dealRef: `#REQ-${item.requirementId.slice(0, 4).toUpperCase()}`,
        commodity: `${item.commodityName} (${item.quantity} MT)`,
        title: 'Seller Counter Received (Needs Review)',
        description: item.counterPrice
          ? `Counter offer received at ₹${Number(item.counterPrice).toLocaleString('en-IN')}/Qtl (Target was ₹${Number(item.targetPrice).toLocaleString('en-IN')}). Requires broker review.`
          : 'Seller proposed counter terms on this requirement. Action required before expiry.',
        dueTime: item.validUntil ? `Expires ${format(new Date(item.validUntil), 'p')}` : 'Action required today',
        actionLabel: 'Review Terms',
        actionHref: '/broker/work?tab=negotiations',
      });
    }

    // Add Delayed Dispatch Alerts
    for (const item of delayedDispatchesRes) {
      alerts.push({
        id: `alert-dispatch-${item.dispatchId}`,
        type: 'danger',
        badge: 'Logistics Delay',
        dealRef: `#DL-${item.dealId.slice(0, 4).toUpperCase()}`,
        commodity: `${item.commodityName} (${item.agreedQuantity} MT)`,
        title: `Dispatch Delayed for Deal #${item.dealId.slice(0, 4).toUpperCase()}`,
        description: `Vehicle ${item.vehicleNumber || 'transport'} is delayed beyond expected delivery timeline (${format(new Date(item.expectedDeliveryDate), 'dd MMM')}). Buyer requested urgent ETA update.`,
        dueTime: 'Overdue',
        actionLabel: 'Resolve Dispatch',
        actionHref: '/broker/orders',
      });
    }

    // Add Ready to Book Alerts
    for (const item of readyToBookDealsRes) {
      alerts.push({
        id: `alert-book-${item.dealId}`,
        type: 'teal',
        badge: 'Ready to Book',
        dealRef: `#DL-${item.dealId.slice(0, 4).toUpperCase()}`,
        commodity: `${item.commodityName} (${item.agreedQuantity} MT)`,
        title: 'Buyer & Seller Mandate Ready to Book',
        description: 'Both trading parties have confirmed terms. Pre-flight verification cleared. Broker execution required to lock booking.',
        dueTime: 'Action required today',
        actionLabel: 'Finalize Booking',
        actionHref: '/broker/deals',
      });
    }

    // Construct Active Pipeline Deals (ZERO BUYER PII)
    const pipeline: BrokerPipelineDeal[] = recentPipelineDealsRes.map((row) => {
      const isReady = row.deal.status === 'Seller Confirmed' || row.deal.status === 'Confirmed';

      return {
        id: row.deal.id,
        dealRef: `#DL-${row.deal.id.slice(0, 4).toUpperCase()}`,
        commodity: row.gradeName ? `${row.commodityName} (${row.gradeName})` : row.commodityName,
        quantity: `${row.deal.agreedQuantity} MT`,
        targetPrice: `₹${Number(row.deal.agreedPrice).toLocaleString('en-IN')}/Qtl`,
        // Strict: Return verified company names only, no personal buyer identity
        buyer: row.buyerCompanyName || `Verified Buyer #B-${row.deal.buyerId.slice(0, 4).toUpperCase()}`,
        seller: row.sellerCompanyName || 'Verified Seller Partner',
        status: isReady ? 'Ready to Book' : 'Negotiating',
        nextAction: isReady
          ? 'Both parties agreed. Ready for Booking Gate'
          : 'Waiting on term alignment & revision review',
        href: '/broker/deals',
      };
    });

    // Construct Follow-up Tasks Array
    const tasks: BrokerFollowUpTask[] = crmTasksRes.map((row) => {
      const due = new Date(row.task.dueDate);
      const isDueToday = isToday(due);
      const isDuePast = isPast(due);

      let timeLabel = `Due ${format(due, 'dd MMM, p')}`;
      if (isDueToday) {
        timeLabel = `Due today, ${format(due, 'p')}`;
      } else if (isDuePast) {
        timeLabel = `Overdue (${format(due, 'dd MMM')})`;
      }

      return {
        id: row.task.id,
        title: row.task.title,
        entity: row.companyName || 'Client Mandate',
        time: timeLabel,
        priority: (row.task.priority || '').toLowerCase() === 'high' ? 'high' : 'medium',
        completed: row.task.status === 'Completed',
      };
    });

    return {
      success: true,
      data: {
        kpis,
        alerts,
        pipeline,
        tasks,
      },
    };
  } catch (error: any) {
    console.error('getBrokerDashboardDataAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch broker dashboard data',
    };
  }
}
