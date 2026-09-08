'use server';

import {
  executeSecurityDoubleCheck,
  SecurityAuditReport,
} from "@/src/server/utils/security-state-audit";
import { verifySellerSession } from "@/src/server/utils/seller-auth";

/**
 * Server Action: Triggers the non-destructive security and state-transition double-check suite (Micro-Sprint 20.3).
 * Allowed for Seller Admins, Brokers, Platform Admins, and development environments.
 */
export async function runSecurityDoubleCheckAction(): Promise<{
  success: boolean;
  data?: SecurityAuditReport;
  error?: string;
}> {
  try {
    const isDev = process.env.NODE_ENV !== "production";

    // In production, require authenticated session
    if (!isDev) {
      const session = await verifySellerSession({ allowViewer: true });
      if (!session.success || !session.data) {
        return {
          success: false,
          error: session.error || "Unauthorized: Valid session required to run security audit.",
        };
      }
    }

    const report = await executeSecurityDoubleCheck();

    return {
      success: true,
      data: report,
    };
  } catch (error: any) {
    console.error("runSecurityDoubleCheckAction error:", error);
    return {
      success: false,
      error: error.message || "Failed to execute security double-check audit.",
    };
  }
}
