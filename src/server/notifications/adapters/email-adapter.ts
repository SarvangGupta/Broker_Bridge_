import { ChannelAdapter, NotificationRecord, DispatchResult } from '../types'

export class EmailAdapter implements ChannelAdapter {
  channel: 'EMAIL' = 'EMAIL'

  async dispatch(notification: NotificationRecord): Promise<DispatchResult> {
    try {
      // Simulate Transactional Email provider dispatch (SMTP/SES/Resend)
      console.log(`[EmailAdapter] Simulating Email dispatch to User ${notification.userId}:`, {
        notificationId: notification.id,
        eventType: notification.eventType,
        title: notification.title,
        message: notification.message,
        payload: notification.payload,
      })

      // Generate a mock external provider message ID
      const providerMessageId = `email_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`

      return {
        success: true,
        providerMessageId,
      }
    } catch (error: any) {
      console.error(`[EmailAdapter] Dispatch failed for notification ${notification.id}:`, error)
      return {
        success: false,
        error: error.message || 'Email dispatch failed',
      }
    }
  }
}

export const emailAdapter = new EmailAdapter()
