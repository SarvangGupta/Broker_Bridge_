import { z } from "zod";
import {
  NotificationChannel,
  NotificationEventType,
  NotificationPayload,
} from "@/src/server/notifications/types";

export const sellerNotificationDispatchSchema = z.object({
  company_id: z.string().uuid().optional().nullable(),
  user_id: z.string().uuid().optional().nullable(),
  event_type: z.string().min(1),
  title: z.string().min(1),
  context_reason: z.string().optional().default(""),
  action_label: z.string().optional().default("View Details"),
  action_url: z.string().min(1).default("/seller"),
  idempotency_key: z.string().optional().nullable(),
  channel: z.enum(["IN_APP", "WHATSAPP", "EMAIL"]).optional().default("IN_APP"),
  payload: z.record(z.any()).optional().nullable(),
});

export type SellerNotificationDispatchInput = z.infer<
  typeof sellerNotificationDispatchSchema
>;

export interface QueueNotificationInput {
  userId: string;
  companyId?: string | null;
  channel: NotificationChannel;
  eventType: NotificationEventType;
  title: string;
  message: string;
  contextReason?: string;
  actionLabel?: string;
  actionUrl?: string | null;
  idempotencyKey?: string | null;
  payload?: NotificationPayload | null;
}

export type ActionCenterFilter =
  | "All"
  | "Unread"
  | "Urgent Action"
  | "Deals & Requests"
  | "Fulfillment & Payments";

export interface ActionCenterNotificationItem {
  id: string;
  userId: string;
  companyId: string | null;
  channel: string;
  eventType: string;
  title: string;
  message: string;
  contextReason: string;
  actionLabel: string;
  actionUrl: string;
  idempotencyKey: string | null;
  deliveryStatus: string;
  isRead: boolean;
  readAt: string | null;
  createdAt: string;
  payload?: any;
}
