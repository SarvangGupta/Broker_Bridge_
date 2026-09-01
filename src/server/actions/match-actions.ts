'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { availabilities, requirements, users } from "@/src/server/db/schema"
import { eq, and, gt, or } from "drizzle-orm"
import { calculateMatchScore } from "@/src/server/utils/match-engine"

export async function runAiMatchAction(requirementId: string) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return { success: false, error: 'Unauthorized' }
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    })
    if (!dbUser) {
      return { success: false, error: 'User profile not found' }
    }

    // Step 1: Fetch the specific Requirement by ID
    const reqResults = await db
      .select()
      .from(requirements)
      .where(eq(requirements.id, requirementId))
      
    const requirement = reqResults[0];

    if (!requirement) {
      return { success: false, error: 'Requirement not found.' }
    }

    // Authorization check: User must be admin, assigned broker, open broker on global requirement, or the buyer company owner
    const isAuthorized = 
      dbUser.role === 'admin' ||
      requirement.brokerId === user.id ||
      (dbUser.role === 'broker' && requirement.visibility === 'global') ||
      (dbUser.companyId && requirement.companyId === dbUser.companyId);

    if (!isAuthorized) {
      return { success: false, error: 'Unauthorized: Access denied to requirement matches' }
    }

    // Dynamic Required Quantity: Total Quantity minus Fulfilled Quantity
    const fulfilledQty = Number(requirement.fulfilledQuantity ?? 0);
    const requiredQty = Math.max(0, Number(requirement.quantity) - fulfilledQty);

    // Step 2: Fetch ALL active Availabilities from the database respecting the Privacy Consent Layer
    const now = new Date();
    
    const availableList = await db
      .select()
      .from(availabilities)
      .where(
        and(
          eq(availabilities.status, 'Active'),
          gt(availabilities.validUntil, now),
          or(
            eq(availabilities.visibility, 'global'),
            eq(availabilities.brokerId, user.id)
          )
        )
      )

    // Step 3: Map over the fetched availabilities, passing each into `calculateMatchScore`.
    const matches = availableList.map(avail => {
      // Cast the db types to match the utility types if necessary
      // Note: price from pg numeric comes as string, so Number() in utility handles it.
      return calculateMatchScore(
        {
          id: requirement.id,
          companyId: requirement.companyId,
          commodityId: requirement.commodityId,
          gradeId: requirement.gradeId,
          quantity: requiredQty,
          unitId: requirement.unitId,
          targetPrice: Number(requirement.targetPrice),
          deliveryTermsId: requirement.deliveryTermsId,
          targetDate: requirement.targetDate,
          status: requirement.status,
        },
        {
          id: avail.id,
          companyId: avail.companyId,
          commodityId: avail.commodityId,
          gradeId: avail.gradeId,
          quantity: Number(avail.quantity),
          unitId: avail.unitId,
          price: Number(avail.price),
          stateId: avail.stateId,
          districtId: avail.districtId,
          validUntil: avail.validUntil,
          status: avail.status,
        }
      )
    })

    // Step 4: Filter out any matches with a score below 60 or nulls.
    const validMatches = matches.filter(match => match !== null && match.totalScore >= 60)

    // Step 5: Sort the remaining matches by `totalScore` descending.
    // @ts-ignore - TS knows match is not null because of filter
    validMatches.sort((a, b) => b.totalScore - a.totalScore)

    // Step 6: Return the ranked array.
    return { success: true, data: validMatches }

  } catch (error: any) {
    console.error('runAiMatchAction error:', error);
    return { success: false, error: error.message || 'An error occurred while running the AI Match Engine.' }
  }
}
