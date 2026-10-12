-- Micro-Sprint 36.4: Backend Database-Level Immutability Rules & Append-Only Engine
-- Migration: 0034_enforce_negotiation_immutability.sql

-- ============================================================================
-- 1. negotiation_events Immutability Trigger
-- Historical negotiation events are permanent legal records of commercial
-- communications and cannot be updated or deleted by any user or API mutation.
-- ============================================================================
CREATE OR REPLACE FUNCTION prevent_negotiation_events_mutation()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'CANNOT_MODIFY_NEGOTIATION_HISTORY: Records in negotiation_events are strictly immutable.';
END;
$$ LANGUAGE plpgsql;

--> statement-breakpoint

DROP TRIGGER IF EXISTS trg_prevent_negotiation_events_mutation ON "negotiation_events";
CREATE TRIGGER trg_prevent_negotiation_events_mutation
BEFORE UPDATE OR DELETE ON "negotiation_events"
FOR EACH ROW
EXECUTE FUNCTION prevent_negotiation_events_mutation();

--> statement-breakpoint

-- ============================================================================
-- 2. deal_versions Snapshot Protection Trigger
-- Old proposal snapshots are permanent commercial records. Only the status column
-- is permitted to be updated (e.g., transitioning to 'Superseded' or 'Closed').
-- Any alteration of snapshot_payload, version_number, or row deletion is strictly blocked.
-- ============================================================================
CREATE OR REPLACE FUNCTION prevent_deal_version_snapshot_tampering()
RETURNS TRIGGER AS $$
BEGIN
  -- Block all deletion attempts
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'CANNOT_DELETE_DEAL_VERSION: Records in deal_versions are strictly immutable and cannot be deleted.';
  END IF;

  -- Verify update permissions
  IF TG_OP = 'UPDATE' THEN
    -- Strictly raise exception if snapshot_payload is altered
    IF OLD.snapshot_payload IS DISTINCT FROM NEW.snapshot_payload THEN
      RAISE EXCEPTION 'CANNOT_MODIFY_DEAL_VERSION_SNAPSHOT: Deal version snapshot payload is strictly immutable.';
    END IF;

    -- Strictly raise exception if version_number is altered
    IF OLD.version_number IS DISTINCT FROM NEW.version_number THEN
      RAISE EXCEPTION 'CANNOT_MODIFY_DEAL_VERSION_NUMBER: Deal version number is strictly immutable.';
    END IF;

    -- Strictly raise exception if relational identifiers or creation metadata are altered
    IF OLD.id IS DISTINCT FROM NEW.id OR 
       OLD.request_id IS DISTINCT FROM NEW.request_id OR 
       OLD.actor_id IS DISTINCT FROM NEW.actor_id OR 
       OLD.created_at IS DISTINCT FROM NEW.created_at THEN
      RAISE EXCEPTION 'CANNOT_MODIFY_DEAL_VERSION_METADATA: Only status column can be updated on deal_versions.';
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--> statement-breakpoint

DROP TRIGGER IF EXISTS trg_prevent_deal_version_snapshot_tampering_update ON "deal_versions";
CREATE TRIGGER trg_prevent_deal_version_snapshot_tampering_update
BEFORE UPDATE ON "deal_versions"
FOR EACH ROW
EXECUTE FUNCTION prevent_deal_version_snapshot_tampering();

--> statement-breakpoint

DROP TRIGGER IF EXISTS trg_prevent_deal_version_snapshot_tampering_delete ON "deal_versions";
CREATE TRIGGER trg_prevent_deal_version_snapshot_tampering_delete
BEFORE DELETE ON "deal_versions"
FOR EACH ROW
EXECUTE FUNCTION prevent_deal_version_snapshot_tampering();
