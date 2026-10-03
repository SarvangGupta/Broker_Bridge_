'use server';

import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { quotations, deals, availabilities, users, companies, masterCommodities, requirements } from "@/src/server/db/schema";
import { eq, and, or, desc, aliasedTable } from "drizzle-orm";
import { acceptQuotationSchema, rejectQuotationSchema, counterQuotationSchema } from "@/src/types/deal-schema";
import { masterGrades } from "@/src/server/db/schema";
import { verifyBuyerSession } from "@/src/server/utils/buyer-auth";
import { sanitizePayloadForBuyer } from "@/src/server/utils/privacy-scrubber";

export async function acceptQuotationAction(data: unknown) {
  try {
    const parsedData = acceptQuotationSchema.parse(data);
    
    const session = await verifyBuyerSession();
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const companyId = session.data.companyId;

    // Use transaction
    const deal = await db.transaction(async (tx) => {
      // a. Fetch the quotation
      const quotationRecords = await tx.select().from(quotations).where(eq(quotations.id, parsedData.quotation_id));
      if (!quotationRecords.length) throw new Error("Quotation not found");
      const quotation = quotationRecords[0];

      if (quotation.status !== 'Sent' && quotation.status !== 'Revised Sent') {
        throw new Error("Quotation is not in a valid state to accept");
      }

      // Fetch the requirement
      const reqRecords = await tx.select().from(requirements).where(eq(requirements.id, quotation.requirementId));
      if (!reqRecords.length) throw new Error("Requirement not found");
      const requirement = reqRecords[0];

      // Verify that the calling user's company matches the requirement's company (i.e. Buyer)
      if (requirement.companyId !== companyId) {
        throw new Error("Not authorized to accept this quotation");
      }

      // Fetch the seller's availability
      const availabilityRecords = await tx.select().from(availabilities).where(eq(availabilities.id, quotation.sellerAvailabilityId));
      if (!availabilityRecords.length) throw new Error("Availability not found");
      const availability = availabilityRecords[0];

      // b. Calculate Partial Fulfillment Math
      const currentFulfilled = Number(requirement.fulfilledQuantity ?? 0);
      const totalReqQuantity = Number(requirement.quantity);
      if (isNaN(totalReqQuantity) || totalReqQuantity <= 0) {
        throw new Error("Invalid requirement quantity");
      }

      const remainingNeeded = Math.max(0, totalReqQuantity - currentFulfilled);
      if (remainingNeeded <= 0) {
        throw new Error("Requirement has already been fully fulfilled");
      }

      const availQuantity = Number(availability.quantity);
      if (isNaN(availQuantity) || availQuantity <= 0) {
        throw new Error("Invalid availability quantity");
      }

      // Determine agreed quantity for this deal
      const agreedQuantity = Math.min(remainingNeeded, availQuantity);
      const newFulfilledQuantity = currentFulfilled + agreedQuantity;

      if (isNaN(newFulfilledQuantity) || newFulfilledQuantity < 0 || agreedQuantity <= 0) {
        throw new Error("Invalid fulfillment quantity calculation");
      }

      // Determine new status based on fulfillment
      const newStatus = newFulfilledQuantity >= totalReqQuantity 
        ? 'Accepted (Booked)' 
        : 'Partially Fulfilled';

      // c. Update quotation status
      await tx.update(quotations)
        .set({ status: 'Accepted' })
        .where(eq(quotations.id, quotation.id));

      // d. Update requirement fulfilled_quantity and status
      await tx.update(requirements)
        .set({ 
          fulfilledQuantity: newFulfilledQuantity,
          status: newStatus,
        })
        .where(eq(requirements.id, requirement.id));

      // e. Insert into deals
      const dealInsert = await tx.insert(deals).values({
        requirementId: requirement.id,
        quotationId: quotation.id,
        buyerId: requirement.companyId,
        sellerId: availability.companyId,
        brokerId: quotation.brokerId,
        agreedPrice: quotation.offeredPrice,
        agreedQuantity: agreedQuantity,
        status: 'Dispatch Pending',
      }).returning();

      return dealInsert[0];
    });

    return { success: true, data: deal };

  } catch (error: any) {
    return { success: false, error: error.message || "Failed to accept quotation" };
  }
}

export async function rejectQuotationAction(data: unknown) {
  try {
    const parsedData = rejectQuotationSchema.parse(data);
    
    const session = await verifyBuyerSession();
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const companyId = session.data.companyId;

    await db.transaction(async (tx) => {
      const quotationRecords = await tx.select().from(quotations).where(eq(quotations.id, parsedData.quotation_id));
      if (!quotationRecords.length) throw new Error("Quotation not found");
      const quotation = quotationRecords[0];

      const reqRecords = await tx.select().from(requirements).where(eq(requirements.id, quotation.requirementId));
      if (!reqRecords.length) throw new Error("Requirement not found");

      if (reqRecords[0].companyId !== companyId && session.data.user.role !== 'admin') {
        throw new Error("Not authorized to reject this quotation");
      }

      await tx.update(quotations)
        .set({ 
          status: 'Rejected',
          rejectionReason: parsedData.reason
        })
        .where(eq(quotations.id, parsedData.quotation_id));
    });

    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to reject quotation" };
  }
}

export async function counterQuotationAction(data: unknown) {
  try {
    const parsedData = counterQuotationSchema.parse(data);
    
    const session = await verifyBuyerSession();
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    const companyId = session.data.companyId;

    await db.transaction(async (tx) => {
      const quotationRecords = await tx.select().from(quotations).where(eq(quotations.id, parsedData.quotation_id));
      if (!quotationRecords.length) throw new Error("Quotation not found");
      const quotation = quotationRecords[0];

      const reqRecords = await tx.select().from(requirements).where(eq(requirements.id, quotation.requirementId));
      if (!reqRecords.length) throw new Error("Requirement not found");

      if (reqRecords[0].companyId !== companyId && session.data.user.role !== 'admin') {
        throw new Error("Not authorized to counter this quotation");
      }

      await tx.update(quotations)
        .set({ 
          status: 'Countered',
          counterPrice: parsedData.counter_price.toString(),
          counterNotes: parsedData.counter_notes || null
        })
        .where(eq(quotations.id, parsedData.quotation_id));
    });

    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to counter quotation" };
  }
}

/**
 * Fetches deals associated with the authenticated user's company (as Buyer or Seller).
 * HARD PRIVACY RULE: If the caller is a Seller, Buyer private PII is NEVER exposed.
 * If the caller is a Buyer, Seller private details are stripped using sanitizePayloadForBuyer.
 */
export const getDealsByCompanyAction = cache(
  async function getDealsByCompanyAction() {
    try {
      const supabase = await createClient();
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return { success: false, error: "Unauthorized" };

      const userId = user.id;
      const userRecords = await db.select().from(users).where(eq(users.id, userId));
      if (!userRecords.length) return { success: false, error: "User not found" };
      
      const dbUser = userRecords[0];
      const companyId = dbUser.companyId;

      if (!companyId) return { success: false, error: "User is not associated with a company" };

      // Fetch all deals where buyerId or sellerId is companyId
      const buyerCompanyTable = aliasedTable(companies, 'buyerCompany');
      const sellerCompanyTable = aliasedTable(companies, 'sellerCompany');

      const rawCompanyDeals = await db
        .select({
          deal: deals,
          requirement: requirements,
          commodity: masterCommodities,
          grade: masterGrades,
          buyerCompany: {
            id: buyerCompanyTable.id,
            name: buyerCompanyTable.name,
            isVerified: buyerCompanyTable.isVerified,
            trustScore: buyerCompanyTable.trustScore,
          },
          sellerCompany: {
            id: sellerCompanyTable.id,
            name: sellerCompanyTable.name,
            isVerified: sellerCompanyTable.isVerified,
            trustScore: sellerCompanyTable.trustScore,
          }
        })
        .from(deals)
        .innerJoin(requirements, eq(deals.requirementId, requirements.id))
        .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
        .innerJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
        .innerJoin(buyerCompanyTable, eq(deals.buyerId, buyerCompanyTable.id))
        .innerJoin(sellerCompanyTable, eq(deals.sellerId, sellerCompanyTable.id))
        .where(or(eq(deals.buyerId, companyId), eq(deals.sellerId, companyId)))
        .orderBy(desc(deals.createdAt));

      // Apply strict privacy transformation for Seller and Buyer views
      const companyDeals = rawCompanyDeals.map((row) => {
        const isSellerViewing = row.deal.sellerId === companyId && row.deal.buyerId !== companyId && dbUser.role !== 'admin';
        const isBuyerViewing = row.deal.buyerId === companyId && row.deal.sellerId !== companyId && dbUser.role !== 'admin';

        let processed = {
          ...row,
          buyerCompany: {
            id: row.buyerCompany.id,
            name: isSellerViewing
              ? `Verified Buyer #B-${row.deal.buyerId.slice(0, 4).toUpperCase()}`
              : row.buyerCompany.name,
            isVerified: row.buyerCompany.isVerified,
            trustScore: row.buyerCompany.trustScore,
          },
          sellerCompany: {
            id: row.sellerCompany.id,
            name: row.sellerCompany.name,
            isVerified: row.sellerCompany.isVerified,
            trustScore: row.sellerCompany.trustScore,
          }
        };

        if (isBuyerViewing) {
          processed = sanitizePayloadForBuyer(processed);
        }

        return processed;
      });

      return { success: true, data: companyDeals };
    } catch (error: any) {
      return { success: false, error: error.message || "Failed to fetch deals" };
    }
  }
);
