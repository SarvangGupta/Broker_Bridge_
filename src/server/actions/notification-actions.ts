"use server";

import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import { notifications, users } from "@/src/server/db/schema";
import { eq, and, desc, isNull, sql, or, inArray } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { verifySellerSession } from "@/src/server/utils/seller-auth";
import {
  NotificationChannel,
  NotificationEventType,
  NotificationPayload,
  NotificationRecord,
} from "../notifications/types";

import { sanitizeNotificationText } from "@/src/server/utils/privacy-scrubber";

import {
  sellerNotificationDispatchSchema,
  SellerNotificationDispatchInput,
  QueueNotificationInput,
  ActionCenterFilter,
  ActionCenterNotificationItem,
} from "@/src/types/notification-schema";

export type {
  SellerNotificationDispatchInput,
  QueueNotificationInput,
  ActionCenterFilter,
  ActionCenterNotificationItem,
};

// Event type groupings for tab filters
const URGENT_EVENT_TYPES = [
  "FINAL_CONFIRMATION_REQUIRED",
  "AVAILABILITY_EXPIRING",
  "AVAILABILITY_EXPIRED",
  "AVAILABILITY_REJECTED",
  "DISPATCH_REMINDER",
  "DOCUMENT_ISSUE",
  "PAYMENT_UPDATE",
];

const DEALS_REQUESTS_EVENT_TYPES = [
  "NEW_BROKER_REQUEST",
  "BROKER_COUNTER",
  "DEAL_VERSION_UPDATE",
  "FINAL_CONFIRMATION_REQUIRED",
  "CONFIRMATION_OUTCOME",
  "BOOKING_CREATED",
  "DEAL_CREATED",
  "DEAL_UPDATED",
  "NEGOTIATION_RECEIVED",
  "NEGOTIATION_ACCEPTED",
  "MATCH_CREATED",
  "MATCH_UPDATED",
];

const FULFILLMENT_PAYMENTS_EVENT_TYPES = [
  "LOADING_REMINDER",
  "DISPATCH_REMINDER",
  "DOCUMENT_ISSUE",
  "DELIVERY_UPDATE",
  "PAYMENT_UPDATE",
  "QUALITY_REVIEW",
  "LAB_UPDATE",
];

// =========================================================================
// 3. DISPATCHER: dispatchSellerNotificationAction
// =========================================================================

/**
 * Server Action: Dispatches an operational seller notification with:
 * 1. Automated Privacy Sanitization (Zero Buyer PII).
 * 2. Idempotency Key Deduplication (Prevents duplicate alerts on retries).
 * 3. 3-Part Operational Hierarchy: What happened (title), Why it matters (contextReason), Next action (actionLabel + actionUrl).
 */
export async function dispatchSellerNotificationAction(
  rawPayload: SellerNotificationDispatchInput
): Promise<{
  success: boolean;
  id?: string;
  message?: string;
  error?: string;
}> {
  try {
    const parsed = sellerNotificationDispatchSchema.parse(rawPayload);

    // 1. Resolve Target User and Company
    let targetUserId = parsed.user_id;
    let targetCompanyId = parsed.company_id;

    if (!targetUserId || !targetCompanyId) {
      const auth = await verifySellerSession({ allowViewer: true });
      if (auth.success && auth.data) {
        if (!targetUserId) targetUserId = auth.data.user.id;
        if (!targetCompanyId) targetCompanyId = auth.data.companyId || null;
      }
    }

    if (!targetUserId) {
      return {
        success: false,
        error: "Target user ID is required to dispatch notification.",
      };
    }

    // 2. IDEMPOTENCY CHECK: Suppress duplicate alerts
    if (parsed.idempotency_key && parsed.idempotency_key.trim() !== "") {
      const cleanKey = parsed.idempotency_key.trim();
      const existing = await db.query.notifications.findFirst({
        where: eq(notifications.idempotencyKey, cleanKey),
      });

      if (existing) {
        return {
          success: true,
          id: existing.id,
          message: "Duplicate suppressed: Notification with this idempotency key already exists.",
        };
      }
    }

    // 3. PRIVACY SANITIZATION GATE: Strip all Buyer PII
    const cleanTitle = sanitizeNotificationText(parsed.title);
    const cleanContextReason = sanitizeNotificationText(parsed.context_reason);
    const cleanActionLabel = sanitizeNotificationText(parsed.action_label) || "View Details";
    const cleanActionUrl = parsed.action_url.trim() || "/seller";

    const isChannelInApp = parsed.channel === "IN_APP";

    // 4. Insert Notification Record
    const [inserted] = await db
      .insert(notifications)
      .values({
        userId: targetUserId,
        companyId: targetCompanyId,
        channel: parsed.channel || "IN_APP",
        eventType: parsed.event_type,
        title: cleanTitle,
        message: cleanContextReason || cleanTitle,
        contextReason: cleanContextReason,
        actionLabel: cleanActionLabel,
        actionUrl: cleanActionUrl,
        idempotencyKey: parsed.idempotency_key?.trim() || null,
        payload: parsed.payload || null,
        deliveryStatus: isChannelInApp ? "Sent" : "Pending",
        isRead: false,
        sentAt: isChannelInApp ? new Date() : null,
        readAt: null,
        attemptCount: 0,
        maxAttempts: 3,
      })
      .returning({ id: notifications.id });

    try {
      revalidatePath("/seller");
      revalidatePath("/seller/notifications");
    } catch (_) {}

    return {
      success: true,
      id: inserted.id,
      message: "Notification successfully dispatched to Action Center.",
    };
  } catch (error: any) {
    console.error("[dispatchSellerNotificationAction] error:", error);
    return {
      success: false,
      error: error.message || "Failed to dispatch notification.",
    };
  }
}

// =========================================================================
// 4. FETCH: getSellerNotificationsAction (Action Center Query)
// =========================================================================

/**
 * Server Action: Fetches filtered, paginated notifications for the authenticated Seller's Action Center.
 */
export async function getSellerNotificationsAction(options?: {
  filter?: ActionCenterFilter;
  page?: number;
  limit?: number;
}): Promise<{
  success: boolean;
  data?: {
    notifications: ActionCenterNotificationItem[];
    counts: {
      all: number;
      unread: number;
      urgent: number;
      deals: number;
      fulfillment: number;
    };
    unreadCount: number;
    total: number;
  };
  error?: string;
}> {
  try {
    const auth = await verifySellerSession({ allowViewer: true });
    if (!auth.success || !auth.data) {
      return {
        success: false,
        error: "Unauthorized: Active seller session required.",
      };
    }

    const currentUserId = auth.data.user.id;
    const currentCompanyId = auth.data.companyId;

    const filter = options?.filter || "All";
    const limit = options?.limit || 50;

    // Base condition: Caller's user ID or company ID
    const userOrCompanyCond = currentCompanyId
      ? or(
          eq(notifications.userId, currentUserId),
          eq(notifications.companyId, currentCompanyId)
        )
      : eq(notifications.userId, currentUserId);

    // Fetch all notifications for the tenant to calculate counts
    const allRecords = await db
      .select()
      .from(notifications)
      .where(userOrCompanyCond)
      .orderBy(desc(notifications.createdAt))
      .limit(100);

    const counts = {
      all: allRecords.length,
      unread: allRecords.filter((n) => !n.isRead && !n.readAt).length,
      urgent: allRecords.filter((n) => URGENT_EVENT_TYPES.includes(n.eventType)).length,
      deals: allRecords.filter((n) => DEALS_REQUESTS_EVENT_TYPES.includes(n.eventType)).length,
      fulfillment: allRecords.filter((n) => FULFILLMENT_PAYMENTS_EVENT_TYPES.includes(n.eventType)).length,
    };

    // Filter records based on selected tab
    let filteredRecords = allRecords;

    if (filter === "Unread") {
      filteredRecords = allRecords.filter((n) => !n.isRead && !n.readAt);
    } else if (filter === "Urgent Action") {
      filteredRecords = allRecords.filter((n) =>
        URGENT_EVENT_TYPES.includes(n.eventType)
      );
    } else if (filter === "Deals & Requests") {
      filteredRecords = allRecords.filter((n) =>
        DEALS_REQUESTS_EVENT_TYPES.includes(n.eventType)
      );
    } else if (filter === "Fulfillment & Payments") {
      filteredRecords = allRecords.filter((n) =>
        FULFILLMENT_PAYMENTS_EVENT_TYPES.includes(n.eventType)
      );
    }

    const formatted: ActionCenterNotificationItem[] = filteredRecords
      .slice(0, limit)
      .map((n) => ({
        id: n.id,
        userId: n.userId,
        companyId: n.companyId,
        channel: n.channel,
        eventType: n.eventType,
        title: n.title,
        message: n.message,
        contextReason: n.contextReason || n.message,
        actionLabel: n.actionLabel || "View Details",
        actionUrl: n.actionUrl || "/seller",
        idempotencyKey: n.idempotencyKey,
        deliveryStatus: n.deliveryStatus,
        isRead: Boolean(n.isRead || n.readAt),
        readAt: n.readAt ? n.readAt.toISOString() : null,
        createdAt: n.createdAt.toISOString(),
        payload: n.payload,
      }));

    return {
      success: true,
      data: {
        notifications: formatted,
        counts,
        unreadCount: counts.unread,
        total: filteredRecords.length,
      },
    };
  } catch (error: any) {
    console.error("[getSellerNotificationsAction] error:", error);
    return {
      success: false,
      error: error.message || "Failed to load Action Center notifications.",
    };
  }
}

// =========================================================================
// 5. MUTATION: markNotificationAsReadAction & markAllNotificationsAsReadAction
// =========================================================================

/**
 * Server Action: Marks a single notification as read for the authenticated seller.
 */
export async function markNotificationAsReadAction(notificationId: string): Promise<{
  success: boolean;
  error?: string;
}> {
  try {
    const auth = await verifySellerSession({ allowViewer: true });
    if (!auth.success || !auth.data) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    if (!notificationId) {
      return { success: false, error: "Notification ID is required." };
    }

    const currentUserId = auth.data.user.id;
    const currentCompanyId = auth.data.companyId;

    const ownershipCond = currentCompanyId
      ? and(
          eq(notifications.id, notificationId),
          or(
            eq(notifications.userId, currentUserId),
            eq(notifications.companyId, currentCompanyId)
          )
        )
      : and(
          eq(notifications.id, notificationId),
          eq(notifications.userId, currentUserId)
        );

    const updated = await db
      .update(notifications)
      .set({
        isRead: true,
        readAt: new Date(),
      })
      .where(ownershipCond)
      .returning({ id: notifications.id });

    if (!updated.length) {
      return {
        success: false,
        error: "Notification not found or unauthorized.",
      };
    }

    revalidatePath("/seller");
    revalidatePath("/seller/notifications");

    return { success: true };
  } catch (error: any) {
    console.error("[markNotificationAsReadAction] error:", error);
    return {
      success: false,
      error: error.message || "Failed to mark notification as read.",
    };
  }
}

/**
 * Server Action: Marks all unread notifications as read for the calling seller.
 */
export async function markAllNotificationsAsReadAction(): Promise<{
  success: boolean;
  updatedCount?: number;
  error?: string;
}> {
  try {
    const auth = await verifySellerSession({ allowViewer: true });
    if (!auth.success || !auth.data) {
      return { success: false, error: "Unauthorized: Active session required." };
    }

    const currentUserId = auth.data.user.id;
    const currentCompanyId = auth.data.companyId;

    const ownershipCond = currentCompanyId
      ? and(
          or(
            eq(notifications.userId, currentUserId),
            eq(notifications.companyId, currentCompanyId)
          ),
          eq(notifications.isRead, false)
        )
      : and(
          eq(notifications.userId, currentUserId),
          eq(notifications.isRead, false)
        );

    const updated = await db
      .update(notifications)
      .set({
        isRead: true,
        readAt: new Date(),
      })
      .where(ownershipCond)
      .returning({ id: notifications.id });

    revalidatePath("/seller");
    revalidatePath("/seller/notifications");

    return {
      success: true,
      updatedCount: updated.length,
    };
  } catch (error: any) {
    console.error("[markAllNotificationsAsReadAction] error:", error);
    return {
      success: false,
      error: error.message || "Failed to mark all notifications as read.",
    };
  }
}

// =========================================================================
// 6. LEGACY / TOP-BAR COMPATIBILITY ACTIONS
// =========================================================================

/**
 * Fetches latest in-app notifications for top-bar bell popover.
 */
export async function getInAppNotificationsAction() {
  try {
    const res = await getSellerNotificationsAction({ filter: "All", limit: 10 });
    if (!res.success || !res.data) {
      return {
        success: false,
        error: res.error || "Failed to fetch notifications",
        data: { notifications: [], unreadCount: 0 },
      };
    }

    return {
      success: true,
      data: {
        notifications: res.data.notifications,
        unreadCount: res.data.unreadCount,
      },
    };
  } catch (error: any) {
    console.error("[getInAppNotificationsAction] error:", error);
    return {
      success: false,
      error: error.message || "Failed to fetch notifications",
      data: { notifications: [], unreadCount: 0 },
    };
  }
}

export async function markAsReadAction(notificationId: string) {
  return markNotificationAsReadAction(notificationId);
}

export async function markAllAsReadAction() {
  return markAllNotificationsAsReadAction();
}

/**
 * Queues a notification (legacy backwards compatibility wrapper).
 */
export async function queueNotificationAction(input: QueueNotificationInput) {
  return dispatchSellerNotificationAction({
    user_id: input.userId,
    company_id: input.companyId,
    channel: input.channel,
    event_type: input.eventType,
    title: input.title,
    context_reason: input.contextReason || input.message,
    action_label: input.actionLabel || "View Details",
    action_url: input.actionUrl || "/seller",
    idempotency_key: input.idempotencyKey,
    payload: input.payload,
  });
}
