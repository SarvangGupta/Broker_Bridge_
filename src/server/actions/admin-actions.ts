'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { 
  users, 
  companies, 
  masterCommodities, 
  masterCategories, 
  masterIndustries,
  requirements,
  availabilities
} from "@/src/server/db/schema"
import { eq, and, isNull, desc } from "drizzle-orm"

export async function getUnassignedRequirementsAction() {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return { success: false, error: 'Unauthorized' }
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    })
    if (!dbUser || dbUser.role !== 'admin') {
      return { success: false, error: 'Unauthorized: Admin access required' }
    }

    const reqs = await db
      .select({
        id: requirements.id,
        createdAt: requirements.createdAt,
        quantity: requirements.quantity,
        targetPrice: requirements.targetPrice,
        companyName: companies.name,
        commodityName: masterCommodities.name,
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
      })
      .from(requirements)
      .where(isNull(requirements.brokerId))
      .leftJoin(companies, eq(companies.id, requirements.companyId))
      .leftJoin(masterCommodities, eq(masterCommodities.id, requirements.commodityId))
      .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
      .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
      .orderBy(desc(requirements.createdAt))

    const avails = await db
      .select({
        id: availabilities.id,
        createdAt: availabilities.createdAt,
        quantity: availabilities.quantity,
        targetPrice: availabilities.price,
        companyName: companies.name,
        commodityName: masterCommodities.name,
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
      })
      .from(availabilities)
      .where(isNull(availabilities.brokerId))
      .leftJoin(companies, eq(companies.id, availabilities.companyId))
      .leftJoin(masterCommodities, eq(masterCommodities.id, availabilities.commodityId))
      .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
      .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
      .orderBy(desc(availabilities.createdAt))

    const mappedReqs = reqs.map(r => ({ ...r, type: 'Buyer Requirement' }))
    const mappedAvails = avails.map(a => ({ ...a, type: 'Seller Availability' }))
    
    const combined = [...mappedReqs, ...mappedAvails].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())

    return { success: true, data: combined }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch unassigned deals' }
  }
}

export async function getActiveBrokersAction() {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return { success: false, error: 'Unauthorized' }
    }

    const results = await db
      .select({
        id: users.id,
        name: users.name,
      })
      .from(users)
      .where(and(eq(users.role, 'broker'), eq(users.status, true)))

    return { success: true, data: results }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch brokers' }
  }
}

export async function assignBrokerToRequirementAction(requirementId: string, brokerId: string) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return { success: false, error: 'Unauthorized' }
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    })
    if (!dbUser || dbUser.role !== 'admin') {
      return { success: false, error: 'Unauthorized: Admin access required' }
    }

    // Since UUIDs are unique, update both tables. The one without the ID will simply affect 0 rows.
    await db
      .update(requirements)
      .set({ brokerId })
      .where(eq(requirements.id, requirementId))

    await db
      .update(availabilities)
      .set({ brokerId })
      .where(eq(availabilities.id, requirementId))

    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to assign broker' }
  }
}
