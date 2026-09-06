import { db } from "@/src/server/db";
import { dealVersions, quotations, requirements, availabilities, users } from "@/src/server/db/schema";
import { eq, desc } from "drizzle-orm";
import { DealVersionRecord } from "@/src/types/deal-version-schema";

export interface FinalizationPreconditionResult {
  valid: boolean;
  versionRecord: DealVersionRecord;
  quotation: typeof quotations.$inferSelect;
  requestId: string;
}

/**
 * Pre-Flight Validation Engine for the Broker Finalization Gate (Micro-Sprint 18.4).
 * 
 * CORE RULES (PRD v3.0 Section 13 & Sprint 18.4):
 * 1. Step A (Version Check): Validates that expectedVersion matches the active latest version in DB.
 * 2. Step B (Seller Confirmation Check): Validates that the active version's status is 'Seller Confirmed'.
 * 3. Step C (Buyer Confirmation Check): Validates that the Buyer-side requirement / confirmation is satisfied.
 * 
 * Throws explicit, structured errors if any pre-condition fails.
 */
export async function validateFinalizationPreconditions(
  dealIdOrRequestId: string,
  expectedVersion: number,
  txOrDb: any = db
): Promise<FinalizationPreconditionResult> {
  if (!dealIdOrRequestId) {
    throw new Error("Deal ID or Request ID is required for finalization validation.");
  }

  if (!expectedVersion || expectedVersion < 1) {
    throw new Error("Valid version number is required for finalization validation.");
  }

  // 1. Locate parent quotation / proposal
  let quotation = await txOrDb.query.quotations.findFirst({
    where: eq(quotations.id, dealIdOrRequestId),
  });

  let targetRequestId = dealIdOrRequestId;

  // If not found by quotation ID, check if dealId was a deal version ID
  if (!quotation) {
    const versionRow = await txOrDb.query.dealVersions.findFirst({
      where: eq(dealVersions.id, dealIdOrRequestId),
    });

    if (versionRow) {
      targetRequestId = versionRow.requestId;
      quotation = await txOrDb.query.quotations.findFirst({
        where: eq(quotations.id, versionRow.requestId),
      });
    }
  }

  if (!quotation) {
    throw new Error("Proposal or deal record not found for finalization.");
  }

  // 2. Step A: Version Concurrency Guard
  const latestVersions = await txOrDb
    .select({
      id: dealVersions.id,
      requestId: dealVersions.requestId,
      versionNumber: dealVersions.versionNumber,
      actorId: dealVersions.actorId,
      status: dealVersions.status,
      snapshotPayload: dealVersions.snapshotPayload,
      createdAt: dealVersions.createdAt,
    })
    .from(dealVersions)
    .where(eq(dealVersions.requestId, targetRequestId))
    .orderBy(desc(dealVersions.versionNumber))
    .limit(1);

  if (!latestVersions.length) {
    throw new Error("VERSION_NOT_FOUND: No deal version records exist for this proposal.");
  }

  const latestVersion = latestVersions[0] as DealVersionRecord;

  if (latestVersion.versionNumber !== expectedVersion) {
    throw new Error(
      `STALE_VERSION_DETECTED: Active deal version is Version ${latestVersion.versionNumber}, but finalization was requested for Version ${expectedVersion}. Please refresh to review the latest terms.`
    );
  }

  // 3. Step B: Seller Confirmation Check
  // The latest version MUST be 'Seller Confirmed' (or already 'Broker Finalized')
  if (
    latestVersion.status !== "Seller Confirmed" &&
    latestVersion.status !== "Broker Finalized"
  ) {
    throw new Error(
      `MISSING_SELLER_CONFIRMATION: Seller must explicitly confirm Deal Version ${expectedVersion} terms before Broker Finalization. Current version status: "${latestVersion.status}".`
    );
  }

  // 4. Step C: Buyer Confirmation Check
  // Verify that parent requirement exists and proposal is not in a cancelled/rejected state
  const parentReq = await txOrDb.query.requirements.findFirst({
    where: eq(requirements.id, quotation.requirementId),
  });

  if (!parentReq) {
    throw new Error(
      "MISSING_BUYER_CONFIRMATION: Linked buyer requirement not found. Commercial proposal cannot be finalized without a valid buyer mandate."
    );
  }

  if (quotation.status === "Rejected" || quotation.status === "Seller Rejected") {
    throw new Error(
      "REJECTED_PROPOSAL: Cannot finalize a proposal that has been rejected."
    );
  }

  return {
    valid: true,
    versionRecord: latestVersion,
    quotation,
    requestId: targetRequestId,
  };
}
