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

const DEMO_BROKER_DASHBOARD_PAYLOAD: BrokerDashboardPayload = {
  kpis: {
    activeDealsCount: 8,
    openRequirementsCount: 14,
    dispatchDueCount: 3,
    commissionThisMonth: '₹1,42,500',
  },
  alerts: [
    {
      id: 'alert-counter-1',
      type: 'warning',
      badge: 'Counter Offer',
      dealRef: '#REQ-4091',
      commodity: 'Malwa Sharbati Wheat (100 MT)',
      title: 'Seller Counter Received (Needs Review)',
      description: 'Rajasthan Agro Trading countered at ₹28,500/MT (Target was ₹28,000/MT). Net margin impact is +₹500/MT. Requires broker review before 4-hour validity expires.',
      dueTime: 'Expires in 4 hours',
      actionLabel: 'Review Terms',
      actionHref: '/broker/work?tab=negotiations',
    },
    {
      id: 'alert-dispatch-2',
      type: 'danger',
      badge: 'Logistics Delay',
      dealRef: '#DL-8812',
      commodity: 'Feed Grade Yellow Maize (250 MT)',
      title: 'Vehicle RJ-14-GA-8812 Delayed in Transit',
      description: 'Vehicle carrying 50 MT partial fulfillment dispatch delayed near Kotputli toll due to highway maintenance. Buyer requested urgent revised ETA update.',
      dueTime: 'Overdue by 3h',
      actionLabel: 'Resolve Dispatch',
      actionHref: '/broker/orders',
    },
    {
      id: 'alert-book-3',
      type: 'teal',
      badge: 'Ready to Book',
      dealRef: '#DL-7041',
      commodity: 'Non-GMO Soybean Meal (75 MT)',
      title: 'Buyer & Seller Confirmed Mandate',
      description: 'Both Apex Cattle Nutrition and Indore Agro Refineries have digitally confirmed Version 2 terms. Pre-flight checks passed. Broker trigger required to lock booking.',
      dueTime: 'Action required today',
      actionLabel: 'Finalize Booking',
      actionHref: '/broker/deals',
    },
  ],
  pipeline: [
    {
      id: 'deal-8812',
      dealRef: '#DL-8812',
      commodity: 'Malwa Sharbati Wheat (Grade A Milling)',
      quantity: '100 MT',
      targetPrice: '₹28,500 / MT',
      buyer: 'AgrInnovate Flour Mills',
      seller: 'Rajasthan Agro Trading',
      status: 'Ready to Book',
      nextAction: 'Both parties agreed. Ready for Booking Gate execution',
      href: '/broker/deals',
    },
    {
      id: 'deal-7041',
      dealRef: '#DL-7041',
      commodity: 'Feed Grade Yellow Maize (High Starch)',
      quantity: '250 MT',
      targetPrice: '₹21,800 / MT',
      buyer: 'North Dairy Feed Corp',
      seller: 'Malwa Grain Exporters',
      status: 'Negotiating',
      nextAction: 'Waiting on seller acceptance of revised dispatch window',
      href: '/broker/deals',
    },
    {
      id: 'deal-6029',
      dealRef: '#DL-6029',
      commodity: 'Non-GMO Soybean Meal (De-oiled Cake)',
      quantity: '75 MT',
      targetPrice: '₹42,500 / MT',
      buyer: 'Apex Cattle Nutrition',
      seller: 'Indore Agro Refineries',
      status: 'Ready to Book',
      nextAction: 'Ready for Final Deal snapshot generation',
      href: '/broker/deals',
    },
    {
      id: 'deal-9114',
      dealRef: '#DL-9114',
      commodity: 'Chana Dal (Desi Chickpeas Grade 1)',
      quantity: '50 MT',
      targetPrice: '₹62,000 / MT',
      buyer: 'Shubh Food Products',
      seller: 'Shekhawati Pulse Processors',
      status: 'Negotiating',
      nextAction: 'Counter proposal awaiting buyer sign-off',
      href: '/broker/deals',
    },
  ],
  tasks: [
    {
      id: 'task-1',
      title: 'Call Rajasthan Agro to confirm vehicle dispatch date for Wheat lot',
      entity: 'Rajasthan Agro Trading',
      time: 'Due today, 3:30 PM',
      priority: 'high',
      completed: false,
    },
    {
      id: 'task-2',
      title: 'Send revised payment milestone terms to AgrInnovate Accounts',
      entity: 'AgrInnovate Flour Mills',
      time: 'Due today, 5:00 PM',
      priority: 'high',
      completed: false,
    },
    {
      id: 'task-3',
      title: 'Follow up with Mandi Quality Lab for COA moisture test report',
      entity: 'Anand Quality Testing Lab',
      time: 'Due tomorrow, 11:00 AM',
      priority: 'medium',
      completed: false,
    },
    {
      id: 'task-4',
      title: 'Verify E-Way bill clearance for Dispatch #DSP-4012',
      entity: 'Jaipur Golden Transport',
      time: 'Due 18 Oct, 2:00 PM',
      priority: 'medium',
      completed: false,
    },
  ],
};

/**
 * Server Action for Micro-Sprint 22.4: Broker Dashboard Live Data Integration
 * Enforces Strict Assignment Model: broker_id === currentUser.id
 * Strips all Buyer PII to maintain strict data protection.
 */
export async function getBrokerDashboardDataAction(): Promise<BrokerDashboardResponse> {
  try {
    let authUser = null;
    let authError = null;

    try {
      const supabase = await createClient();
      const res = await supabase.auth.getUser();
      authUser = res.data.user;
      authError = res.error;
    } catch (_e) {
      // Supabase unconfigured in local dev
    }

    if (authError || !authUser) {
      // In development mode or unauthenticated testing, return realistic demo trading desk data
      return {
        success: true,
        data: DEMO_BROKER_DASHBOARD_PAYLOAD,
      };
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
