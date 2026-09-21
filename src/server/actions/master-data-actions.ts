'use server';

import { cache } from 'react';
import { createClient } from '@/lib/supabase/server';
import { db } from '../db';
import { 
  users,
  masterCommodities, 
  masterStates, 
  masterDistricts, 
  masterGrades, 
  masterQualityParameters,
  masterUnits, 
  masterVehicleTypes,
  masterIndustries,
  masterCategories,
  masterLaboratories,
  requirements,
  availabilities
} from '../db/schema';
import { eq, asc, and } from 'drizzle-orm';
import { masterQualityParameterFormSchema } from '@/src/types/quality-schema';

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

export async function getMasterLaboratoriesAction() {
  try {
    const labs = await db
      .select()
      .from(masterLaboratories)
      .where(eq(masterLaboratories.isActive, true))
      .orderBy(asc(masterLaboratories.name));

    if (!labs || labs.length === 0) {
      const fallbackLabs = [
        { id: '11111111-1111-1111-1111-111111111101', name: 'SGS India', location: 'Gurugram, Haryana', isActive: true },
        { id: '11111111-1111-1111-1111-111111111102', name: 'Farelabs', location: 'Gurugram, Haryana', isActive: true },
        { id: '11111111-1111-1111-1111-111111111103', name: 'NCML (National Commodities Management)', location: 'Jaipur, Rajasthan', isActive: true },
        { id: '11111111-1111-1111-1111-111111111104', name: 'National Collateral Management Services (NCMSL)', location: 'Bhopal, MP', isActive: true },
        { id: '11111111-1111-1111-1111-111111111105', name: 'Dr. Amin Controllers', location: 'Mumbai, Maharashtra', isActive: true },
        { id: '11111111-1111-1111-1111-111111111106', name: 'ITC Agri Business Quality Lab', location: 'Hyderabad, Telangana', isActive: true },
        { id: '11111111-1111-1111-1111-111111111107', name: 'Vimta Labs', location: 'Hyderabad, Telangana', isActive: true },
        { id: '11111111-1111-1111-1111-111111111108', name: 'Eurofins Analytical Services', location: 'Bengaluru, Karnataka', isActive: true },
        { id: '11111111-1111-1111-1111-111111111109', name: 'TUV India', location: 'Pune, Maharashtra', isActive: true },
        { id: '11111111-1111-1111-1111-111111111110', name: 'Intertek India', location: 'New Delhi, Delhi', isActive: true },
      ];
      return { success: true, data: fallbackLabs };
    }

    return { success: true, data: labs };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch master laboratories' };
  }
}

export const getMasterVehicleTypesAction = cache(
  async function getMasterVehicleTypesAction() {
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
);

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

export async function getQualityParametersAction(commodityId?: string) {
  try {
    const baseQuery = db
      .select({
        id: masterQualityParameters.id,
        commodityId: masterQualityParameters.commodityId,
        name: masterQualityParameters.name,
        type: masterQualityParameters.type,
        unit: masterQualityParameters.unit,
        minValue: masterQualityParameters.minValue,
        maxValue: masterQualityParameters.maxValue,
        targetValue: masterQualityParameters.targetValue,
        isRequired: masterQualityParameters.isRequired,
        isActive: masterQualityParameters.isActive,
        commodityName: masterCommodities.name,
      })
      .from(masterQualityParameters)
      .leftJoin(masterCommodities, eq(masterQualityParameters.commodityId, masterCommodities.id))
      .where(
        commodityId
          ? and(
              eq(masterQualityParameters.commodityId, commodityId),
              eq(masterQualityParameters.isActive, true)
            )
          : eq(masterQualityParameters.isActive, true)
      )
      .orderBy(asc(masterCommodities.name), asc(masterQualityParameters.name));

    const parameters = await baseQuery;
    return { success: true, data: parameters };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch quality parameters' };
  }
}

export async function addQualityParameterAction(payload: unknown) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const data = masterQualityParameterFormSchema.parse(payload);

    const inserted = await db
      .insert(masterQualityParameters)
      .values({
        commodityId: data.commodity_id,
        name: data.name,
        type: data.type,
        unit: data.unit || null,
        minValue: data.min_value !== undefined && data.min_value !== null ? data.min_value.toString() : null,
        maxValue: data.max_value !== undefined && data.max_value !== null ? data.max_value.toString() : null,
        targetValue: data.target_value !== undefined && data.target_value !== null ? data.target_value.toString() : null,
        isRequired: data.is_required,
        isActive: true,
      })
      .returning();

    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to add quality parameter' };
  }
}

export async function updateQualityParameterAction(id: string, payload: unknown) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const data = masterQualityParameterFormSchema.parse(payload);

    const updated = await db
      .update(masterQualityParameters)
      .set({
        commodityId: data.commodity_id,
        name: data.name,
        type: data.type,
        unit: data.unit || null,
        minValue: data.min_value !== undefined && data.min_value !== null ? data.min_value.toString() : null,
        maxValue: data.max_value !== undefined && data.max_value !== null ? data.max_value.toString() : null,
        targetValue: data.target_value !== undefined && data.target_value !== null ? data.target_value.toString() : null,
        isRequired: data.is_required,
        updatedAt: new Date(),
      })
      .where(eq(masterQualityParameters.id, id))
      .returning();

    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to update quality parameter' };
  }
}

export async function deleteQualityParameterAction(id: string) {
  try {
    const auth = await verifyAdminSession();
    if (!auth.authorized) return { success: false, error: auth.error };

    const updated = await db
      .update(masterQualityParameters)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(masterQualityParameters.id, id))
      .returning();

    return { success: true, data: updated[0] };
  } catch (error: any) {
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
