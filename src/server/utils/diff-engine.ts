import { DealVersionSnapshot } from "@/src/types/deal-version-schema";

export type FieldDiffState =
  | "unchanged"
  | "increased"
  | "decreased"
  | "changed"
  | "added"
  | "removed";

export interface FieldDiffItem {
  key: string;
  label: string;
  oldValue: any;
  newValue: any;
  state: FieldDiffState;
  isDifferent: boolean;
  formattedOld?: string;
  formattedNew?: string;
}

export interface VersionDiffResult {
  isFirstVersion: boolean;
  hasChanges: boolean;
  changedFieldNames: string[];
  fields: Record<string, FieldDiffItem>;
}

/**
 * Normalizes values for deterministic comparison:
 * - Trims strings
 * - Coerces numeric strings to numbers
 * - Extracts YYYY-MM-DD for date comparisons
 * - Normalizes empty/null/undefined to null
 */
function normalizeVal(val: any): any {
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
 * Formats a value for display in visual diffs
 */
function formatDisplayValue(key: string, val: any, unitSymbol: string = "MT"): string {
  if (val === null || val === undefined || val === "") return "None";

  if (key === "rate") {
    const num = typeof val === "number" ? val : Number(val);
    return isNaN(num) ? String(val) : `₹${num.toLocaleString("en-IN")}/${unitSymbol}`;
  }

  if (key === "quantity") {
    const num = typeof val === "number" ? val : Number(val);
    return isNaN(num) ? String(val) : `${num.toLocaleString("en-IN")} ${unitSymbol}`;
  }

  if (key === "totalValuation") {
    const num = typeof val === "number" ? val : Number(val);
    return isNaN(num) ? String(val) : `₹${num.toLocaleString("en-IN", { maximumFractionDigits: 2 })}`;
  }

  if (key === "brokerageRate") {
    const num = typeof val === "number" ? val : Number(val);
    return isNaN(num) ? String(val) : `₹${num.toLocaleString("en-IN")}/${unitSymbol}`;
  }

  if (key === "deliveryDate" && typeof val === "string" && /^\d{4}-\d{2}-\d{2}/.test(val)) {
    try {
      const parts = val.substring(0, 10).split("-");
      const d = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
      return d.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
    } catch {
      return val;
    }
  }

  return String(val);
}

/**
 * Material field descriptor list for visual diff computation
 */
interface FieldDescriptor {
  key: string;
  label: string;
  isNumeric?: boolean;
  favorableWhenHigher?: boolean; // For seller rate, higher is favorable (green/increased)
  getter: (snap: DealVersionSnapshot | null | undefined) => any;
}

const DIFF_FIELD_DESCRIPTORS: FieldDescriptor[] = [
  {
    key: "rate",
    label: "Rate / Price",
    isNumeric: true,
    favorableWhenHigher: true,
    getter: (s) => (s?.rate !== undefined && s?.rate !== null ? Number(s.rate) : null),
  },
  {
    key: "quantity",
    label: "Agreed Quantity",
    isNumeric: true,
    favorableWhenHigher: true,
    getter: (s) => (s?.quantity !== undefined && s?.quantity !== null ? Number(s.quantity) : null),
  },
  {
    key: "totalValuation",
    label: "Total Valuation",
    isNumeric: true,
    favorableWhenHigher: true,
    getter: (s) =>
      typeof s?.quantity === "number" && typeof s?.rate === "number" ? s.quantity * s.rate : null,
  },
  {
    key: "deliveryDate",
    label: "Delivery Date",
    getter: (s) => s?.deliveryDate || null,
  },
  {
    key: "deliveryTerms",
    label: "Delivery / Freight Terms",
    getter: (s) => s?.deliveryTerms || null,
  },
  {
    key: "deliveryLocation",
    label: "Delivery Location",
    getter: (s) => {
      if (!s) return null;
      const parts = [s.deliveryLocation, s.deliveryDistrict, s.deliveryState].filter(Boolean);
      return parts.length > 0 ? parts.join(", ") : null;
    },
  },
  {
    key: "paymentTerms",
    label: "Payment Terms",
    getter: (s) => s?.paymentTerms || null,
  },
  {
    key: "packagingType",
    label: "Packaging Type",
    getter: (s) => s?.packagingType || null,
  },
  {
    key: "gradeName",
    label: "Quality Grade",
    getter: (s) => s?.gradeName || null,
  },
  {
    key: "lotNumber",
    label: "Lot Number",
    getter: (s) => s?.lotNumber || null,
  },
  {
    key: "brokerageRate",
    label: "Brokerage Rate",
    isNumeric: true,
    favorableWhenHigher: false, // For seller, lower brokerage is favorable
    getter: (s) =>
      s?.brokerageRate !== undefined && s?.brokerageRate !== null ? Number(s.brokerageRate) : null,
  },
  {
    key: "qualityNotes",
    label: "Quality Notes",
    getter: (s) => s?.qualityNotes || null,
  },
  {
    key: "specialConditions",
    label: "Special Conditions",
    getter: (s) => s?.specialConditions || null,
  },
  {
    key: "remarks",
    label: "Remarks",
    getter: (s) => s?.remarks || null,
  },
  {
    key: "loadingReadiness",
    label: "Loading Readiness",
    getter: (s) => {
      if (!s?.loadingReadiness) return null;
      const lr = s.loadingReadiness;
      const parts = [lr.status];
      if (lr.durationDays) parts.push(`${lr.durationDays} Days`);
      return parts.filter(Boolean).join(" - ");
    },
  },
];

/**
 * Server-Side Version Diff Engine:
 * Compares two immutable deal snapshots and produces a structured diff result.
 * 
 * Rules:
 * - If previousSnapshot is null/undefined: isFirstVersion is true, all fields marked 'unchanged'.
 * - If numeric field (e.g. rate):
 *   - current > previous: 'increased' (green)
 *   - current < previous: 'decreased' (red)
 * - If string/date field:
 *   - added if old was null and new is not
 *   - removed if old was not null and new is null
 *   - changed if old !== new
 * - Returns changedFieldNames array for the "What Changed" summary banner.
 */
export function computeVersionDiff(
  previousSnapshot: DealVersionSnapshot | null | undefined,
  currentSnapshot: DealVersionSnapshot | null | undefined
): VersionDiffResult {
  const isFirstVersion = !previousSnapshot;
  const fields: Record<string, FieldDiffItem> = {};
  const changedFieldNames: string[] = [];

  const unitSymbol = currentSnapshot?.unitSymbol || previousSnapshot?.unitSymbol || "MT";

  for (const descriptor of DIFF_FIELD_DESCRIPTORS) {
    const rawOld = descriptor.getter(previousSnapshot);
    const rawNew = descriptor.getter(currentSnapshot);

    const normOld = normalizeVal(rawOld);
    const normNew = normalizeVal(rawNew);

    if (isFirstVersion || normOld === null && normNew === null) {
      fields[descriptor.key] = {
        key: descriptor.key,
        label: descriptor.label,
        oldValue: normOld,
        newValue: normNew,
        state: "unchanged",
        isDifferent: false,
        formattedOld: formatDisplayValue(descriptor.key, normOld, unitSymbol),
        formattedNew: formatDisplayValue(descriptor.key, normNew, unitSymbol),
      };
      continue;
    }

    if (normOld === normNew) {
      fields[descriptor.key] = {
        key: descriptor.key,
        label: descriptor.label,
        oldValue: normOld,
        newValue: normNew,
        state: "unchanged",
        isDifferent: false,
        formattedOld: formatDisplayValue(descriptor.key, normOld, unitSymbol),
        formattedNew: formatDisplayValue(descriptor.key, normNew, unitSymbol),
      };
      continue;
    }

    // Material difference detected
    let state: FieldDiffState = "changed";

    if (normOld === null && normNew !== null) {
      state = "added";
    } else if (normOld !== null && normNew === null) {
      state = "removed";
    } else if (
      descriptor.isNumeric &&
      typeof normOld === "number" &&
      typeof normNew === "number"
    ) {
      if (normNew > normOld) {
        state = "increased";
      } else {
        state = "decreased";
      }
    }

    fields[descriptor.key] = {
      key: descriptor.key,
      label: descriptor.label,
      oldValue: normOld,
      newValue: normNew,
      state,
      isDifferent: true,
      formattedOld: formatDisplayValue(descriptor.key, normOld, unitSymbol),
      formattedNew: formatDisplayValue(descriptor.key, normNew, unitSymbol),
    };

    // Add to summary banner list
    if (descriptor.key !== "totalValuation") {
      changedFieldNames.push(descriptor.label);
    }
  }

  // Deep compare dynamic quality parameters
  const oldQuality = JSON.stringify(previousSnapshot?.qualityParameters || []);
  const newQuality = JSON.stringify(currentSnapshot?.qualityParameters || []);
  if (!isFirstVersion && oldQuality !== newQuality) {
    if (!changedFieldNames.includes("Quality Specifications")) {
      changedFieldNames.push("Quality Specifications");
    }
  }

  return {
    isFirstVersion,
    hasChanges: changedFieldNames.length > 0,
    changedFieldNames,
    fields,
  };
}
