'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '../db';
import { 
  users,
  masterCommodities, 
  masterStates, 
  masterDistricts, 
  masterGrades, 
  masterUnits, 
  masterVehicleTypes,
  masterIndustries,
  masterCategories,
  requirements,
  availabilities
} from '../db/schema';
import { eq, asc } from 'drizzle-orm';

async function verifyAdminSession(): Promise<{ authorized: boolean; error?: string }> {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { authorized: false, error: 'Unauthorized' };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser || dbUser.role !== 'admin') {
      return { authorized: false, error: 'Unauthorized: Admin access required' };
    }
    return { authorized: true };
  } catch (err: any) {
    return { authorized: false, error: err.message || 'Authentication check failed' };
  }
}

export async function getMasterVehicleTypesAction() {
  try {
    const types = await db
      .select()
      .from(masterVehicleTypes)
      .where(eq(masterVehicleTypes.status, true))
      .orderBy(asc(masterVehicleTypes.name));
    return { success: true, data: types };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch vehicle types' };
  }
}

export async function getIndustriesAction() {
  try {
    const industries = await db
      .select()
      .from(masterIndustries)
      .where(eq(masterIndustries.isActive, true))
      .orderBy(asc(masterIndustries.name));
    return { success: true, data: industries };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch industries' };
  }
}

export async function addIndustryAction(name: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const inserted = await db.insert(masterIndustries).values({ name }).returning();
    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to add industry' };
  }
}

export async function updateIndustryAction(id: string, name: string, isActive?: boolean) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const values: { name: string; isActive?: boolean } = { name };
    if (isActive !== undefined) values.isActive = isActive;
    const updated = await db.update(masterIndustries).set(values).where(eq(masterIndustries.id, id)).returning();
    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to update industry' };
  }
}

export async function deleteIndustryAction(id: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const updated = await db.update(masterIndustries).set({ isActive: false }).where(eq(masterIndustries.id, id)).returning();
    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to delete industry' };
  }
}

export async function getCategoriesAction() {
  try {
    const categories = await db
      .select({
        id: masterCategories.id,
        name: masterCategories.name,
        industryId: masterCategories.industryId,
        isActive: masterCategories.isActive,
        industryName: masterIndustries.name,
      })
      .from(masterCategories)
      .leftJoin(masterIndustries, eq(masterCategories.industryId, masterIndustries.id))
      .where(eq(masterCategories.isActive, true))
      .orderBy(asc(masterCategories.name));
    return { success: true, data: categories };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch categories' };
  }
}

export async function addCategoryAction(name: string, industryId?: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const inserted = await db.insert(masterCategories).values({
      name,
      industryId: industryId || undefined,
    }).returning();
    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to add category' };
  }
}

export async function updateCategoryAction(id: string, name: string, industryId?: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const values: { name: string; industryId?: string | null } = { name };
    if (industryId !== undefined) {
      values.industryId = industryId || null;
    }
    const updated = await db.update(masterCategories).set(values).where(eq(masterCategories.id, id)).returning();
    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to update category' };
  }
}

export async function deleteCategoryAction(id: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const updated = await db.update(masterCategories).set({ isActive: false }).where(eq(masterCategories.id, id)).returning();
    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to delete category' };
  }
}

export async function addCommodityAction(name: string, categoryId?: string, code?: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const inserted = await db.insert(masterCommodities).values({ 
      name, 
      categoryId: categoryId || undefined, 
      code 
    }).returning();
    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to add commodity' };
  }
}

export async function getCommoditiesAction() {
  try {
    const commodities = await db
      .select({
        id: masterCommodities.id,
        name: masterCommodities.name,
        code: masterCommodities.code,
        categoryId: masterCommodities.categoryId,
        status: masterCommodities.status,
        categoryName: masterCategories.name,
      })
      .from(masterCommodities)
      .leftJoin(masterCategories, eq(masterCommodities.categoryId, masterCategories.id))
      .where(eq(masterCommodities.status, true))
      .orderBy(asc(masterCommodities.name));
    return { success: true, data: commodities };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch commodities' };
  }
}

export async function updateCommodityAction(id: string, name: string, categoryId?: string, code?: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const valuesToUpdate: { name: string; categoryId?: string | null; code?: string } = { name };
    if (categoryId !== undefined) {
      valuesToUpdate.categoryId = categoryId || null;
    }
    if (code !== undefined) {
      valuesToUpdate.code = code;
    }
    const updated = await db.update(masterCommodities).set(valuesToUpdate).where(eq(masterCommodities.id, id)).returning();
    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to update commodity' };
  }
}

export async function softDeleteCommodityAction(id: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const updated = await db
      .update(masterCommodities)
      .set({ status: false })
      .where(eq(masterCommodities.id, id))
      .returning();
    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to soft delete commodity' };
  }
}

export async function addStateAction(name: string, code?: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const inserted = await db.insert(masterStates).values({ name, code }).returning();
    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to add state' };
  }
}

export async function getStatesAction() {
  try {
    const states = await db.select().from(masterStates);
    return { success: true, data: states };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch states' };
  }
}

export async function addDistrictAction(name: string, stateId: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const inserted = await db.insert(masterDistricts).values({ name, stateId }).returning();
    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to add district' };
  }
}

export async function getDistrictsAction() {
  try {
    const districts = await db.select().from(masterDistricts);
    return { success: true, data: districts };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch districts' };
  }
}

export async function getGradesAction() {
  try {
    const grades = await db.select().from(masterGrades);
    return { success: true, data: grades };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch grades' };
  }
}

export async function getUnitsAction() {
  try {
    const units = await db.select().from(masterUnits);
    return { success: true, data: units };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch units' };
  }
}

export async function addGradeAction(commodityId: string, gradeName: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const inserted = await db.insert(masterGrades).values({ commodityId, gradeName }).returning();
    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to add grade' };
  }
}

export async function updateGradeAction(id: string, commodityId: string, gradeName: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const updated = await db.update(masterGrades).set({ commodityId, gradeName }).where(eq(masterGrades.id, id)).returning();
    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to update grade' };
  }
}

export async function deleteGradeAction(id: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const [linkedReqs, linkedAvails] = await Promise.all([
      db.select({ id: requirements.id }).from(requirements).where(eq(requirements.gradeId, id)).limit(1),
      db.select({ id: availabilities.id }).from(availabilities).where(eq(availabilities.gradeId, id)).limit(1),
    ]);

    if (linkedReqs.length > 0 || linkedAvails.length > 0) {
      return { 
        success: false, 
        error: 'Cannot delete this Quality Parameter because it is linked to existing trading requirements or seller availabilities.' 
      };
    }

    await db.delete(masterGrades).where(eq(masterGrades.id, id));
    return { success: true };
  } catch (error: any) {
    if (error?.code === '23503' || error?.message?.includes('foreign key')) {
      return { 
        success: false, 
        error: 'Cannot delete this Quality Parameter because it is referenced in trading records.' 
      };
    }
    return { success: false, error: error.message || 'Failed to delete quality parameter' };
  }
}

export async function addUnitAction(name: string, symbol?: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const inserted = await db.insert(masterUnits).values({ name, symbol }).returning();
    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to add unit' };
  }
}

export async function updateUnitAction(id: string, name: string, symbol?: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const updated = await db.update(masterUnits).set({ name, symbol }).where(eq(masterUnits.id, id)).returning();
    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to update unit' };
  }
}

export async function deleteUnitAction(id: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const [linkedReqs, linkedAvails] = await Promise.all([
      db.select({ id: requirements.id }).from(requirements).where(eq(requirements.unitId, id)).limit(1),
      db.select({ id: availabilities.id }).from(availabilities).where(eq(availabilities.unitId, id)).limit(1),
    ]);

    if (linkedReqs.length > 0 || linkedAvails.length > 0) {
      return { 
        success: false, 
        error: 'Cannot delete this Unit because it is linked to active requirements or availabilities.' 
      };
    }

    await db.delete(masterUnits).where(eq(masterUnits.id, id));
    return { success: true };
  } catch (error: any) {
    if (error?.code === '23503' || error?.message?.includes('foreign key')) {
      return { 
        success: false, 
        error: 'Cannot delete this Unit because it is referenced in trading records.' 
      };
    }
    return { success: false, error: error.message || 'Failed to delete unit' };
  }
}
