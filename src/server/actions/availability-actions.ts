"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { 
  users, 
  masterCommodities, 
  masterCategories, 
  masterIndustries, 
  masterGrades, 
  masterUnits, 
  masterStates, 
  masterDistricts,
  availabilities
} from "@/src/server/db/schema";
import { availabilitySchema } from "@/src/types/availability-schema";
import { eq, desc, and } from "drizzle-orm";
import { revalidatePath } from "next/cache";

export async function createAvailabilityAction(data: unknown) {
  try {
    const parsedData = availabilitySchema.parse(data);

    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return { success: false, error: "Unauthorized" };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser || !dbUser.companyId) {
      return { success: false, error: "User is not linked to a company" };
    }

    const inserted = await db.insert(availabilities).values({
      companyId: dbUser.companyId,
      commodityId: parsedData.commodity_id,
      gradeId: parsedData.grade_id,
      quantity: parsedData.quantity,
      unitId: parsedData.unit_id,
      price: parsedData.price.toString(),
      stateId: parsedData.state_id,
      districtId: parsedData.district_id,
      validUntil: parsedData.valid_until,
      visibility: parsedData.visibility,
      status: "Open",
      brokerId: parsedData.broker_id || null,
    }).returning();

    revalidatePath('/', 'layout');
    return { success: true, data: inserted[0] };
  } catch (error: any) {
    console.error("Failed to create availability:", error);
    return { success: false, error: error.message || "Failed to create availability" };
  }
}

export async function getMyAvailabilitiesAction() {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser || !dbUser.companyId) return { success: false, error: "Company not found" };

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
      .where(eq(availabilities.companyId, dbUser.companyId))
      .orderBy(desc(availabilities.createdAt));

    return { success: true, data: results };
  } catch (error: any) {
    console.error("Failed to fetch availabilities:", error);
    return { success: false, error: error.message };
  }
}

export async function cancelAvailabilityAction(id: string) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser || !dbUser.companyId) return { success: false, error: "Company not found" };

    const updated = await db
      .update(availabilities)
      .set({ status: 'Cancelled' })
      .where(
        and(
          eq(availabilities.id, id),
          eq(availabilities.companyId, dbUser.companyId),
          eq(availabilities.status, 'Open')
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
