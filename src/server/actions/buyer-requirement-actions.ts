'use server'

import { db } from "@/src/server/db"
import { 
  requirements, 
  requirementQualitySpecs, 
  requirementDocuments,
  masterQualityParameters, 
  masterCommodities, 
  masterGrades, 
  masterUnits, 
  users 
} from "@/src/server/db/schema"
import { eq, and, desc } from "drizzle-orm"
import { revalidatePath } from "next/cache"
import { verifyBuyerSession } from "@/src/server/utils/buyer-auth"
import { requirementWizardSchema } from "@/src/lib/validations/requirement-schema"

const FORBIDDEN_EDIT_STATUSES = ['Negotiating', 'Accepted', 'Booked', 'Fulfilled', 'Closed']
const FORBIDDEN_CANCEL_STATUSES = ['Booked', 'Accepted', 'Fulfilled', 'Closed']

export async function getBuyerRequirementsListAction(filters?: { status?: string; search?: string }) {
  try {
    const session = await verifyBuyerSession()
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized' }
    }
    const companyId = session.data.companyId

    const rawResults = await db
      .select({
        requirement: requirements,
        commodityName: masterCommodities.name,
        gradeName: masterGrades.gradeName,
        unitSymbol: masterUnits.symbol,
        unitName: masterUnits.name,
      })
      .from(requirements)
      .leftJoin(masterCommodities, eq(masterCommodities.id, requirements.commodityId))
      .leftJoin(masterGrades, eq(masterGrades.id, requirements.gradeId))
      .leftJoin(masterUnits, eq(masterUnits.id, requirements.unitId))
      .where(eq(requirements.companyId, companyId))
      .orderBy(desc(requirements.createdAt))

    let results = rawResults

    if (filters?.status && filters.status !== 'ALL') {
      results = results.filter((r) => r.requirement.status.toLowerCase() === filters.status!.toLowerCase())
    }

    if (filters?.search) {
      const q = filters.search.toLowerCase().trim()
      results = results.filter((r) => 
        (r.commodityName && r.commodityName.toLowerCase().includes(q)) ||
        (r.gradeName && r.gradeName.toLowerCase().includes(q)) ||
        (r.requirement.id && r.requirement.id.toLowerCase().includes(q))
      )
    }

    return { success: true, data: results }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch requirement inbox' }
  }
}

export async function getBuyerRequirementDetailAction(requirementId: string) {
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
        gradeName: masterGrades.gradeName,
        unitSymbol: masterUnits.symbol,
        unitName: masterUnits.name,
      })
      .from(requirements)
      .leftJoin(masterCommodities, eq(masterCommodities.id, requirements.commodityId))
      .leftJoin(masterGrades, eq(masterGrades.id, requirements.gradeId))
      .leftJoin(masterUnits, eq(masterUnits.id, requirements.unitId))
      .where(and(eq(requirements.id, requirementId), eq(requirements.companyId, companyId)))

    if (!results.length) {
      return { success: false, error: 'Requirement not found or access denied.' }
    }

    const item = results[0]
    const req = item.requirement

    // Fetch assigned broker name if available
    let brokerName = null
    if (req.brokerId) {
      const brokerUsers = await db
        .select({ name: users.name, mobile: users.mobile })
        .from(users)
        .where(eq(users.id, req.brokerId))
      if (brokerUsers.length) {
        brokerName = brokerUsers[0].name || brokerUsers[0].mobile
      }
    }

    const originalQuantity = Number(req.quantity || 0)
    const bookedQuantity = Number(req.fulfilledQuantity || 0)
    const remainingQuantity = Math.max(0, originalQuantity - bookedQuantity)
    const progressPercentage = originalQuantity > 0 
      ? Math.min(100, Math.round((bookedQuantity / originalQuantity) * 100)) 
      : 0

    // Micro-Sprint 34.2: Fetch Persisted Quality Specifications
    let qualitySpecs: any[] = []
    try {
      qualitySpecs = await db
        .select({
          id: requirementQualitySpecs.id,
          parameterId: requirementQualitySpecs.parameterId,
          targetValue: requirementQualitySpecs.targetValue,
          tolerance: requirementQualitySpecs.tolerance,
          name: masterQualityParameters.name,
          unit: masterQualityParameters.unit,
          minValue: masterQualityParameters.minValue,
          maxValue: masterQualityParameters.maxValue,
          isRequired: masterQualityParameters.isRequired,
        })
        .from(requirementQualitySpecs)
        .innerJoin(
          masterQualityParameters,
          eq(masterQualityParameters.id, requirementQualitySpecs.parameterId)
        )
        .where(eq(requirementQualitySpecs.requirementId, requirementId))
    } catch (qErr) {
      // Table may not have records yet or pending migration
    }

    // Micro-Sprint 34.3: Fetch Persisted Document Requirements
    let requiredDocuments: string[] = []
    try {
      const docRecords = await db
        .select({ documentType: requirementDocuments.documentType })
        .from(requirementDocuments)
        .where(eq(requirementDocuments.requirementId, requirementId))
      requiredDocuments = docRecords.map((d) => d.documentType)
    } catch (dErr) {
      // Table may not have records yet or pending migration
    }

    return {
      success: true,
      data: {
        ...item,
        brokerName,
        qualitySpecs,
        requiredDocuments,
        fulfillment: {
          originalQuantity,
          bookedQuantity,
          remainingQuantity,
          progressPercentage,
        },
      },
    }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch requirement detail' }
  }
}

export async function updateRequirementAction(
  id: string, 
  rawData: unknown, 
  isDraft: boolean = false
) {
  try {
    const session = await verifyBuyerSession()
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized' }
    }
    const companyId = session.data.companyId

    // Fetch existing requirement
    const existing = await db
      .select()
      .from(requirements)
      .where(and(eq(requirements.id, id), eq(requirements.companyId, companyId)))

    if (!existing.length) {
      return { success: false, error: 'Requirement not found or access denied.' }
    }

    const currentReq = existing[0]

    // STATE CHECK: Lock editing if requirement is in active negotiation or fulfillment
    if (FORBIDDEN_EDIT_STATUSES.includes(currentReq.status)) {
      return { 
        success: false, 
        error: 'Cannot edit a requirement currently in active negotiation or fulfillment.' 
      }
    }

    const data = rawData as any

    if (!isDraft) {
      // Validate full schema for publication
      const validation = requirementWizardSchema.safeParse(rawData)
      if (!validation.success) {
        return { success: false, error: 'Invalid requirement data provided.' }
      }
    }

    let unitId = data.unit_id || currentReq.unitId
    if (!unitId || unitId === '00000000-0000-0000-0000-000000000000') {
      const defaultUnit = await db.select({ id: masterUnits.id }).from(masterUnits).limit(1)
      if (defaultUnit.length > 0) {
        unitId = defaultUnit[0].id
      }
    }

    const updated = await db
      .update(requirements)
      .set({
        commodityId: data.commodity_id || currentReq.commodityId,
        gradeId: data.grade_id || currentReq.gradeId,
        quantity: data.quantity ? Number(data.quantity) : currentReq.quantity,
        unitId,
        targetPrice: data.target_price ? Number(data.target_price) : currentReq.targetPrice,
        deliveryTermsId: data.freight_terms || data.delivery_terms_id || currentReq.deliveryTermsId,
        targetDate: data.delivery_window_end ? new Date(data.delivery_window_end) : (data.target_date ? new Date(data.target_date) : currentReq.targetDate),
        visibility: data.visibility || currentReq.visibility,
        brokerId: data.broker_id || null,
        status: isDraft ? 'Draft' : 'Open',
      })
      .where(and(eq(requirements.id, id), eq(requirements.companyId, companyId)))
      .returning()

    revalidatePath('/', 'layout')
    revalidatePath('/buyer/requirements')
    return { 
      success: true, 
      data: {
        ...updated[0],
        quality_parameters: data.quality_parameters || [],
      } 
    }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to update requirement' }
  }
}

export async function cancelRequirementAction(id: string, reason?: string) {
  try {
    const session = await verifyBuyerSession()
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized' }
    }
    const companyId = session.data.companyId

    const existing = await db
      .select()
      .from(requirements)
      .where(and(eq(requirements.id, id), eq(requirements.companyId, companyId)))

    if (!existing.length) {
      return { success: false, error: 'Requirement not found or access denied.' }
    }

    const currentReq = existing[0]

    // STATE CHECK: Ensure requirement is not Booked, Accepted, Fulfilled, or Closed
    if (FORBIDDEN_CANCEL_STATUSES.includes(currentReq.status)) {
      return { 
        success: false, 
        error: 'Requirement cannot be cancelled in its current state.' 
      }
    }

    const updated = await db
      .update(requirements)
      .set({ 
        status: 'Cancelled',
      })
      .where(and(eq(requirements.id, id), eq(requirements.companyId, companyId)))
      .returning()

    if (!updated.length) {
      return { success: false, error: 'Failed to cancel requirement.' }
    }

    revalidatePath('/', 'layout')
    revalidatePath('/buyer/requirements')
    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to cancel requirement' }
  }
}

export async function saveDraftRequirementAction(rawData: unknown) {
  try {
    const session = await verifyBuyerSession()
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized' }
    }
    const companyId = session.data.companyId
    const data = rawData as any

    if (!data.commodity_id || !data.grade_id) {
      return { success: false, error: 'Commodity and Grade are required to save a draft.' }
    }

    let unitId = data.unit_id
    if (!unitId || unitId === '00000000-0000-0000-0000-000000000000') {
      const defaultUnit = await db.select({ id: masterUnits.id }).from(masterUnits).limit(1)
      if (defaultUnit.length > 0) {
        unitId = defaultUnit[0].id
      } else {
        return { success: false, error: 'No default unit available in master units database.' }
      }
    }

    const newReq = await db.insert(requirements).values({
      companyId,
      commodityId: data.commodity_id,
      gradeId: data.grade_id,
      quantity: data.quantity ? Number(data.quantity) : 1,
      unitId,
      targetPrice: data.target_price ? Number(data.target_price) : 1,
      deliveryTermsId: data.freight_terms || data.delivery_terms_id || 'EXW',
      targetDate: data.delivery_window_end ? new Date(data.delivery_window_end) : new Date(Date.now() + 14 * 86400000),
      visibility: data.visibility || 'global',
      status: 'Draft',
      brokerId: data.broker_id || null,
    }).returning()

    revalidatePath('/', 'layout')
    revalidatePath('/buyer/requirements')
    return { 
      success: true, 
      data: {
        ...newReq[0],
        quality_parameters: data.quality_parameters || [],
      } 
    }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to save draft' }
  }
}
