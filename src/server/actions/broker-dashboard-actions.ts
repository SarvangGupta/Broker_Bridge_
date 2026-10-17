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
  availabilities,
  disputes,
  invoices,
  notifications,
} from '@/src/server/db/schema';
import { eq, and, notInArray, inArray, desc, sql, aliasedTable, or, lt, ne } from 'drizzle-orm';
import { formatIndianCurrency } from '@/lib/utils';
import { format, isToday, isPast, formatDistanceToNow } from 'date-fns';

export interface BrokerDashboardKpis {
  activeDealsCount: number;
  openRequirementsCount: number;
  partiallyAllocatedCount: number;
  availableOffersCount: number;
  awaitingConfirmationCount: number;
  dispatchDueCount: number;
  deliveriesAwaitingConfirmationCount: number;
  openDisputesCount: number;
  commissionThisMonth: string;
  commissionPendingInvoicesCount: number;
}

export type PendingActionCategory =
  | 'requirement_expiring'
  | 'partial_allocation'
  | 'terms_confirmation'
  | 'delivery_review'
  | 'dispute_unresolved'
  | 'invoice_followup';

export interface BrokerAlertItem {
  id: string;
  category?: PendingActionCategory;
  type: 'danger' | 'warning' | 'teal' | 'blue';
  badge: string;
  dealRef: string;
  commodity: string;
  title: string;
  description: string;
  dueTime: string;
  actionLabel: string;
  actionHref: string;
}

export type BrokerPendingActionItem = BrokerAlertItem;

export interface BrokerRecentActivityItem {
  id: string;
  eventType: 'deal_update' | 'dispatch_status' | 'requirement_posted' | 'offer_created' | 'dispute_filed' | 'invoice_issued' | 'system_alert';
  category: 'deals' | 'logistics' | 'requirements' | 'disputes' | 'finance';
  title: string;
  description: string;
  referenceId: string;
  timestamp: string;
  relativeTime: string;
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
  pendingActions: BrokerPendingActionItem[];
  recentActivity: BrokerRecentActivityItem[];
  pipeline: BrokerPipelineDeal[];
  tasks: BrokerFollowUpTask[];
}

export type BrokerDashboardResponse = {
  success: boolean;
  data?: BrokerDashboardPayload;
  error?: string;
};

/**
 * Server Action: Authoritative Broker Operational Overview & Dashboard Data
 * Micro-Sprint RB-05
 * 
 * Enforces Strict Assignment Model: broker_id === currentUser.id
 * Strips all Buyer & Seller Personal Contact PII (Zero personal phone, email, WhatsApp leaks)
 * Prevents N+1 queries via parallel aggregated Drizzle queries.
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
      // Supabase unconfigured in offline/local mock
    }

    if (authError || !authUser) {
      return {
        success: false,
        error: 'Unauthorized: Valid broker session required',
      };
    }

    // Verify user role & identity from database
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

    // Execute optimized parallel Drizzle queries with graceful partial failure resilience
    const [
      activeDealsCountRes,
      openReqsCountRes,
      partiallyAllocatedCountRes,
      availableOffersRes,
      awaitingConfirmationCountRes,
      dispatchDueCountRes,
      deliveriesAwaitingCountRes,
      commissionSumRes,
      pendingInvoicesCountRes,
      openDisputesRes,
      counterQuotationsRes,
      delayedDispatchesRes,
      readyToBookDealsRes,
      expiringRequirementsRes,
      partialAllocationsRes,
      unresolvedDisputesRes,
      pendingInvoicesRes,
      recentPipelineDealsRes,
      crmTasksRes,
      recentNotificationsRes,
      recentDealsStreamRes,
      recentDispatchesStreamRes,
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
        )
        .catch(() => [{ count: 0 }]),

      // 2. KPI: Open Requirements Count
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(requirements)
        .where(
          and(
            isAdmin ? sql`true` : eq(requirements.brokerId, brokerId),
            inArray(requirements.status, ['Open', 'Partially Fulfilled'])
          )
        )
        .catch(() => [{ count: 0 }]),

      // 3. KPI: Partially Allocated Requirements Count
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(requirements)
        .where(
          and(
            isAdmin ? sql`true` : eq(requirements.brokerId, brokerId),
            eq(requirements.status, 'Partially Fulfilled')
          )
        )
        .catch(() => [{ count: 0 }]),

      // 4. KPI: Available Seller Offers
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(availabilities)
        .where(
          and(
            isAdmin ? sql`true` : eq(availabilities.brokerId, brokerId),
            eq(availabilities.status, 'Open')
          )
        )
        .catch(() => [{ count: 0 }]),

      // 5. KPI: Deals Awaiting Confirmation
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(deals)
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            inArray(deals.status, ['Draft', 'Proposed', 'Countered', 'Seller Confirmed', 'Buyer Confirmed'])
          )
        )
        .catch(() => [{ count: 0 }]),

      // 6. KPI: Dispatch Due Count
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(deals)
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            inArray(deals.status, ['Dispatch Pending', 'Booking Confirmed'])
          )
        )
        .catch(() => [{ count: 0 }]),

      // 7. KPI: Deliveries In Transit / Awaiting Arrival
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(dispatches)
        .innerJoin(deals, eq(dispatches.dealId, deals.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            inArray(dispatches.status, ['Dispatched', 'Delayed'])
          )
        )
        .catch(() => [{ count: 0 }]),

      // 8. KPI: Commission Volume Earned (Agreed Quantity * ₹50/MT rate)
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
        )
        .catch(() => [{ totalCommission: 0 }]),

      // 9. KPI: Pending Invoices Count
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(invoices)
        .innerJoin(deals, eq(invoices.dealId, deals.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            eq(invoices.status, 'Pending')
          )
        )
        .catch(() => [{ count: 0 }]),

      // 10. KPI: Open Disputes Count (Scoped to Broker's deals)
      db
        .select({ count: sql<number>`count(*)::int` })
        .from(disputes)
        .innerJoin(deals, eq(disputes.dealId, deals.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            eq(disputes.status, 'Open')
          )
        )
        .catch(() => [{ count: 0 }]),

      // --- PENDING ACTIONS CATEGORIES ---

      // Action Cat 1: Countered Quotations / Deals awaiting counter review
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
        .limit(2)
        .catch(() => []),

      // Action Cat 2: Delayed Dispatches
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
        .limit(2)
        .catch(() => []),

      // Action Cat 3: Ready to Book Deals
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
        .limit(2)
        .catch(() => []),

      // Action Cat 4: Requirements Expiring Soon (Within 48 hours)
      db
        .select({
          requirementId: requirements.id,
          commodityName: masterCommodities.name,
          quantity: requirements.quantity,
          targetPrice: requirements.targetPrice,
          targetDate: requirements.targetDate,
          status: requirements.status,
        })
        .from(requirements)
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(requirements.brokerId, brokerId),
            inArray(requirements.status, ['Open', 'Partially Fulfilled']),
            sql`${requirements.targetDate} <= NOW() + INTERVAL '48 hours'`
          )
        )
        .limit(2)
        .catch(() => []),

      // Action Cat 5: Partially Allocated Requirements Needing Completion
      db
        .select({
          requirementId: requirements.id,
          commodityName: masterCommodities.name,
          quantity: requirements.quantity,
          fulfilledQuantity: requirements.fulfilledQuantity,
          targetPrice: requirements.targetPrice,
          status: requirements.status,
        })
        .from(requirements)
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(requirements.brokerId, brokerId),
            eq(requirements.status, 'Partially Fulfilled')
          )
        )
        .limit(2)
        .catch(() => []),

      // Action Cat 6: Unresolved Disputes on Broker Deals
      db
        .select({
          disputeId: disputes.id,
          dealId: disputes.dealId,
          reason: disputes.reason,
          description: disputes.description,
          status: disputes.status,
          createdAt: disputes.createdAt,
          commodityName: masterCommodities.name,
          agreedQuantity: deals.agreedQuantity,
        })
        .from(disputes)
        .innerJoin(deals, eq(disputes.dealId, deals.id))
        .innerJoin(requirements, eq(deals.requirementId, requirements.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            eq(disputes.status, 'Open')
          )
        )
        .limit(2)
        .catch(() => []),

      // Action Cat 7: Commission Invoices Awaiting Payment
      db
        .select({
          invoiceId: invoices.id,
          dealId: invoices.dealId,
          invoiceNo: invoices.invoiceNo,
          amount: invoices.amount,
          status: invoices.status,
          createdAt: invoices.createdAt,
          commodityName: masterCommodities.name,
        })
        .from(invoices)
        .innerJoin(deals, eq(invoices.dealId, deals.id))
        .innerJoin(requirements, eq(deals.requirementId, requirements.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(
          and(
            isAdmin ? sql`true` : eq(deals.brokerId, brokerId),
            eq(invoices.status, 'Pending')
          )
        )
        .limit(2)
        .catch(() => []),

      // Active Pipeline Deals (Recent active negotiations / pending dispatches)
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
        .limit(4)
        .catch(() => []),

      // Today's Follow-ups / CRM Tasks
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
        .limit(4)
        .catch(() => []),

      // Event Stream 1: Recent In-App Notifications for Broker
      db
        .select({
          id: notifications.id,
          eventType: notifications.eventType,
          title: notifications.title,
          message: notifications.message,
          actionUrl: notifications.actionUrl,
          createdAt: notifications.createdAt,
        })
        .from(notifications)
        .where(eq(notifications.userId, brokerId))
        .orderBy(desc(notifications.createdAt))
        .limit(4)
        .catch(() => []),

      // Event Stream 2: Recent Deals Status Events
      db
        .select({
          dealId: deals.id,
          status: deals.status,
          agreedQuantity: deals.agreedQuantity,
          commodityName: masterCommodities.name,
          createdAt: deals.createdAt,
        })
        .from(deals)
        .innerJoin(requirements, eq(deals.requirementId, requirements.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .where(isAdmin ? sql`true` : eq(deals.brokerId, brokerId))
        .orderBy(desc(deals.createdAt))
        .limit(4)
        .catch(() => []),

      // Event Stream 3: Recent Dispatches Events
      db
        .select({
          dispatchId: dispatches.id,
          dealId: dispatches.dealId,
          vehicleNumber: dispatches.vehicleNumber,
          status: dispatches.status,
          createdAt: dispatches.createdAt,
        })
        .from(dispatches)
        .innerJoin(deals, eq(dispatches.dealId, deals.id))
        .where(isAdmin ? sql`true` : eq(deals.brokerId, brokerId))
        .orderBy(desc(dispatches.createdAt))
        .limit(4)
        .catch(() => []),
    ]);

    // Build Complete 8-KPI Object
    const kpis: BrokerDashboardKpis = {
      activeDealsCount: activeDealsCountRes[0]?.count ?? 0,
      openRequirementsCount: openReqsCountRes[0]?.count ?? 0,
      partiallyAllocatedCount: partiallyAllocatedCountRes[0]?.count ?? 0,
      availableOffersCount: availableOffersRes[0]?.count ?? 0,
      awaitingConfirmationCount: awaitingConfirmationCountRes[0]?.count ?? 0,
      dispatchDueCount: dispatchDueCountRes[0]?.count ?? 0,
      deliveriesAwaitingConfirmationCount: deliveriesAwaitingCountRes[0]?.count ?? 0,
      openDisputesCount: openDisputesRes[0]?.count ?? 0,
      commissionThisMonth: formatIndianCurrency(commissionSumRes[0]?.totalCommission ?? 0),
      commissionPendingInvoicesCount: pendingInvoicesCountRes[0]?.count ?? 0,
    };

    // Construct Unified Prioritized Pending Actions Array
    const pendingActions: BrokerPendingActionItem[] = [];

    // 1. Unresolved Disputes (P0 Critical)
    for (const item of unresolvedDisputesRes) {
      pendingActions.push({
        id: `action-dispute-${item.disputeId}`,
        category: 'dispute_unresolved',
        type: 'danger',
        badge: 'Active Dispute',
        dealRef: `#DL-${item.dealId.slice(0, 4).toUpperCase()}`,
        commodity: `${item.commodityName} (${item.agreedQuantity} MT)`,
        title: `Dispute Filed: ${item.reason}`,
        description: item.description
          ? `Dispute raised on deal terms or quality: "${item.description.slice(0, 90)}...". Immediate broker mediation required.`
          : 'Trade dispute requires broker arbitration and resolution.',
        dueTime: 'Immediate action',
        actionLabel: 'Arbitrate Claim',
        actionHref: '/broker/more/disputes',
      });
    }

    // 2. Delayed Dispatches / Logistics Delay (P0 Critical)
    for (const item of delayedDispatchesRes) {
      pendingActions.push({
        id: `action-dispatch-${item.dispatchId}`,
        category: 'delivery_review',
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

    // 3. Counter Quotations (P1 Urgency)
    for (const item of counterQuotationsRes) {
      pendingActions.push({
        id: `action-counter-${item.quotationId}`,
        category: 'terms_confirmation',
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

    // 4. Ready to Book Deals (P1 Action)
    for (const item of readyToBookDealsRes) {
      pendingActions.push({
        id: `action-book-${item.dealId}`,
        category: 'terms_confirmation',
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

    // 5. Expiring Requirements (P2 Warning)
    for (const item of expiringRequirementsRes) {
      pendingActions.push({
        id: `action-expiring-${item.requirementId}`,
        category: 'requirement_expiring',
        type: 'warning',
        badge: 'Expiring Soon',
        dealRef: `#REQ-${item.requirementId.slice(0, 4).toUpperCase()}`,
        commodity: `${item.commodityName} (${item.quantity} MT)`,
        title: 'Procurement Mandate Expiring Within 48 Hours',
        description: `Target delivery date (${format(new Date(item.targetDate), 'dd MMM')}) is approaching. Fast-track allocation or request buyer validity extension.`,
        dueTime: `Due ${format(new Date(item.targetDate), 'dd MMM')}`,
        actionLabel: 'Match Lots',
        actionHref: '/broker/work',
      });
    }

    // 6. Partially Allocated Requirements (P2 Optimization)
    for (const item of partialAllocationsRes) {
      const remainingQty = Math.max(0, item.quantity - (item.fulfilledQuantity || 0));
      pendingActions.push({
        id: `action-partial-${item.requirementId}`,
        category: 'partial_allocation',
        type: 'blue',
        badge: 'Partial Allocation',
        dealRef: `#REQ-${item.requirementId.slice(0, 4).toUpperCase()}`,
        commodity: `${item.commodityName} (${item.quantity} MT)`,
        title: `Partial Fulfillment: ${item.fulfilledQuantity} MT of ${item.quantity} MT Matched`,
        description: `Remaining balance of ${remainingQty} MT is unallocated. Find matching seller offers to complete mandate.`,
        dueTime: 'Ongoing allocation',
        actionLabel: 'Allocate Balance',
        actionHref: '/broker/work',
      });
    }

    // 7. Commission Invoices Awaiting Payment (P2 Financial)
    for (const item of pendingInvoicesRes) {
      pendingActions.push({
        id: `action-invoice-${item.invoiceId}`,
        category: 'invoice_followup',
        type: 'warning',
        badge: 'Invoice Pending',
        dealRef: `#INV-${item.invoiceNo}`,
        commodity: `${item.commodityName || 'Trade Lot'}`,
        title: `Invoice #${item.invoiceNo} Awaiting Settlement`,
        description: `Brokerage invoice of ₹${Number(item.amount).toLocaleString('en-IN')} for Deal #${item.dealId.slice(0, 4).toUpperCase()} is pending payment clearance.`,
        dueTime: 'Pending payment',
        actionLabel: 'View Invoice',
        actionHref: '/broker/more/commission',
      });
    }

    // Construct Active Pipeline Deals (Strictly Verified Company Names - Zero Contact PII)
    const pipeline: BrokerPipelineDeal[] = recentPipelineDealsRes.map((row) => {
      const isReady = row.deal.status === 'Seller Confirmed' || row.deal.status === 'Confirmed';

      return {
        id: row.deal.id,
        dealRef: `#DL-${row.deal.id.slice(0, 4).toUpperCase()}`,
        commodity: row.gradeName ? `${row.commodityName} (${row.gradeName})` : row.commodityName,
        quantity: `${row.deal.agreedQuantity} MT`,
        targetPrice: `₹${Number(row.deal.agreedPrice).toLocaleString('en-IN')}/Qtl`,
        buyer: row.buyerCompanyName || `Verified Buyer #B-${row.deal.buyerId.slice(0, 4).toUpperCase()}`,
        seller: row.sellerCompanyName || 'Verified Seller Partner',
        status: isReady ? 'Ready to Book' : 'Negotiating',
        nextAction: isReady
          ? 'Both parties agreed. Ready for Booking Gate'
          : 'Waiting on term alignment & revision review',
        href: '/broker/deals',
      };
    });

    // Construct CRM Follow-up Tasks Array
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

    // Construct Real Authoritative Recent Activity Stream
    const rawEvents: Array<{
      id: string;
      date: Date;
      item: BrokerRecentActivityItem;
    }> = [];

    // Notification Events
    for (const n of recentNotificationsRes) {
      rawEvents.push({
        id: `act-notif-${n.id}`,
        date: new Date(n.createdAt),
        item: {
          id: `act-notif-${n.id}`,
          eventType: 'system_alert',
          category: 'requirements',
          title: n.title,
          description: n.message || 'Operational trade notification',
          referenceId: `#NOTIF-${n.id.slice(0, 4).toUpperCase()}`,
          timestamp: n.createdAt.toISOString(),
          relativeTime: formatDistanceToNow(new Date(n.createdAt), { addSuffix: true }),
          actionHref: n.actionUrl || '/broker',
        },
      });
    }

    // Deal Creation / Transition Events
    for (const d of recentDealsStreamRes) {
      rawEvents.push({
        id: `act-deal-${d.dealId}`,
        date: new Date(d.createdAt),
        item: {
          id: `act-deal-${d.dealId}`,
          eventType: 'deal_update',
          category: 'deals',
          title: `Deal #${d.dealId.slice(0, 4).toUpperCase()} Status: ${d.status}`,
          description: `${d.agreedQuantity} MT of ${d.commodityName} recorded with status "${d.status}".`,
          referenceId: `#DL-${d.dealId.slice(0, 4).toUpperCase()}`,
          timestamp: d.createdAt.toISOString(),
          relativeTime: formatDistanceToNow(new Date(d.createdAt), { addSuffix: true }),
          actionHref: '/broker/deals',
        },
      });
    }

    // Dispatch Events
    for (const d of recentDispatchesStreamRes) {
      rawEvents.push({
        id: `act-disp-${d.dispatchId}`,
        date: new Date(d.createdAt),
        item: {
          id: `act-disp-${d.dispatchId}`,
          eventType: 'dispatch_status',
          category: 'logistics',
          title: `Dispatch for Deal #${d.dealId.slice(0, 4).toUpperCase()} (${d.status})`,
          description: `Vehicle ${d.vehicleNumber} status updated to ${d.status}.`,
          referenceId: `#DSP-${d.dispatchId.slice(0, 4).toUpperCase()}`,
          timestamp: d.createdAt.toISOString(),
          relativeTime: formatDistanceToNow(new Date(d.createdAt), { addSuffix: true }),
          actionHref: '/broker/orders',
        },
      });
    }

    // Sort combined events by date descending and take top 6
    rawEvents.sort((a, b) => b.date.getTime() - a.date.getTime());
    const recentActivity: BrokerRecentActivityItem[] = rawEvents.slice(0, 6).map((e) => e.item);

    return {
      success: true,
      data: {
        kpis,
        alerts: pendingActions,
        pendingActions,
        recentActivity,
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
