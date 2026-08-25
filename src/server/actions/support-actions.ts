"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { supportTickets, users, companies } from "@/src/server/db/schema";
import { eq, desc } from "drizzle-orm";
import { supportTicketSchema } from "@/src/types/support-schema";

export async function createSupportTicketAction(data: unknown) {
  try {
    const parsedData = supportTicketSchema.parse(data);

    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return { success: false, error: "Unauthorized. Please sign in." };
    }

    // Lookup user role from users table or metadata
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    const userRole = dbUser?.role || (user.user_metadata?.role as string) || "Trader";

    const inserted = await db.insert(supportTickets).values({
      userId: user.id,
      role: userRole,
      issueType: parsedData.issue_type,
      description: parsedData.description,
      status: "Open",
    }).returning();

    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to submit support ticket" };
  }
}

export async function getOpenTicketsAction() {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return { success: false, error: "Unauthorized" };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser || dbUser.role !== 'admin') {
      return { success: false, error: "Unauthorized: Admin access required" };
    }

    const tickets = await db
      .select({
        id: supportTickets.id,
        userId: supportTickets.userId,
        role: supportTickets.role,
        issueType: supportTickets.issueType,
        description: supportTickets.description,
        status: supportTickets.status,
        createdAt: supportTickets.createdAt,
        resolvedAt: supportTickets.resolvedAt,
        userName: users.name,
        userEmail: users.email,
        userMobile: users.mobile,
        companyName: companies.name,
      })
      .from(supportTickets)
      .leftJoin(users, eq(supportTickets.userId, users.id))
      .leftJoin(companies, eq(users.companyId, companies.id))
      .orderBy(desc(supportTickets.createdAt));

    return { success: true, data: tickets };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to fetch support tickets" };
  }
}

export async function resolveTicketAction(ticketId: string) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return { success: false, error: "Unauthorized" };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });
    if (!dbUser || dbUser.role !== 'admin') {
      return { success: false, error: "Unauthorized: Admin access required" };
    }

    const updated = await db
      .update(supportTickets)
      .set({
        status: "Resolved",
        resolvedAt: new Date(),
      })
      .where(eq(supportTickets.id, ticketId))
      .returning();

    if (updated.length === 0) {
      return { success: false, error: "Ticket not found" };
    }

    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to resolve support ticket" };
  }
}
