'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { deals, requirements, availabilities, users } from "@/src/server/db/schema"
import { eq, and, ne, notInArray, inArray, sql } from "drizzle-orm"

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
export async function getSellerKpisAction(): Promise<{ success: boolean; data?: SellerKpis; error?: string }> {
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
            eq(availabilities.status, 'Open')
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
