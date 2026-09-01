"use server";

import { db } from "@/src/server/db";
import { availabilities } from "@/src/server/db/schema";
import { eq, and, sql } from "drizzle-orm";

/**
 * Transaction-safe quantity reservation.
 * Moves quantity from available to reserved if enough available quantity exists.
 */
export async function reserveQuantity(availabilityId: string, quantity: number, currentVersion: number) {
  return await db.transaction(async (tx) => {
    // We update the availability directly using optimistic locking.
    // Drizzle evaluates the subtraction on the DB side natively, ensuring atomic update.
    const updated = await tx
      .update(availabilities)
      .set({
        availableQuantity: sql`${availabilities.availableQuantity} - ${quantity}`,
        reservedQuantity: sql`${availabilities.reservedQuantity} + ${quantity}`,
        version: sql`${availabilities.version} + 1`
      })
      .where(
        and(
          eq(availabilities.id, availabilityId),
          eq(availabilities.version, currentVersion),
          // Explicitly prevent negative available quantities natively
          sql`${availabilities.availableQuantity} >= ${quantity}`
        )
      )
      .returning();

    if (updated.length === 0) {
      throw new Error("Stale data detected or insufficient available quantity. This inventory was modified by another user or deal. Please refresh to see the latest quantities.");
    }
    
    return updated[0];
  });
}

/**
 * Transaction-safe release of reserved quantity.
 * Moves quantity from reserved back to available.
 */
export async function releaseReservedQuantity(availabilityId: string, quantity: number, currentVersion: number) {
  return await db.transaction(async (tx) => {
    const updated = await tx
      .update(availabilities)
      .set({
        availableQuantity: sql`${availabilities.availableQuantity} + ${quantity}`,
        reservedQuantity: sql`${availabilities.reservedQuantity} - ${quantity}`,
        version: sql`${availabilities.version} + 1`
      })
      .where(
        and(
          eq(availabilities.id, availabilityId),
          eq(availabilities.version, currentVersion),
          sql`${availabilities.reservedQuantity} >= ${quantity}`
        )
      )
      .returning();

    if (updated.length === 0) {
      throw new Error("Stale data detected or insufficient reserved quantity. Please refresh to see the latest quantities.");
    }

    return updated[0];
  });
}

/**
 * Transaction-safe consumption of reserved quantity (closing a deal).
 * Moves quantity from reserved to sold.
 */
export async function consumeReservedQuantity(availabilityId: string, quantity: number, currentVersion: number) {
  return await db.transaction(async (tx) => {
    const updated = await tx
      .update(availabilities)
      .set({
        soldQuantity: sql`${availabilities.soldQuantity} + ${quantity}`,
        reservedQuantity: sql`${availabilities.reservedQuantity} - ${quantity}`,
        version: sql`${availabilities.version} + 1`
      })
      .where(
        and(
          eq(availabilities.id, availabilityId),
          eq(availabilities.version, currentVersion),
          sql`${availabilities.reservedQuantity} >= ${quantity}`
        )
      )
      .returning();

    if (updated.length === 0) {
      throw new Error("Stale data detected or insufficient reserved quantity. Please refresh to see the latest quantities.");
    }

    return updated[0];
  });
}
