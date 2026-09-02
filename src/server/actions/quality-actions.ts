'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  masterQualityParameters,
  availabilityQualityValues,
  availabilities,
  users,
} from '@/src/server/db/schema';
import { eq, and, asc } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import {
  saveQualityValuesSchema,
  SaveQualityValuesInput,
  validateQualityEntries,
} from '@/src/types/quality-schema';

export type QualityActionResponse<T = any> = {
  success: boolean;
  data?: T;
  error?: string;
  validationErrors?: Record<string, string>;
};

/**
 * Fetches dynamic quality parameter templates configured for a specific commodity.
 * Gated by Supabase authentication.
 *
 * @param commodityId The UUID of the master commodity
 */
export async function getQualityTemplateByCommodityAction(
  commodityId: string
): Promise<QualityActionResponse<typeof masterQualityParameters.$inferSelect[]>> {
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

    return {
      success: true,
      data: parameters,
    };
  } catch (error: any) {
    console.error('getQualityTemplateByCommodityAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch quality parameters for commodity.',
    };
  }
}

/**
 * Saves or updates lot-scoped quality values for an availability lot.
 * Validates against commodity templates and enforces tenant ownership.
 */
export async function saveAvailabilityQualityValuesAction(
  rawInput: SaveQualityValuesInput
): Promise<QualityActionResponse<{ insertedCount: number }>> {
  try {
    // 1. Authenticate Session via @supabase/ssr
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    // 2. Validate input schema
    const parsed = saveQualityValuesSchema.safeParse(rawInput);
    if (!parsed.success) {
      return {
        success: false,
        error: 'Invalid quality parameters payload format.',
      };
    }
    const { availability_id, values } = parsed.data;

    // 3. Verify availability existence and tenant ownership
    const availability = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, availability_id),
    });

    if (!availability) {
      return { success: false, error: 'Availability lot not found.' };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User profile not found.' };
    }

    const isOwner = dbUser.companyId && dbUser.companyId === availability.companyId;
    const isAdmin = dbUser.role === 'admin';

    if (!isOwner && !isAdmin) {
      return {
        success: false,
        error: 'Unauthorized: You do not have permission to modify this lot.',
      };
    }

    // 4. Validate values against active master quality parameters
    const activeParams = await db
      .select()
      .from(masterQualityParameters)
      .where(
        and(
          eq(masterQualityParameters.commodityId, availability.commodityId),
          eq(masterQualityParameters.isActive, true)
        )
      );

    const validation = validateQualityEntries(values, activeParams);
    if (!validation.isValid) {
      const firstError = Object.values(validation.errors)[0] || 'Quality validation failed.';
      return {
        success: false,
        error: firstError,
        validationErrors: validation.errors,
      };
    }

    // 5. Atomic Drizzle Transaction: Delete existing entries and insert new ones
    const recordsToInsert = values
      .filter((v) => v.value !== undefined && v.value !== null && String(v.value).trim() !== '')
      .map((v) => ({
        availabilityId: availability_id,
        parameterId: v.parameter_id,
        value: String(v.value).trim(),
        source: 'Seller Declared',
        verificationStatus: 'Pending',
      }));

    await db.transaction(async (tx) => {
      // Clear previous values for this availability
      await tx
        .delete(availabilityQualityValues)
        .where(eq(availabilityQualityValues.availabilityId, availability_id));

      // Insert new records if any
      if (recordsToInsert.length > 0) {
        await tx.insert(availabilityQualityValues).values(recordsToInsert);
      }
    });

    revalidatePath('/seller');
    return {
      success: true,
      data: { insertedCount: recordsToInsert.length },
    };
  } catch (error: any) {
    console.error('saveAvailabilityQualityValuesAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to save quality parameters.',
    };
  }
}

/**
 * Fetches all quality values attached to an availability lot, joined with parameter definitions.
 */
export async function getAvailabilityQualityValuesAction(
  availabilityId: string
): Promise<QualityActionResponse<any[]>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    if (!availabilityId) {
      return { success: false, error: 'Availability ID is required.' };
    }

    const values = await db
      .select({
        id: availabilityQualityValues.id,
        availabilityId: availabilityQualityValues.availabilityId,
        parameterId: availabilityQualityValues.parameterId,
        value: availabilityQualityValues.value,
        source: availabilityQualityValues.source,
        verificationStatus: availabilityQualityValues.verificationStatus,
        createdAt: availabilityQualityValues.createdAt,
        updatedAt: availabilityQualityValues.updatedAt,
        parameterName: masterQualityParameters.name,
        parameterType: masterQualityParameters.type,
        unit: masterQualityParameters.unit,
        minValue: masterQualityParameters.minValue,
        maxValue: masterQualityParameters.maxValue,
        targetValue: masterQualityParameters.targetValue,
        isRequired: masterQualityParameters.isRequired,
      })
      .from(availabilityQualityValues)
      .innerJoin(
        masterQualityParameters,
        eq(availabilityQualityValues.parameterId, masterQualityParameters.id)
      )
      .where(eq(availabilityQualityValues.availabilityId, availabilityId))
      .orderBy(asc(masterQualityParameters.name));

    return {
      success: true,
      data: values,
    };
  } catch (error: any) {
    console.error('getAvailabilityQualityValuesAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch quality values for availability.',
    };
  }
}
