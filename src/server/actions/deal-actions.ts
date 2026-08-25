'use server';

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { quotations, deals, availabilities, users, companies, masterCommodities, requirements } from "@/src/server/db/schema";
import { eq, and, or, sql, desc, aliasedTable } from "drizzle-orm";
import { acceptQuotationSchema, rejectQuotationSchema, counterQuotationSchema } from "@/src/types/deal-schema";
import { masterGrades } from "@/src/server/db/schema";

export async function acceptQuotationAction(data: unknown) {
  try {
    const parsedData = acceptQuotationSchema.parse(data);
    
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return { success: false, error: "Unauthorized" };

    const userId = user.id;

    // Fetch user details to verify role and get company ID
    const userRecords = await db.select().from(users).where(eq(users.id, userId));
    if (!userRecords.length) return { success: false, error: "User not found" };
    const dbUser = userRecords[0];
    const companyId = dbUser.companyId;

    if (!companyId) return { success: false, error: "User is not associated with a company" };

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
    
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser || !dbUser.companyId) return { success: false, error: "Company profile not found" };

    await db.transaction(async (tx) => {
      const quotationRecords = await tx.select().from(quotations).where(eq(quotations.id, parsedData.quotation_id));
      if (!quotationRecords.length) throw new Error("Quotation not found");
      const quotation = quotationRecords[0];

      const reqRecords = await tx.select().from(requirements).where(eq(requirements.id, quotation.requirementId));
      if (!reqRecords.length) throw new Error("Requirement not found");

      if (reqRecords[0].companyId !== dbUser.companyId && dbUser.role !== 'admin') {
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
    
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser || !dbUser.companyId) return { success: false, error: "Company profile not found" };

    await db.transaction(async (tx) => {
      const quotationRecords = await tx.select().from(quotations).where(eq(quotations.id, parsedData.quotation_id));
      if (!quotationRecords.length) throw new Error("Quotation not found");
      const quotation = quotationRecords[0];

      const reqRecords = await tx.select().from(requirements).where(eq(requirements.id, quotation.requirementId));
      if (!reqRecords.length) throw new Error("Requirement not found");

      if (reqRecords[0].companyId !== dbUser.companyId && dbUser.role !== 'admin') {
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

export async function getDealsByCompanyAction() {
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

    const companyDeals = await db
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

    return { success: true, data: companyDeals };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to fetch deals" };
  }
}
