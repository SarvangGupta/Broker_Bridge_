'use server';

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { deals, payments, disputes, users, requirements } from "@/src/server/db/schema";
import { eq, sql } from "drizzle-orm";
import { paymentSchema, fileDisputeSchema, resolveDisputeSchema } from "@/src/types/transaction-schema";

export async function confirmPaymentAction(data: unknown) {
  try {
    const parsedData = paymentSchema.parse(data);
    
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser) return { success: false, error: "User profile not found" };

    const payment = await db.transaction(async (tx) => {
      const dealRecords = await tx.select().from(deals).where(eq(deals.id, parsedData.deal_id));
      if (!dealRecords.length) throw new Error("Deal not found");
      const deal = dealRecords[0];

      const isPartyToDeal = 
        (dbUser.companyId && (deal.buyerId === dbUser.companyId || deal.sellerId === dbUser.companyId)) ||
        deal.brokerId === user.id ||
        dbUser.role === 'admin';

      if (!isPartyToDeal) {
        throw new Error("Unauthorized to confirm payment for this deal");
      }

      const insertResult = await tx.insert(payments).values({
        dealId: parsedData.deal_id,
        amount: parsedData.amount.toString(),
        referenceNumber: parsedData.reference_number,
        status: 'Confirmed'
      }).returning();

      await tx.update(deals)
        .set({ status: 'Closed', closedAt: new Date() })
        .where(eq(deals.id, parsedData.deal_id));

      return insertResult[0];
    });

    return { success: true, data: payment };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to confirm payment" };
  }
}

export async function fileDisputeAction(data: unknown) {
  try {
    const parsedData = fileDisputeSchema.parse(data);
    
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser) return { success: false, error: "User profile not found" };

    const dispute = await db.transaction(async (tx) => {
      const dealRecords = await tx.select().from(deals).where(eq(deals.id, parsedData.deal_id));
      if (!dealRecords.length) throw new Error("Deal not found");
      const deal = dealRecords[0];

      const isPartyToDeal = 
        (dbUser.companyId && (deal.buyerId === dbUser.companyId || deal.sellerId === dbUser.companyId)) ||
        deal.brokerId === user.id ||
        dbUser.role === 'admin';

      if (!isPartyToDeal) {
        throw new Error("Unauthorized to file dispute on this deal");
      }

      const insertResult = await tx.insert(disputes).values({
        dealId: parsedData.deal_id,
        filedBy: user.id,
        reason: parsedData.reason,
        description: parsedData.description || null,
        status: 'Open'
      }).returning();

      await tx.update(deals)
        .set({ status: 'Disputed' })
        .where(eq(deals.id, parsedData.deal_id));

      return insertResult[0];
    });

    return { success: true, data: dispute };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to file dispute" };
  }
}

export async function resolveDisputeAction(data: unknown) {
  try {
    const parsedData = resolveDisputeSchema.parse(data);
    
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    // Verify Tier 0 Admin
    const userRecords = await db.select().from(users).where(eq(users.id, user.id));
    if (!userRecords.length || userRecords[0].role !== 'admin') {
      return { success: false, error: "Unauthorized: Admin access required" };
    }

    const resolvedDispute = await db.transaction(async (tx) => {
      const disputeRecords = await tx.select().from(disputes).where(eq(disputes.id, parsedData.dispute_id));
      if (!disputeRecords.length) throw new Error("Dispute not found");

      const updateResult = await tx.update(disputes)
        .set({ 
          status: 'Resolved',
          resolutionNotes: parsedData.resolution_notes,
          resolvedAt: new Date()
        })
        .where(eq(disputes.id, parsedData.dispute_id))
        .returning();

      await tx.update(deals)
        .set({ 
          status: parsedData.final_deal_status,
          ...(parsedData.final_deal_status === 'Closed' ? { closedAt: new Date() } : {})
        })
        .where(eq(deals.id, parsedData.deal_id));

      return updateResult[0];
    });

    return { success: true, data: resolvedDispute };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to resolve dispute" };
  }
}

export async function getOpenDisputesAction() {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    // Verify Tier 0 Admin
    const userRecords = await db.select().from(users).where(eq(users.id, user.id));
    if (!userRecords.length || userRecords[0].role !== 'admin') {
      return { success: false, error: "Unauthorized: Admin access required" };
    }

    const { companies, masterCommodities } = await import('@/src/server/db/schema');

    const openDisputes = await db
      .select({
        dispute: disputes,
        deal: deals,
        buyerCompany: {
          id: companies.id,
          name: companies.name,
        },
        sellerCompany: {
          name: sql<string>`seller_companies.name`,
        },
        commodity: masterCommodities,
        filedByUser: {
          name: users.name,
          email: users.email
        }
      })
      .from(disputes)
      .innerJoin(deals, eq(disputes.dealId, deals.id))
      .innerJoin(requirements, eq(deals.requirementId, requirements.id))
      .innerJoin(masterCommodities, eq(requirements.commodityId, masterCommodities.id))
      .innerJoin(companies, eq(deals.buyerId, companies.id))
      .innerJoin(sql`companies as seller_companies`, sql`deals.seller_id = seller_companies.id`)
      .innerJoin(users, eq(disputes.filedBy, users.id))
      .where(eq(disputes.status, 'Open'));

    return { success: true, data: openDisputes };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to fetch open disputes" };
  }
}
