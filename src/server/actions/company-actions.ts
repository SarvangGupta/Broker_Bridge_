'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { companies, users, masterStates, masterDistricts } from "@/src/server/db/schema"
import { eq, sql } from "drizzle-orm"

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

    // Insert company
    const newCompany = await db.insert(companies).values({
      name: data.name,
      gst: data.gst,
      stateId: data.state_id,
      districtId: data.district_id,
      businessTypeId: data.business_type_id,
      status: false, // explicitly set to pending approval
    }).returning()
    
    if (!newCompany.length) {
      throw new Error("Failed to insert company")
    }
    
    const companyId = newCompany[0].id
    
    // Update user's company_id and mobile number
    await db.update(users)
      .set({ companyId, mobile: data.mobile })
      .where(eq(users.id, user.id))
      
    return { success: true, data: newCompany[0] }
  } catch (error: any) {
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

    // Get user's companyId
    const currentUser = await db.select().from(users).where(eq(users.id, user.id))
    
    if (!currentUser.length || !currentUser[0].companyId) {
      return { success: false, error: 'Company profile not found', status: 'NONE' as const }
    }

    const dbUser = currentUser[0]

    // Get company
    const company = await db.select().from(companies).where(eq(companies.id, dbUser.companyId!))
    
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

    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to reject company' }
  }
}
