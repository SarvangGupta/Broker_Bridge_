"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { 
  users, 
  companies, 
  availabilities, 
  quotations,
  requirements,
  crmContacts,
  crmActivities,
  crmTasks
} from "@/src/server/db/schema";
import { eq, and, desc } from "drizzle-orm";
import { activitySchema, taskSchema } from "@/src/types/crm-schema";

export async function getCrmContactsAction() {
  try {
    const supabase = await createClient();

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const [dbUser] = await db
      .select({ id: users.id, role: users.role })
      .from(users)
      .where(eq(users.id, user.id))
      .limit(1);

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { success: false, error: "Forbidden: Broker role required" };
    }

    const brokerId = user.id;

    // Contact map to de-duplicate by ID
    const contactMap = new Map<string, {
      id: string;
      companyName: string;
      userName: string;
      role: string;
      mobile: string;
      label: string;
    }>();

    const isExcludedRole = (role?: string | null) => {
      if (!role) return false;
      const r = role.toLowerCase();
      return r === 'admin' || r === 'broker' || r === 'superadmin';
    };

    const normalizeRole = (role?: string | null, fallbackRole: string = 'Client') => {
      if (!role) return fallbackRole;
      const r = role.toLowerCase();
      if (r === 'buyer') return 'Buyer';
      if (r === 'seller') return 'Seller';
      return fallbackRole;
    };

    // 1. Primary: Fetch from crm_contacts directly assigned to this broker
    try {
      const crmList = await db
        .select({
          contactId: crmContacts.id,
          userId: users.id,
          userName: users.name,
          userRole: users.role,
          userMobile: users.mobile,
          companyId: companies.id,
          companyName: companies.name,
        })
        .from(crmContacts)
        .leftJoin(users, eq(crmContacts.userId, users.id))
        .leftJoin(companies, eq(crmContacts.companyId, companies.id))
        .where(eq(crmContacts.brokerId, brokerId));

      for (const row of crmList) {
        if (isExcludedRole(row.userRole)) continue;

        const compName = row.companyName || "Independent Client";
        const usrName = row.userName || (row.userMobile ? `Contact (${row.userMobile})` : "Representative");
        const role = normalizeRole(row.userRole, "Client");
        const id = row.contactId;

        contactMap.set(id, {
          id,
          companyName: compName,
          userName: usrName,
          role,
          mobile: row.userMobile || "",
          label: `${compName} — ${usrName} (${role})`,
        });
      }
    } catch (e) {
      console.warn("CRM: Failed to query crm_contacts:", e);
    }

    // 2. Fallback/Union: Fetch Buyers from Requirements assigned to this broker
    try {
      const reqBuyers = await db
        .select({
          requirementId: requirements.id,
          companyId: companies.id,
          companyName: companies.name,
          userId: users.id,
          userName: users.name,
          userRole: users.role,
          userMobile: users.mobile,
        })
        .from(requirements)
        .innerJoin(companies, eq(requirements.companyId, companies.id))
        .leftJoin(users, eq(users.companyId, companies.id))
        .where(eq(requirements.brokerId, brokerId));

      for (const r of reqBuyers) {
        if (isExcludedRole(r.userRole)) continue;

        const compName = r.companyName || "Buyer Enterprise";
        const usrName = r.userName || (r.userMobile ? `Contact (${r.userMobile})` : "Procurement Desk");
        const role = "Buyer";
        const id = r.companyId || r.userId || r.requirementId;

        if (!contactMap.has(id)) {
          contactMap.set(id, {
            id,
            companyName: compName,
            userName: usrName,
            role,
            mobile: r.userMobile || "",
            label: `${compName} — ${usrName} (${role})`,
          });
        }
      }
    } catch (e) {
      console.warn("CRM: Failed to query requirement buyers:", e);
    }

    // 3. Fallback/Union: Fetch Sellers from Availabilities assigned to this broker
    try {
      const availSellers = await db
        .select({
          availabilityId: availabilities.id,
          companyId: companies.id,
          companyName: companies.name,
          userId: users.id,
          userName: users.name,
          userRole: users.role,
          userMobile: users.mobile,
        })
        .from(availabilities)
        .innerJoin(companies, eq(availabilities.companyId, companies.id))
        .leftJoin(users, eq(users.companyId, companies.id))
        .where(eq(availabilities.brokerId, brokerId));

      for (const a of availSellers) {
        if (isExcludedRole(a.userRole)) continue;

        const compName = a.companyName || "Supplier Enterprise";
        const usrName = a.userName || (a.userMobile ? `Contact (${a.userMobile})` : "Sales Desk");
        const role = "Seller";
        const id = a.companyId || a.userId || a.availabilityId;

        if (!contactMap.has(id)) {
          contactMap.set(id, {
            id,
            companyName: compName,
            userName: usrName,
            role,
            mobile: a.userMobile || "",
            label: `${compName} — ${usrName} (${role})`,
          });
        }
      }
    } catch (e) {
      console.warn("CRM: Failed to query availability sellers:", e);
    }

    // 4. Fallback/Union: Fetch Clients from Quotations/Deals created by this broker
    try {
      const quoteDeals = await db
        .select({
          quoteId: quotations.id,
          reqCompanyId: requirements.companyId,
          reqCompanyName: companies.name,
        })
        .from(quotations)
        .where(eq(quotations.brokerId, brokerId))
        .leftJoin(requirements, eq(quotations.requirementId, requirements.id))
        .leftJoin(companies, eq(requirements.companyId, companies.id));

      for (const q of quoteDeals) {
        if (q.reqCompanyId && !contactMap.has(q.reqCompanyId)) {
          const compName = q.reqCompanyName || "Buyer Client";
          contactMap.set(q.reqCompanyId, {
            id: q.reqCompanyId,
            companyName: compName,
            userName: "Procurement Desk",
            role: "Buyer",
            mobile: "",
            label: `${compName} — Procurement Desk (Buyer)`,
          });
        }
      }
    } catch (e) {
      console.warn("CRM: Failed to query quotation deals:", e);
    }

    const formattedContacts = Array.from(contactMap.values());

    return { success: true, data: formattedContacts };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to fetch CRM contacts" };
  }
}

export async function logActivityAction(data: unknown) {
  try {
    const parsedData = activitySchema.parse(data);
    
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const [dbUser] = await db
      .select({ id: users.id, role: users.role })
      .from(users)
      .where(eq(users.id, user.id))
      .limit(1);

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { success: false, error: "Forbidden: Broker role required" };
    }

    if (dbUser.role !== 'admin') {
      const contactRecord = await db
        .select({ id: crmContacts.id, brokerId: crmContacts.brokerId })
        .from(crmContacts)
        .where(eq(crmContacts.id, parsedData.contact_id))
        .limit(1);

      if (contactRecord.length === 0 || contactRecord[0].brokerId !== user.id) {
        return { success: false, error: "Unauthorized: You do not have permission to manage this contact" };
      }
    }

    const inserted = await db.insert(crmActivities).values({
      contactId: parsedData.contact_id,
      type: parsedData.type,
      notes: parsedData.notes,
      followUpDate: parsedData.follow_up_date,
    }).returning();

    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to log activity" };
  }
}

export async function getTasksAction() {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const [dbUser] = await db
      .select({ id: users.id, role: users.role })
      .from(users)
      .where(eq(users.id, user.id))
      .limit(1);

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { success: false, error: "Forbidden: Broker role required" };
    }

    const results = await db
      .select()
      .from(crmTasks)
      .where(
        and(
          eq(crmTasks.status, 'Pending'),
          eq(crmTasks.brokerId, user.id)
        )
      )
      .orderBy(crmTasks.dueDate);

    return { success: true, data: results };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to fetch tasks" };
  }
}

export async function createTaskAction(data: unknown) {
  try {
    const parsedData = taskSchema.parse(data);
    
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const [dbUser] = await db
      .select({ id: users.id, role: users.role })
      .from(users)
      .where(eq(users.id, user.id))
      .limit(1);

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { success: false, error: "Forbidden: Broker role required" };
    }

    if (parsedData.contact_id && dbUser.role !== 'admin') {
      const contactRecord = await db
        .select({ id: crmContacts.id, brokerId: crmContacts.brokerId })
        .from(crmContacts)
        .where(eq(crmContacts.id, parsedData.contact_id))
        .limit(1);

      if (contactRecord.length === 0 || contactRecord[0].brokerId !== user.id) {
        return { success: false, error: "Unauthorized: You do not have permission to attach tasks to this contact" };
      }
    }

    const brokerIdToUse = user.id;

    const inserted = await db.insert(crmTasks).values({
      brokerId: brokerIdToUse,
      contactId: parsedData.contact_id,
      title: parsedData.title,
      dueDate: parsedData.due_date,
      priority: parsedData.priority,
      status: 'Pending',
    }).returning();

    return { success: true, data: inserted[0] };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to create task" };
  }
}

export async function toggleTaskStatusAction(taskId: string) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) return { success: false, error: "Unauthorized" };

    const [dbUser] = await db
      .select({ id: users.id, role: users.role })
      .from(users)
      .where(eq(users.id, user.id))
      .limit(1);

    if (!dbUser || (dbUser.role !== 'broker' && dbUser.role !== 'admin')) {
      return { success: false, error: "Forbidden: Broker role required" };
    }

    const existingTasks = await db.select().from(crmTasks).where(
      and(
        eq(crmTasks.id, taskId),
        eq(crmTasks.brokerId, user.id)
      )
    );

    if (existingTasks.length === 0) return { success: false, error: "Task not found" };

    const task = existingTasks[0];
    const newStatus = task.status === 'Pending' ? 'Completed' : 'Pending';

    const updated = await db.update(crmTasks)
      .set({ status: newStatus })
      .where(eq(crmTasks.id, taskId))
      .returning();

    return { success: true, data: updated[0] };
  } catch (error: any) {
    return { success: false, error: error.message || "Failed to update task status" };
  }
}
