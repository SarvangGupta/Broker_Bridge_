/**
 * Buyer Order & Booking Visibility Types (Micro-Sprints 38.1 & 38.2)
 * Defined according to Buyer PRD Sprint 38 (Orders, Booking & Delivery).
 */

export type BuyerBookingStatus =
  | 'Confirmed'
  | 'Booked'
  | 'Dispatch Planned'
  | 'Dispatched'
  | 'In Transit'
  | 'Delivered'
  | 'Completed'
  | 'Cancelled'
  | 'Awaiting Broker Finalization';

export interface BuyerBookingVisibilityData {
  bookingId: string; // The physical Booking reference (e.g. 'BKG-2026-1042')
  bookingUuid?: string; // Primary key UUID in bookings table
  bookingStatus: BuyerBookingStatus | string;
  createdAt: string; // ISO date string
  dealId: string;
  dealReference: string; // e.g. 'DEAL-BKG-1042'
  requirementId?: string;
  requirementReference?: string; // e.g. 'REQ-XXXX'
  commodityName: string;
  gradeName?: string;
  finalQuantity: number;
  unitSymbol: string;
  finalRate: number; // ₹ per unit
  totalEstimatedValue: number;
  deliveryTerms?: string;
  paymentTerms?: string;
  brokerAgency?: string;
  isBrokerFinalized: boolean;
  // Partial Fulfillment Math (Micro-Sprint 38.3)
  originalQuantity?: number;
  bookedQuantity?: number;
  remainingQuantity?: number;
  fulfillmentPercentage?: number;
  fulfillmentMath?: OrderFulfillmentMath;
  // Live Dispatch & Delivery Logistics (Micro-Sprints 38.4 & 38.5)
  dispatchDetails?: BuyerDispatchDetails | null;
  hasActiveDispatch?: boolean;
}

export interface BuyerDispatchDocument {
  id: string;
  documentType: 'LR' | 'E-Way Bill' | 'Invoice' | string;
  fileName: string;
  filePath: string;
  signedUrl?: string | null;
  uploadedAt?: string;
}

export interface BuyerDispatchDetails {
  id: string;
  dispatchReference?: string;
  dispatchDate: string; // ISO date string
  expectedDeliveryDate: string; // ISO date string (ETA)
  dispatchedQuantity: number; // Loaded Quantity
  unitSymbol?: string;
  vehicleNumber: string;
  vehicleType?: string;
  transporterName: string;
  driverName?: string;
  driverMobile?: string;
  loadingLocation: string;
  destination: string;
  status: string; // 'Booked' | 'Dispatch Planned' | 'Dispatched' | 'In Transit' | 'Delivered' | 'Completed' | 'Delayed' | 'Cancelled' | 'Disputed'
  documents: BuyerDispatchDocument[];
}

export interface OrderFulfillmentMath {
  originalQuantity: number;
  bookedQuantity: number;
  remainingQuantity: number;
  fulfillmentPercentage: number;
  unitSymbol: string;
  isPartialFulfillment: boolean;
}

export type BuyerBookingVisibilityResponse =
  | {
      success: true;
      data: BuyerBookingVisibilityData;
      isPendingBrokerFinalization?: boolean;
      error?: undefined;
    }
  | {
      success: false;
      error: string;
      data?: undefined;
      isPendingBrokerFinalization?: boolean;
    };

/**
 * Task 1 (Micro-Sprint 38.2): Buyer Orders List Types.
 */
export interface BuyerOrderItem {
  id: string; // Booking UUID or Deal UUID
  bookingId: string; // e.g. 'BKG-2026-1042'
  status: BuyerBookingStatus | string;
  createdAt: string; // ISO date string
  dealId: string;
  dealReference: string;
  commodityName: string;
  gradeName?: string;
  finalQuantity: number;
  unitSymbol: string;
  finalRate: number; // ₹ per unit
  totalEstimatedValue: number;
  deliveryLocation: string;
  deliveryTerms?: string;
  paymentTerms?: string;
  brokerAgency?: string;
}

export interface BuyerOrdersListFilters {
  status?: string;
  search?: string;
}

export type BuyerOrdersListResponse =
  | {
      success: true;
      data: BuyerOrderItem[];
      error?: undefined;
    }
  | {
      success: false;
      error: string;
      data: BuyerOrderItem[];
    };
