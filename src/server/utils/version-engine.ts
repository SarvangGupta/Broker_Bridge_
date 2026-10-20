import { DealVersionSnapshot } from "@/src/types/deal-version-schema";
import { dealVersions, quotations } from "@/src/server/db/schema";
import { eq, desc, or } from "drizzle-orm";

export interface MaterialFieldDiff {
  field: string;
  label: string;
  oldValue: any;
  newValue: any;
  type: "increased" | "reduced" | "changed" | "added" | "removed";
}

/**
 * Normalizes values for deterministic comparison:
 * - Trims strings
 * - Coerces numeric strings to numbers
 * - Extracts YYYY-MM-DD for date comparisons
 * - Normalizes empty/null/undefined to null
 */
function normalizeValue(val: any): any {
  if (val === null || val === undefined || val === "") return null;
  if (typeof val === "number") return val;
  if (typeof val === "string") {
    const trimmed = val.trim();
    const num = Number(trimmed);
    if (!isNaN(num) && trimmed !== "" && !trimmed.includes("-") && !trimmed.includes("/")) {
      return num;
    }
    // Check if ISO date string
    if (/^\d{4}-\d{2}-\d{2}/.test(trimmed)) {
      return trimmed.substring(0, 10);
    }
    return trimmed;
  }
  if (val instanceof Date) {
    return val.toISOString().substring(0, 10);
  }
  return val;
}

/**
 * Material commercial fields descriptor
 */
const MATERIAL_FIELD_MAPPINGS: Array<{
  name: string;
  label: string;
  keys: string[];
  isNumeric?: boolean;
}> = [
  { name: "rate", label: "Rate / Price", keys: ["rate", "price", "offeredPrice", "askingPrice"], isNumeric: true },
  { name: "quantity", label: "Quantity", keys: ["quantity", "totalQuantity", "requestedQuantity"], isNumeric: true },
  { name: "deliveryDate", label: "Delivery Date", keys: ["deliveryDate", "delivery_date", "targetDate", "target_date"] },
  { name: "deliveryTerms", label: "Delivery Terms", keys: ["deliveryTerms", "delivery_terms", "deliveryTermsId"] },
  { name: "deliveryState", label: "Delivery State", keys: ["deliveryState", "delivery_state", "stateId"] },
  { name: "deliveryDistrict", label: "Delivery District", keys: ["deliveryDistrict", "delivery_district", "districtId"] },
  { name: "deliveryLocation", label: "Delivery Location", keys: ["deliveryLocation", "delivery_location", "warehouse"] },
  { name: "paymentTerms", label: "Payment Terms", keys: ["paymentTerms", "payment_terms"] },
  { name: "commodityId", label: "Commodity", keys: ["commodityId", "commodity_id"] },
  { name: "gradeId", label: "Grade / Quality Parameter", keys: ["gradeId", "grade_id"] },
  { name: "lotNumber", label: "Lot / Batch Number", keys: ["lotNumber", "lot_number", "lotId", "lot_id"] },
  { name: "packagingType", label: "Packaging Type", keys: ["packagingType", "packaging_type", "packagingTypeId"] },
  { name: "unitSymbol", label: "Unit of Measurement", keys: ["unitSymbol", "unitId", "unit_id"] },
  { name: "brokerageRate", label: "Brokerage Rate", keys: ["brokerageRate", "brokerage_rate"], isNumeric: true },
];

/**
 * Compares two commercial snapshots and returns true if any material commercial field has changed.
 * Ignores non-material fields (e.g. internal notes, read status, view counters, UI transient keys).
 *
 * @param oldSnapshot The previous snapshot
 * @param newSnapshot The new incoming snapshot
 * @returns boolean true if at least one material commercial term changed
 */
export function detectMaterialChanges(
  oldSnapshot: Record<string, any> | null | undefined,
  newSnapshot: Record<string, any> | null | undefined
): boolean {
  if (!oldSnapshot && !newSnapshot) return false;
  if (!oldSnapshot || !newSnapshot) return true;

  for (const field of MATERIAL_FIELD_MAPPINGS) {
    let oldVal: any = null;
    let newVal: any = null;

    for (const key of field.keys) {
      if (oldSnapshot[key] !== undefined && oldSnapshot[key] !== null) {
        oldVal = oldSnapshot[key];
        break;
      }
    }

    for (const key of field.keys) {
      if (newSnapshot[key] !== undefined && newSnapshot[key] !== null) {
        newVal = newSnapshot[key];
        break;
      }
    }

    const normOld = normalizeValue(oldVal);
    const normNew = normalizeValue(newVal);

    if (normOld !== normNew) {
      if (normOld === null && normNew === null) continue;
      return true;
    }
  }

  // Deep compare quality parameters
  const oldQuality = JSON.stringify(oldSnapshot.qualityParameters || oldSnapshot.quality_parameters || []);
  const newQuality = JSON.stringify(newSnapshot.qualityParameters || newSnapshot.quality_parameters || []);
  if (oldQuality !== newQuality) {
    return true;
  }

  return false;
}

/**
 * Returns a detailed list of material differences between two snapshots.
 * Powers the Visual Diff on Deal Confirmation (Sprint 18).
 */
export function getMaterialDiffList(
  oldSnapshot: Record<string, any> | null | undefined,
  newSnapshot: Record<string, any> | null | undefined
): MaterialFieldDiff[] {
  const diffs: MaterialFieldDiff[] = [];
  if (!newSnapshot) return diffs;

  for (const field of MATERIAL_FIELD_MAPPINGS) {
    let oldVal: any = null;
    let newVal: any = null;

    if (oldSnapshot) {
      for (const key of field.keys) {
        if (oldSnapshot[key] !== undefined && oldSnapshot[key] !== null) {
          oldVal = oldSnapshot[key];
          break;
        }
      }
    }

    for (const key of field.keys) {
      if (newSnapshot[key] !== undefined && newSnapshot[key] !== null) {
        newVal = newSnapshot[key];
        break;
      }
    }

    const normOld = normalizeValue(oldVal);
    const normNew = normalizeValue(newVal);

    if (normOld !== normNew) {
      if (normOld === null && normNew === null) continue;

      let type: MaterialFieldDiff["type"] = "changed";
      if (normOld === null && normNew !== null) {
        type = "added";
      } else if (normOld !== null && normNew === null) {
        type = "removed";
      } else if (field.isNumeric && typeof normOld === "number" && typeof normNew === "number") {
        type = normNew > normOld ? "increased" : "reduced";
      }

      diffs.push({
        field: field.name,
        label: field.label,
        oldValue: normOld,
        newValue: normNew,
        type,
      });
    }
  }

  return diffs;
}

/**
 * Stale Version Guard (Optimistic Concurrency Control):
 * Compares the client's expected version number against the latest version in the database.
 * If highest version in DB > expectedVersion, throws an explicit Error with "STALE_VERSION_DETECTED".
 */
export async function verifyLatestVersion(
  txOrDb: any,
  requestId: string,
  expectedVersion?: number | null
): Promise<{ latestVersionNumber: number; isLatest: boolean }> {
  if (!requestId) return { latestVersionNumber: 1, isLatest: true };

  const versions = await txOrDb
    .select({
      id: dealVersions.id,
      versionNumber: dealVersions.versionNumber,
      status: dealVersions.status,
    })
    .from(dealVersions)
    .where(eq(dealVersions.requestId, requestId))
    .orderBy(desc(dealVersions.versionNumber))
    .limit(1);

  const highestVersion = versions.length > 0 ? versions[0].versionNumber : 1;

  if (expectedVersion !== undefined && expectedVersion !== null) {
    if (highestVersion > expectedVersion) {
      throw new Error(
        `STALE_VERSION_DETECTED: The Broker has updated the terms of this deal to Version ${highestVersion}. Please refresh to review the latest version.`
      );
    }
  }

  return {
    latestVersionNumber: highestVersion,
    isLatest: true,
  };
}

/**
 * Internal Transaction-Safe Helper:
 * Evaluates material changes against existing versions, supersedes older records,
 * and inserts a new immutable Deal Version within an existing transaction context.
 */
export async function createDealVersionInTransaction(
  tx: any,
  params: {
    requestId: string;
    newSnapshot: DealVersionSnapshot;
    actorId: string;
    status?: any;
    expectedVersionNumber?: number | null;
  }
): Promise<{ version: any; created: boolean }> {
  // Stale Version Protection Guard
  if (params.expectedVersionNumber !== undefined && params.expectedVersionNumber !== null) {
    await verifyLatestVersion(tx, params.requestId, params.expectedVersionNumber);
  }

  // Step A: Find highest existing version for this request_id
  const existingVersions = await tx
    .select({
      id: dealVersions.id,
      versionNumber: dealVersions.versionNumber,
      status: dealVersions.status,
      snapshotPayload: dealVersions.snapshotPayload,
    })
    .from(dealVersions)
    .where(eq(dealVersions.requestId, params.requestId))
    .orderBy(desc(dealVersions.versionNumber));

  let highestVersion = existingVersions.length > 0 ? existingVersions[0] : null;

  // If no deal_versions record exists yet, synthesize Version 1 first
  if (!highestVersion) {
    const parentQuotation = await tx.query.quotations?.findFirst({
      where: or(eq(quotations.id, params.requestId), eq(quotations.requirementId, params.requestId)),
    });

    if (parentQuotation) {
      const initialV1Snapshot: DealVersionSnapshot = {
        ...params.newSnapshot,
        rate: Number(parentQuotation.offeredPrice || params.newSnapshot.rate),
        originatorRole: "broker",
        timestamp: new Date(parentQuotation.createdAt || Date.now()).toISOString(),
      };

      const [v1] = await tx
        .insert(dealVersions)
        .values({
          requestId: params.requestId,
          versionNumber: 1,
          actorId: parentQuotation.brokerId || params.actorId,
          status: parentQuotation.status === "Sent" ? "Proposed" : (parentQuotation.status as any) || "Proposed",
          snapshotPayload: initialV1Snapshot,
        })
        .returning();

      highestVersion = v1;
    }
  }

  // Step B: Check if material terms changed
  if (highestVersion) {
    const isDifferent = detectMaterialChanges(
      highestVersion.snapshotPayload as Record<string, any>,
      params.newSnapshot as Record<string, any>
    );

    if (!isDifferent) {
      if (params.status && params.status !== highestVersion.status) {
        const [updated] = await tx
          .update(dealVersions)
          .set({ status: params.status })
          .where(eq(dealVersions.id, highestVersion.id))
          .returning();
        return { version: updated, created: false };
      }
      return { version: highestVersion, created: false };
    }

    // Step C: Atomically supersede previous active versions
    await tx
      .update(dealVersions)
      .set({ status: "Superseded" })
      .where(eq(dealVersions.requestId, params.requestId));
  }

  // Step D: Insert new incremental deal version
  const newVersionNumber = highestVersion ? highestVersion.versionNumber + 1 : 1;
  const targetStatus = params.status || "Proposed";

  const [newVer] = await tx
    .insert(dealVersions)
    .values({
      requestId: params.requestId,
      versionNumber: newVersionNumber,
      actorId: params.actorId,
      status: targetStatus,
      snapshotPayload: {
        ...params.newSnapshot,
        timestamp: new Date().toISOString(),
      },
    })
    .returning();

  return { version: newVer, created: true };
}


