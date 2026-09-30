"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { users } from "@/src/server/db/schema";
import { eq, desc } from "drizzle-orm";
import { createClient as createSupabaseAdminClient } from "@supabase/supabase-js";
import { revalidatePath } from "next/cache";

export type AdminActionResult<T = any> = {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
};

export interface CreateBrokerInput {
  name: string;
  email: string;
  password: string;
  phone?: string;
}

/**
 * Task 2: Admin God-Mode Server Action for Invite-Only Broker Provisioning.
 * Creates a new Supabase Auth user and public.users DB record with role 'broker'.
 */
export async function createBrokerByAdminAction(
  input: CreateBrokerInput
): Promise<AdminActionResult> {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized: Session required." };
    }

    const callerDbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!callerDbUser || callerDbUser.role !== "admin") {
      return { success: false, error: "Unauthorized: Tier 0 Admin privileges required." };
    }

    const name = input.name?.trim();
    const email = input.email?.trim().toLowerCase();
    const password = input.password?.trim();
    const phone = input.phone?.trim();

    if (!name || !email || !password) {
      return { success: false, error: "Name, email, and password are required fields." };
    }

    if (password.length < 6) {
      return { success: false, error: "Temporary password must be at least 6 characters." };
    }

    // Check if email already exists in Drizzle database
    const existingUser = await db.query.users.findFirst({
      where: eq(users.email, email),
    });

    if (existingUser) {
      return { success: false, error: "A user with this email address already exists." };
    }

    // Instantiate admin auth client using service role key (or fallback to anon key)
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

    const supabaseAdmin = createSupabaseAdminClient(supabaseUrl, serviceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    let newAuthUserId: string;

    // Use admin.createUser to create user without disrupting admin caller session
    const { data: authData, error: adminCreateError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: name,
        name: name,
        role: "broker",
      },
    });

    if (adminCreateError || !authData.user) {
      // Fallback: If service role key lacks admin permissions, attempt fallback sign-up
      const { data: fallbackAuth, error: fallbackError } = await supabaseAdmin.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: name,
            name: name,
            role: "broker",
          },
        },
      });

      if (fallbackError || !fallbackAuth.user) {
        return {
          success: false,
          error: adminCreateError?.message || fallbackError?.message || "Failed to create broker Auth account.",
        };
      }

      newAuthUserId = fallbackAuth.user.id;
    } else {
      newAuthUserId = authData.user.id;
    }

    // Insert public.users record
    await db.insert(users).values({
      id: newAuthUserId,
      name,
      email,
      mobile: phone || null,
      role: "broker",
      status: true,
    });

    revalidatePath("/admin");

    return {
      success: true,
      message: `Broker workspace provisioned successfully for ${name}.`,
      data: {
        id: newAuthUserId,
        email,
        name,
      },
    };
  } catch (error: any) {
    console.error("createBrokerByAdminAction error:", error);
    return { success: false, error: error.message || "Failed to provision broker account." };
  }
}

/**
 * Fetches all broker users for the Admin Brokers Vault data table.
 */
export async function getAdminBrokersListAction(): Promise<AdminActionResult> {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized" };
    }

    const callerDbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!callerDbUser || callerDbUser.role !== "admin") {
      return { success: false, error: "Unauthorized: Admin access required." };
    }

    const brokerList = await db
      .select({
        id: users.id,
        name: users.name,
        email: users.email,
        mobile: users.mobile,
        status: users.status,
        createdAt: users.createdAt,
      })
      .from(users)
      .where(eq(users.role, "broker"))
      .orderBy(desc(users.createdAt));

    return { success: true, data: brokerList };
  } catch (error: any) {
    console.error("getAdminBrokersListAction error:", error);
    return { success: false, error: error.message || "Failed to fetch brokers list." };
  }
}
