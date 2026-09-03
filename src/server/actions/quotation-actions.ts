'use server';

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { quotations } from "@/src/server/db/schema";
import { eq, asc, desc } from "drizzle-orm";
import { quotationSchema } from "@/src/types/quotation-schema";
import { 
  users, 
  masterCommodities, 
  masterGrades, 
  availabilities, 
  companies, 
  requirements 
} from "@/src/server/db/schema";
import { sendQuotationWhatsAppNotification } from "@/src/server/services/whatsapp-service";
import { logDecisionGateAuditEventAction } from "@/src/server/actions/audit-actions";

export async function createQuotationAction(data: unknown) {
  try {
    const parsedData = quotationSchema.parse(data);
    
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { 
        success: false, 
        error: "AI autonomous action prohibited. Only an authorized Broker can initiate commercial proposals." 
      };
    }

    const inserted = await db.insert(quotations).values({
      requirementId: parsedData.requirement_id,
      brokerId: user.id,
      sellerAvailabilityId: parsedData.seller_availability_id,
      offeredPrice: parsedData.offered_price.toString(), // numeric column
      validUntil: parsedData.valid_until,
      status: 'Sent',
    }).returning();

    // Log Non-Autonomous Broker Provenance Audit
    await logDecisionGateAuditEventAction({
      action: "BROKER_REQUEST_INITIATED",
      actorId: user.id,
      actorRole: dbUser.role || "broker",
      entity: "quotations",
      entityId: inserted[0].id,
      metadata: {
        aiRecommended: true,
        brokerOverride: false,
        humanReviewed: true,
        offeredPrice: parsedData.offered_price,
      },
    });

    await sendQuotationAction(inserted[0].id);

    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to create quotation" };
  }
}

export async function getQuotationsByRequirementAction(requirementId: string) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser) return { success: false, error: "User profile not found" };

    const reqRecord = await db.query.requirements.findFirst({
      where: eq(requirements.id, requirementId),
    });
    if (!reqRecord) return { success: false, error: "Requirement not found" };

    const isAuthorized = 
      dbUser.role === 'admin' || 
      reqRecord.brokerId === user.id || 
      (dbUser.companyId && reqRecord.companyId === dbUser.companyId);

    if (!isAuthorized) {
      return { success: false, error: "Unauthorized: Access denied to requirement quotations" };
    }

    const results = await db
      .select()
      .from(quotations)
      .where(eq(quotations.requirementId, requirementId));

    return { success: true, data: results };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to fetch quotations" };
  }
}

export async function getBrokerQuotationsAction() {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const quotes = await db
      .select()
      .from(quotations)
      .where(eq(quotations.brokerId, user.id))
      .orderBy(desc(quotations.createdAt));

    // Fetch buyer and seller details for each quotation
    const mappedQuotes = await Promise.all(
      quotes.map(async (quote) => {
        // Buyer Info
        const buyerData = await db
          .select({ name: users.name, mobile: users.mobile })
          .from(requirements)
          .innerJoin(companies, eq(requirements.companyId, companies.id))
          .innerJoin(users, eq(users.companyId, companies.id))
          .where(eq(requirements.id, quote.requirementId))
          .limit(1);

        // Seller Info
        const sellerData = await db
          .select({ name: users.name, mobile: users.mobile })
          .from(availabilities)
          .innerJoin(companies, eq(availabilities.companyId, companies.id))
          .innerJoin(users, eq(users.companyId, companies.id))
          .where(eq(availabilities.id, quote.sellerAvailabilityId))
          .limit(1);

        return {
          ...quote,
          buyerName: buyerData[0]?.name || '',
          buyerMobile: buyerData[0]?.mobile || '',
          sellerName: sellerData[0]?.name || '',
          sellerMobile: sellerData[0]?.mobile || '',
        };
      })
    );

    return { success: true, data: mappedQuotes };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to fetch quotations" };
  }
}

export async function reviseQuotationAction(data: { quotation_id: string; revised_price: number; valid_until: string }) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const existingQuote = await db.query.quotations.findFirst({
      where: eq(quotations.id, data.quotation_id),
    });
    if (!existingQuote) return { success: false, error: "Quotation not found" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser || (existingQuote.brokerId !== user.id && dbUser.role !== 'admin')) {
      return { success: false, error: "Unauthorized: You can only revise your own quotations" };
    }

    const updated = await db
      .update(quotations)
      .set({
        offeredPrice: data.revised_price.toString(),
        validUntil: new Date(data.valid_until),
        status: 'Revised Sent',
        counterPrice: null,
        counterNotes: null,
        rejectionReason: null,
      })
      .where(eq(quotations.id, data.quotation_id))
      .returning();

    if (!updated || updated.length === 0) {
      return { success: false, error: "Quotation not found" };
    }

    // Trigger WhatsApp notification for the revised quote
    await sendQuotationAction(data.quotation_id);

    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to revise quotation" };
  }
}

export async function sendQuotationAction(quotationId: string) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser) return { success: false, error: "User not found" };

    const existingQuote = await db.query.quotations.findFirst({
      where: eq(quotations.id, quotationId),
    });
    if (!existingQuote) return { success: false, error: "Quotation not found" };

    if (existingQuote.brokerId !== user.id && dbUser.role !== 'admin') {
      return { success: false, error: "Unauthorized: Only the assigned broker or admin can dispatch this quotation" };
    }

    const result = await db
      .select({
        price: quotations.offeredPrice,
        buyerCompanyId: requirements.companyId,
        commodityName: masterCommodities.name,
      })
      .from(quotations)
      .where(eq(quotations.id, quotationId))
      .leftJoin(requirements, eq(requirements.id, quotations.requirementId))
      .leftJoin(masterCommodities, eq(masterCommodities.id, requirements.commodityId))
      .limit(1);

    if (!result || result.length === 0) return { success: false, error: "Quotation details not found" };
    
    const quoteData = result[0];

    if (!quoteData.buyerCompanyId) {
      return { success: false, error: "Requirement missing company association" };
    }

    const userResult = await db
      .select({
        mobile: users.mobile,
        name: users.name,
      })
      .from(users)
      .where(eq(users.companyId, quoteData.buyerCompanyId))
      .orderBy(asc(users.createdAt))
      .limit(1);

    if (!userResult || userResult.length === 0 || !userResult[0].mobile) {
      return { success: false, error: "Buyer has no valid mobile number" };
    }

    const buyerUser = userResult[0];

    const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';
    const pdfUrl = `${appUrl}/api/quotations/${quotationId}/pdf`;

    const dispatchResult = await sendQuotationWhatsAppNotification({
      recipientPhone: buyerUser.mobile!,
      quotationId: quotationId,
      buyerName: buyerUser.name || 'Unknown',
      commodityName: quoteData.commodityName || 'Unknown',
      price: parseFloat(quoteData.price),
      pdfUrl: pdfUrl,
    });

    if (!dispatchResult.success) {
       return { success: false, error: dispatchResult.error };
    }
    
    return { success: true, data: dispatchResult };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to dispatch quotation" };
  }
}

export async function getBuyerQuotationsAction() {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const userId = user.id;
    const userRecords = await db.select().from(users).where(eq(users.id, userId));
    if (!userRecords.length || !userRecords[0].companyId) {
      return { success: false, error: "User is not associated with a company" };
    }
    const companyId = userRecords[0].companyId;

    // Fetch quotations for requirements belonging to this company
    const results = await db
      .select({
        quotation: quotations,
        requirement: requirements,
        commodity: masterCommodities,
        grade: masterGrades,
        sellerCompany: companies,
      })
      .from(quotations)
      .innerJoin(requirements, eq(quotations.requirementId, requirements.id))
      .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .innerJoin(masterGrades, eq(requirements.gradeId, masterGrades.id))
      .innerJoin(availabilities, eq(quotations.sellerAvailabilityId, availabilities.id))
      .innerJoin(companies, eq(availabilities.companyId, companies.id))
      .where(eq(requirements.companyId, companyId))
      .orderBy(desc(quotations.createdAt));

    return { success: true, data: results };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to fetch quotations" };
  }
}
