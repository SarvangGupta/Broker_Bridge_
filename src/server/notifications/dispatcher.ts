import { db } from '@/src/server/db'
import { notifications } from '@/src/server/db/schema'
import { sql, eq } from 'drizzle-orm'
import { NotificationRecord, ChannelAdapter } from './types'
import { whatsAppAdapter } from './adapters/whatsapp-adapter'
import { emailAdapter } from './adapters/email-adapter'

const adapters: Record<string, ChannelAdapter> = {
  WHATSAPP: whatsAppAdapter,
  EMAIL: emailAdapter,
}

function calculateNextRetryAt(attemptCount: number, maxAttempts: number): Date | null {
  if (attemptCount >= maxAttempts) return null
  const now = new Date()
  if (attemptCount === 1) {
    return new Date(now.getTime() + 1 * 60 * 1000) // 1 min backoff
  } else if (attemptCount === 2) {
    return new Date(now.getTime() + 5 * 60 * 1000) // 5 min backoff
  } else {
    return new Date(now.getTime() + 15 * 60 * 1000) // 15 min backoff
  }
}

export interface DispatchSummary {
  success: boolean
  claimedCount: number
  sentCount: number
  failedCount: number
  errors: string[]
}

/**
 * Atomically claims and processes batch of pending / eligible retry notifications
 */
export async function dispatchPendingNotifications(batchSize: number = 50): Promise<DispatchSummary> {
  const summary: DispatchSummary = {
    success: true,
    claimedCount: 0,
    sentCount: 0,
    failedCount: 0,
    errors: [],
  }

  try {
    // 1. Atomically claim eligible records with CTE and FOR UPDATE SKIP LOCKED
    const claimResult = await db.execute(sql`
      WITH claimable AS (
        SELECT id FROM public.notifications
        WHERE (
          (delivery_status = 'Pending' AND attempt_count = 0)
          OR
          (delivery_status = 'Failed' AND attempt_count < max_attempts AND (next_retry_at IS NULL OR next_retry_at <= now()))
        )
        AND channel IN ('WHATSAPP', 'EMAIL')
        ORDER BY created_at ASC
        LIMIT ${batchSize}
        FOR UPDATE SKIP LOCKED
      )
      UPDATE public.notifications n
      SET 
        delivery_status = 'Processing',
        attempt_count = n.attempt_count + 1,
        last_attempt_at = now()
      FROM claimable
      WHERE n.id = claimable.id
      RETURNING 
        n.id,
        n.user_id AS "userId",
        n.company_id AS "companyId",
        n.channel,
        n.event_type AS "eventType",
        n.title,
        n.message,
        n.payload,
        n.delivery_status AS "deliveryStatus",
        n.read_at AS "readAt",
        n.attempt_count AS "attemptCount",
        n.max_attempts AS "maxAttempts",
        n.last_attempt_at AS "lastAttemptAt",
        n.next_retry_at AS "nextRetryAt",
        n.error_message AS "errorMessage",
        n.provider_message_id AS "providerMessageId",
        n.sent_at AS "sentAt",
        n.failed_at AS "failedAt",
        n.created_at AS "createdAt";
    `)

    const claimedRecords = (claimResult || []) as unknown as NotificationRecord[]
    summary.claimedCount = claimedRecords.length

    if (claimedRecords.length === 0) {
      return summary
    }

    // 2. Process each claimed record through appropriate channel adapter
    for (const record of claimedRecords) {
      const adapter = adapters[record.channel]

      if (!adapter) {
        const errorMsg = `No adapter configured for channel ${record.channel}`
        summary.failedCount += 1
        summary.errors.push(errorMsg)

        await db
          .update(notifications)
          .set({
            deliveryStatus: 'Failed',
            errorMessage: errorMsg,
            nextRetryAt: null, // Permanent failure
            failedAt: new Date(),
          })
          .where(eq(notifications.id, record.id))
        continue
      }

      try {
        const dispatchRes = await adapter.dispatch(record)

        if (dispatchRes.success) {
          summary.sentCount += 1
          await db
            .update(notifications)
            .set({
              deliveryStatus: 'Sent',
              sentAt: new Date(),
              providerMessageId: dispatchRes.providerMessageId || null,
              errorMessage: null,
              nextRetryAt: null,
            })
            .where(eq(notifications.id, record.id))
        } else {
          summary.failedCount += 1
          const nextRetryAt = calculateNextRetryAt(record.attemptCount, record.maxAttempts)
          const isPermanentlyFailed = nextRetryAt === null

          await db
            .update(notifications)
            .set({
              deliveryStatus: 'Failed',
              errorMessage: dispatchRes.error || 'Provider dispatch failed',
              nextRetryAt,
              failedAt: isPermanentlyFailed ? new Date() : null,
            })
            .where(eq(notifications.id, record.id))
        }
      } catch (err: any) {
        summary.failedCount += 1
        summary.errors.push(err.message || 'Unexpected dispatch error')

        const nextRetryAt = calculateNextRetryAt(record.attemptCount, record.maxAttempts)
        const isPermanentlyFailed = nextRetryAt === null

        await db
          .update(notifications)
          .set({
            deliveryStatus: 'Failed',
            errorMessage: err.message || 'Unexpected error during dispatch',
            nextRetryAt,
            failedAt: isPermanentlyFailed ? new Date() : null,
          })
          .where(eq(notifications.id, record.id))
      }
    }

    return summary
  } catch (error: any) {
    console.error('[dispatchPendingNotifications] Fatal error:', error)
    summary.success = false
    summary.errors.push(error.message || 'Fatal dispatcher execution error')
    return summary
  }
}
