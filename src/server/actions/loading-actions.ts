"use server";

import { db } from "@/src/server/db";
import { availabilities } from "@/src/server/db/schema";
import { loadingReadinessSchema, LoadingReadinessPayload } from "@/src/types/loading-schema";
import { eq, and } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { verifySellerSession } from "@/src/server/utils/seller-auth";

export type LoadingActionResponse<T = any> = {
  success: boolean;
  data?: T;
  error?: string;
};

/**
 * Updates the loading readiness operational attributes of an inventory lot.
 * Strictly verifies authenticated Seller organization ownership and role permissions.
 *
 * @param availabilityId UUID of the target inventory lot
 * @param data Loading readiness payload conforming to loadingReadinessSchema
 */
export async function updateLoadingReadinessAction(
  availabilityId: string,
  data: unknown
): Promise<LoadingActionResponse> {
  try {
    // 1. Security Checkpoint: Verify logged-in session & company association
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized: Valid Seller session required." };
    }

    if (!availabilityId) {
      return { success: false, error: "Availability lot ID is required." };
    }

    // 2. Validate incoming payload with Zod schema (including status refinements)
    const validationResult = loadingReadinessSchema.safeParse(data);
    if (!validationResult.success) {
      const firstError = validationResult.error.errors[0]?.message || "Validation failed";
      return { success: false, error: firstError };
    }

    const payload = validationResult.data;

    // 3. Security Checkpoint: Verify that the availability exists and belongs to this Seller company
    const existingLot = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, availabilityId),
    });

    if (!existingLot) {
      return { success: false, error: "Inventory lot not found." };
    }

    if (existingLot.companyId !== session.data.companyId) {
      return { success: false, error: "Unauthorized: You do not have permission to modify this lot." };
    }

    // 4. Update the database record using Drizzle ORM
    const updated = await db
      .update(availabilities)
      .set({
        loadingStatus: payload.loading_status,
        loadingDuration: payload.loading_duration ?? null,
        loadingStartDate: payload.loading_start_date ?? null,
        loadingCapacity: payload.loading_capacity ? payload.loading_capacity.toString() : null,
        loadingRemarks: payload.loading_remarks ?? null,
        loadingUpdatedAt: new Date(),
      })
      .where(
        and(
          eq(availabilities.id, availabilityId),
          eq(availabilities.companyId, session.data.companyId)
        )
      )
      .returning();

    if (!updated || updated.length === 0) {
      return { success: false, error: "Failed to update loading readiness record." };
    }

    // 5. Revalidate cache for responsive UI updates
    revalidatePath("/seller");
    revalidatePath("/", "layout");

    return {
      success: true,
      data: updated[0],
    };
  } catch (error: any) {
    console.error("Failed to update loading readiness:", error);
    return {
      success: false,
      error: error.message || "An unexpected error occurred while updating loading readiness.",
    };
  }
}

/**
 * Fetches the loading readiness details for a specific inventory lot.
 * Enforces company ownership check or Broker/Admin visibility.
 */
export async function getLoadingReadinessAction(
  availabilityId: string
): Promise<LoadingActionResponse> {
  try {
    const session = await verifySellerSession({ allowViewer: true });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized." };
    }

    if (!availabilityId) {
      return { success: false, error: "Availability ID is required." };
    }

    const lot = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, availabilityId),
      columns: {
        id: true,
        companyId: true,
        lotNumber: true,
        loadingStatus: true,
        loadingDuration: true,
        loadingStartDate: true,
        loadingCapacity: true,
        loadingRemarks: true,
        loadingUpdatedAt: true,
      },
    });

    if (!lot) {
      return { success: false, error: "Inventory lot not found." };
    }

    if (lot.companyId !== session.data.companyId) {
      return { success: false, error: "Unauthorized: You do not own this inventory lot." };
    }

    return {
      success: true,
      data: lot,
    };
  } catch (error: any) {
    console.error("Failed to fetch loading readiness:", error);
    return {
      success: false,
      error: error.message || "Failed to fetch loading readiness data.",
    };
  }
}
