'use server'

import { runAiMatchAction } from "./match-actions"
import { db } from "@/src/server/db"
import { 
  availabilities, 
  companies, 
  masterCommodities, 
  masterCategories, 
  masterIndustries,
  labTests,
} from "@/src/server/db/schema"
import { eq, inArray } from "drizzle-orm"
import { MatchResult } from "@/src/server/utils/match-engine"
import { computeLabFreshness } from "@/src/types/lab-schema"

export type EnrichedMatchResult = MatchResult & {
  companyName: string;
  isVerified?: boolean;
  trustScore?: number;
  commodityName?: string | null;
  categoryName?: string | null;
  industryName?: string | null;
  labTestId?: string | null;
  qualityStatus?: string;
  isQualityVerified?: boolean;
  labTestValidUntil?: Date | null;
};

export async function runAiMatchWithDetailsAction(requirementId: string) {
  try {
    // 1. Get the raw match results
    const result = await runAiMatchAction(requirementId);
    
    if (!result.success || !result.data || result.data.length === 0) {
      return result;
    }

    const matchData = result.data as MatchResult[];
    const availabilityIds = matchData.map(m => m.availabilityId);

    // 2. Fetch the company names, trust credentials, sector hierarchy, and lab tests for these availabilities
    const availabilityDetails = await db
      .select({
         id: availabilities.id,
         companyName: companies.name,
         isVerified: companies.isVerified,
         trustScore: companies.trustScore,
         commodityName: masterCommodities.name,
         categoryName: masterCategories.name,
         industryName: masterIndustries.name,
         labTestId: labTests.id,
         labTestStatus: labTests.status,
         labTestValidUntil: labTests.validUntil,
         labTestTestDate: labTests.testDate,
      })
      .from(availabilities)
      .leftJoin(companies, eq(availabilities.companyId, companies.id))
      .leftJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
      .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
      .leftJoin(labTests, eq(availabilities.id, labTests.availabilityId))
      .where(inArray(availabilities.id, availabilityIds));

    // 3. Map the company names, trust credentials, and quality verification status back into results
    const enrichedMatches: EnrichedMatchResult[] = matchData.map(match => {
       const detail = availabilityDetails.find(d => d.id === match.availabilityId);
       
       // Calculate mathematical freshness and effective quality status
       let effectiveQualityStatus = detail?.labTestStatus || 'Seller Declared';
       if (detail?.labTestTestDate) {
         const freshness = computeLabFreshness(detail.labTestTestDate, detail.labTestValidUntil);
         if (freshness === 'Expired') {
           effectiveQualityStatus = 'Expired';
         }
       } else if (detail?.labTestValidUntil && new Date(detail.labTestValidUntil).getTime() < Date.now()) {
         effectiveQualityStatus = 'Expired';
       }

       const isQualityVerified = effectiveQualityStatus === 'Verified';

       return {
         ...match,
         companyName: detail?.companyName || 'Unknown Company',
         isVerified: detail?.isVerified ?? false,
         trustScore: detail?.trustScore ?? 95,
         commodityName: detail?.commodityName || null,
         categoryName: detail?.categoryName || null,
         industryName: detail?.industryName || null,
         labTestId: detail?.labTestId || null,
         qualityStatus: effectiveQualityStatus,
         isQualityVerified,
         labTestValidUntil: detail?.labTestValidUntil || null,
       }
    });

    return { success: true, data: enrichedMatches };
  } catch (error: any) {
    console.error('runAiMatchWithDetailsAction error:', error);
    return { success: false, error: error.message || 'Failed to fetch enriched match details.' }
  }
}
