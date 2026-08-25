'use server'

import { createClient } from '@/lib/supabase/server'
import { db } from '@/src/server/db'
import { notifications, users } from '@/src/server/db/schema'
import { eq, and, desc, isNull, sql } from 'drizzle-orm'
import { NotificationChannel, NotificationEventType, NotificationPayload } from '../notifications/types'

export interface QueueNotificationInput {
  userId: string
  companyId?: string | null
  channel: NotificationChannel
  eventType: NotificationEventType
  title: string
  message: string
  payload?: NotificationPayload | null
}

/**
 * 1. queueNotificationAction
 * Queues a notification intent.
 * - IN_APP: immediately saved with delivery_status = 'Sent', sent_at = now(), read_at = null
 * - WHATSAPP / EMAIL: saved with delivery_status = 'Pending' for background cron dispatcher
 */
export async function queueNotificationAction(input: QueueNotificationInput) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required to queue notifications' }
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    })
    if (!dbUser) {
      return { success: false, error: 'Unauthorized: User profile not found' }
    }

    const isChannelInApp = input.channel === 'IN_APP'

    // If companyId is not provided, look up recipient user's company
    let targetCompanyId = input.companyId
    if (!targetCompanyId) {
      const recipientUser = await db.select({ companyId: users.companyId }).from(users).where(eq(users.id, input.userId))
      targetCompanyId = recipientUser[0]?.companyId || null
    }

    const inserted = await db
      .insert(notifications)
      .values({
        userId: input.userId,
        companyId: targetCompanyId,
        channel: input.channel,
        eventType: input.eventType,
        title: input.title,
        message: input.message,
        payload: input.payload || null,
        deliveryStatus: isChannelInApp ? 'Sent' : 'Pending',
        sentAt: isChannelInApp ? new Date() : null,
        readAt: null,
        attemptCount: 0,
        maxAttempts: 3,
      })
      .returning({ id: notifications.id })

    return {
      success: true,
      data: { id: inserted[0]?.id },
    }
  } catch (error: any) {
    console.error('[queueNotificationAction] error:', error)
    return { success: false, error: error.message || 'Failed to queue notification' }
  }
}

/**
 * 2. getInAppNotificationsAction
 * Fetches latest 20 IN_APP notifications for the authenticated user and calculates unread count.
 * Multi-tenant & recipient isolated.
 */
export async function getInAppNotificationsAction() {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return { success: false, error: 'Unauthorized', data: { notifications: [], unreadCount: 0 } }
    }

    const [userNotifications, unreadCountRes] = await Promise.all([
      db
        .select()
        .from(notifications)
        .where(
          and(
            eq(notifications.userId, user.id),
            eq(notifications.channel, 'IN_APP')
          )
        )
        .orderBy(desc(notifications.createdAt))
        .limit(20),

      db
        .select({ count: sql<number>`count(*)::int` })
        .from(notifications)
        .where(
          and(
            eq(notifications.userId, user.id),
            eq(notifications.channel, 'IN_APP'),
            isNull(notifications.readAt)
          )
        ),
    ])

    const unreadCount = Number(unreadCountRes[0]?.count ?? 0)

    return {
      success: true,
      data: {
        notifications: userNotifications,
        unreadCount,
      },
    }
  } catch (error: any) {
    console.error('[getInAppNotificationsAction] error:', error)
    return { success: false, error: error.message || 'Failed to fetch notifications', data: { notifications: [], unreadCount: 0 } }
  }
}

/**
 * 3. markAsReadAction
 * Updates read_at timestamp for a specific IN_APP notification.
 * Strictly verifies ownership (userId = authenticatedUser.id) and does NOT mutate delivery_status.
 */
export async function markAsReadAction(notificationId: string) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return { success: false, error: 'Unauthorized' }
    }

    const updated = await db
      .update(notifications)
      .set({ readAt: new Date() })
      .where(
        and(
          eq(notifications.id, notificationId),
          eq(notifications.userId, user.id),
          eq(notifications.channel, 'IN_APP')
        )
      )
      .returning({ id: notifications.id })

    if (updated.length === 0) {
      return { success: false, error: 'Notification not found or access denied' }
    }

    return { success: true }
  } catch (error: any) {
    console.error('[markAsReadAction] error:', error)
    return { success: false, error: error.message || 'Failed to mark notification as read' }
  }
}

/**
 * 4. markAllAsReadAction
 * Marks all unread IN_APP notifications as read for the authenticated user.
 */
export async function markAllAsReadAction() {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return { success: false, error: 'Unauthorized' }
    }

    await db
      .update(notifications)
      .set({ readAt: new Date() })
      .where(
        and(
          eq(notifications.userId, user.id),
          eq(notifications.channel, 'IN_APP'),
          isNull(notifications.readAt)
        )
      )

    return { success: true }
  } catch (error: any) {
    console.error('[markAllAsReadAction] error:', error)
    return { success: false, error: error.message || 'Failed to mark all notifications as read' }
  }
}
