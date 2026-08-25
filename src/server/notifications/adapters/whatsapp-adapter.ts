import { ChannelAdapter, NotificationRecord, DispatchResult } from '../types'

export class WhatsAppAdapter implements ChannelAdapter {
  channel: 'WHATSAPP' = 'WHATSAPP'

  async dispatch(notification: NotificationRecord): Promise<DispatchResult> {
    try {
      // Simulate WhatsApp Business API delivery
      console.log(`[WhatsAppAdapter] Simulating WhatsApp dispatch to User ${notification.userId}:`, {
        notificationId: notification.id,
        eventType: notification.eventType,
        title: notification.title,
        message: notification.message,
        payload: notification.payload,
      })

      // Generate a mock external provider message ID
      const providerMessageId = `wa_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`

      return {
        success: true,
        providerMessageId,
      }
    } catch (error: any) {
      console.error(`[WhatsAppAdapter] Dispatch failed for notification ${notification.id}:`, error)
      return {
        success: false,
        error: error.message || 'WhatsApp dispatch failed',
      }
    }
  }
}

export const whatsAppAdapter = new WhatsAppAdapter()
