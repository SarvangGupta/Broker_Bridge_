'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  requirements,
  availabilities,
  masterQualityParameters,
  availabilityQualityValues,
  labTests,
  labTestResults,
  masterCommodities,
  masterGrades,
  masterUnits,
  companies,
  users,
} from '@/src/server/db/schema';
import { eq, and, asc } from 'drizzle-orm';
import { computeLabFreshness, type LabFreshnessStatus } from '@/src/types/lab-schema';
import { getSignedLabDocumentUrlAction } from './quality-verification-actions';

export type QualityDocumentState = 'Verified' | 'Received' | 'Required' | 'Missing' | 'Correction Required' | 'Rejected';

export interface QualityParameterComparison {
  parameterId: string;
  name: string;
  unit: string | null;
  type: string;
  buyerTarget: string | null;
  buyerMin: string | null;
  buyerMax: string | null;
  buyerFormattedSpec: string;
  sellerValue: string | null;
  source: 'Laboratory Certified' | 'Seller Declared' | 'Missing';
  isCompliant: boolean;
  statusLabel: 'Compliant' | 'Variance' | 'Missing';
  discrepancyNote?: string;
}

export interface BrokerQualityComparisonData {
  requirement: {
    id: string;
    ref: string;
    buyerCompanyName: string;
    commodityName: string;
    gradeName: string;
  };
  availability: {
    id: string;
    lotNumber: string;
    sellerCompanyName: string;
    commodityName: string;
    gradeName: string;
    quantity: number;
    unitSymbol: string;
  };
  documentState: QualityDocumentState;
  documentStateLabel: string;
  labTest: {
    id: string;
    laboratoryName: string;
    laboratoryLocation: string | null;
    sampleId: string | null;
    reportNumber: string;
    reportDateFormatted: string | null;
    testDateFormatted: string | null;
    validUntilFormatted: string | null;
    fileUrl: string | null;
    hasPhysicalDocument: boolean;
    status: string;
    freshness: LabFreshnessStatus;
    verifiedAtFormatted: string | null;
    verificationNotes: string | null;
  } | null;
  summary: {
    totalParameters: number;
    compliantParameters: number;
    varianceCount: number;
    missingCount: number;
    overallStatus: 'Fully Compliant' | 'Minor Variances' | 'Specification Discrepancy' | 'Pending Verification';
    summaryText: string;
  };
  parameters: QualityParameterComparison[];
}

export type QualityComparisonResponse = {
  success: boolean;
  data?: BrokerQualityComparisonData;
  error?: string;
};

/**
 * Micro-Sprint 24.2: Fetch Quality & Lab Comparison between Buyer Requirement and Seller Lot
 */
export async function getBrokerQualityComparisonAction(input: {
  requirementId: string;
  availabilityId: string;
}): Promise<QualityComparisonResponse> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Authentication required' };
    }

    const { requirementId, availabilityId } = input;
    if (!requirementId || !availabilityId) {
      return { success: false, error: 'Both requirementId and availabilityId are required.' };
    }

    // 1. Fetch Requirement Details
    const reqRes = await db
      .select({
        id: requirements.id,
        commodityId: requirements.commodityId,
        commodityName: masterCommodities.name,
        gradeId: requirements.gradeId,
        gradeName: masterGrades.gradeName,
        gradeParameters: masterGrades.parameters,
        buyerCompanyName: companies.name,
      })
      .from(requirements)
      .innerJoin(companies, eq(requirements.companyId, companies.id))
      .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .innerJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
      .where(eq(requirements.id, requirementId))
      .limit(1);

    if (!reqRes || reqRes.length === 0) {
      return { success: false, error: 'Buyer requirement not found.' };
    }
    const req = reqRes[0];

    // 2. Fetch Availability Details
    const availRes = await db
      .select({
        id: availabilities.id,
        lotNumber: availabilities.lotNumber,
        commodityId: availabilities.commodityId,
        commodityName: masterCommodities.name,
        gradeId: availabilities.gradeId,
        gradeName: masterGrades.gradeName,
        availableQuantity: availabilities.availableQuantity,
        unitName: masterUnits.name,
        unitSymbol: masterUnits.symbol,
        sellerCompanyName: companies.name,
      })
      .from(availabilities)
      .innerJoin(companies, eq(availabilities.companyId, companies.id))
      .innerJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .innerJoin(masterGrades, eq(availabilities.gradeId, masterGrades.id))
      .innerJoin(masterUnits, eq(availabilities.unitId, masterUnits.id))
      .where(eq(availabilities.id, availabilityId))
      .limit(1);

    if (!availRes || availRes.length === 0) {
      return { success: false, error: 'Seller availability lot not found.' };
    }
    const avail = availRes[0];

    // 3. Fetch Master Quality Parameters for Commodity
    const masterParams = await db
      .select()
      .from(masterQualityParameters)
      .where(
        and(
          eq(masterQualityParameters.commodityId, req.commodityId),
          eq(masterQualityParameters.isActive, true)
        )
      )
      .orderBy(asc(masterQualityParameters.name));

    // 4. Fetch Lab Test for Lot (if any)
    const labTestRec = await db.query.labTests.findFirst({
      where: eq(labTests.availabilityId, availabilityId),
    });

    let labResults: Array<{ parameterId: string; measuredValue: string; isWithinBounds: boolean }> = [];
    if (labTestRec) {
      labResults = await db
        .select({
          parameterId: labTestResults.parameterId,
          measuredValue: labTestResults.measuredValue,
          isWithinBounds: labTestResults.isWithinBounds,
        })
        .from(labTestResults)
        .where(eq(labTestResults.labTestId, labTestRec.id));
    }

    // 5. Fetch Seller Declared Values (if any)
    const declaredValues = await db
      .select()
      .from(availabilityQualityValues)
      .where(eq(availabilityQualityValues.availabilityId, availabilityId));

    // Map into comparison matrix
    let compliantCount = 0;
    let varianceCount = 0;
    let missingCount = 0;

    const comparisons: QualityParameterComparison[] = masterParams.map((param) => {
      // Buyer spec derivation
      let buyerTarget = param.targetValue;
      let buyerMin = param.minValue;
      let buyerMax = param.maxValue;

      // Check if requirement grade overrides parameters
      if (req.gradeParameters && typeof req.gradeParameters === 'object') {
        const gradeParamVal = (req.gradeParameters as any)[param.name];
        if (gradeParamVal !== undefined) {
          buyerTarget = String(gradeParamVal);
        }
      }

      let buyerFormattedSpec = 'Standard Grade Tolerance';
      if (buyerMin && buyerMax) {
        buyerFormattedSpec = `${buyerMin} - ${buyerMax} ${param.unit || ''}`.trim();
      } else if (buyerMax) {
        buyerFormattedSpec = `Max ${buyerMax} ${param.unit || ''}`.trim();
      } else if (buyerMin) {
        buyerFormattedSpec = `Min ${buyerMin} ${param.unit || ''}`.trim();
      } else if (buyerTarget) {
        buyerFormattedSpec = `Target: ${buyerTarget} ${param.unit || ''}`.trim();
      }

      // Seller value lookup
      const labMatch = labResults.find((r) => r.parameterId === param.id);
      const declMatch = declaredValues.find((d) => d.parameterId === param.id);

      let sellerValue: string | null = null;
      let source: QualityParameterComparison['source'] = 'Missing';
      let isCompliant = true;
      let statusLabel: QualityParameterComparison['statusLabel'] = 'Compliant';
      let discrepancyNote: string | undefined = undefined;

      if (labMatch && labMatch.measuredValue) {
        sellerValue = labMatch.measuredValue;
        source = 'Laboratory Certified';
        isCompliant = labMatch.isWithinBounds;
      } else if (declMatch && declMatch.value) {
        sellerValue = declMatch.value;
        source = 'Seller Declared';
        // Check compliance numerically if min/max exists
        const numVal = parseFloat(declMatch.value);
        if (!isNaN(numVal)) {
          if (buyerMax && numVal > parseFloat(buyerMax)) {
            isCompliant = false;
            discrepancyNote = `+${(numVal - parseFloat(buyerMax)).toFixed(1)} ${param.unit || ''} above max`;
          } else if (buyerMin && numVal < parseFloat(buyerMin)) {
            isCompliant = false;
            discrepancyNote = `${(numVal - parseFloat(buyerMin)).toFixed(1)} ${param.unit || ''} below min`;
          }
        }
      } else {
        source = 'Missing';
        sellerValue = null;
        isCompliant = !param.isRequired;
        if (param.isRequired) {
          discrepancyNote = 'Mandatory specification not declared';
        }
      }

      if (source === 'Missing') {
        statusLabel = param.isRequired ? 'Variance' : 'Missing';
        missingCount++;
      } else if (!isCompliant) {
        statusLabel = 'Variance';
        varianceCount++;
      } else {
        statusLabel = 'Compliant';
        compliantCount++;
      }

      return {
        parameterId: param.id,
        name: param.name,
        unit: param.unit,
        type: param.type,
        buyerTarget,
        buyerMin,
        buyerMax,
        buyerFormattedSpec,
        sellerValue,
        source,
        isCompliant,
        statusLabel,
        discrepancyNote,
      };
    });

    // Compute document state
    let documentState: QualityDocumentState = 'Missing';
    let documentStateLabel = 'Missing Evidence';

    if (labTestRec) {
      const freshness = computeLabFreshness(labTestRec.testDate, labTestRec.validUntil);
      if (labTestRec.status === 'Verified') {
        if (freshness === 'Expired') {
          documentState = 'Required';
          documentStateLabel = 'Lab Report Expired';
        } else {
          documentState = 'Verified';
          documentStateLabel = 'Lab Verified';
        }
      } else if (labTestRec.status === 'Correction Required') {
        documentState = 'Correction Required';
        documentStateLabel = 'Correction Required';
      } else if (labTestRec.status === 'Rejected') {
        documentState = 'Rejected';
        documentStateLabel = 'Lab Rejected';
      } else {
        documentState = 'Received';
        documentStateLabel = 'Lab Report Received (Pending Review)';
      }
    } else {
      if (masterParams.some((p) => p.isRequired)) {
        documentState = 'Required';
        documentStateLabel = 'COA Required';
      } else {
        documentState = 'Missing';
        documentStateLabel = 'No Evidence Attached';
      }
    }

    // Overall summary text
    let overallStatus: BrokerQualityComparisonData['summary']['overallStatus'] = 'Fully Compliant';
    let summaryText = `All ${comparisons.length} parameters match buyer requirement`;

    if (varianceCount > 0) {
      overallStatus = 'Specification Discrepancy';
      summaryText = `${varianceCount} of ${comparisons.length} parameters have specification variances`;
    } else if (documentState === 'Received') {
      overallStatus = 'Pending Verification';
      summaryText = `${compliantCount} parameters compliant — COA report awaiting broker audit`;
    } else if (missingCount > 0) {
      overallStatus = 'Minor Variances';
      summaryText = `${compliantCount} parameters compliant, ${missingCount} parameters optional/undeclared`;
    }

    const labTestData = labTestRec
      ? {
          id: labTestRec.id,
          laboratoryName: labTestRec.laboratoryName,
          laboratoryLocation: labTestRec.laboratoryLocation,
          sampleId: labTestRec.sampleId,
          reportNumber: labTestRec.reportNumber,
          reportDateFormatted: labTestRec.reportDate ? labTestRec.reportDate.toISOString().split('T')[0] : null,
          testDateFormatted: labTestRec.testDate ? labTestRec.testDate.toISOString().split('T')[0] : null,
          validUntilFormatted: labTestRec.validUntil ? labTestRec.validUntil.toISOString().split('T')[0] : null,
          fileUrl: labTestRec.fileUrl,
          hasPhysicalDocument: !!labTestRec.fileUrl,
          status: labTestRec.status,
          freshness: computeLabFreshness(labTestRec.testDate, labTestRec.validUntil),
          verifiedAtFormatted: labTestRec.verifiedAt ? labTestRec.verifiedAt.toISOString().split('T')[0] : null,
          verificationNotes: labTestRec.verificationNotes,
        }
      : null;

    return {
      success: true,
      data: {
        requirement: {
          id: req.id,
          ref: `REQ-${req.id.slice(0, 8).toUpperCase()}`,
          buyerCompanyName: req.buyerCompanyName,
          commodityName: req.commodityName,
          gradeName: req.gradeName,
        },
        availability: {
          id: avail.id,
          lotNumber: avail.lotNumber || `LOT-${avail.id.slice(0, 8).toUpperCase()}`,
          sellerCompanyName: avail.sellerCompanyName,
          commodityName: avail.commodityName,
          gradeName: avail.gradeName,
          quantity: Number(avail.availableQuantity) || 0,
          unitSymbol: avail.unitSymbol || avail.unitName || 'MT',
        },
        documentState,
        documentStateLabel,
        labTest: labTestData,
        summary: {
          totalParameters: comparisons.length,
          compliantParameters: compliantCount,
          varianceCount,
          missingCount,
          overallStatus,
          summaryText,
        },
        parameters: comparisons,
      },
    };
  } catch (error: any) {
    console.error('getBrokerQualityComparisonAction error:', error);
    return {
      success: false,
      error: error.message || 'Failed to generate quality comparison report.',
    };
  }
}
