'use server'

import { cache } from "react"
import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { users, companies } from "@/src/server/db/schema"
import { eq } from "drizzle-orm"
import { z } from "zod"

const updateProfileSchema = z.object({
  personalName: z.string().min(2, "Name must be at least 2 characters"),
  mobile: z.string().min(10, "Mobile must be at least 10 digits").optional().or(z.literal("")),
  companyName: z.string().min(2, "Company Name must be at least 2 characters"),
  gst: z.string().optional().or(z.literal("")),
  stateId: z.string().optional().or(z.literal("")),
  districtId: z.string().optional().or(z.literal("")),
})

const updatePasswordSchema = z.string().min(6, "Password must be at least 6 characters")

import { getFullBuyerProfileDetailsAction as getFullBuyerProfileDetailsFromCompany } from "@/src/server/actions/company-actions"

export const getFullBuyerProfileDetailsAction = cache(
  async function getFullBuyerProfileDetailsAction() {
    return getFullBuyerProfileDetailsFromCompany()
  }
)

export async function updateBuyerProfileDetailsAction(data: { 
  personalName: string; 
  mobile?: string;
  companyName: string;
  gst?: string;
  stateId?: string;
  districtId?: string;
}) {
  try {
    const validated = updateProfileSchema.parse(data)

    const supabase = await createClient()
    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) throw new Error("Not authenticated")

    // 1. Get user record to find companyId
    const userRecord = await db.select().from(users).where(eq(users.id, user.id)).limit(1)
    if (!userRecord || userRecord.length === 0) throw new Error("User profile not found")

    // 2. Update Users table
    await db.update(users).set({
      name: validated.personalName,
      mobile: validated.mobile || null,
    }).where(eq(users.id, user.id))

    // 3. Update Companies table if it exists
    if (userRecord[0].companyId) {
      await db.update(companies).set({
        name: validated.companyName,
        gst: validated.gst || null,
        stateId: validated.stateId || null,
        districtId: validated.districtId || null,
      }).where(eq(companies.id, userRecord[0].companyId))
    }

    // 4. Update Supabase Auth metadata for full_name
    await supabase.auth.updateUser({
      data: {
        full_name: validated.personalName,
        name: validated.personalName
      }
    })

    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message }
  }
}

export async function updateUserPasswordAction(newPassword: string) {
  try {
    const validated = updatePasswordSchema.parse(newPassword)

    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) throw new Error("Not authenticated")

    const { error } = await supabase.auth.updateUser({ password: validated })
    if (error) throw new Error(error.message)

    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message }
  }
}
