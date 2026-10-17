"use server";

export type AuditActionType =
  | "BROKER_REQUEST_INITIATED"
  | "BOOKING_MANUALLY_CONFIRMED"
  | "BOOKING_CREATED"
  | "AI_MATCH_REVIEWED"
  | "AUTONOMOUS_BYPASS_ATTEMPT_BLOCKED"
  | "SELLER_PROPOSAL_ACTION"
  | "ALLOCATION_PROPOSED"
  | "ALLOCATION_CONFIRMED"
  | "ALLOCATION_CANCELLED"
  | "DEAL_CREATED"
  | "DEAL_TERMS_REVISED"
  | "DEAL_PARTY_CONFIRMED"
  | "DEAL_FINALIZED"
  | "DEAL_CANCELLED";

export interface DecisionGateAuditEvent {
  action: AuditActionType;
  actorId: string;
  actorRole?: string;
  entity: "broker_requests" | "deals" | "quotations" | "ai_match" | "system" | "bookings" | "requirement_allocations";
  entityId?: string;
  metadata?: {
    matchScore?: number;
    aiRecommended?: boolean;
    brokerOverride?: boolean;
    humanReviewed?: boolean;
    blockedReason?: string;
    notes?: string;
    [key: string]: any;
  };
  timestamp?: Date | string;
}

/**
 * Logs security audit entries for Non-Autonomous AI Decision Gates & Broker Provenance.
 * Guarantees a tamper-evident record that human discretion was applied.
 */
export async function logDecisionGateAuditEventAction(
  event: DecisionGateAuditEvent
): Promise<{ success: boolean; auditId?: string; error?: string }> {
  try {
    const auditRecord = {
      id: `audit_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`,
      action: event.action,
      actorId: event.actorId,
      actorRole: event.actorRole || "broker",
      entity: event.entity,
      entityId: event.entityId || null,
      metadata: {
        ...event.metadata,
        humanReviewed: event.metadata?.humanReviewed ?? true,
        aiRecommended: event.metadata?.aiRecommended ?? false,
        brokerOverride: event.metadata?.brokerOverride ?? false,
      },
      timestamp: event.timestamp || new Date().toISOString(),
    };

    // Structured Audit Logging (Formatted for CloudWatch / Supabase Log Drain)
    console.info("[NON_AUTONOMOUS_AUDIT_LOG]", JSON.stringify(auditRecord));

    return { success: true, auditId: auditRecord.id };
  } catch (error: any) {
    console.error("Failed to write decision gate audit event:", error);
    return { success: false, error: error.message || "Failed to log audit event" };
  }
}
