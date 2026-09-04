import { z } from "zod";

export const DEAL_VERSION_STATUSES = [
  "Draft",
  "Proposed",
  "Countered",
  "Seller Confirmed",
  "Buyer Confirmed",
  "Broker Finalized",
  "Superseded",
] as const;

export type DealVersionStatus = typeof DEAL_VERSION_STATUSES[number];

/**
 * Quality parameter snapshot frozen inside the deal version
 */
export const qualityParameterSnapshotSchema = z.object({
  parameterId: z.string().optional().nullable(),
  name: z.string().min(1, "Parameter name is required"),
  value: z.union([z.string(), z.number()]),
  unit: z.string().optional().nullable(),
  source: z.string().optional().nullable(),
});

/**
 * Loading readiness snapshot frozen inside the deal version
 */
export const loadingReadinessSnapshotSchema = z.object({
  status: z.string().optional().nullable(),
  durationDays: z.number().optional().nullable(),
  loadingStartDate: z.string().optional().nullable(),
  loadingCapacity: z.number().optional().nullable(),
  remarks: z.string().optional().nullable(),
});

/**
 * Comprehensive, immutable commercial snapshot schema.
 * Freezes the exact terms agreed or proposed at a specific point in time.
 */
export const dealVersionSnapshotSchema = z.object({
  // Commodity & Classification Hierarchy
  commodityId: z.string().min(1, "Commodity ID is required"),
  commodityName: z.string().min(1, "Commodity name is required"),
  categoryId: z.string().optional().nullable(),
  categoryName: z.string().optional().nullable(),
  industryId: z.string().optional().nullable(),
  industryName: z.string().optional().nullable(),
  gradeId: z.string().optional().nullable(),
  gradeName: z.string().optional().nullable(),

  // Lot & Supply Traceability
  lotId: z.string().optional().nullable(),
  lotNumber: z.string().optional().nullable(),

  // Quantity & Units
  quantity: z.preprocess(
    (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
    z.number({ invalid_type_error: "Quantity must be a valid number" }).positive("Quantity must be positive")
  ),
  unitId: z.string().optional().nullable(),
  unitSymbol: z.string().min(1, "Unit symbol is required"),

  // Commercial Pricing & Rates
  rate: z.preprocess(
    (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
    z.number({ invalid_type_error: "Rate must be a valid number" }).positive("Rate must be positive")
  ),
  brokerageRate: z.preprocess(
    (val) => (val === "" || val === null || val === undefined || isNaN(Number(val)) ? undefined : Number(val)),
    z.number().nonnegative().optional().nullable()
  ),

  // Logistics & Delivery Terms
  deliveryState: z.string().optional().nullable(),
  deliveryDistrict: z.string().optional().nullable(),
  deliveryLocation: z.string().optional().nullable(),
  deliveryTerms: z.string().optional().nullable(),
  deliveryDate: z.string().optional().nullable(),

  // Payment & Packaging
  paymentTerms: z.string().optional().nullable(),
  packagingType: z.string().optional().nullable(),

  // Dynamic Quality & Evidence Snapshots
  qualityNotes: z.string().optional().nullable(),
  qualityParameters: z.array(qualityParameterSnapshotSchema).optional().nullable(),
  loadingReadiness: loadingReadinessSnapshotSchema.optional().nullable(),

  // Special Conditions & Remarks
  specialConditions: z.string().max(1000, "Special conditions cannot exceed 1000 characters").optional().nullable(),
  remarks: z.string().max(1000, "Remarks cannot exceed 1000 characters").optional().nullable(),
  
  // Originator & Timestamp Metadata
  originatorRole: z.enum(["broker", "seller", "buyer", "admin"]).optional(),
  timestamp: z.string().optional(),
});

export type DealVersionSnapshot = z.infer<typeof dealVersionSnapshotSchema>;

/**
 * Server Action input schema for creating a new immutable Deal Version.
 */
export const createDealVersionInputSchema = z.object({
  requestId: z.string().uuid("Valid broker request/deal ID is required"),
  status: z.enum(DEAL_VERSION_STATUSES).default("Proposed"),
  expectedVersionNumber: z.number().int().positive().optional(),
  expected_version_number: z.number().int().positive().optional(),
  snapshot: dealVersionSnapshotSchema,
});

export type CreateDealVersionInput = z.infer<typeof createDealVersionInputSchema>;

/**
 * Deal version database record representation
 */
export interface DealVersionRecord {
  id: string;
  requestId: string;
  versionNumber: number;
  actorId: string;
  actorName?: string | null;
  actorRole?: string | null;
  status: DealVersionStatus;
  snapshotPayload: DealVersionSnapshot;
  createdAt: Date | string;
}

export interface NegotiationTimelineItem {
  id: string;
  requestId: string;
  type: "DEAL_VERSION" | "NEGOTIATION_ACTION" | "PROPOSAL_INITIATED";
  title: string;
  status: string;
  actorName: string;
  actorRole: "Seller" | "Broker" | "Buyer" | "System" | "Admin";
  isSeller: boolean;
  versionNumber?: number | null;
  summary: string;
  details?: Record<string, any> | null;
  createdAt: string;
}

