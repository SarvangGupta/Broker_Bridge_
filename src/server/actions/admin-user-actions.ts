"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { users, companies, profilesBuyer, profilesSeller } from "@/src/server/db/schema";
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

export interface CreateBuyerSellerInput {
  userFullName: string;
  email: string;
  password: string;
  phone?: string;
  role: "buyer" | "seller";
  companyName: string;
  gst?: string;
  industryId?: string;
  categoryId?: string;
  stateId?: string;
  districtId?: string;
}

/**
 * Task 1: Super Admin Direct Buyer/Seller Provisioning Server Action.
 * Directly provisions an authenticated Buyer/Seller Auth user and an approved Company,
 * bypassing public onboarding and focus mode traps.
 */
export async function createBuyerSellerByAdminAction(
  data: CreateBuyerSellerInput
): Promise<AdminActionResult> {
  try {
    // 1. Authenticate caller session strictly ensuring Tier 0 Admin
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

    // Input Sanitization & Validation
    const userFullName = data.userFullName?.trim();
    const email = data.email?.trim().toLowerCase();
    const password = data.password?.trim();
    const phone = data.phone?.trim();
    const role = data.role?.toLowerCase() as "buyer" | "seller";
    const companyName = data.companyName?.trim();
    const gst = data.gst?.trim().toUpperCase();
    const stateId = data.stateId?.trim() || null;
    const districtId = data.districtId?.trim() || null;

    if (!userFullName || !email || !password || !companyName || !role) {
      return {
        success: false,
        error: "Full Name, Email, Password, Company Name, and Role are required.",
      };
    }

    if (role !== "buyer" && role !== "seller") {
      return { success: false, error: "Role must be either 'buyer' or 'seller'." };
    }

    if (password.length < 6) {
      return { success: false, error: "Temporary password must be at least 6 characters." };
    }

    if (gst && gst.length > 15) {
      return { success: false, error: "GST cannot exceed 15 characters." };
    }

    // Check if email already exists in Drizzle database
    const existingUser = await db.query.users.findFirst({
      where: eq(users.email, email),
    });

    if (existingUser) {
      return { success: false, error: "A user with this email address already exists." };
    }

    // 2. Instantiate Supabase admin client with service role key
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

    const supabaseAdmin = createSupabaseAdminClient(supabaseUrl, serviceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // 3. Call supabase.auth.admin.createUser({ email, password, email_confirm: true })
    let newAuthUserId: string;

    const { data: authData, error: adminCreateError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: userFullName,
        name: userFullName,
        role: role,
      },
    });

    if (adminCreateError || !authData.user) {
      // Fallback for development if service role key lacks full admin privileges
      const { data: fallbackAuth, error: fallbackError } = await supabaseAdmin.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: userFullName,
            name: userFullName,
            role: role,
          },
        },
      });

      if (fallbackError || !fallbackAuth.user) {
        return {
          success: false,
          error: adminCreateError?.message || fallbackError?.message || "Failed to create user Auth account.",
        };
      }

      newAuthUserId = fallbackAuth.user.id;
    } else {
      newAuthUserId = authData.user.id;
    }

    // 4. Use Drizzle ORM to INSERT into companies table with status = true and isVerified = true
    const [newCompany] = await db
      .insert(companies)
      .values({
        name: companyName,
        gst: gst || null,
        stateId: stateId,
        districtId: districtId,
        status: true, // APPROVED: Bypasses onboarding queue
        isVerified: true, // APPROVED: Bypasses focus mode onboarding gates
        trustScore: 100,
      })
      .returning({ id: companies.id });

    if (!newCompany?.id) {
      // Cleanup created auth user if company creation fails
      try {
        await supabaseAdmin.auth.admin.deleteUser(newAuthUserId);
      } catch (_) {}
      return { success: false, error: "Failed to create company record." };
    }

    const companyId = newCompany.id;

    // 5. Use Drizzle ORM to INSERT into users table mapping id to new auth.uid
    try {
      await db.insert(users).values({
        id: newAuthUserId,
        name: userFullName,
        email: email,
        mobile: phone || null,
        role: role,
        companyId: companyId,
        status: true,
      });

      // Also create role-specific profile records if applicable
      if (role === "buyer") {
        await db.insert(profilesBuyer).values({ id: newAuthUserId }).onConflictDoNothing();
      } else if (role === "seller") {
        await db.insert(profilesSeller).values({ id: newAuthUserId }).onConflictDoNothing();
      }
    } catch (dbUserError: any) {
      // Cleanup company and auth user on failure
      try {
        await db.delete(companies).where(eq(companies.id, companyId));
        await supabaseAdmin.auth.admin.deleteUser(newAuthUserId);
      } catch (_) {}
      return { success: false, error: dbUserError.message || "Failed to link user with company." };
    }

    // Revalidate paths for instant UI reflection
    revalidatePath("/admin");
    revalidatePath("/seller");
    revalidatePath("/buyer");

    return {
      success: true,
      message: "Account & Company Provisioned Successfully",
      data: {
        userId: newAuthUserId,
        companyId: companyId,
        email,
        role,
        companyName,
      },
    };
  } catch (error: any) {
    console.error("createBuyerSellerByAdminAction error:", error);
    return {
      success: false,
      error: error.message || "Failed to provision buyer/seller account.",
    };
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
