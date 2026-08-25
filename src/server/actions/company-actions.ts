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
      return { success: false, error: 'Unauthorized' }
    }

    // Get user's companyId
    const currentUser = await db.select().from(users).where(eq(users.id, user.id))
    
    if (!currentUser.length || !currentUser[0].companyId) {
      return { success: false, error: 'Company profile not found' }
    }

    // Get company
    const company = await db.select().from(companies).where(eq(companies.id, currentUser[0].companyId))
    
    if (!company.length) {
       return { success: false, error: 'Company not found' }
    }
    
    return { success: true, data: company[0] }
  } catch (error: any) {
    console.error("getCompanyProfile DB error:", error)
    return { success: false, error: error.message || 'Failed to fetch company profile' }
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
        },
        stateName: masterStates.name,
        districtName: masterDistricts.name,
      })
      .from(companies)
      .where(eq(companies.status, false))
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

    await db.update(companies).set({ status: true }).where(eq(companies.id, companyId))
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

    await db.update(companies).set({ status: false }).where(eq(companies.id, companyId))
    await db.update(users).set({ status: false }).where(eq(users.companyId, companyId))

    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to reject company' }
  }
}
