"use server";

import { db } from "@/src/server/db";
import {
  masterCommodities,
  masterCategories,
  masterIndustries,
  masterGrades,
  masterUnits,
  masterStates,
  masterDistricts,
  availabilities
} from "@/src/server/db/schema";
import { availabilitySchema, AvailabilityStatus, VALID_STATUS_TRANSITIONS } from "@/src/types/availability-schema";
import { eq, desc, and, sql } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { verifySellerSession } from "@/src/server/utils/seller-auth";

/**
 * Creates a new commodity availability lot for the authenticated Seller organization.
 * Protected by verifySellerSession({ allowViewer: false }).
 */
export async function createAvailabilityAction(data: unknown) {
  try {
    // 1. Authorize session & verify mutation permissions BEFORE execution
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    // 2. Validate payload against schema
    const parsedData = availabilitySchema.parse(data);

    // 3. Insert record bound strictly to authenticated server-side companyId
    const inserted = await db.insert(availabilities).values({
      companyId: session.data.companyId,
      commodityId: parsedData.commodity_id,
      gradeId: parsedData.grade_id,
      quantity: parsedData.total_quantity, // Sprint 6 compatibility
      unitId: parsedData.unit_id,
      price: parsedData.asking_price.toString(), // Sprint 6 compatibility
      stateId: parsedData.state_id,
      districtId: parsedData.district_id,
      visibility: parsedData.visibility,
      status: "Active",
      brokerId: parsedData.broker_id || null,

      // New Lot-Level Fields (Sprint 14.1)
      lotNumber: parsedData.lot_number || null,
      totalQuantity: parsedData.total_quantity.toString(),
      availableQuantity: parsedData.total_quantity.toString(),
      reservedQuantity: "0",
      soldQuantity: "0",
      minimumOrderQuantity: parsedData.minimum_order_quantity ? parsedData.minimum_order_quantity.toString() : null,
      askingPrice: parsedData.asking_price.toString(),
      confidentialMinimumPrice: parsedData.confidential_minimum_price ? parsedData.confidential_minimum_price.toString() : null,
      availableFrom: parsedData.available_from,
      validUntil: parsedData.valid_until,
      version: 1
    }).returning();

    revalidatePath('/', 'layout');
    return { success: true, data: inserted[0] };
  } catch (error: any) {
    console.error("Failed to create availability:", error);
    return { success: false, error: error.message || "Failed to create availability" };
  }
}

/**
 * Fetches listed availabilities belonging strictly to the authenticated Seller organization.
 * Confidential minimum price is only accessible to the owning Seller organization.
 */
export async function getMyAvailabilitiesAction() {
  try {
    const session = await verifySellerSession({ allowViewer: true });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const results = await db
      .select({
        id: availabilities.id,
        quantity: availabilities.quantity,
        price: availabilities.price,
        status: availabilities.status,
        createdAt: availabilities.createdAt,
        validUntil: availabilities.validUntil,
        commodityName: masterCommodities.name,
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
        gradeName: masterGrades.gradeName,
        unitSymbol: masterUnits.symbol,
        stateName: masterStates.name,
        districtName: masterDistricts.name,
      })
      .from(availabilities)
      .leftJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
      .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
      .leftJoin(masterGrades, eq(availabilities.gradeId, masterGrades.id))
      .leftJoin(masterUnits, eq(availabilities.unitId, masterUnits.id))
      .leftJoin(masterStates, eq(availabilities.stateId, masterStates.id))
      .leftJoin(masterDistricts, eq(availabilities.districtId, masterDistricts.id))
      .where(eq(availabilities.companyId, session.data.companyId))
      .orderBy(desc(availabilities.createdAt));

    return { success: true, data: results };
  } catch (error: any) {
    console.error("Failed to fetch availabilities:", error);
    return { success: false, error: error.message };
  }
}

/**
 * Cancels an active availability lot. Enforces company tenant boundary and role check.
 * Protected by verifySellerSession({ allowViewer: false }).
 */
export async function cancelAvailabilityAction(id: string) {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const updated = await db
      .update(availabilities)
      .set({ status: 'Deactivated' })
      .where(
        and(
          eq(availabilities.id, id),
          eq(availabilities.companyId, session.data.companyId),
          eq(availabilities.status, 'Active')
        )
      )
      .returning();

    if (updated.length === 0) {
      return { success: false, error: "Availability not found or cannot be cancelled." };
    }

    revalidatePath("/seller");
    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}

/**
 * Updates the status of an availability enforcing state machine transition guards.
 */
export async function updateAvailabilityStatusAction(payload: { id: string, newStatus: AvailabilityStatus }) {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const { id, newStatus } = payload;

    // Fetch the current record
    const record = await db.query.availabilities.findFirst({
      where: and(
        eq(availabilities.id, id),
        eq(availabilities.companyId, session.data.companyId)
      )
    });

    if (!record) {
      return { success: false, error: "Availability not found." };
    }

    const currentStatus = record.status as AvailabilityStatus;

    // Check transition guards
    const allowedTransitions = VALID_STATUS_TRANSITIONS[currentStatus] || [];
    if (!allowedTransitions.includes(newStatus)) {
      return {
        success: false,
        error: `Invalid state transition: Cannot transition from '${currentStatus}' to '${newStatus}'.`
      };
    }

    const updated = await db
      .update(availabilities)
      .set({ status: newStatus })
      .where(eq(availabilities.id, id))
      .returning();

    revalidatePath("/seller");
    return { success: true, data: updated[0] };
  } catch (error: any) {
    console.error("Failed to update availability status:", error);
    return { success: false, error: error.message || "Failed to update availability status" };
  }
}

/**
 * Fetches an expired availability record to pre-fill the Quick Renew form.
 */
export async function getAvailabilityForRenewalAction(id: string) {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const record = await db.query.availabilities.findFirst({
      where: and(
        eq(availabilities.id, id),
        eq(availabilities.companyId, session.data.companyId)
      )
    });

    if (!record) {
      return { success: false, error: "Availability not found." };
    }

    if (record.status !== "Expired") {
      return { success: false, error: "Quick Renew is only available on expired records." };
    }

    let industryId = "";
    let categoryId = "";

    const commodityRecord = await db.select().from(masterCommodities).where(eq(masterCommodities.id, record.commodityId)).limit(1);
    if (commodityRecord.length > 0) {
      categoryId = commodityRecord[0].categoryId || "";
      const categoryRecord = await db.select().from(masterCategories).where(eq(masterCategories.id, categoryId)).limit(1);
      if (categoryRecord.length > 0) {
        industryId = categoryRecord[0].industryId || "";
      }
    }

    // Strip protected/internal fields
    const { id: _id, createdAt: _ca, version: _v, ...renewData } = record;

    return { success: true, data: { ...renewData, industryId, categoryId } };
  } catch (error: any) {
    console.error("Failed to fetch renewal data:", error);
    return { success: false, error: error.message || "Failed to fetch renewal data" };
  }
}

/**
 * Fetches an active availability record to pre-fill the Edit form.
 */
export async function getAvailabilityForEditAction(id: string) {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const record = await db.query.availabilities.findFirst({
      where: and(
        eq(availabilities.id, id),
        eq(availabilities.companyId, session.data.companyId)
      )
    });

    if (!record) {
      return { success: false, error: "Availability not found." };
    }

    if (record.status === "Expired" || record.status === "Sold" || record.status === "Deactivated") {
      return { success: false, error: "You cannot edit expired, sold, or cancelled records." };
    }

    let industryId = "";
    let categoryId = "";

    const commodityRecord = await db.select().from(masterCommodities).where(eq(masterCommodities.id, record.commodityId)).limit(1);
    if (commodityRecord.length > 0) {
      categoryId = commodityRecord[0].categoryId || "";
      const categoryRecord = await db.select().from(masterCategories).where(eq(masterCategories.id, categoryId)).limit(1);
      if (categoryRecord.length > 0) {
        industryId = categoryRecord[0].industryId || "";
      }
    }

    return { success: true, data: { ...record, industryId, categoryId } };
  } catch (error: any) {
    console.error("Failed to fetch edit data:", error);
    return { success: false, error: error.message || "Failed to fetch edit data" };
  }
}


/**
 * Updates an availability record using optimistic locking to prevent stale data overwrites.
 */
export async function updateAvailabilityAction(payload: any) {
  try {
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    if (!payload.id || payload.version === undefined) {
      return { success: false, error: "Missing required fields: id and version" };
    }

    // Prepare fields to update
    const parsedData = availabilitySchema.parse(payload);
    const id = payload.id;
    const version = payload.version;
    
    // Explicitly increment the version using SQL and map form fields to DB columns
    const dataToUpdate = {
      commodityId: parsedData.commodity_id,
      gradeId: parsedData.grade_id,
      quantity: parsedData.total_quantity, // Sprint 6 compatibility
      unitId: parsedData.unit_id,
      price: parsedData.asking_price.toString(), // Sprint 6 compatibility
      stateId: parsedData.state_id,
      districtId: parsedData.district_id,
      visibility: parsedData.visibility,
      brokerId: parsedData.broker_id || null,

      lotNumber: parsedData.lot_number || null,
      totalQuantity: parsedData.total_quantity.toString(),
      // Note: In a fully robust system, availableQuantity would be recalculated based on 
      // (new totalQuantity - reserved - sold) atomically. For now, assuming edit doesn't change reserved/sold status drastically.
      availableQuantity: parsedData.total_quantity.toString(), 
      minimumOrderQuantity: parsedData.minimum_order_quantity ? parsedData.minimum_order_quantity.toString() : null,
      askingPrice: parsedData.asking_price.toString(),
      confidentialMinimumPrice: parsedData.confidential_minimum_price ? parsedData.confidential_minimum_price.toString() : null,
      availableFrom: parsedData.available_from,
      validUntil: parsedData.valid_until,
      version: sql`${availabilities.version} + 1`
    };

    const updated = await db
      .update(availabilities)
      .set(dataToUpdate)
      .where(
        and(
          eq(availabilities.id, id),
          eq(availabilities.companyId, session.data.companyId),
          eq(availabilities.version, version)
        )
      )
      .returning();

    if (updated.length === 0) {
      throw new Error("Stale data detected. This inventory was modified by another user or deal. Please refresh to see the latest quantities.");
    }

    revalidatePath("/seller");
    return { success: true, data: updated[0] };
  } catch (error: any) {
    console.error("Failed to update availability:", error);
    return { success: false, error: error.message || "Failed to update availability" };
  }
}
