'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  requirements,
  availabilities,
  companies,
  masterUnits,
  requirementAllocations,
  users,
} from '@/src/server/db/schema';
import { eq, and, sql, desc, inArray } from 'drizzle-orm';
import { logDecisionGateAuditEventAction } from '@/src/server/actions/audit-actions';

export interface BrokerAllocationDetail {
  id: string;
  allocationReference: string;
  requirementId: string;
  availabilityId: string;
  lotNumber: string | null;
  sellerCompanyId: string;
  sellerCompanyName: string;
  sellerCompanyVerified: boolean;
  brokerId: string;
  dealId: string | null;
  allocatedQuantity: number;
  unitId: string;
  unitName: string;
  unitSymbol: string | null;
  priceBasis: string;
  allocatedPrice: number | null;
  status: 'PROPOSED' | 'CONFIRMED' | 'COMMITTED_TO_DEAL' | 'RELEASED' | 'CANCELLED';
  notes: string | null;
  releaseReason: string | null;
  version: number;
  allocatedAt: string;
  confirmedAt: string | null;
  releasedAt: string | null;
}

export interface AllocationSummary {
  requirementId: string;
  totalRequested: number;
  totalAllocated: number;
  remainingBalance: number;
  allocationCount: number;
  unitName: string;
  unitSymbol: string | null;
}

export interface ProposeAllocationPayload {
  requirementId: string;
  availabilityId: string;
  allocatedQuantity: number;
  priceBasis?: string;
  allocatedPrice?: number;
  notes?: string;
}

export interface ConfirmAllocationPayload {
  allocationId: string;
  expectedVersion?: number;
}

export interface CancelAllocationPayload {
  allocationId: string;
  reason: string;
}

type AuthResult =
  | { success: true; user: typeof users.$inferSelect; isAdmin: boolean }
  | { success: false; error: string };

/**
 * Helper: Authorizes authenticated broker or admin from trusted server session.
 */
async function getAuthorizedBroker(): Promise<AuthResult> {
  let authUser = null;
  let authError = null;

  try {
    const supabase = await createClient();
    const res = await supabase.auth.getUser();
    authUser = res.data.user;
    authError = res.error;
  } catch (_e) {
    // Supabase cookies outside request context (e.g. CLI test environment)
  }

  if (authError || !authUser) {
    return { success: false, error: 'Unauthorized: Valid broker session required' };
  }

  const dbUser = await db.query.users.findFirst({
    where: eq(users.id, authUser.id),
  });

  if (!dbUser) {
    return { success: false, error: 'Unauthorized: User record not found' };
  }

  const role = (dbUser.role || '').toLowerCase();
  if (role !== 'broker' && role !== 'admin') {
    return { success: false, error: 'Forbidden: Broker access privileges required' };
  }

  return { success: true, user: dbUser, isAdmin: role === 'admin' };
}

/**
 * Fetch all allocations and summary for a specific requirement.
 */
export async function getRequirementAllocationsAction(requirementId: string): Promise<{
  success: boolean;
  allocations?: BrokerAllocationDetail[];
  summary?: AllocationSummary;
  error?: string;
}> {
  try {
    const auth = await getAuthorizedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }
    const { user: authBroker, isAdmin } = auth;

    // Verify requirement exists and broker has access
    const reqRes = await db
      .select({
        id: requirements.id,
        quantity: requirements.quantity,
        fulfilledQuantity: requirements.fulfilledQuantity,
        brokerId: requirements.brokerId,
        unitId: requirements.unitId,
        unitName: masterUnits.name,
        unitSymbol: masterUnits.symbol,
      })
      .from(requirements)
      .innerJoin(masterUnits, eq(requirements.unitId, masterUnits.id))
      .where(eq(requirements.id, requirementId))
      .limit(1);

    if (!reqRes || reqRes.length === 0) {
      return { success: false, error: 'Requirement not found' };
    }

    const reqRecord = reqRes[0];
    if (!isAdmin && reqRecord.brokerId !== authBroker.id) {
      return { success: false, error: 'Forbidden: You are not authorized to view this requirement' };
    }

    // Fetch allocations joined with availability and seller company
    const rawAllocations = await db
      .select({
        id: requirementAllocations.id,
        allocationReference: requirementAllocations.allocationReference,
        requirementId: requirementAllocations.requirementId,
        availabilityId: requirementAllocations.availabilityId,
        lotNumber: availabilities.lotNumber,
        sellerCompanyId: availabilities.companyId,
        sellerCompanyName: companies.name,
        sellerCompanyVerified: companies.isVerified,
        brokerId: requirementAllocations.brokerId,
        dealId: requirementAllocations.dealId,
        allocatedQuantity: requirementAllocations.allocatedQuantity,
        unitId: requirementAllocations.unitId,
        unitName: masterUnits.name,
        unitSymbol: masterUnits.symbol,
        priceBasis: requirementAllocations.priceBasis,
        allocatedPrice: requirementAllocations.allocatedPrice,
        status: requirementAllocations.status,
        notes: requirementAllocations.notes,
        releaseReason: requirementAllocations.releaseReason,
        version: requirementAllocations.version,
        allocatedAt: requirementAllocations.allocatedAt,
        confirmedAt: requirementAllocations.confirmedAt,
        releasedAt: requirementAllocations.releasedAt,
      })
      .from(requirementAllocations)
      .innerJoin(availabilities, eq(requirementAllocations.availabilityId, availabilities.id))
      .innerJoin(companies, eq(availabilities.companyId, companies.id))
      .innerJoin(masterUnits, eq(requirementAllocations.unitId, masterUnits.id))
      .where(eq(requirementAllocations.requirementId, requirementId))
      .orderBy(desc(requirementAllocations.allocatedAt));

    const allocations: BrokerAllocationDetail[] = rawAllocations.map((a) => ({
      id: a.id,
      allocationReference: a.allocationReference,
      requirementId: a.requirementId,
      availabilityId: a.availabilityId,
      lotNumber: a.lotNumber,
      sellerCompanyId: a.sellerCompanyId,
      sellerCompanyName: a.sellerCompanyName || 'Verified Seller',
      sellerCompanyVerified: a.sellerCompanyVerified ?? false,
      brokerId: a.brokerId,
      dealId: a.dealId,
      allocatedQuantity: Number(a.allocatedQuantity) || 0,
      unitId: a.unitId,
      unitName: a.unitName,
      unitSymbol: a.unitSymbol,
      priceBasis: a.priceBasis || 'FOR_DESTINATION',
      allocatedPrice: a.allocatedPrice ? Number(a.allocatedPrice) : null,
      status: a.status as BrokerAllocationDetail['status'],
      notes: a.notes,
      releaseReason: a.releaseReason,
      version: a.version,
      allocatedAt: a.allocatedAt.toISOString(),
      confirmedAt: a.confirmedAt ? a.confirmedAt.toISOString() : null,
      releasedAt: a.releasedAt ? a.releasedAt.toISOString() : null,
    }));

    // Calculate live allocation summary
    const totalRequested = Number(reqRecord.quantity) || 0;
    const activeAllocated = allocations
      .filter((a) => ['PROPOSED', 'CONFIRMED', 'COMMITTED_TO_DEAL'].includes(a.status))
      .reduce((sum, a) => sum + a.allocatedQuantity, 0);

    const remainingBalance = Math.max(0, totalRequested - activeAllocated);

    const summary: AllocationSummary = {
      requirementId,
      totalRequested,
      totalAllocated: activeAllocated,
      remainingBalance,
      allocationCount: allocations.filter((a) => ['PROPOSED', 'CONFIRMED', 'COMMITTED_TO_DEAL'].includes(a.status)).length,
      unitName: reqRecord.unitName,
      unitSymbol: reqRecord.unitSymbol,
    };

    return {
      success: true,
      allocations,
      summary,
    };
  } catch (error: any) {
    console.error('Error in getRequirementAllocationsAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to fetch requirement allocations',
    };
  }
}

/**
 * Propose a new partial allocation against an eligible requirement and seller offer.
 * Critical Rule: An allocation is a recommendation/intent, not a confirmed reservation or deal.
 */
export async function proposeAllocationAction(payload: ProposeAllocationPayload): Promise<{
  success: boolean;
  allocationId?: string;
  reference?: string;
  error?: string;
}> {
  try {
    const auth = await getAuthorizedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }
    const { user: authBroker, isAdmin } = auth;

    const quantity = Number(payload.allocatedQuantity);
    if (isNaN(quantity) || quantity <= 0) {
      return { success: false, error: 'Allocation quantity must be greater than zero' };
    }

    // 1. Validate Target Requirement
    const reqRes = await db
      .select({
        id: requirements.id,
        quantity: requirements.quantity,
        fulfilledQuantity: requirements.fulfilledQuantity,
        brokerId: requirements.brokerId,
        unitId: requirements.unitId,
        status: requirements.status,
      })
      .from(requirements)
      .where(eq(requirements.id, payload.requirementId))
      .limit(1);

    if (!reqRes || reqRes.length === 0) {
      return { success: false, error: 'Target requirement not found' };
    }

    const reqRecord = reqRes[0];
    if (!isAdmin && reqRecord.brokerId !== authBroker.id) {
      return { success: false, error: 'Forbidden: You are not authorized to allocate this requirement' };
    }

    if (!['Active', 'Open'].includes(reqRecord.status)) {
      return { success: false, error: `Requirement is in '${reqRecord.status}' status and cannot accept new allocations` };
    }

    const totalReqQty = Number(reqRecord.quantity) || 0;
    const fulfilledReqQty = Number(reqRecord.fulfilledQuantity) || 0;
    const remainingReqQty = Math.max(0, totalReqQty - fulfilledReqQty);

    if (quantity > remainingReqQty) {
      return {
        success: false,
        error: `Allocated quantity (${quantity}) exceeds remaining requirement quantity (${remainingReqQty})`,
      };
    }

    // 2. Validate Seller Availability Lot
    const now = new Date();
    const availRes = await db
      .select({
        id: availabilities.id,
        availableQuantity: availabilities.availableQuantity,
        validUntil: availabilities.validUntil,
        status: availabilities.status,
        visibility: availabilities.visibility,
        brokerId: availabilities.brokerId,
        unitId: availabilities.unitId,
        askingPrice: availabilities.askingPrice,
      })
      .from(availabilities)
      .where(eq(availabilities.id, payload.availabilityId))
      .limit(1);

    if (!availRes || availRes.length === 0) {
      return { success: false, error: 'Seller availability lot not found' };
    }

    const availRecord = availRes[0];
    if (!['Active', 'Open'].includes(availRecord.status)) {
      return { success: false, error: 'Seller offer is inactive or closed' };
    }

    if (new Date(availRecord.validUntil) <= now) {
      return { success: false, error: 'Seller offer validity has expired' };
    }

    if (!isAdmin && availRecord.visibility === 'restricted' && availRecord.brokerId !== authBroker.id) {
      return { success: false, error: 'Forbidden: Seller offer is restricted to another broker desk' };
    }

    const availableSupplyQty = Number(availRecord.availableQuantity) || 0;
    if (quantity > availableSupplyQty) {
      return {
        success: false,
        error: `Allocated quantity (${quantity}) exceeds seller offer available quantity (${availableSupplyQty})`,
      };
    }

    // Generate unique allocation reference
    const timestampStr = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    const randSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    const reference = `ALC-${timestampStr}-${randSuffix}`;

    const inserted = await db
      .insert(requirementAllocations)
      .values({
        allocationReference: reference,
        requirementId: payload.requirementId,
        availabilityId: payload.availabilityId,
        brokerId: authBroker.id,
        allocatedQuantity: quantity,
        unitId: reqRecord.unitId,
        priceBasis: payload.priceBasis || 'FOR_DESTINATION',
        allocatedPrice: payload.allocatedPrice ? String(payload.allocatedPrice) : String(availRecord.askingPrice),
        status: 'PROPOSED',
        notes: payload.notes || null,
        version: 1,
      })
      .returning();

    if (!inserted || inserted.length === 0) {
      return { success: false, error: 'Failed to record allocation' };
    }

    // Log decision gate audit event
    await logDecisionGateAuditEventAction({
      action: 'ALLOCATION_PROPOSED',
      actorId: authBroker.id,
      actorRole: 'broker',
      entity: 'requirement_allocations',
      entityId: inserted[0].id,
      metadata: {
        allocationReference: reference,
        requirementId: payload.requirementId,
        availabilityId: payload.availabilityId,
        allocatedQuantity: quantity,
        priceBasis: payload.priceBasis,
        status: 'PROPOSED',
        notes: payload.notes,
        humanReviewed: true,
      },
    });

    return {
      success: true,
      allocationId: inserted[0].id,
      reference,
    };
  } catch (error: any) {
    console.error('Error in proposeAllocationAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to propose allocation',
    };
  }
}

/**
 * Confirm a proposed allocation.
 * CONCURRENCY PROTECTION & ATOMICITY:
 * 1. Executes strictly inside db.transaction()
 * 2. Checks current availability and requirement balance at confirmation time.
 * 3. Applies database-level atomic conditional updates ensuring availability >= quantity.
 * 4. Optimistic locking on availability.version prevents simultaneous double-allocation.
 */
export async function confirmAllocationAction(payload: ConfirmAllocationPayload): Promise<{
  success: boolean;
  allocationId?: string;
  error?: string;
}> {
  try {
    const auth = await getAuthorizedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }
    const { user: authBroker, isAdmin } = auth;

    return await db.transaction(async (tx) => {
      // 1. Fetch Allocation
      const allocRes = await tx
        .select()
        .from(requirementAllocations)
        .where(eq(requirementAllocations.id, payload.allocationId))
        .limit(1);

      if (!allocRes || allocRes.length === 0) {
        throw new Error('Allocation record not found');
      }

      const allocation = allocRes[0];

      if (!isAdmin && allocation.brokerId !== authBroker.id) {
        throw new Error('Forbidden: You are not authorized to confirm this allocation');
      }

      if (allocation.status !== 'PROPOSED') {
        throw new Error(`Allocation cannot be confirmed from status '${allocation.status}' (must be PROPOSED)`);
      }

      const allocatedQty = Number(allocation.allocatedQuantity);

      // 2. Authoritative check on Requirement balance
      const reqRes = await tx
        .select({
          id: requirements.id,
          quantity: requirements.quantity,
          fulfilledQuantity: requirements.fulfilledQuantity,
          status: requirements.status,
        })
        .from(requirements)
        .where(eq(requirements.id, allocation.requirementId))
        .limit(1);

      if (!reqRes || reqRes.length === 0) {
        throw new Error('Target requirement no longer exists');
      }

      const reqRecord = reqRes[0];
      if (!['Active', 'Open'].includes(reqRecord.status)) {
        throw new Error('Target requirement is no longer active');
      }

      const totalReq = Number(reqRecord.quantity) || 0;
      const fulfilledReq = Number(reqRecord.fulfilledQuantity) || 0;
      const remainingReq = Math.max(0, totalReq - fulfilledReq);

      if (allocatedQty > remainingReq) {
        throw new Error(`Cannot confirm: Allocated quantity (${allocatedQty}) exceeds remaining requirement quantity (${remainingReq})`);
      }

      // 3. Authoritative check on Availability lot with optimistic version locking
      const availRes = await tx
        .select({
          id: availabilities.id,
          availableQuantity: availabilities.availableQuantity,
          reservedQuantity: availabilities.reservedQuantity,
          version: availabilities.version,
          status: availabilities.status,
          validUntil: availabilities.validUntil,
        })
        .from(availabilities)
        .where(eq(availabilities.id, allocation.availabilityId))
        .limit(1);

      if (!availRes || availRes.length === 0) {
        throw new Error('Seller availability lot no longer exists');
      }

      const availRecord = availRes[0];
      if (!['Active', 'Open'].includes(availRecord.status)) {
        throw new Error('Seller offer is no longer active');
      }

      if (new Date(availRecord.validUntil) <= new Date()) {
        throw new Error('Seller offer validity has expired');
      }

      if (payload.expectedVersion !== undefined && availRecord.version !== payload.expectedVersion) {
        throw new Error('Stale availability data detected. Another broker modified this supply lot. Please refresh.');
      }

      const availableSupply = Number(availRecord.availableQuantity) || 0;
      if (allocatedQty > availableSupply) {
        throw new Error(`Cannot confirm: Allocated quantity (${allocatedQty}) exceeds current available quantity (${availableSupply})`);
      }

      // 4. ATOMIC UPDATE ON AVAILABILITY: Reserve quantity and increment version
      const updatedAvail = await tx
        .update(availabilities)
        .set({
          availableQuantity: sql`${availabilities.availableQuantity} - ${allocatedQty}`,
          reservedQuantity: sql`${availabilities.reservedQuantity} + ${allocatedQty}`,
          version: sql`${availabilities.version} + 1`,
        })
        .where(
          and(
            eq(availabilities.id, allocation.availabilityId),
            sql`CAST(${availabilities.availableQuantity} AS NUMERIC) >= ${allocatedQty}`,
            eq(availabilities.version, availRecord.version)
          )
        )
        .returning();

      if (!updatedAvail || updatedAvail.length === 0) {
        throw new Error('Concurrency conflict: Failed to atomically lock availability quantity. Please try again.');
      }

      // 5. ATOMIC UPDATE ON REQUIREMENT: Increment fulfilled quantity
      const updatedReq = await tx
        .update(requirements)
        .set({
          fulfilledQuantity: sql`${requirements.fulfilledQuantity} + ${allocatedQty}`,
        })
        .where(
          and(
            eq(requirements.id, allocation.requirementId),
            sql`${requirements.quantity} - ${requirements.fulfilledQuantity} >= ${allocatedQty}`
          )
        )
        .returning();

      if (!updatedReq || updatedReq.length === 0) {
        throw new Error('Concurrency conflict: Allocation would over-fulfill the requirement.');
      }

      // 6. UPDATE ALLOCATION RECORD STATUS TO CONFIRMED
      const updatedAlloc = await tx
        .update(requirementAllocations)
        .set({
          status: 'CONFIRMED',
          confirmedAt: new Date(),
          version: sql`${requirementAllocations.version} + 1`,
        })
        .where(
          and(
            eq(requirementAllocations.id, payload.allocationId),
            eq(requirementAllocations.status, 'PROPOSED')
          )
        )
        .returning();

      if (!updatedAlloc || updatedAlloc.length === 0) {
        throw new Error('Failed to update allocation status to CONFIRMED');
      }

      // Log decision gate audit event
      await logDecisionGateAuditEventAction({
        action: 'ALLOCATION_CONFIRMED',
        actorId: authBroker.id,
        actorRole: 'broker',
        entity: 'requirement_allocations',
        entityId: allocation.id,
        metadata: {
          allocationReference: allocation.allocationReference,
          requirementId: allocation.requirementId,
          availabilityId: allocation.availabilityId,
          confirmedQuantity: allocatedQty,
          newAvailabilityVersion: updatedAvail[0].version,
          humanReviewed: true,
        },
      });

      return {
        success: true,
        allocationId: allocation.id,
      };
    });
  } catch (error: any) {
    console.error('Error in confirmAllocationAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to confirm allocation',
    };
  }
}

/**
 * Release or Cancel an existing allocation.
 *
 * CRITICAL BUSINESS RULES:
 * 1. If allocation has been committed to a deal (deal_id IS NOT NULL), it CANNOT be cancelled here (RB-09 rule).
 * 2. If status was CONFIRMED, reserved quantity is restored to available quantity on availability and deducted from requirement fulfilled quantity.
 * 3. Reason is strictly mandatory (min 3 chars).
 * 4. All actions are executed transactionally.
 */
export async function cancelAllocationAction(payload: CancelAllocationPayload): Promise<{
  success: boolean;
  allocationId?: string;
  error?: string;
}> {
  try {
    const auth = await getAuthorizedBroker();
    if (!auth.success) {
      return { success: false, error: auth.error };
    }
    const { user: authBroker, isAdmin } = auth;

    if (!payload.reason || payload.reason.trim().length < 3) {
      return { success: false, error: 'A valid cancellation reason (minimum 3 characters) is required' };
    }

    return await db.transaction(async (tx) => {
      // 1. Fetch Allocation
      const allocRes = await tx
        .select()
        .from(requirementAllocations)
        .where(eq(requirementAllocations.id, payload.allocationId))
        .limit(1);

      if (!allocRes || allocRes.length === 0) {
        throw new Error('Allocation record not found');
      }

      const allocation = allocRes[0];

      if (!isAdmin && allocation.brokerId !== authBroker.id) {
        throw new Error('Forbidden: You are not authorized to cancel this allocation');
      }

      // Deal Guard: Commited to deal cannot be released directly
      if (allocation.dealId) {
        throw new Error('Cannot release an allocation already committed to a finalized deal (RB-09 invariant).');
      }

      if (['RELEASED', 'CANCELLED'].includes(allocation.status)) {
        throw new Error(`Allocation is already in '${allocation.status}' state`);
      }

      const allocatedQty = Number(allocation.allocatedQuantity);

      // 2. If CONFIRMED, restore quantities transactionally
      if (allocation.status === 'CONFIRMED') {
        // Restore availability: +availableQuantity, -reservedQuantity, +version
        await tx
          .update(availabilities)
          .set({
            availableQuantity: sql`${availabilities.availableQuantity} + ${allocatedQty}`,
            reservedQuantity: sql`GREATEST(0, ${availabilities.reservedQuantity} - ${allocatedQty})`,
            version: sql`${availabilities.version} + 1`,
          })
          .where(eq(availabilities.id, allocation.availabilityId));

        // Restore requirement: -fulfilledQuantity
        await tx
          .update(requirements)
          .set({
            fulfilledQuantity: sql`GREATEST(0, ${requirements.fulfilledQuantity} - ${allocatedQty})`,
          })
          .where(eq(requirements.id, allocation.requirementId));
      }

      // 3. Mark Allocation as RELEASED / CANCELLED with audit reason
      const updatedAlloc = await tx
        .update(requirementAllocations)
        .set({
          status: 'RELEASED',
          releaseReason: payload.reason.trim(),
          releasedAt: new Date(),
          version: sql`${requirementAllocations.version} + 1`,
        })
        .where(eq(requirementAllocations.id, payload.allocationId))
        .returning();

      // Log decision gate audit event
      await logDecisionGateAuditEventAction({
        action: 'ALLOCATION_CANCELLED',
        actorId: authBroker.id,
        actorRole: 'broker',
        entity: 'requirement_allocations',
        entityId: allocation.id,
        metadata: {
          allocationReference: allocation.allocationReference,
          previousStatus: allocation.status,
          newStatus: 'RELEASED',
          releasedQuantity: allocatedQty,
          reason: payload.reason.trim(),
          humanReviewed: true,
        },
      });

      return {
        success: true,
        allocationId: allocation.id,
      };
    });
  } catch (error: any) {
    console.error('Error in cancelAllocationAction:', error);
    return {
      success: false,
      error: error.message || 'Failed to cancel allocation',
    };
  }
}
