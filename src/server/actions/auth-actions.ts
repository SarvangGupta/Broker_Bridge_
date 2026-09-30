"use server"

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { users } from "@/src/server/db/schema"
import { redirect } from "next/navigation"

import { z } from "zod"

const allowedRegistrationRoles = z.enum(["buyer", "seller"])

export async function signUpAction(formData: FormData) {
  const email = formData.get("email") as string
  const password = formData.get("password") as string
  const name = formData.get("name") as string
  const rawRole = (formData.get("role") as string)?.toLowerCase()

  if (!email || !password || !name || !rawRole) {
    return { error: "Missing required fields" }
  }

  if (rawRole === "broker") {
    return { error: "Broker registration is invite-only. Please contact platform Admin." }
  }

  const roleValidation = allowedRegistrationRoles.safeParse(rawRole)
  if (!roleValidation.success) {
    return { error: "Invalid registration role. Admin & Broker registration are restricted." }
  }
  const role = roleValidation.data

  const supabase = await createClient()

  // Create user in Supabase Auth
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        role: role,
        full_name: name,
        name: name
      }
    }
  })

  if (error) {
    return { error: error.message }
  }

  if (data.user) {
    try {
      // Insert into our Drizzle database using the Supabase auth user ID
      const userId = data.user.id;
      await db.insert(users).values({
        id: userId,
        name,
        email,
        role,
        status: true,
      })
      
    } catch (dbError: any) {
      console.error("DB Insert Error:", dbError)
      return { error: "Failed to create user profile in database" }
    }
  }

  // Force sign out just in case Supabase auto-logged them in
  await supabase.auth.signOut()
  return { success: "Account created successfully! You can now sign in." }
}

export async function signInAction(formData: FormData) {
  const email = formData.get("email") as string
  const password = formData.get("password") as string

  if (!email || !password) {
    return { error: "Missing email or password" }
  }

  const supabase = await createClient()

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error) {
    return { error: error.message }
  }

  if (data.user) {
    let userRecord;
    try {
      // Explicitly check Drizzle database for role
      userRecord = await db.query.users.findFirst({
        where: (users, { eq }) => eq(users.id, data.user.id)
      })
    } catch (err) {
      console.error("Database check failed or timed out:", err)
      await supabase.auth.signOut()
      return { error: "Database timeout. Please try again." }
    }

    if (!userRecord || !userRecord.role) {
      // User exists in auth but has no database profile/role
      await supabase.auth.signOut()
      return { error: "Account setup incomplete. Please contact support." }
    }

    // STAMP THE ROLE ONTO THE AUTH SESSION METADATA
    await supabase.auth.updateUser({ data: { role: userRecord.role } });

    let targetPath = "/";
    if (userRecord.role === "admin") targetPath = "/admin";
    else if (userRecord.role === "broker") targetPath = "/broker";
    else if (userRecord.role === "buyer") targetPath = "/buyer";
    else if (userRecord.role === "seller") targetPath = "/seller";

    return { success: "Signed in successfully", redirectUrl: targetPath };
  }

  return { success: "Signed in successfully" }
}

export async function signOutAction() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect("/login")
}
