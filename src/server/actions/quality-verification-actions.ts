'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  labTests,
  labTestResults,
  availabilityQualityValues,
  availabilities,
  masterQualityParameters,
  masterCommodities,
  masterGrades,
  companies,
  users,
  quotations,
  requirements,
} from '@/src/server/db/schema';
import { eq, and, asc, desc } from 'drizzle-orm';
import { revalidatePath } from 'next/cache';
import { computeLabFreshness, LabFreshnessStatus } from '@/src/types/lab-schema';

export type QualityActionResponse<T = any> = {
  success: boolean;
  data?: T;
  error?: string;
};

export type VerificationDecision = 'Verified' | 'Correction Required' | 'Rejected';

/**
 * Broker / Admin action to verify, reject, or request correction on a lot's lab test evidence.
 * Strictly checks that caller is a Broker or Admin.
 */
export async function reviewLabTestAction(input: {
  labTestId: string;
  decision: VerificationDecision;
  verificationNotes?: string;
}): Promise<QualityActionResponse<{ labTestId: string; decision: VerificationDecision }>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    const { labTestId, decision, verificationNotes } = input;
    if (!labTestId || !decision) {
      return { success: false, error: 'Lab test ID and decision are required.' };
    }

    const validDecisions: VerificationDecision[] = ['Verified', 'Correction Required', 'Rejected'];
    if (!validDecisions.includes(decision)) {
      return { success: false, error: 'Invalid verification decision.' };
    }

    // Check Role: Caller MUST have role 'broker' or 'admin'
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return {
        success: false,
        error: 'Forbidden: Only verified Brokers and Platform Administrators can review lab evidence.',
      };
    }

    const labTest = await db.query.labTests.findFirst({
      where: eq(labTests.id, labTestId),
    });

    if (!labTest) {
      return { success: false, error: 'Lab test record not found.' };
    }

    // Execute atomic transaction for lab_test update and corresponding availability_quality_values update
    await db.transaction(async (tx) => {
      // 1. Update lab_tests status and verification audit trail
      await tx
        .update(labTests)
        .set({
          status: decision,
          verifiedBy: user.id,
          verifiedAt: new Date(),
          verificationNotes: verificationNotes?.trim() || null,
          updatedAt: new Date(),
        })
        .where(eq(labTests.id, labTestId));

      // 2. Cascade verification status to lot-scoped availability_quality_values
      const qualityStatus =
        decision === 'Verified'
          ? 'Verified'
          : decision === 'Correction Required'
          ? 'Correction Required'
          : 'Rejected';

      await tx
        .update(availabilityQualityValues)
        .set({
          verificationStatus: qualityStatus,
          updatedAt: new Date(),
        })
        .where(eq(availabilityQualityValues.availabilityId, labTest.availabilityId));
    });

    revalidatePath('/broker');
    revalidatePath('/seller');
    revalidatePath('/admin');

    return {
      success: true,
      data: { labTestId, decision },
    };
  } catch (error: any) {
    console.error('reviewLabTestAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to record verification decision.',
    };
  }
}

/**
 * Generates a short-lived (15-minute / 900s) signed URL for viewing or downloading lab evidence files.
 * Restricts access to Admins, Brokers, or the owning Seller company.
 */
export async function getSignedLabDocumentUrlAction(
  labTestId: string
): Promise<QualityActionResponse<{ signedUrl: string }>> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    if (!labTestId) {
      return { success: false, error: 'Lab test ID is required.' };
    }

    const labTest = await db.query.labTests.findFirst({
      where: eq(labTests.id, labTestId),
    });

    if (!labTest) {
      return { success: false, error: 'Lab test record not found.' };
    }

    if (!labTest.fileUrl) {
      return { success: false, error: 'No physical laboratory evidence document is attached to this lot.' };
    }

    // Path Traversal Defense: Block directory traversal sequences
    if (labTest.fileUrl.includes('..') || labTest.fileUrl.includes('\\') || labTest.fileUrl.includes('\0')) {
      return { success: false, error: 'Unauthorized: Invalid file path format.' };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User profile not found.' };
    }

    const isBrokerOrAdmin = dbUser.role === 'admin' || dbUser.role === 'broker';
    const isOwner = dbUser.companyId && dbUser.companyId === labTest.companyId;

    let isBuyerParticipant = false;
    if (!isBrokerOrAdmin && !isOwner && dbUser.companyId) {
      const availabilityMatch = await db.query.quotations.findFirst({
        where: eq(quotations.sellerAvailabilityId, labTest.availabilityId),
      });
      if (availabilityMatch) {
        const reqMatch = await db.query.requirements.findFirst({
          where: and(
            eq(requirements.id, availabilityMatch.requirementId),
            eq(requirements.companyId, dbUser.companyId)
          ),
        });
        if (reqMatch) isBuyerParticipant = true;
      }
    }

    if (!isBrokerOrAdmin && !isOwner && !isBuyerParticipant) {
      return {
        success: false,
        error: 'Unauthorized: You do not have permission to view this evidence document.',
      };
    }

    // Generate short-lived 15-minute (900 seconds) signed URL
    const { data, error } = await supabase.storage
      .from('brokerbridge_lab_evidence')
      .createSignedUrl(labTest.fileUrl, 900);

    if (error || !data?.signedUrl) {
      return {
        success: false,
        error: error?.message || 'Failed to generate secure temporary document link.',
      };
    }

    return {
      success: true,
      data: { signedUrl: data.signedUrl },
    };
  } catch (error: any) {
    console.error('getSignedLabDocumentUrlAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to retrieve evidence file URL.',
    };
  }
}

/**
 * Fetches structured lab test data and parameter comparisons for Broker Review Dialog.
 */
export async function getLabTestReviewDetailsAction(input: {
  labTestId?: string;
  availabilityId?: string;
}): Promise<
  QualityActionResponse<{
    labTest: {
      id: string;
      availabilityId: string;
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
      freshness: LabFreshnessStatus;
      effectiveStatus: string;
    };
    availability: {
      id: string;
      lotNumber: string | null;
      totalQuantity: string | null;
      commodityName: string | null;
      gradeName: string | null;
      sellerCompanyName: string | null;
    };
    parameters: Array<{
      parameterId: string;
      parameterName: string;
      unit: string | null;
      type: string;
      minValue: string | null;
      maxValue: string | null;
      targetValue: string | null;
      measuredValue: string;
      isWithinBounds: boolean;
    }>;
  }>
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

    const { labTestId, availabilityId } = input;
    if (!labTestId && !availabilityId) {
      return { success: false, error: 'Lab test ID or Availability ID is required.' };
    }

    // 1. Fetch lab test record
    const labTest = labTestId
      ? await db.query.labTests.findFirst({ where: eq(labTests.id, labTestId) })
      : await db.query.labTests.findFirst({ where: eq(labTests.availabilityId, availabilityId!) });

    if (!labTest) {
      return { success: false, error: 'Lab test record not found.' };
    }

    // 2. Fetch availability metadata
    const availabilityData = await db
      .select({
        id: availabilities.id,
        lotNumber: availabilities.lotNumber,
        totalQuantity: availabilities.totalQuantity,
        commodityName: masterCommodities.name,
        gradeName: masterGrades.gradeName,
        sellerCompanyName: companies.name,
      })
      .from(availabilities)
      .leftJoin(companies, eq(availabilities.companyId, companies.id))
      .leftJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .leftJoin(masterGrades, eq(availabilities.gradeId, masterGrades.id))
      .where(eq(availabilities.id, labTest.availabilityId))
      .limit(1);

    const availability = availabilityData[0] || {
      id: labTest.availabilityId,
      lotNumber: null,
      totalQuantity: null,
      commodityName: null,
      gradeName: null,
      sellerCompanyName: null,
    };

    // 3. Fetch structured lab test results with quality parameter definitions
    const results = await db
      .select({
        parameterId: labTestResults.parameterId,
        measuredValue: labTestResults.measuredValue,
        isWithinBounds: labTestResults.isWithinBounds,
        parameterName: masterQualityParameters.name,
        unit: masterQualityParameters.unit,
        type: masterQualityParameters.type,
        minValue: masterQualityParameters.minValue,
        maxValue: masterQualityParameters.maxValue,
        targetValue: masterQualityParameters.targetValue,
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
        labTest: {
          id: labTest.id,
          availabilityId: labTest.availabilityId,
          laboratoryName: labTest.laboratoryName,
          laboratoryLocation: labTest.laboratoryLocation,
          sampleId: labTest.sampleId,
          sampleDate: labTest.sampleDate,
          testDate: labTest.testDate,
          reportNumber: labTest.reportNumber,
          reportDate: labTest.reportDate,
          validUntil: labTest.validUntil,
          fileUrl: labTest.fileUrl,
          status: labTest.status,
          verifiedBy: labTest.verifiedBy,
          verifiedAt: labTest.verifiedAt,
          verificationNotes: labTest.verificationNotes,
          freshness,
          effectiveStatus,
        },
        availability,
        parameters: results,
      },
    };
  } catch (error: any) {
    console.error('getLabTestReviewDetailsAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch lab test review details.',
    };
  }
}
