export type TimeRange = '7d' | '30d' | 'all';

export interface SellerKpisDTO {
  grossRevenue: number;
  netReceivables: number;
  totalCollected: number;
  totalOutstanding: number;
  totalOverdue: number;
  totalCommission: number;
  unitsSold: number; // in Metric Tons / primary unit
  totalOrdersCount: number;
  activeDispatchesCount: number;
}

export interface InventoryDistributionDTO {
  availableQuantity: number;
  reservedQuantity: number;
  soldQuantity: number;
  totalQuantity: number;
  availablePercent: number;
  reservedPercent: number;
  soldPercent: number;
}

export interface SalesTimeSeriesPointDTO {
  date: string; // ISO date format YYYY-MM-DD
  displayDate: string; // Formatted e.g. "Sep 02"
  volume: number; // in MT
  revenue: number; // in INR
  dealsCount: number;
}

export interface PipelineDistributionDTO {
  dispatchPending: number;
  inTransit: number;
  delivered: number;
  closed: number;
}

export interface RecentTransactionDTO {
  id: string;
  bookingReference: string;
  commodityName: string;
  gradeName: string;
  lotNumber: string;
  bookedQuantity: number;
  unitSymbol: string;
  lockedRate: number;
  grossSaleValue: number;
  brokerCommission: number;
  netReceivable: number;
  paidAmount: number;
  outstandingAmount: number;
  dealStatus: string;
  settlementStatus: string;
  createdAt: string;
  formattedDate: string;
}

export interface SellerAnalyticsData {
  timeRange: TimeRange;
  kpis: SellerKpisDTO;
  inventory: InventoryDistributionDTO;
  timeSeries: SalesTimeSeriesPointDTO[];
  pipeline: PipelineDistributionDTO;
  recentTransactions: RecentTransactionDTO[];
  companyName: string;
}

export type SellerAnalyticsResponse =
  | { success: true; data: SellerAnalyticsData; error?: undefined }
  | { success: false; error: string; data?: undefined };
