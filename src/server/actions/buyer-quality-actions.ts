'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  requirements,
  requirementQualitySpecs,
  masterQualityParameters,
  masterGrades,
} from '@/src/server/db/schema';
import { eq, and, asc, sql } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';

export interface CommodityQualityParameter {
  id: string;
  parameter_id: string;
  commodity_id: string;
  name: string;
  type: string;
  unit: string | null;
  min_value: number | null;
  max_value: number | null;
  target_value: number | null;
  is_mandatory: boolean;
  is_required: boolean;
  grade_baseline: string | null;
  minValue?: string | null;
  maxValue?: string | null;
  targetValue?: string | null;
  isRequired?: boolean;
  gradeBaseline?: string | null;
}

export type BuyerQualityActionResponse<T = any> = {
  success: boolean;
  data?: T;
  error?: string;
};

/**
 * Micro-Sprint 34.1: Fetch Master Quality Parameters for Buyer Requirements
 * 
 * Retrieves dynamic master quality parameters for a given commodity,
 * optionally cross-referencing and sorting by grade-specific parameter baseline limits.
 * Strictly master-driven, preventing arbitrary free-text quality definitions.
 *
 * @param commodityId The UUID of the master commodity
 * @param gradeId Optional UUID of the selected master grade
 */
export async function getCommodityQualityParametersAction(
  commodityId: string,
  gradeId?: string
): Promise<BuyerQualityActionResponse<CommodityQualityParameter[]>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    if (!commodityId) {
      return { success: false, error: 'Commodity ID is required.' };
    }

    // 1. Fetch active master quality parameters configured for the commodity
    const parameters = await db
      .select()
      .from(masterQualityParameters)
      .where(
        and(
          eq(masterQualityParameters.commodityId, commodityId),
          eq(masterQualityParameters.isActive, true)
        )
      )
      .orderBy(asc(masterQualityParameters.name));

    // 2. If gradeId is provided, optionally fetch grade-specific baseline parameters
    let gradeParametersMap: Record<string, any> = {};
    if (gradeId) {
      const gradeRecord = await db.query.masterGrades.findFirst({
        where: eq(masterGrades.id, gradeId),
      });

      if (gradeRecord?.parameters && typeof gradeRecord.parameters === 'object') {
        gradeParametersMap = gradeRecord.parameters as Record<string, any>;
      }
    }

    // 3. Map parameters into standard schema with snake_case and camelCase compatibility
    const mapped: CommodityQualityParameter[] = parameters.map((p) => {
      const gradeBaselineRaw =
        gradeParametersMap[p.name] ??
        (p.id ? gradeParametersMap[p.id] : undefined) ??
        null;

      const gradeBaseline =
        gradeBaselineRaw !== null && gradeBaselineRaw !== undefined
          ? String(gradeBaselineRaw)
          : null;

      const minVal = p.minValue !== null && p.minValue !== undefined ? Number(p.minValue) : null;
      const maxVal = p.maxValue !== null && p.maxValue !== undefined ? Number(p.maxValue) : null;
      const targetVal = p.targetValue !== null && p.targetValue !== undefined ? Number(p.targetValue) : null;

      return {
        id: p.id,
        parameter_id: p.id,
        commodity_id: p.commodityId,
        name: p.name,
        type: p.type || 'numeric',
        unit: p.unit ?? null,
        min_value: isNaN(minVal as number) ? null : minVal,
        max_value: isNaN(maxVal as number) ? null : maxVal,
        target_value: isNaN(targetVal as number) ? null : targetVal,
        is_mandatory: Boolean(p.isRequired),
        is_required: Boolean(p.isRequired),
        grade_baseline: gradeBaseline,
        minValue: p.minValue,
        maxValue: p.maxValue,
        targetValue: p.targetValue,
        isRequired: Boolean(p.isRequired),
        gradeBaseline,
      };
    });

    // 4. Sort: prioritize parameters specified in the grade baseline, then mandatory parameters, then alphabetically
    if (gradeId && Object.keys(gradeParametersMap).length > 0) {
      mapped.sort((a, b) => {
        const aInGrade = a.grade_baseline !== null;
        const bInGrade = b.grade_baseline !== null;
        if (aInGrade && !bInGrade) return -1;
        if (!aInGrade && bInGrade) return 1;
        if (a.is_mandatory && !b.is_mandatory) return -1;
        if (!a.is_mandatory && b.is_mandatory) return 1;
        return a.name.localeCompare(b.name);
      });
    }

    return {
      success: true,
      data: mapped,
    };
  } catch (error: any) {
    console.error('getCommodityQualityParametersAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch commodity quality parameters.',
    };
  }
}

export interface QualitySpecPayloadItem {
  parameterId?: string;
  parameter_id?: string;
  targetValue?: number | string;
  target_value?: number | string;
  tolerance?: number | string | null;
}

/**
 * Micro-Sprint 34.2: Server Action for Quality Persistence
 * 
 * Persists validated quality specifications for a Buyer requirement.
 * Strictly verifies authentication, organization ownership, state machine guard ('Draft' | 'Open'),
 * and independently re-validates mathematical range boundaries against master data on the server
 * to prevent API tampering.
 * 
 * Executes atomically in a Drizzle db.transaction().
 */
export async function saveRequirementQualitySpecsAction(
  requirementId: string,
  specs: QualitySpecPayloadItem[]
): Promise<BuyerQualityActionResponse<{ count: number }>> {
  try {
    // 1. Authenticate session & enforce BUYER_ADMIN role
    const session = await verifyBuyerSession();
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized: Authentication required.' };
    }

    if (session.data.role !== 'BUYER_ADMIN') {
      return { success: false, error: 'Forbidden: Insufficient privileges. BUYER_ADMIN role required.' };
    }

    const sessionCompanyId = session.data.companyId;

    if (!requirementId) {
      return { success: false, error: 'Requirement ID is required.' };
    }

    // 2. Fetch requirement and verify organization ownership
    const reqResults = await db
      .select()
      .from(requirements)
      .where(and(eq(requirements.id, requirementId), eq(requirements.companyId, sessionCompanyId)));

    if (!reqResults.length) {
      return { success: false, error: 'Requirement not found or access denied.' };
    }

    const requirement = reqResults[0];

    // 3. STATE CHECK: Ensure requirement status is 'Draft' or 'Open'
    // Prevent editing locked, negotiating, or fulfilled requirements
    const ALLOWED_STATUSES = ['Draft', 'Open'];
    if (!ALLOWED_STATUSES.includes(requirement.status)) {
      return {
        success: false,
        error: `Cannot modify quality specifications for requirement in '${requirement.status}' status. Editing is only permitted for 'Draft' or 'Open' requirements.`,
      };
    }

    // 4. Fetch the corresponding master_quality_parameters for the requirement's commodity
    const masterParams = await db
      .select()
      .from(masterQualityParameters)
      .where(
        and(
          eq(masterQualityParameters.commodityId, requirement.commodityId),
          eq(masterQualityParameters.isActive, true)
        )
      );

    const masterMap = new Map<string, typeof masterParams[0]>();
    for (const p of masterParams) {
      masterMap.set(p.id, p);
    }

    // 5. SERVER-SIDE BOUNDS RE-VERIFICATION & ANTI-TAMPERING
    const rowsToInsert: Array<{
      requirementId: string;
      parameterId: string;
      targetValue: string;
      tolerance?: string | null;
    }> = [];

    // Normalize incoming specs
    const normalizedSpecs = (specs || []).map((s) => ({
      parameterId: s.parameterId || s.parameter_id || '',
      targetValue: s.targetValue !== undefined ? s.targetValue : s.target_value,
      tolerance: s.tolerance,
    })).filter((s) => s.parameterId !== '');

    // Check mandatory parameters from master data
    for (const master of masterParams) {
      if (master.isRequired) {
        const found = normalizedSpecs.find((s) => s.parameterId === master.id);
        if (!found || found.targetValue === undefined || found.targetValue === null || String(found.targetValue).trim() === '') {
          return {
            success: false,
            error: `Mandatory quality parameter '${master.name}' is missing a required value.`,
          };
        }
      }
    }

    // Validate each provided spec against master limits
    for (const spec of normalizedSpecs) {
      const master = masterMap.get(spec.parameterId);
      if (!master) {
        return {
          success: false,
          error: `Parameter ID '${spec.parameterId}' does not belong to the commodity of this requirement.`,
        };
      }

      // Convert and validate target value
      const valStr = String(spec.targetValue).trim().replace(',', '.');
      const numVal = parseFloat(valStr);

      if (isNaN(numVal) || !isFinite(numVal)) {
        return {
          success: false,
          error: `Quality parameter '${master.name}' must have a valid numeric value.`,
        };
      }

      const minVal = master.minValue !== null && master.minValue !== undefined ? Number(master.minValue) : null;
      const maxVal = master.maxValue !== null && master.maxValue !== undefined ? Number(master.maxValue) : null;
      const unitStr = master.unit ? ` ${master.unit}` : '';

      if (minVal !== null && numVal < minVal) {
        return {
          success: false,
          error: `${master.name} value (${numVal}) is below minimum allowed limit of ${minVal}${unitStr}.`,
        };
      }

      if (maxVal !== null && numVal > maxVal) {
        return {
          success: false,
          error: `${master.name} value (${numVal}) exceeds maximum allowed limit of ${maxVal}${unitStr}.`,
        };
      }

      let toleranceStr: string | null = null;
      if (spec.tolerance !== undefined && spec.tolerance !== null && String(spec.tolerance).trim() !== '') {
        const tolNum = parseFloat(String(spec.tolerance).trim().replace(',', '.'));
        if (!isNaN(tolNum)) {
          toleranceStr = String(tolNum);
        }
      }

      rowsToInsert.push({
        requirementId,
        parameterId: master.id,
        targetValue: String(numVal),
        tolerance: toleranceStr,
      });
    }

    // 6. DB Resilience: Ensure requirement_quality_specs table exists
    try {
      await db.execute(sql`
        CREATE TABLE IF NOT EXISTS "requirement_quality_specs" (
          "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          "requirement_id" uuid NOT NULL REFERENCES "public"."requirements"("id") ON DELETE CASCADE,
          "parameter_id" uuid NOT NULL REFERENCES "public"."master_quality_parameters"("id"),
          "target_value" numeric NOT NULL,
          "tolerance" numeric,
          "created_at" timestamp DEFAULT now() NOT NULL,
          "updated_at" timestamp DEFAULT now() NOT NULL
        );
        CREATE INDEX IF NOT EXISTS "idx_req_quality_specs_req_id" ON "requirement_quality_specs"("requirement_id");
        CREATE INDEX IF NOT EXISTS "idx_req_quality_specs_param_id" ON "requirement_quality_specs"("parameter_id");
      `);
    } catch (tblErr) {
      // Table already created
    }

    // 7. Atomic Transaction: Delete previous specs & insert validated specs
    await db.transaction(async (tx) => {
      await tx
        .delete(requirementQualitySpecs)
        .where(eq(requirementQualitySpecs.requirementId, requirementId));

      if (rowsToInsert.length > 0) {
        await tx.insert(requirementQualitySpecs).values(rowsToInsert);
      }
    });

    // 8. Revalidate paths for instant client-side update
    revalidatePath('/', 'layout');
    revalidatePath('/buyer/requirements');
    revalidatePath(`/buyer/requirements/${requirementId}`);

    return {
      success: true,
      data: { count: rowsToInsert.length },
    };
  } catch (error: any) {
    console.error('saveRequirementQualitySpecsAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to save requirement quality specifications.',
    };
  }
}

/**
 * Micro-Sprint 34.2: Fetch Persisted Quality Specifications for a Requirement
 * 
 * Retrieves saved requirement_quality_specs linked with master_quality_parameters definitions.
 */
export async function getRequirementQualitySpecsAction(
  requirementId: string
): Promise<BuyerQualityActionResponse<any[]>> {
  try {
    const session = await verifyBuyerSession();
    if (!session.success || !session.data) {
      return { success: false, error: session.error || 'Unauthorized: Authentication required.' };
    }

    const sessionCompanyId = session.data.companyId;

    if (!requirementId) {
      return { success: false, error: 'Requirement ID is required.' };
    }

    // Verify ownership
    const reqResults = await db
      .select({ id: requirements.id })
      .from(requirements)
      .where(and(eq(requirements.id, requirementId), eq(requirements.companyId, sessionCompanyId)));

    if (!reqResults.length) {
      return { success: false, error: 'Requirement not found or access denied.' };
    }

    const specs = await db
      .select({
        id: requirementQualitySpecs.id,
        requirementId: requirementQualitySpecs.requirementId,
        parameterId: requirementQualitySpecs.parameterId,
        targetValue: requirementQualitySpecs.targetValue,
        tolerance: requirementQualitySpecs.tolerance,
        name: masterQualityParameters.name,
        unit: masterQualityParameters.unit,
        minValue: masterQualityParameters.minValue,
        maxValue: masterQualityParameters.maxValue,
        isRequired: masterQualityParameters.isRequired,
      })
      .from(requirementQualitySpecs)
      .innerJoin(
        masterQualityParameters,
        eq(masterQualityParameters.id, requirementQualitySpecs.parameterId)
      )
      .where(eq(requirementQualitySpecs.requirementId, requirementId));

    return {
      success: true,
      data: specs,
    };
  } catch (error: any) {
    console.error('getRequirementQualitySpecsAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch requirement quality specifications.',
    };
  }
}
