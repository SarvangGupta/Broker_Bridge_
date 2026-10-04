'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { 
  users, 
  masterCommodities, 
  masterCategories, 
  masterIndustries, 
  masterGrades, 
  requirements 
} from "@/src/server/db/schema"
import { eq, and, inArray, desc } from "drizzle-orm"
import { requirementSchema } from "@/src/types/requirement-schema"
import { revalidatePath } from "next/cache"
import { verifyBuyerSession } from "@/src/server/utils/buyer-auth"

export async function createRequirementAction(rawData: unknown) {
  try {
    const session = await verifyBuyerSession()
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized' }
    }
    const companyId = session.data.companyId

    // Validate data using Zod
    const validation = requirementSchema.safeParse(rawData)
    if (!validation.success) {
      return { success: false, error: 'Invalid requirement data provided.' }
    }
    const data = validation.data

    // Anti-Spoofing Rule: Insert requirement using server-derived companyId exclusively
    const newReq = await db.insert(requirements).values({
      companyId,
      commodityId: data.commodity_id,
      gradeId: data.grade_id,
      quantity: data.quantity,
      unitId: data.unit_id,
      targetPrice: data.target_price,
      deliveryTermsId: data.delivery_terms_id || 'EXW',
      targetDate: data.target_date || new Date(Date.now() + 14 * 86400000),
      visibility: data.visibility || 'global',
      status: 'Open',
      brokerId: data.broker_id || null,

    }).returning()

    revalidatePath('/', 'layout')
    return { success: true, data: newReq[0] }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to create requirement' }
  }
}

export async function getMyRequirementsAction() {
  try {
    const session = await verifyBuyerSession()
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized' }
    }
    const companyId = session.data.companyId

    const results = await db
      .select({
        requirement: requirements,
        commodityName: masterCommodities.name,
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
        gradeName: masterGrades.gradeName,
      })
      .from(requirements)
      .where(eq(requirements.companyId, companyId))
      .leftJoin(masterCommodities, eq(masterCommodities.id, requirements.commodityId))
      .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
      .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
      .leftJoin(masterGrades, eq(masterGrades.id, requirements.gradeId))
      .orderBy(desc(requirements.createdAt))

    return { success: true, data: results }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch requirements' }
  }
}

export async function cancelRequirementAction(id: string) {
  try {
    const session = await verifyBuyerSession()
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized' }
    }
    const companyId = session.data.companyId

    // Only allow cancelling if it belongs to the company and is Open or Draft
    const updated = await db
      .update(requirements)
      .set({ status: 'Cancelled' })
      .where(
        and(
          eq(requirements.id, id),
          eq(requirements.companyId, companyId),
          inArray(requirements.status, ['Open', 'Draft'])
        )
      )
      .returning()

    if (!updated.length) {
      return { success: false, error: 'Requirement not found or cannot be cancelled in its current state.' }
    }

    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to cancel requirement' }
  }
}

