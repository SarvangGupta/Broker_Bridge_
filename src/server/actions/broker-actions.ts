'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { 
  companies, 
  masterCommodities, 
  masterCategories, 
  masterIndustries, 
  quotations,
  requirements,
  availabilities
} from "@/src/server/db/schema"
import { eq, desc } from "drizzle-orm"

export async function getBrokerAssignmentsAction() {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return { success: false, error: 'Unauthorized' }
    }

    // 1. Fetch assigned requirements
    const reqs = await db
      .select({
        id: requirements.id,
        createdAt: requirements.createdAt,
        quantity: requirements.quantity,
        targetPrice: requirements.targetPrice,
        status: requirements.status,
        companyName: companies.name,
        commodityName: masterCommodities.name,
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
      })
      .from(requirements)
      .where(eq(requirements.brokerId, user.id))
      .leftJoin(companies, eq(companies.id, requirements.companyId))
      .leftJoin(masterCommodities, eq(masterCommodities.id, requirements.commodityId))
      .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
      .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
      .orderBy(desc(requirements.createdAt))

    // 2. Fetch assigned availabilities
    const avails = await db
      .select({
        id: availabilities.id,
        createdAt: availabilities.createdAt,
        quantity: availabilities.quantity,
        targetPrice: availabilities.price,
        status: availabilities.status,
        companyName: companies.name,
        commodityName: masterCommodities.name,
        categoryName: masterCategories.name,
        industryName: masterIndustries.name,
      })
      .from(availabilities)
      .where(eq(availabilities.brokerId, user.id))
      .leftJoin(companies, eq(companies.id, availabilities.companyId))
      .leftJoin(masterCommodities, eq(masterCommodities.id, availabilities.commodityId))
      .leftJoin(masterCategories, eq(masterCategories.id, masterCommodities.categoryId))
      .leftJoin(masterIndustries, eq(masterIndustries.id, masterCategories.industryId))
      .orderBy(desc(availabilities.createdAt))

    // 3. Fetch broker's quotations to ensure live lifecycle status is synchronized
    const brokerQuotes = await db
      .select({
        requirementId: quotations.requirementId,
        sellerAvailabilityId: quotations.sellerAvailabilityId,
        status: quotations.status,
      })
      .from(quotations)
      .where(eq(quotations.brokerId, user.id))

    // 4. Map requirements with live transaction status
    const mappedReqs = reqs.map(r => {
      let finalStatus = r.status || 'Open'
      
      // If the requirement is already booked, show 'Accepted (Booked)'
      if (finalStatus === 'Accepted (Booked)') {
        finalStatus = 'Accepted (Booked)'
      } else {
        // Cross reference with quotation status
        const quote = brokerQuotes.find(q => q.requirementId === r.id)
        if (quote) {
          if (quote.status === 'Accepted') {
            finalStatus = 'Accepted (Booked)'
          } else if (quote.status === 'Sent' || quote.status === 'Countered' || quote.status === 'Rejected') {
            finalStatus = quote.status
          }
        }
      }

      return {
        ...r,
        status: finalStatus,
        type: 'Buyer Requirement' as const,
      }
    })

    // 5. Map availabilities with live transaction status
    const mappedAvails = avails.map(a => {
      let finalStatus = a.status || 'Open'

      const quote = brokerQuotes.find(q => q.sellerAvailabilityId === a.id)
      if (quote) {
        if (quote.status === 'Accepted') {
          finalStatus = 'Accepted (Booked)'
        } else if (finalStatus === 'Open' && (quote.status === 'Sent' || quote.status === 'Countered')) {
          finalStatus = quote.status
        }
      }

      return {
        ...a,
        status: finalStatus,
        type: 'Seller Availability' as const,
      }
    })

    const combined = [...mappedReqs, ...mappedAvails].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())

    return { success: true, data: combined }
  } catch (error: any) {
    return { success: false, error: error.message || 'Failed to fetch assigned deals' }
  }
}
