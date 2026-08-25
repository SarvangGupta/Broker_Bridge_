'use server'

import { runAiMatchAction } from "./match-actions"
import { db } from "@/src/server/db"
import { 
  availabilities, 
  companies, 
  masterCommodities, 
  masterCategories, 
  masterIndustries 
} from "@/src/server/db/schema"
import { eq, inArray } from "drizzle-orm"
import { MatchResult } from "@/src/server/utils/match-engine"

export type EnrichedMatchResult = MatchResult & {
  companyName: string;
  isVerified?: boolean;
  trustScore?: number;
  commodityName?: string | null;
  categoryName?: string | null;
  industryName?: string | null;
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

    // 2. Fetch the company names, trust credentials, and sector hierarchy for these availabilities
    const availabilityDetails = await db
      .select({
         id: availabilities.id,
         companyName: companies.name,
         isVerified: companies.isVerified,
         trustScore: companies.trustScore,
         commodityName: masterCommodities.name,
         categoryName: masterCategories.name,
         industryName: masterIndustries.name,
      })
      .from(availabilities)
      .leftJoin(companies, eq(availabilities.companyId, companies.id))
      .leftJoin(masterCommodities, eq(availabilities.commodityId, masterCommodities.id))
      .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
      .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
      .where(inArray(availabilities.id, availabilityIds));

    // 3. Map the company names, trust credentials, and sector hierarchy back into the results
    const enrichedMatches: EnrichedMatchResult[] = matchData.map(match => {
       const detail = availabilityDetails.find(d => d.id === match.availabilityId);
       return {
         ...match,
         companyName: detail?.companyName || 'Unknown Company',
         isVerified: detail?.isVerified ?? false,
         trustScore: detail?.trustScore ?? 95,
         commodityName: detail?.commodityName || null,
         categoryName: detail?.categoryName || null,
         industryName: detail?.industryName || null,
       }
    });

    return { success: true, data: enrichedMatches };
  } catch (error: any) {
    console.error('runAiMatchWithDetailsAction error:', error);
    return { success: false, error: error.message || 'Failed to fetch enriched match details.' }
  }
}
