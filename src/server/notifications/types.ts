export type NotificationChannel = 'IN_APP' | 'WHATSAPP' | 'EMAIL'

export type NotificationEventType =
  | 'MATCH_CREATED'
  | 'MATCH_UPDATED'
  | 'NEGOTIATION_RECEIVED'
  | 'NEGOTIATION_ACCEPTED'
  | 'DEAL_CREATED'
  | 'DEAL_UPDATED'
  | 'SYSTEM'

export type NotificationDeliveryStatus = 'Pending' | 'Processing' | 'Sent' | 'Failed'

export type NotificationPayload = {
  dealId?: string
  requirementId?: string
  availabilityId?: string
  quotationId?: string
  buyerId?: string
  sellerId?: string
  brokerId?: string
  url?: string
  [key: string]: any
}

export interface NotificationRecord {
  id: string
  userId: string
  companyId?: string | null
  channel: string
  eventType: string
  title: string
  message: string
  payload?: NotificationPayload | null
  deliveryStatus: string
  readAt?: Date | null
  attemptCount: number
  maxAttempts: number
  lastAttemptAt?: Date | null
  nextRetryAt?: Date | null
  errorMessage?: string | null
  providerMessageId?: string | null
  sentAt?: Date | null
  failedAt?: Date | null
  createdAt: Date
}

export interface DispatchResult {
  success: boolean
  providerMessageId?: string
  error?: string
}

export interface ChannelAdapter {
  channel: NotificationChannel
  dispatch(notification: NotificationRecord): Promise<DispatchResult>
}
