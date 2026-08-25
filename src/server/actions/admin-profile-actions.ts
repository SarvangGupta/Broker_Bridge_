'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { users } from "@/src/server/db/schema"
import { eq } from "drizzle-orm"
import { z } from "zod"

const updateProfileSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  mobile: z.string().min(10, "Mobile must be at least 10 digits").optional().or(z.literal("")),
});

const updatePasswordSchema = z.string().min(6, "Password must be at least 6 characters");

export async function getAdminProfileDetailsAction() {
  try {
    const supabase = await createClient()
    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) throw new Error("Not authenticated")

    const adminUser = await db.select().from(users).where(eq(users.id, user.id)).limit(1)
    if (!adminUser || adminUser.length === 0 || adminUser[0].role !== 'admin') {
      throw new Error("Unauthorized: Admin profile not found")
    }

    return { success: true, data: adminUser[0] }
  } catch (error: any) {
    return { success: false, error: error.message }
  }
}

export async function updateAdminProfileAction(data: { name: string; mobile?: string }) {
  try {
    const validated = updateProfileSchema.parse(data)

    const supabase = await createClient()
    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) throw new Error("Not authenticated")

    const adminUser = await db.select().from(users).where(eq(users.id, user.id)).limit(1)
    if (!adminUser || adminUser.length === 0 || adminUser[0].role !== 'admin') {
      throw new Error("Unauthorized: Admin profile not found")
    }

    await db.update(users).set({
      name: validated.name,
      mobile: validated.mobile || null,
    }).where(eq(users.id, user.id))

    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message }
  }
}

export async function updateAdminPasswordAction(newPassword: string) {
  try {
    const validated = updatePasswordSchema.parse(newPassword)

    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) throw new Error("Not authenticated")

    const adminUser = await db.select().from(users).where(eq(users.id, user.id)).limit(1)
    if (!adminUser || adminUser.length === 0 || adminUser[0].role !== 'admin') {
      throw new Error("Unauthorized: Admin profile not found")
    }

    const { error } = await supabase.auth.updateUser({ password: validated })
    if (error) throw new Error(error.message)

    return { success: true }
  } catch (error: any) {
    return { success: false, error: error.message }
  }
}
