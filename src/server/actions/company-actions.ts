'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { companies, users, masterStates, masterDistricts, masterBusinessTypes } from "@/src/server/db/schema"
import { eq, sql } from "drizzle-orm"
import { revalidatePath } from "next/cache"
import { verifyBuyerSession } from "@/src/server/utils/buyer-auth"
import { logDecisionGateAuditEventAction } from "@/src/server/actions/audit-actions"

export async function createCompanyProfile(data: {
  name: string
  gst?: string
  state_id?: string
  district_id?: string
  business_type_id?: string
  mobile: string
}) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    
    if (authError || !user) {
      return { success: false, error: 'Unauthorized' }
    }

    // Check if user already exists in DB
    const existingUsers = await db.select().from(users).where(eq(users.id, user.id))
    const existingUser = existingUsers[0] || null

    let companyId: string

    // If user already has a companyId linked, update that company record to prevent duplicates
    if (existingUser && existingUser.companyId) {
      companyId = existingUser.companyId
      await db.update(companies)
        .set({
          name: data.name,
          gst: data.gst || null,
          stateId: data.state_id || null,
          districtId: data.district_id || null,
          businessTypeId: data.business_type_id || null,
        })
        .where(eq(companies.id, companyId))

      await db.update(users)
        .set({ mobile: data.mobile })
        .where(eq(users.id, user.id))

      const updatedCompany = await db.select().from(companies).where(eq(companies.id, companyId))
      revalidatePath('/seller')
      revalidatePath('/seller', 'page')
      revalidatePath('/seller', 'layout')
      revalidatePath('/buyer')
      revalidatePath('/buyer', 'page')
      revalidatePath('/buyer', 'layout')
      revalidatePath('/', 'layout')
      return { success: true, data: updatedCompany[0] }
    }

    // Insert new company (pending approval)
    const newCompany = await db.insert(companies).values({
      name: data.name,
      gst: data.gst || null,
      stateId: data.state_id || null,
      districtId: data.district_id || null,
      businessTypeId: data.business_type_id || null,
      status: false, // pending approval
      isVerified: false,
    }).returning()
    
    if (!newCompany.length) {
      throw new Error("Failed to insert company profile")
    }
    
    companyId = newCompany[0].id
    
    // Upsert user row in users table to guarantee companyId is ALWAYS linked
    if (!existingUser) {
      const userRole = (user.user_metadata?.role as string)?.toLowerCase() || 'buyer'
      const userName = user.user_metadata?.name || user.user_metadata?.full_name || user.email?.split('@')[0] || 'User'
      await db.insert(users).values({
        id: user.id,
        name: userName,
        email: user.email || null,
        mobile: data.mobile,
        role: userRole,
        companyId: companyId,
        status: true,
      })
    } else {
      await db.update(users)
        .set({ companyId, mobile: data.mobile })
        .where(eq(users.id, user.id))
    }
      
    revalidatePath('/seller')
    revalidatePath('/seller', 'page')
    revalidatePath('/seller', 'layout')
    revalidatePath('/buyer')
    revalidatePath('/buyer', 'page')
    revalidatePath('/buyer', 'layout')
    revalidatePath('/', 'layout')
    return { success: true, data: newCompany[0] }
  } catch (error: any) {
    console.error("createCompanyProfile error:", error)
    return { success: false, error: error.message || 'Failed to create company profile' }
  }
}

export async function getCompanyProfile() {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    
    if (authError || !user) {
      return { success: false, error: 'Unauthorized', status: 'NONE' as const }
    }

    // Get user from DB
    let currentUserList = await db.select().from(users).where(eq(users.id, user.id))
    
    // If user record is missing in PostgreSQL users table, auto-heal user record
    if (!currentUserList.length) {
      const userRole = (user.user_metadata?.role as string)?.toLowerCase() || 'buyer'
      const userName = user.user_metadata?.name || user.user_metadata?.full_name || user.email?.split('@')[0] || 'User'
      currentUserList = await db.insert(users).values({
        id: user.id,
        name: userName,
        email: user.email || null,
        role: userRole,
        status: true,
      }).returning()
    }

    const dbUser = currentUserList[0]

    if (!dbUser.companyId) {
      return { success: false, error: 'Company profile not found', status: 'NONE' as const }
    }

    // Get company
    const company = await db.select().from(companies).where(eq(companies.id, dbUser.companyId))
    
    if (!company.length) {
       return { success: false, error: 'Company not found', status: 'NONE' as const }
    }
    
    const dbCompany = company[0]

    let onboardingStatus: 'NONE' | 'PENDING' | 'APPROVED' | 'REJECTED' = 'NONE'

    const isApproved = Boolean(dbCompany.status) || Boolean(dbCompany.isVerified) || String(dbCompany.status) === 'true' || String(dbCompany.isVerified) === 'true'
    const isRejected = dbUser.status === false && !isApproved

    if (isApproved) {
      onboardingStatus = 'APPROVED'
    } else if (isRejected) {
      onboardingStatus = 'REJECTED'
    } else {
      onboardingStatus = 'PENDING'
    }

    return { 
      success: true, 
      data: dbCompany,
      user: dbUser,
      status: onboardingStatus 
    }
  } catch (error: any) {
    console.error("getCompanyProfile DB error:", error)
    return { success: false, error: error.message || 'Failed to fetch company profile', status: 'NONE' as const }
  }
}

export async function getFullBuyerProfileDetailsAction() {
  try {
    const session = await verifyBuyerSession()
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized' }
    }

    const { companyId, user: dbUser } = session.data

    const companyResults = await db
      .select({
        id: companies.id,
        name: companies.name,
        gst: companies.gst,
        businessTypeId: companies.businessTypeId,
        businessTypeName: masterBusinessTypes.name,
        stateId: companies.stateId,
        stateName: masterStates.name,
        districtId: companies.districtId,
        districtName: masterDistricts.name,
        status: companies.status,
        isVerified: companies.isVerified,
        trustScore: companies.trustScore,
        gstVerified: companies.gstVerified,
        gstVerifiedAt: companies.gstVerifiedAt,
      })
      .from(companies)
      .leftJoin(masterBusinessTypes, sql`${companies.businessTypeId} = cast(${masterBusinessTypes.id} as text)`)
      .leftJoin(masterStates, sql`${companies.stateId} = cast(${masterStates.id} as text)`)
      .leftJoin(masterDistricts, sql`${companies.districtId} = cast(${masterDistricts.id} as text)`)
      .where(eq(companies.id, companyId))

    if (!companyResults.length) {
      return { success: false, error: 'Company profile not found' }
    }

    const company = companyResults[0]

    const isApproved = Boolean(company.status) || Boolean(company.isVerified) || String(company.status) === 'true' || String(company.isVerified) === 'true'
    const isRejected = dbUser.status === false && !isApproved

    let onboardingStatus: 'NONE' | 'PENDING' | 'APPROVED' | 'REJECTED' = 'PENDING'
    if (isApproved) {
      onboardingStatus = 'APPROVED'
    } else if (isRejected) {
      onboardingStatus = 'REJECTED'
    }

    return {
      success: true,
      data: {
        company: {
          ...company,
          onboardingStatus,
        },
        user: {
          id: dbUser.id,
          name: dbUser.name || 'Buyer Admin',
          email: dbUser.email || null,
          mobile: dbUser.mobile || null,
          role: 'BUYER_ADMIN' as const,
        },
      },
    }
  } catch (error: any) {
    console.error('getFullBuyerProfileDetailsAction error:', error)
    return { success: false, error: error.message || 'Failed to fetch buyer profile details' }
  }
}

export async function getPendingCompaniesAction() {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) return { success: false, error: 'Unauthorized' }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    })
    if (!dbUser || dbUser.role !== 'admin') {
      return { success: false, error: 'Unauthorized: Admin access required' }
    }

    const results = await db
      .select({
        company: companies,
        user: {
          id: users.id,
          name: users.name,
          email: users.email,
          status: users.status,
        },
        stateName: masterStates.name,
        districtName: masterDistricts.name,
      })
      .from(companies)
      .leftJoin(users, eq(users.companyId, companies.id))
      // Cast UUID to text to avoid Postgres operator errors
      .leftJoin(masterStates, sql`${companies.stateId} = ${masterStates.id}::text`)
      .leftJoin(masterDistricts, sql`${companies.districtId} = ${masterDistricts.id}::text`)

    return { success: true, data: results }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch companies' }
  }
}

export async function approveCompanyAction(companyId: string) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) return { success: false, error: 'Unauthorized' }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    })
    if (!dbUser || dbUser.role !== 'admin') {
      return { success: false, error: 'Unauthorized: Admin access required' }
    }

    await db.update(companies).set({ status: true, isVerified: true }).where(eq(companies.id, companyId))
    await db.update(users).set({ status: true }).where(eq(users.companyId, companyId))

    revalidatePath('/seller')
    revalidatePath('/seller', 'page')
    revalidatePath('/seller', 'layout')
    revalidatePath('/buyer')
    revalidatePath('/buyer', 'page')
    revalidatePath('/buyer', 'layout')
    revalidatePath('/admin')
    revalidatePath('/', 'layout')
    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to approve company' }
  }
}

export async function rejectCompanyAction(companyId: string) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) return { success: false, error: 'Unauthorized' }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    })
    if (!dbUser || dbUser.role !== 'admin') {
      return { success: false, error: 'Unauthorized: Admin access required' }
    }

    await db.update(companies).set({ status: false, isVerified: false }).where(eq(companies.id, companyId))
    await db.update(users).set({ status: false }).where(eq(users.companyId, companyId))

    revalidatePath('/seller')
    revalidatePath('/seller', 'page')
    revalidatePath('/seller', 'layout')
    revalidatePath('/buyer')
    revalidatePath('/buyer', 'page')
    revalidatePath('/buyer', 'layout')
    revalidatePath('/admin')
    revalidatePath('/', 'layout')
    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to reject company' }
  }
}


/**
 * Phase 1 - Live GST Verification Engine (Backend Action)
 * Validates GST details with an external government API wrapper or dev mode simulation.
 * Updates company record and logs an immutable audit event.
 */
/**
 * Manual GST Web Verification Workflow
 * Allows platform Admin (Tier 0) or Broker (Tier 1) to mark a company's GST as verified
 * after external web portal inspection, storing audit trail and manual source metadata.
 */
export async function manuallyVerifyGstAction(companyId: string, gstNumber: string) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Session required' }
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    })

    if (!dbUser) {
      return { success: false, error: 'Unauthorized: User profile not found' }
    }

    // Role verification: STRICTLY Admin (Tier 0) or Broker (Tier 1) ONLY.
    // Standard Buyer/Seller is NOT permitted to manually lock verification.
    const normalizedRole = (dbUser.role || '').toLowerCase()
    const isAdmin = normalizedRole === 'admin'
    const isBroker = normalizedRole === 'broker'

    if (!isAdmin && !isBroker) {
      return {
        success: false,
        error: 'Unauthorized: Only platform Admins or Brokers can manually verify GST records',
      }
    }

    // Ensure company exists
    const existingCompany = await db.query.companies.findFirst({
      where: eq(companies.id, companyId),
    })

    if (!existingCompany) {
      return { success: false, error: 'Company not found' }
    }

    const cleanedGst = gstNumber?.trim().toUpperCase()
    if (!cleanedGst) {
      return { success: false, error: 'GST number is required' }
    }

    const verifiedAt = new Date()

    // Structured manual verification payload
    const manualPayload = {
      source: 'Manual Web Verification',
      status: 'Active',
      verifiedBy: user.id,
      verifiedByRole: dbUser.role || (isAdmin ? 'admin' : 'broker'),
      verifiedAt: verifiedAt.toISOString(),
      legal_name: existingCompany.name,
    }

    // Database Update: Set gst_verified = true, gst_verified_at = now(), gst_live_data = manualPayload
    await db.update(companies)
      .set({
        gst: cleanedGst,
        gstVerified: true,
        gstVerifiedAt: verifiedAt,
        gstLiveData: manualPayload,
      })
      .where(eq(companies.id, companyId))

    // Log an immutable audit event: "GST manually verified by Admin"
    await logDecisionGateAuditEventAction({
      action: 'GST manually verified by Admin',
      actorId: user.id,
      actorRole: dbUser.role || (isAdmin ? 'admin' : 'broker'),
      entity: 'companies',
      entityId: companyId,
      metadata: {
        event: 'GST manually verified by Admin',
        notes: 'GST manually verified by Admin',
        gstNumber: cleanedGst,
        companyName: existingCompany.name,
        verifiedBy: user.id,
        verifiedAt: verifiedAt.toISOString(),
      },
    })

    revalidatePath('/seller')
    revalidatePath('/seller', 'page')
    revalidatePath('/seller', 'layout')
    revalidatePath('/buyer')
    revalidatePath('/buyer', 'page')
    revalidatePath('/buyer', 'layout')
    revalidatePath('/admin')
    revalidatePath('/broker')
    revalidatePath('/', 'layout')

    return { success: true, data: manualPayload }
  } catch (error: any) {
    console.error('manuallyVerifyGstAction error:', error)
    return { success: false, error: error.message || 'Failed to manually verify GST' }
  }
}

// Backwards-compatible alias for any external callers
export const verifyGstOnlineAction = manuallyVerifyGstAction
