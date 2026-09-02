'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  labTests,
  labTestResults,
  availabilities,
  masterQualityParameters,
  users,
} from '@/src/server/db/schema';
import { eq, and, asc } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import {
  labTestFormSchema,
  checkIsWithinBounds,
  computeLabFreshness,
  LabFreshnessStatus,
} from '@/src/types/lab-schema';

export type LabActionResponse<T = any> = {
  success: boolean;
  data?: T;
  error?: string;
};

/**
 * Saves or updates a structured laboratory test record and its measured results.
 * Strictly verifies company tenant ownership.
 */
export async function saveLabTestRecordAction(
  rawPayload: unknown
): Promise<LabActionResponse<{ labTestId: string; resultsCount: number }>> {
  try {
    // 1. Authenticate session with @supabase/ssr
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    // 2. Validate input schema
    const parseResult = labTestFormSchema.safeParse(rawPayload);
    if (!parseResult.success) {
      const firstError = parseResult.error.issues[0]?.message || 'Invalid lab test data provided.';
      return { success: false, error: firstError };
    }
    const payload = parseResult.data;

    // 3. Verify tenant ownership on availability lot
    const availability = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, payload.availability_id),
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
        error: 'Unauthorized: You do not have permission to attach lab tests to this lot.',
      };
    }

    // 4. Fetch active commodity quality parameters for boundary verification
    const activeParams = await db
      .select()
      .from(masterQualityParameters)
      .where(
        and(
          eq(masterQualityParameters.commodityId, availability.commodityId),
          eq(masterQualityParameters.isActive, true)
        )
      );

    // 5. Execute Drizzle Transaction
    let labTestId = '';
    let resultsCount = 0;

    await db.transaction(async (tx) => {
      const existingLabTest = await tx.query.labTests.findFirst({
        where: eq(labTests.availabilityId, payload.availability_id),
      });

      if (existingLabTest) {
        labTestId = existingLabTest.id;
        await tx
          .update(labTests)
          .set({
            laboratoryName: payload.laboratory_name,
            laboratoryLocation: payload.laboratory_location || null,
            sampleId: payload.sample_id || null,
            sampleDate: payload.sample_date ? new Date(payload.sample_date) : null,
            testDate: new Date(payload.test_date),
            reportNumber: payload.report_number,
            reportDate: new Date(payload.report_date),
            validUntil: payload.valid_until ? new Date(payload.valid_until) : null,
            fileUrl: payload.file_url ?? existingLabTest.fileUrl,
            status: existingLabTest.status === 'Verified' ? 'Verified' : 'Under Review',
            updatedAt: new Date(),
          })
          .where(eq(labTests.id, labTestId));
      } else {
        const inserted = await tx
          .insert(labTests)
          .values({
            availabilityId: payload.availability_id,
            companyId: availability.companyId,
            laboratoryName: payload.laboratory_name,
            laboratoryLocation: payload.laboratory_location || null,
            sampleId: payload.sample_id || null,
            sampleDate: payload.sample_date ? new Date(payload.sample_date) : null,
            testDate: new Date(payload.test_date),
            reportNumber: payload.report_number,
            reportDate: new Date(payload.report_date),
            validUntil: payload.valid_until ? new Date(payload.valid_until) : null,
            fileUrl: payload.file_url || null,
            status: 'Under Review',
          })
          .returning({ id: labTests.id });

        labTestId = inserted[0].id;
      }

      // Delete existing results and bulk-insert new ones
      await tx.delete(labTestResults).where(eq(labTestResults.labTestId, labTestId));

      const toInsert = payload.results
        .filter(
          (r) => r.measured_value !== undefined && r.measured_value !== null && String(r.measured_value).trim() !== ''
        )
        .map((r) => {
          const param = activeParams.find((p) => p.id === r.parameter_id);
          const isWithin = param ? checkIsWithinBounds(r.measured_value, param) : true;
          return {
            labTestId,
            parameterId: r.parameter_id,
            measuredValue: String(r.measured_value).trim(),
            isWithinBounds: isWithin,
          };
        });

      if (toInsert.length > 0) {
        await tx.insert(labTestResults).values(toInsert);
      }

      resultsCount = toInsert.length;
    });

    revalidatePath('/seller');
    return {
      success: true,
      data: { labTestId, resultsCount },
    };
  } catch (error: any) {
    console.error('saveLabTestRecordAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to save lab test record.',
    };
  }
}

/**
 * Attaches or updates a physical certificate/evidence file URL to an availability's lab test record.
 */
export async function attachLabDocumentAction(input: {
  availabilityId: string;
  fileUrl: string;
}): Promise<LabActionResponse<{ fileUrl: string }>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    const { availabilityId, fileUrl } = input;
    if (!availabilityId || !fileUrl) {
      return { success: false, error: 'Availability ID and File URL are required.' };
    }

    const availability = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, availabilityId),
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
        error: 'Unauthorized: You do not have permission to attach documents to this lot.',
      };
    }

    const existingLabTest = await db.query.labTests.findFirst({
      where: eq(labTests.availabilityId, availabilityId),
    });

    if (existingLabTest) {
      await db
        .update(labTests)
        .set({
          fileUrl,
          status: existingLabTest.status === 'Verified' ? 'Verified' : 'Report Uploaded',
          updatedAt: new Date(),
        })
        .where(eq(labTests.id, existingLabTest.id));
    } else {
      await db.insert(labTests).values({
        availabilityId,
        companyId: availability.companyId,
        laboratoryName: 'Pending Lab Details',
        testDate: new Date(),
        reportNumber: 'PENDING-DOC',
        reportDate: new Date(),
        fileUrl,
        status: 'Report Uploaded',
      });
    }

    revalidatePath('/seller');
    return {
      success: true,
      data: { fileUrl },
    };
  } catch (error: any) {
    console.error('attachLabDocumentAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to attach lab evidence document.',
    };
  }
}

/**
 * Uploads a physical laboratory certificate / COA evidence file to Supabase Storage via Server Action.
 * Guarantees SSR httpOnly cookie authentication and verifies tenant lot ownership.
 */
export async function uploadLabEvidenceAction(
  formData: FormData
): Promise<LabActionResponse<{ path: string }>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    const file = formData.get('file') as File | null;
    const availabilityId = formData.get('availabilityId') as string | null;

    if (!file || !availabilityId) {
      return { success: false, error: 'File and availability lot ID are required.' };
    }

    // 1. Verify availability lot exists and user has ownership or admin/broker role
    const availability = await db.query.availabilities.findFirst({
      where: eq(availabilities.id, availabilityId),
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
    const isAdminOrBroker = dbUser.role === 'admin' || dbUser.role === 'broker';

    if (!isOwner && !isAdminOrBroker) {
      return {
        success: false,
        error: 'Unauthorized: You do not have permission to upload evidence for this lot.',
      };
    }

    // 2. Format sanitized path
    const cleanFileName = file.name.replace(/[^a-zA-Z0-9.-]/g, '_');
    const filePath = `${availabilityId}/${Date.now()}_${cleanFileName}`;

    // 3. Convert File to Buffer for reliable server upload
    const arrayBuffer = await file.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    const { data, error } = await supabase.storage
      .from('brokerbridge_lab_evidence')
      .upload(filePath, buffer, {
        contentType: file.type || 'application/octet-stream',
        cacheControl: '3600',
        upsert: false,
      });

    if (error) {
      console.error('Supabase storage upload error:', error);
      return { success: false, error: error.message };
    }

    return {
      success: true,
      data: { path: data.path },
    };
  } catch (error: any) {
    console.error('uploadLabEvidenceAction exception:', error);
    return { success: false, error: error.message || 'Failed to upload laboratory evidence.' };
  }
}

/**
 * Generates an authorized, time-limited signed URL for viewing or downloading private lab evidence.
 */
export async function getLabEvidenceSignedUrlAction(
  filePath: string
): Promise<LabActionResponse<{ signedUrl: string }>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    if (!filePath) {
      return { success: false, error: 'File path is required.' };
    }

    // Extract availabilityId from path: {availability_id}/{filename}
    const availabilityId = filePath.split('/')[0];
    if (!availabilityId) {
      return { success: false, error: 'Invalid evidence file path format.' };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User profile not found.' };
    }

    const isAdminOrBroker = dbUser.role === 'admin' || dbUser.role === 'broker';

    if (!isAdminOrBroker) {
      const availability = await db.query.availabilities.findFirst({
        where: eq(availabilities.id, availabilityId),
      });

      const isOwner = availability && dbUser.companyId && dbUser.companyId === availability.companyId;
      if (!isOwner) {
        return {
          success: false,
          error: 'Unauthorized: You do not have access to view this laboratory evidence.',
        };
      }
    }

    // Generate signed URL valid for 60 minutes
    const { data, error } = await supabase.storage
      .from('brokerbridge_lab_evidence')
      .createSignedUrl(filePath, 3600);

    if (error || !data?.signedUrl) {
      return { success: false, error: error?.message || 'Failed to generate signed download link.' };
    }

    return {
      success: true,
      data: { signedUrl: data.signedUrl },
    };
  } catch (error: any) {
    console.error('getLabEvidenceSignedUrlAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to retrieve evidence file link.',
    };
  }
}

/**
 * Fetches structured lab test record for an availability lot with computed freshness.
 */
export async function getLabTestByAvailabilityAction(
  availabilityId: string
): Promise<
  LabActionResponse<{
    id: string;
    availabilityId: string;
    companyId: string;
    laboratoryName: string;
    laboratoryLocation: string | null;
    sampleId: string | null;
    sampleDate: Date | null;
    testDate: Date;
    reportNumber: string;
    reportDate: Date;
    validUntil: Date | null;
    fileUrl: string | null;
    status: string;
    verifiedBy: string | null;
    verifiedAt: Date | null;
    verificationNotes: string | null;
    createdAt: Date;
    updatedAt: Date;
    freshness: LabFreshnessStatus;
    effectiveStatus: string;
    results: any[];
  } | null>
> {
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

    const labTest = await db.query.labTests.findFirst({
      where: eq(labTests.availabilityId, availabilityId),
    });

    if (!labTest) {
      return { success: true, data: null };
    }

    const results = await db
      .select({
        id: labTestResults.id,
        labTestId: labTestResults.labTestId,
        parameterId: labTestResults.parameterId,
        measuredValue: labTestResults.measuredValue,
        isWithinBounds: labTestResults.isWithinBounds,
        createdAt: labTestResults.createdAt,
        parameterName: masterQualityParameters.name,
        parameterType: masterQualityParameters.type,
        unit: masterQualityParameters.unit,
        minValue: masterQualityParameters.minValue,
        maxValue: masterQualityParameters.maxValue,
        targetValue: masterQualityParameters.targetValue,
        isRequired: masterQualityParameters.isRequired,
      })
      .from(labTestResults)
      .innerJoin(
        masterQualityParameters,
        eq(labTestResults.parameterId, masterQualityParameters.id)
      )
      .where(eq(labTestResults.labTestId, labTest.id))
      .orderBy(asc(masterQualityParameters.name));

    const freshness = computeLabFreshness(labTest.testDate, labTest.validUntil);
    const effectiveStatus =
      freshness === 'Expired' && labTest.status === 'Verified' ? 'Expired' : labTest.status;

    return {
      success: true,
      data: {
        ...labTest,
        fileUrl: labTest.fileUrl || null,
        freshness,
        effectiveStatus,
        results,
      },
    };
  } catch (error: any) {
    console.error('getLabTestByAvailabilityAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch lab test record.',
    };
  }
}
