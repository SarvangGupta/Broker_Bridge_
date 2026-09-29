'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  crmContacts,
  crmActivities,
  crmTasks,
  companies,
  users,
  requirements,
  deals,
} from '@/src/server/db/schema';
import { eq, or, and, desc, asc, inArray, notInArray, sql } from 'drizzle-orm';

export interface CrmActivityItem {
  id: string;
  type: string; // 'Call', 'Meeting', 'Note', 'Task'
  notes: string;
  followUpDate?: string | null;
  createdAt: string;
}

export interface ContactAggregatedProfilePayload {
  contactId: string;
  companyId: string;
  companyName: string;
  userName: string;
  userEmail?: string | null;
  userMobile?: string | null;
  role: 'Buyer' | 'Seller' | 'Client';
  openRequirementsCount: number;
  activeDealsCount: number;
  nextFollowUpDate: string | null; // ISO string
  followUpStatus: 'OVERDUE' | 'TODAY' | 'UPCOMING' | 'NONE';
  recentActivities: CrmActivityItem[];
}

export interface SingleProfileResult {
  success: boolean;
  data?: ContactAggregatedProfilePayload;
  error?: string;
}

export interface ContactsListResult {
  success: boolean;
  data?: ContactAggregatedProfilePayload[];
  error?: string;
}

/**
 * Server Action: Fetches a 360-degree aggregated profile for a single CRM Contact.
 * (Micro-Sprint 28.3 - Task 1)
 *
 * Parallel query execution via Promise.all for fast execution.
 * Enforces strict broker isolation.
 */
export async function getBrokerContactAggregatedProfileAction(
  contactId: string
): Promise<SingleProfileResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    if (!contactId) {
      return { success: false, error: 'Contact ID is required' };
    }

    // Verify broker / admin role
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User profile not found' };
    }

    const role = (dbUser.role || '').toLowerCase();
    if (role !== 'broker' && role !== 'admin') {
      return { success: false, error: 'Forbidden: Broker access privileges required' };
    }

    const userId = authUser.id;
    const isPlatformAdmin = role === 'admin';

    // 1. Fetch core CRM contact row joined with user & company
    const contactRows = await db
      .select({
        contactId: crmContacts.id,
        brokerId: crmContacts.brokerId,
        companyId: crmContacts.companyId,
        userId: crmContacts.userId,
        companyName: companies.name,
        userName: users.name,
        userEmail: users.email,
        userMobile: users.mobile,
        userRole: users.role,
      })
      .from(crmContacts)
      .leftJoin(companies, eq(crmContacts.companyId, companies.id))
      .leftJoin(users, eq(crmContacts.userId, users.id))
      .where(eq(crmContacts.id, contactId));

    if (!contactRows.length) {
      return { success: false, error: 'Contact record not found' };
    }

    const contactRow = contactRows[0];

    // Enforce broker isolation boundary
    if (!isPlatformAdmin && contactRow.brokerId !== userId) {
      return { success: false, error: 'Unauthorized to view this contact' };
    }

    const targetCompanyId = contactRow.companyId;

    // Resolve Contact Role Badge ('Buyer', 'Seller', 'Client')
    let contactRole: 'Buyer' | 'Seller' | 'Client' = 'Client';
    const rLower = (contactRow.userRole || '').toLowerCase();
    if (rLower === 'buyer') contactRole = 'Buyer';
    else if (rLower === 'seller') contactRole = 'Seller';

    // 2. Parallel Subqueries (Activities, Next Task, Open Requirements, Active Deals)
    const [activitiesRows, pendingTasksRows, reqCountRows, dealsCountRows] = await Promise.all([
      // A. Last 5 activities from crm_activities
      db
        .select({
          id: crmActivities.id,
          type: crmActivities.type,
          notes: crmActivities.notes,
          followUpDate: crmActivities.followUpDate,
          createdAt: crmActivities.createdAt,
        })
        .from(crmActivities)
        .where(eq(crmActivities.contactId, contactId))
        .orderBy(desc(crmActivities.createdAt))
        .limit(5),

      // B. Next pending follow-up task
      db
        .select({
          dueDate: crmTasks.dueDate,
          title: crmTasks.title,
        })
        .from(crmTasks)
        .where(and(eq(crmTasks.contactId, contactId), eq(crmTasks.status, 'Pending')))
        .orderBy(asc(crmTasks.dueDate))
        .limit(1),

      // C. Count of Open Requirements linked to company
      targetCompanyId
        ? db
            .select({ count: sql<number>`count(*)` })
            .from(requirements)
            .where(
              and(
                eq(requirements.companyId, targetCompanyId),
                inArray(requirements.status, ['Open', 'Active', 'Matching', 'In Negotiation'])
              )
            )
        : Promise.resolve([{ count: 0 }]),

      // D. Count of Active Deals linked to company
      targetCompanyId
        ? db
            .select({ count: sql<number>`count(*)` })
            .from(deals)
            .where(
              and(
                or(eq(deals.buyerId, targetCompanyId), eq(deals.sellerId, targetCompanyId)),
                notInArray(deals.status, ['Closed', 'Completed', 'Cancelled'])
              )
            )
        : Promise.resolve([{ count: 0 }]),
    ]);

    // Calculate Next Follow-Up Date & Status
    let nextFollowUpDate: string | null = null;
    if (pendingTasksRows.length > 0 && pendingTasksRows[0].dueDate) {
      nextFollowUpDate = new Date(pendingTasksRows[0].dueDate).toISOString();
    } else if (activitiesRows.length > 0 && activitiesRows[0].followUpDate) {
      nextFollowUpDate = new Date(activitiesRows[0].followUpDate).toISOString();
    }

    let followUpStatus: 'OVERDUE' | 'TODAY' | 'UPCOMING' | 'NONE' = 'NONE';
    if (nextFollowUpDate) {
      const targetDate = new Date(nextFollowUpDate);
      const now = new Date();

      const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
      const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

      if (targetDate < startOfToday) {
        followUpStatus = 'OVERDUE';
      } else if (targetDate <= endOfToday) {
        followUpStatus = 'TODAY';
      } else {
        followUpStatus = 'UPCOMING';
      }
    }

    const recentActivities: CrmActivityItem[] = activitiesRows.map((a) => ({
      id: a.id,
      type: a.type || 'Note',
      notes: a.notes || '',
      followUpDate: a.followUpDate ? new Date(a.followUpDate).toISOString() : null,
      createdAt: a.createdAt ? new Date(a.createdAt).toISOString() : new Date().toISOString(),
    }));

    const openRequirementsCount = Number(reqCountRows[0]?.count || 0);
    const activeDealsCount = Number(dealsCountRows[0]?.count || 0);

    return {
      success: true,
      data: {
        contactId: contactRow.contactId,
        companyId: targetCompanyId || '',
        companyName: contactRow.companyName || 'Independent Client',
        userName: contactRow.userName || (contactRow.userMobile ? `Contact (${contactRow.userMobile})` : 'Representative'),
        userEmail: contactRow.userEmail || null,
        userMobile: contactRow.userMobile || null,
        role: contactRole,
        openRequirementsCount,
        activeDealsCount,
        nextFollowUpDate,
        followUpStatus,
        recentActivities,
      },
    };
  } catch (err: any) {
    console.error('Error fetching broker contact aggregated profile:', err);
    return {
      success: false,
      error: err.message || 'Failed to fetch contact profile.',
    };
  }
}

/**
 * Server Action: Fetches all CRM contact 360-degree aggregated profiles for the active Broker workspace.
 */
export async function getBrokerAggregatedContactsListAction(): Promise<ContactsListResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    // Verify broker / admin role
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User profile not found' };
    }

    const role = (dbUser.role || '').toLowerCase();
    if (role !== 'broker' && role !== 'admin') {
      return { success: false, error: 'Forbidden: Broker access privileges required' };
    }

    const userId = authUser.id;
    const isPlatformAdmin = role === 'admin';

    // 1. Fetch all assigned crm_contacts
    const contactRows = await db
      .select({
        id: crmContacts.id,
      })
      .from(crmContacts)
      .where(isPlatformAdmin ? sql`true` : eq(crmContacts.brokerId, userId));

    if (!contactRows.length) {
      return { success: true, data: [] };
    }

    // 2. Parallel profile fetch across contacts
    const profilePromises = contactRows.map((c) =>
      getBrokerContactAggregatedProfileAction(c.id)
    );
    const profileResults = await Promise.all(profilePromises);

    const aggregatedContacts: ContactAggregatedProfilePayload[] = profileResults
      .filter((res) => res.success && res.data)
      .map((res) => res.data!);

    return {
      success: true,
      data: aggregatedContacts,
    };
  } catch (err: any) {
    console.error('Error fetching broker aggregated contacts list:', err);
    return {
      success: false,
      error: err.message || 'Failed to fetch CRM contacts list.',
    };
  }
}
