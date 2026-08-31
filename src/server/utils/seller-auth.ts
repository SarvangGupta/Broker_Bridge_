import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { users } from "@/src/server/db/schema";
import { eq } from "drizzle-orm";

export type SellerRole = 'SELLER_ADMIN' | 'SELLER_USER' | 'SELLER_VIEWER';

export type SellerSessionData = {
  user: typeof users.$inferSelect;
  companyId: string;
  role: SellerRole;
};

export type SellerSessionResult =
  | { success: true; data: SellerSessionData; error?: undefined }
  | { success: false; error: string; data?: undefined };

/**
 * Resolves the effective Seller role from database/user record.
 * Maps:
 * - 'seller' -> 'SELLER_ADMIN'
 * - 'SELLER_ADMIN' -> 'SELLER_ADMIN'
 * - 'SELLER_USER' -> 'SELLER_USER'
 * - 'SELLER_VIEWER' -> 'SELLER_VIEWER'
 * - 'admin' -> 'SELLER_ADMIN'
 */
export function resolveSellerRole(rawRole?: string | null): SellerRole {
  if (!rawRole) return 'SELLER_ADMIN';
  const r = rawRole.toUpperCase();
  if (r.includes('VIEWER')) return 'SELLER_VIEWER';
  if (r.includes('USER') || r.includes('OPERATOR')) return 'SELLER_USER';
  return 'SELLER_ADMIN';
}

/**
 * Verifies that the incoming request has a valid authenticated Seller session
 * linked to an active company tenant. Enforces role-based mutation gates.
 *
 * @param options.allowViewer If false (default), rejects SELLER_VIEWER accounts with an unauthorized error.
 */
export async function verifySellerSession(options?: {
  allowViewer?: boolean;
}): Promise<SellerSessionResult> {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Unauthorized" };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser) {
      return { success: false, error: "User profile not found" };
    }

    if (!dbUser.companyId) {
      return { success: false, error: "User is not linked to a company" };
    }

    const effectiveRole = resolveSellerRole(dbUser.role);

    // If caller is SELLER_VIEWER and viewer mutations are not allowed
    if (effectiveRole === 'SELLER_VIEWER' && options?.allowViewer !== true) {
      return {
        success: false,
        error: "Unauthorized: Read-only viewer accounts cannot create or modify records.",
      };
    }

    return {
      success: true,
      data: {
        user: dbUser,
        companyId: dbUser.companyId,
        role: effectiveRole,
      },
    };
  } catch (error: any) {
    console.error("verifySellerSession error:", error);
    return { success: false, error: error.message || "Authentication failed" };
  }
}
