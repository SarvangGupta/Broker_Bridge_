import { DealVersionSnapshot } from "@/src/types/deal-version-schema";
import { dealVersions } from "@/src/server/db/schema";
import { eq, desc } from "drizzle-orm";

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

