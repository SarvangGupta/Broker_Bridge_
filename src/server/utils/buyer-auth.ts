import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { users, companies } from "@/src/server/db/schema";
import { eq } from "drizzle-orm";
import { provisionableRole, trustedRole } from "./trusted-role";

/**
 * Strict Flat Role Model for Buyer Module.
 * There is exactly ONE Buyer role: `BUYER_ADMIN`.
 * Legacy sub-roles (`BUYER_USER`, `BUYER_VIEWER`) are scrubbed and mapped directly to `BUYER_ADMIN`.
 */
export type BuyerRole = 'BUYER_ADMIN';

export type BuyerSessionData = {
  user: typeof users.$inferSelect;
  companyId: string;
  company: typeof companies.$inferSelect;
  role: BuyerRole;
};

export type BuyerSessionResult =
  | { success: true; data: BuyerSessionData; error?: undefined }
  | { success: false; error: string; data?: undefined };

/**
 * Resolves the effective Buyer role from a raw role string.
 * Strictly enforces `BUYER_ADMIN` as the sole Buyer role.
 */
export function resolveBuyerRole(rawRole?: string | null): BuyerRole {
  return 'BUYER_ADMIN';
}

/**
 * Verifies that the incoming request has an authenticated session
 * linked to a valid Buyer organization.
 */
export async function verifyBuyerSession(): Promise<BuyerSessionResult> {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized" };
    }

    let dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser) {
      // Never a privileged role from client-controlled user_metadata: inserting
      // role 'admin' here would be copied into trusted app_metadata by trg_sync_privileged_role.
      const userRole = provisionableRole(user);
      const userName = user.user_metadata?.name || user.user_metadata?.full_name || user.email?.split('@')[0] || 'User';
      const inserted = await db.insert(users).values({
        id: user.id,
        name: userName,
        email: user.email || null,
        role: userRole,
        status: true,
      }).returning();
      dbUser = inserted[0];
    }

    // Buyer actions are for Buyer accounts only (previously any role passed).
    if (trustedRole(user, dbUser.role) !== 'buyer') {
      return { success: false, error: "Buyer access required" };
    }

    if (!dbUser.companyId) {
      return { success: false, error: "User is not linked to a company" };
    }

    const companyRecord = await db.query.companies.findFirst({
      where: eq(companies.id, dbUser.companyId),
    });

    if (!companyRecord) {
      return { success: false, error: "Company profile not found" };
    }

    return {
      success: true,
      data: {
        user: dbUser,
        companyId: dbUser.companyId,
        company: companyRecord,
        role: 'BUYER_ADMIN',
      },
    };
  } catch (error: any) {
    console.error("verifyBuyerSession error:", error);
    return { success: false, error: error.message || "Authentication failed" };
  }
}
