export type NotificationChannel = 'IN_APP' | 'WHATSAPP' | 'EMAIL'

export type NotificationEventType =
  | 'KYC_STATUS'
  | 'AVAILABILITY_APPROVED'
  | 'AVAILABILITY_REJECTED'
  | 'AVAILABILITY_EXPIRING'
  | 'AVAILABILITY_EXPIRED'
  | 'QUALITY_REVIEW'
  | 'LAB_UPDATE'
  | 'NEW_BROKER_REQUEST'
  | 'BROKER_COUNTER'
  | 'DEAL_VERSION_UPDATE'
  | 'FINAL_CONFIRMATION_REQUIRED'
  | 'CONFIRMATION_OUTCOME'
  | 'BOOKING_CREATED'
  | 'LOADING_REMINDER'
  | 'DISPATCH_REMINDER'
  | 'DOCUMENT_ISSUE'
  | 'DELIVERY_UPDATE'
  | 'PAYMENT_UPDATE'
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
  bookingId?: string
  bookingReference?: string
  dispatchId?: string
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
  contextReason?: string
  actionLabel?: string
  actionUrl?: string
  idempotencyKey?: string | null
  payload?: NotificationPayload | null
  deliveryStatus: string
  isRead?: boolean
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
