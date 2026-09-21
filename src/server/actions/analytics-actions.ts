'use server'

import { cache } from "react"
import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { deals, requirements, availabilities, users, companies, dispatches, disputes, bookings } from "@/src/server/db/schema"
import { eq, and, ne, notInArray, inArray, sql } from "drizzle-orm"
import { getSellerSettlementOverviewAction } from "@/src/server/actions/settlement-actions"

export type AdminKpis = {
  totalGmv: number
  activeDealsCount: number
  totalUsersCount: number
}

export type BrokerKpis = {
  myGmv: number
  activeDealsCount: number
  openRequirementsCount: number
}

export type BuyerKpis = {
  activeRequirementsCount: number
  bookedDealsCount: number
  totalSpent: number
}

export type SellerKpis = {
  activeAvailabilitiesCount: number
  pendingDispatchesCount: number
  totalRevenue: number
}

/**
 * 1. getAdminKpisAction
 * - Total Platform GMV (Sum of agreed_price * agreed_quantity from deals where status != 'Cancelled')
 * - Active Deals Count (status not in 'Closed', 'Cancelled')
 * - Total Registered Users Count
 */
export async function getAdminKpisAction(): Promise<{ success: boolean; data?: AdminKpis; error?: string }> {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return { success: false, error: "Unauthorized" }
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    })
    if (!dbUser || dbUser.role !== 'admin') {
      return { success: false, error: "Unauthorized: Admin access required" }
    }

    const [gmvRes, activeDealsRes, usersRes] = await Promise.all([
      db
        .select({
          totalGmv: sql<number>`COALESCE(SUM(CAST(${deals.agreedPrice} AS NUMERIC) * ${deals.agreedQuantity}), 0)::float`,
        })
        .from(deals)
        .where(ne(deals.status, 'Cancelled')),

      db
        .select({
          count: sql<number>`count(*)::int`,
        })
        .from(deals)
        .where(notInArray(deals.status, ['Closed', 'Cancelled'])),

      db
        .select({
          count: sql<number>`count(*)::int`,
        })
        .from(users)
        .where(ne(users.role, 'admin')),
    ])

    return {
      success: true,
      data: {
        totalGmv: Number(gmvRes[0]?.totalGmv ?? 0),
        activeDealsCount: Number(activeDealsRes[0]?.count ?? 0),
        totalUsersCount: Number(usersRes[0]?.count ?? 0),
      },
    }
  } catch (error: any) {
    console.error("getAdminKpisAction error:", error)
    return { success: false, error: error.message || "Failed to fetch Admin KPIs" }
  }
}

/**
 * 2. getBrokerKpisAction
 * - My GMV (Sum of deal values where broker_id = currentUser.id)
 * - My Active Deals Count (where broker_id = currentUser.id and status not in 'Closed', 'Cancelled')
 * - Open Requirements Count (assigned to this broker with status 'Open' or 'Partially Fulfilled')
 */
export async function getBrokerKpisAction(): Promise<{ success: boolean; data?: BrokerKpis; error?: string }> {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return { success: false, error: "Unauthorized" }
    }

    const [gmvRes, activeDealsRes, openReqsRes] = await Promise.all([
      db
        .select({
          myGmv: sql<number>`COALESCE(SUM(CAST(${deals.agreedPrice} AS NUMERIC) * ${deals.agreedQuantity}), 0)::float`,
        })
        .from(deals)
        .where(
          and(
            eq(deals.brokerId, user.id),
            ne(deals.status, 'Cancelled')
          )
        ),

      db
        .select({
          count: sql<number>`count(*)::int`,
        })
        .from(deals)
        .where(
          and(
            eq(deals.brokerId, user.id),
            notInArray(deals.status, ['Closed', 'Cancelled'])
          )
        ),

      db
        .select({
          count: sql<number>`count(*)::int`,
        })
        .from(requirements)
        .where(
          and(
            eq(requirements.brokerId, user.id),
            inArray(requirements.status, ['Open', 'Partially Fulfilled'])
          )
        ),
    ])

    return {
      success: true,
      data: {
        myGmv: Number(gmvRes[0]?.myGmv ?? 0),
        activeDealsCount: Number(activeDealsRes[0]?.count ?? 0),
        openRequirementsCount: Number(openReqsRes[0]?.count ?? 0),
      },
    }
  } catch (error: any) {
    console.error("getBrokerKpisAction error:", error)
    return { success: false, error: error.message || "Failed to fetch Broker KPIs" }
  }
}

/**
 * 3. getBuyerKpisAction
 * - Active Requirements Count (belonging to currentUser's company, status in 'Open', 'Partially Fulfilled')
 * - Booked Deals Count (deals where buyerId = companyId and status != 'Cancelled')
 * - Total Value Spent (Sum of deal values for this buyer)
 */
export async function getBuyerKpisAction(): Promise<{ success: boolean; data?: BuyerKpis; error?: string }> {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return { success: false, error: "Unauthorized" }
    }

    const userRecords = await db.select().from(users).where(eq(users.id, user.id))
    const companyId = userRecords[0]?.companyId

    if (!companyId) {
      return {
        success: true,
        data: {
          activeRequirementsCount: 0,
          bookedDealsCount: 0,
          totalSpent: 0,
        },
      }
    }

    const [activeReqsRes, bookedDealsRes, spentRes] = await Promise.all([
      db
        .select({
          count: sql<number>`count(*)::int`,
        })
        .from(requirements)
        .where(
          and(
            eq(requirements.companyId, companyId),
            inArray(requirements.status, ['Open', 'Partially Fulfilled'])
          )
        ),

      db
        .select({
          count: sql<number>`count(*)::int`,
        })
        .from(deals)
        .where(
          and(
            eq(deals.buyerId, companyId),
            ne(deals.status, 'Cancelled')
          )
        ),

      db
        .select({
          totalSpent: sql<number>`COALESCE(SUM(CAST(${deals.agreedPrice} AS NUMERIC) * ${deals.agreedQuantity}), 0)::float`,
        })
        .from(deals)
        .where(
          and(
            eq(deals.buyerId, companyId),
            ne(deals.status, 'Cancelled')
          )
        ),
    ])

    return {
      success: true,
      data: {
        activeRequirementsCount: Number(activeReqsRes[0]?.count ?? 0),
        bookedDealsCount: Number(bookedDealsRes[0]?.count ?? 0),
        totalSpent: Number(spentRes[0]?.totalSpent ?? 0),
      },
    }
  } catch (error: any) {
    console.error("getBuyerKpisAction error:", error)
    return { success: false, error: error.message || "Failed to fetch Buyer KPIs" }
  }
}

/**
 * 4. getSellerKpisAction
 * - Active Availabilities Count (where companyId = sellerCompanyId and status = 'Open')
 * - Pending Dispatches Count (deals where sellerId = sellerCompanyId and status = 'Dispatch Pending')
 * - Total Revenue (Sum of deal values for this seller)
 */
export const getSellerKpisAction = cache(
  async function getSellerKpisAction(): Promise<{ success: boolean; data?: SellerKpis; error?: string }> {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return { success: false, error: "Unauthorized" }
    }

    const userRecords = await db.select().from(users).where(eq(users.id, user.id))
    const companyId = userRecords[0]?.companyId

    if (!companyId) {
      return {
        success: true,
        data: {
          activeAvailabilitiesCount: 0,
          pendingDispatchesCount: 0,
          totalRevenue: 0,
        },
      }
    }

    const [activeAvailsRes, pendingDispatchesRes, revenueRes] = await Promise.all([
      db
        .select({
          count: sql<number>`count(*)::int`,
        })
        .from(availabilities)
        .where(
          and(
            eq(availabilities.companyId, companyId),
            inArray(availabilities.status, ['Active', 'Open'])
          )
        ),

      db
        .select({
          count: sql<number>`count(*)::int`,
        })
        .from(deals)
        .where(
          and(
            eq(deals.sellerId, companyId),
            eq(deals.status, 'Dispatch Pending')
          )
        ),

      db
        .select({
          totalRevenue: sql<number>`COALESCE(SUM(CAST(${deals.agreedPrice} AS NUMERIC) * ${deals.agreedQuantity}), 0)::float`,
        })
        .from(deals)
        .where(
          and(
            eq(deals.sellerId, companyId),
            ne(deals.status, 'Cancelled')
          )
        ),
    ])

    return {
      success: true,
      data: {
        activeAvailabilitiesCount: Number(activeAvailsRes[0]?.count ?? 0),
        pendingDispatchesCount: Number(pendingDispatchesRes[0]?.count ?? 0),
        totalRevenue: Number(revenueRes[0]?.totalRevenue ?? 0),
      },
    }
  } catch (error: any) {
    console.error("getSellerKpisAction error:", error)
    return { success: false, error: error.message || "Failed to fetch Seller KPIs" }
  }
}
);

export type ActionRequiredItem = {
  id: string
  type:
    | 'DISPATCH_DUE'
    | 'DISPATCH_DELAYED'
    | 'DISPUTE_FILED'
    | 'PAYMENT_OVERDUE'
    | 'INVENTORY_EXPIRING'
    | 'KYC_PENDING'
    | 'DEAL_CONFIRMATION'
    | 'BROKER_REQUEST'
  title: string
  description: string
  severity: 'critical' | 'warning' | 'info'
  targetTab: string
  targetUrl?: string
  actionLabel: string
  entityId?: string
  badgeText?: string
}

export type SellerCommandCenterData = {
  kpis: {
    activeAvailabilitiesCount: number
    pendingDispatchesCount: number
    totalRevenue: number
  }
  actionItems: ActionRequiredItem[]
  inventoryCount: number
  activeDealsCount: number
  isKycVerified: boolean
  isKycPending: boolean
}

/**
 * 5. getSellerCommandCenterDataAction
 * Operational Command Center aggregation:
 * - Active Inventory & Expiring Inventory
 * - Pending Dispatches & Disputed Deals
 * - Revenue aggregates
 * - Dynamic P0 Action Required alert queue
 */
export const getSellerCommandCenterDataAction = cache(
  async function getSellerCommandCenterDataAction(): Promise<{
    success: boolean
    data?: SellerCommandCenterData
    error?: string
  }> {
    try {
      const supabase = await createClient()
      const { data: { user }, error: authError } = await supabase.auth.getUser()
      if (authError || !user) {
        return { success: false, error: "Unauthorized" }
      }

      const userRecords = await db.select().from(users).where(eq(users.id, user.id))
      const companyId = userRecords[0]?.companyId

      if (!companyId) {
        return {
          success: true,
          data: {
            kpis: {
              activeAvailabilitiesCount: 0,
              pendingDispatchesCount: 0,
              totalRevenue: 0,
            },
            actionItems: [
              {
                id: 'missing-kyc-action',
                type: 'KYC_PENDING',
                title: 'Complete Company Profile & KYC',
                description: 'Your organization details are required to list commodity supply and trade.',
                severity: 'critical',
                targetTab: 'team',
                actionLabel: 'Complete Profile',
                badgeText: 'Action Required',
              }
            ],
            inventoryCount: 0,
            activeDealsCount: 0,
            isKycVerified: false,
            isKycPending: true,
          },
        }
      }

      const [
        activeAvailsRes, 
        expiringAvailsRes,
        pendingDispatchesRes, 
        disputedDealsRes,
        allDealsCountRes,
        revenueRes,
        companyRes,
        delayedDispatchesRes,
        settlementOverviewRes
      ] = await Promise.all([
        // 1. Active Availabilities
        db
          .select({ count: sql<number>`count(*)::int` })
          .from(availabilities)
          .where(
            and(
              eq(availabilities.companyId, companyId),
              inArray(availabilities.status, ['Active', 'Open'])
            )
          ),

        // 2. Expiring Lots (within 48 hours)
        db
          .select({ count: sql<number>`count(*)::int` })
          .from(availabilities)
          .where(
            and(
              eq(availabilities.companyId, companyId),
              inArray(availabilities.status, ['Active', 'Open']),
              sql`${availabilities.validUntil} <= (now() + interval '48 hours')`
            )
          ),

        // 3. Pending Dispatches
        db
          .select({ count: sql<number>`count(*)::int` })
          .from(deals)
          .where(
            and(
              eq(deals.sellerId, companyId),
              eq(deals.status, 'Dispatch Pending')
            )
          ),

        // 4. Disputed Deals
        db
          .select({ count: sql<number>`count(*)::int` })
          .from(deals)
          .where(
            and(
              eq(deals.sellerId, companyId),
              eq(deals.status, 'Disputed')
            )
          ),

        // 5. Total Active Deals
        db
          .select({ count: sql<number>`count(*)::int` })
          .from(deals)
          .where(
            and(
              eq(deals.sellerId, companyId),
              notInArray(deals.status, ['Cancelled'])
            )
          ),

        // 6. Cumulative Revenue
        db
          .select({
            totalRevenue: sql<number>`COALESCE(SUM(CAST(${deals.agreedPrice} AS NUMERIC) * ${deals.agreedQuantity}), 0)::float`,
          })
          .from(deals)
          .where(
            and(
              eq(deals.sellerId, companyId),
              ne(deals.status, 'Cancelled')
            )
          ),

        // 7. Company Verification Status
        db.query.companies.findFirst({
          where: eq(companies.id, companyId),
        }),

        // 8. Delayed Dispatches
        db
          .select({ count: sql<number>`count(*)::int` })
          .from(dispatches)
          .innerJoin(deals, eq(dispatches.dealId, deals.id))
          .where(
            and(
              eq(deals.sellerId, companyId),
              eq(dispatches.status, 'Delayed')
            )
          ),

        // 9. Settlement Overview
        getSellerSettlementOverviewAction(),
      ])

      const activeAvailCount = Number(activeAvailsRes[0]?.count ?? 0)
      const expiringAvailCount = Number(expiringAvailsRes[0]?.count ?? 0)
      const pendingDispatchCount = Number(pendingDispatchesRes[0]?.count ?? 0)
      const disputedCount = Number(disputedDealsRes[0]?.count ?? 0)
      const totalDealsCount = Number(allDealsCountRes[0]?.count ?? 0)
      const totalRevenue = Number(revenueRes[0]?.totalRevenue ?? 0)
      const delayedDispatchCount = Number(delayedDispatchesRes[0]?.count ?? 0)
      const settlementSummary = settlementOverviewRes?.success && settlementOverviewRes.data ? settlementOverviewRes.data.summary : null

      const isKycVerified = companyRes?.isVerified === true && companyRes?.status === true
      const isKycPending = companyRes ? companyRes.status === false : true

      // Construct P0 Action Items
      const actionItems: ActionRequiredItem[] = []

      // 1. Overdue Payments Alert (P0 Critical)
      if (settlementSummary && settlementSummary.overdueCount > 0) {
        actionItems.push({
          id: 'payment-overdue-alert',
          type: 'PAYMENT_OVERDUE',
          title: `₹${settlementSummary.totalOverdue.toLocaleString('en-IN')} Overdue across ${settlementSummary.overdueCount} Payment${settlementSummary.overdueCount > 1 ? 's' : ''}`,
          description: 'Past-due settlement invoices awaiting payment reconciliation or broker escalation.',
          severity: 'critical',
          targetTab: 'payments',
          targetUrl: '/seller/payments',
          actionLabel: 'View Overdue Ledger',
          badgeText: 'Payment Overdue',
        })
      }

      // 2. Active Disputes Alert (P0 Critical)
      const totalDisputed = Math.max(disputedCount, settlementSummary?.disputedCount || 0)
      if (totalDisputed > 0) {
        actionItems.push({
          id: 'dispute-active-alert',
          type: 'DISPUTE_FILED',
          title: `${totalDisputed} Deal Dispute${totalDisputed > 1 ? 's' : ''} Under Broker Mediation`,
          description: 'Quality or delivery exceptions have been flagged for administrator mediation.',
          severity: 'critical',
          targetTab: 'payments',
          targetUrl: '/seller/payments',
          actionLabel: 'View Dispute Details',
          badgeText: 'Urgent Mediation',
        })
      }

      // 3. Delayed Dispatches Alert (P0 Warning/Action)
      if (delayedDispatchCount > 0) {
        actionItems.push({
          id: 'dispatch-delayed-alert',
          type: 'DISPATCH_DELAYED',
          title: `${delayedDispatchCount} Transport Dispatch${delayedDispatchCount > 1 ? 'es' : ''} Reported Delayed`,
          description: 'Transit checkpoint or carrier delays reported on live dispatches.',
          severity: 'warning',
          targetTab: 'orders',
          targetUrl: '/seller/dispatch',
          actionLabel: 'Track Shipments',
          badgeText: 'Transit Delayed',
        })
      }

      // 4. Pending Logistics Dispatches
      if (pendingDispatchCount > 0) {
        actionItems.push({
          id: 'dispatch-pending-alert',
          type: 'DISPATCH_DUE',
          title: `${pendingDispatchCount} Shipment${pendingDispatchCount > 1 ? 's' : ''} Awaiting Logistics Dispatch`,
          description: 'Booked deals are confirmed and awaiting vehicle & driver details to initiate transport.',
          severity: 'critical',
          targetTab: 'orders',
          targetUrl: '/seller/dispatch',
          actionLabel: 'Dispatch Shipment',
          badgeText: 'Action Required',
        })
      }

      // 5. Expiring Inventory
      if (expiringAvailCount > 0) {
        actionItems.push({
          id: 'inventory-expiring-alert',
          type: 'INVENTORY_EXPIRING',
          title: `${expiringAvailCount} Inventory Lot${expiringAvailCount > 1 ? 's' : ''} Expiring Soon`,
          description: 'Your validity window is ending within 48 hours. Extend validity or quick-renew.',
          severity: 'warning',
          targetTab: 'inventory',
          actionLabel: 'Update Validity',
          badgeText: 'Expiring Soon',
        })
      }

      // 6. Pending KYC
      if (isKycPending) {
        actionItems.push({
          id: 'kyc-pending-alert',
          type: 'KYC_PENDING',
          title: 'Company Verification in Progress',
          description: 'Your KYC submission is under verification by the BrokerBridge administrator.',
          severity: 'warning',
          targetTab: 'team',
          actionLabel: 'Review Profile',
          badgeText: 'Pending KYC',
        })
      }

      return {
        success: true,
        data: {
          kpis: {
            activeAvailabilitiesCount: activeAvailCount,
            pendingDispatchesCount: pendingDispatchCount,
            totalRevenue,
          },
          actionItems,
          inventoryCount: activeAvailCount,
          activeDealsCount: totalDealsCount,
          isKycVerified,
          isKycPending,
        },
      }
    } catch (error: any) {
      console.error("getSellerCommandCenterDataAction error:", error)
      return { success: false, error: error.message || "Failed to fetch Command Center data" }
    }
  }
)

