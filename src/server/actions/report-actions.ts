'use server';

import { db } from "@/src/server/db";
import {
  availabilities,
  bookings,
  deals,
  dealVersions,
  dispatches,
  disputes,
  payments,
  quotations,
  companies,
} from "@/src/server/db/schema";
import { eq, or, desc, and } from "drizzle-orm";
import { verifySellerSession } from "@/src/server/utils/seller-auth";
import {
  TimeRange,
  SellerAnalyticsResponse,
  SellerAnalyticsData,
  SalesTimeSeriesPointDTO,
  RecentTransactionDTO,
  InventoryDistributionDTO,
  PipelineDistributionDTO,
  SellerKpisDTO,
} from "@/src/types/report-schema";
import { DealVersionSnapshot } from "@/src/types/deal-version-schema";

/**
 * Server Action: Fetches and calculates high-integrity, server-aggregated
 * analytics and reporting metrics for the authenticated Seller.
 *
 * ZERO BUYER PII & STRICT TENANT ISOLATION:
 * - Aggregation is computed server-side filtered strictly by Seller company ID.
 * - All returned records are transformed into sanitized DTOs with no buyer contact/personal data.
 */
export async function getSellerAnalyticsAction(
  timeRange: TimeRange = '30d'
): Promise<SellerAnalyticsResponse> {
  try {
    // 1. Authorize Seller Session (allow read access to SELLER_VIEWER, SELLER_USER, SELLER_ADMIN)
    const session = await verifySellerSession({ allowViewer: true });
    if (!session.success || !session.data) {
      return {
        success: false,
        error: session.error || "Unauthorized: Valid seller session required.",
      };
    }

    const sellerCompanyId = session.data.companyId;
    const isPlatformAdmin =
      session.data.user.role === "admin" || session.data.user.role === "ADMIN";

    // Resolve company name
    const companyRecord = await db.query.companies.findFirst({
      where: eq(companies.id, sellerCompanyId),
    });
    const companyName = companyRecord?.name || "Seller Enterprise";

    // 2. Compute Inventory Distribution Metrics
    const allSellerLots = await db.query.availabilities.findMany({
      where: isPlatformAdmin ? undefined : eq(availabilities.companyId, sellerCompanyId),
    });

    let totalAvailQty = 0;
    let totalReservedQty = 0;
    let totalSoldQty = 0;
    let totalStockQty = 0;

    for (const lot of allSellerLots) {
      const avail = Number(lot.availableQuantity || 0);
      const res = Number(lot.reservedQuantity || 0);
      const sold = Number(lot.soldQuantity || 0);
      const tot = Number(lot.totalQuantity || (avail + res + sold) || 0);

      totalAvailQty += avail;
      totalReservedQty += res;
      totalSoldQty += sold;
      totalStockQty += tot;
    }

    // Protect against division by zero
    const sumInventory = totalAvailQty + totalReservedQty + totalSoldQty || totalStockQty || 1;
    const inventoryDistribution: InventoryDistributionDTO = {
      availableQuantity: Number(totalAvailQty.toFixed(2)),
      reservedQuantity: Number(totalReservedQty.toFixed(2)),
      soldQuantity: Number(totalSoldQty.toFixed(2)),
      totalQuantity: Number((totalStockQty || sumInventory).toFixed(2)),
      availablePercent: Math.min(100, Math.round((totalAvailQty / sumInventory) * 100)),
      reservedPercent: Math.min(100, Math.round((totalReservedQty / sumInventory) * 100)),
      soldPercent: Math.min(100, Math.round((totalSoldQty / sumInventory) * 100)),
    };

    // 3. Fetch Bookings & Related Deals
    const allBookings = await db
      .select({
        id: bookings.id,
        bookingReference: bookings.bookingReference,
        dealId: bookings.dealId,
        lockedVersionId: bookings.lockedVersionId,
        status: bookings.status,
        createdAt: bookings.createdAt,
      })
      .from(bookings)
      .orderBy(desc(bookings.createdAt));

    // Calculate Date Threshold
    const now = new Date();
    let startDate: Date | null = null;
    if (timeRange === '7d') {
      startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    } else if (timeRange === '30d') {
      startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    }

    let grossRevenue = 0;
    let netReceivables = 0;
    let totalCollected = 0;
    let totalOutstanding = 0;
    let totalOverdue = 0;
    let totalCommission = 0;
    let unitsSold = 0;
    let totalOrdersCount = 0;

    const pipelineCounts: PipelineDistributionDTO = {
      dispatchPending: 0,
      inTransit: 0,
      delivered: 0,
      closed: 0,
    };

    // Time-series date map (key: YYYY-MM-DD)
    const timeSeriesMap = new Map<string, { volume: number; revenue: number; count: number }>();

    // Pre-populate time series buckets for smooth charts
    const numDays = timeRange === '7d' ? 7 : timeRange === '30d' ? 30 : 0;
    if (numDays > 0) {
      for (let i = numDays - 1; i >= 0; i--) {
        const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
        const key = d.toISOString().split('T')[0];
        timeSeriesMap.set(key, { volume: 0, revenue: 0, count: 0 });
      }
    }

    const recentTransactions: RecentTransactionDTO[] = [];

    for (const b of allBookings) {
      // Resolve Deal Record
      const dealRecord = await db.query.deals.findFirst({
        where: or(eq(deals.id, b.dealId), eq(deals.quotationId, b.dealId)),
      });

      const quotationId = dealRecord ? dealRecord.quotationId : b.dealId;
      const quotationRecord = await db.query.quotations.findFirst({
        where: eq(quotations.id, quotationId),
      });

      const lotRecord = quotationRecord?.sellerAvailabilityId
        ? await db.query.availabilities.findFirst({
            where: eq(availabilities.id, quotationRecord.sellerAvailabilityId),
          })
        : null;

      // Strict Tenant Authorization Check
      const dealSellerId = dealRecord?.sellerId;
      const lotCompanyId = lotRecord?.companyId;

      const isOwnedBySeller =
        isPlatformAdmin ||
        dealSellerId === sellerCompanyId ||
        dealSellerId === session.data.user.id ||
        lotCompanyId === sellerCompanyId;

      if (!isOwnedBySeller) {
        continue;
      }

      // Check Pipeline status for all active seller deals
      const dealStatus = dealRecord?.status || "Dispatch Pending";
      const normalizedDealStatus = dealStatus.toLowerCase();

      if (normalizedDealStatus.includes("dispatch") || normalizedDealStatus.includes("pending")) {
        pipelineCounts.dispatchPending++;
      } else if (normalizedDealStatus.includes("transit") || normalizedDealStatus.includes("dispatched")) {
        pipelineCounts.inTransit++;
      } else if (normalizedDealStatus.includes("deliver")) {
        pipelineCounts.delivered++;
      } else if (normalizedDealStatus.includes("close") || normalizedDealStatus.includes("settled")) {
        pipelineCounts.closed++;
      }

      // Resolve Deal Snapshot for financial terms
      let versionRecord = await db.query.dealVersions.findFirst({
        where: eq(dealVersions.id, b.lockedVersionId),
      });

      if (!versionRecord && quotationId) {
        versionRecord = await db.query.dealVersions.findFirst({
          where: eq(dealVersions.requestId, quotationId),
          orderBy: desc(dealVersions.versionNumber),
        });
      }

      const snap = (versionRecord?.snapshotPayload || {}) as DealVersionSnapshot;

      // Query Deal Payments & Disputes
      const targetDealId = dealRecord ? dealRecord.id : b.dealId;
      const [dealPayments, dealDisputes] = await Promise.all([
        db.query.payments.findMany({
          where: eq(payments.dealId, targetDealId),
          orderBy: desc(payments.createdAt),
        }),
        db.query.disputes.findMany({
          where: eq(disputes.dealId, targetDealId),
          orderBy: desc(disputes.createdAt),
        }),
      ]);

      // Server-Side Financial Math
      const bookedQty = Number(dealRecord?.agreedQuantity || snap.quantity || 0);
      const lockedRate = Number(dealRecord?.agreedPrice || snap.rate || 0);
      const grossSaleValue = Number((bookedQty * lockedRate).toFixed(2));

      const brokerCommissionRate = Number(
        (snap as any).commissionRate || (snap as any).brokerCommission || 25
      );
      const brokerCommission = Number((bookedQty * brokerCommissionRate).toFixed(2));
      const otherCharges = Number((snap as any).otherCharges || 0);

      const netReceivable = Math.max(
        0,
        Number((grossSaleValue - brokerCommission - otherCharges).toFixed(2))
      );

      const confirmedPayments = dealPayments.filter(
        (p) => p.status === "Confirmed" || p.status === "Success" || p.status === "Completed"
      );
      const paidAmount = Number(
        confirmedPayments.reduce((sum, p) => sum + Number(p.amount || 0), 0).toFixed(2)
      );
      const outstandingAmount = Math.max(
        0,
        Number((netReceivable - paidAmount).toFixed(2))
      );

      // Due Date & Overdue calculation
      let dueDateObj: Date;
      if (snap.deliveryDate) {
        dueDateObj = new Date(snap.deliveryDate);
      } else {
        dueDateObj = new Date(b.createdAt);
        dueDateObj.setDate(dueDateObj.getDate() + 7);
      }
      const isPastDue = now > dueDateObj;

      // Settlement Status
      const openDispute = dealDisputes.find((d) => d.status === "Open");
      let settlementStatus = "Pending";
      if (openDispute) {
        settlementStatus = "Disputed";
      } else if (outstandingAmount <= 0 && netReceivable > 0) {
        settlementStatus = "Paid";
      } else if (paidAmount > 0 && outstandingAmount > 0) {
        settlementStatus = "Part Paid";
      } else if (isPastDue && outstandingAmount > 0) {
        settlementStatus = "Overdue";
      }

      // Check if within the requested time range for KPIs & Time Series
      const bookingDate = new Date(b.createdAt);
      const isInRange = !startDate || bookingDate >= startDate;

      if (isInRange) {
        grossRevenue += grossSaleValue;
        netReceivables += netReceivable;
        totalCollected += paidAmount;
        totalOutstanding += outstandingAmount;
        if (isPastDue && outstandingAmount > 0) {
          totalOverdue += outstandingAmount;
        }
        totalCommission += brokerCommission;
        unitsSold += bookedQty;
        totalOrdersCount++;

        // Add to Time-Series bucket
        const dateKey = bookingDate.toISOString().split('T')[0];
        const existingBucket = timeSeriesMap.get(dateKey) || { volume: 0, revenue: 0, count: 0 };
        timeSeriesMap.set(dateKey, {
          volume: Number((existingBucket.volume + bookedQty).toFixed(2)),
          revenue: Number((existingBucket.revenue + netReceivable).toFixed(2)),
          count: existingBucket.count + 1,
        });
      }

      // Populate Recent Transactions DTO (Sanitized, zero buyer contact/PII)
      if (recentTransactions.length < 20) {
        recentTransactions.push({
          id: b.id,
          bookingReference: b.bookingReference,
          commodityName: snap.commodityName || "Agricultural Commodity",
          gradeName: snap.gradeName || "Standard Grade",
          lotNumber: snap.lotNumber || lotRecord?.lotNumber || "N/A",
          bookedQuantity: bookedQty,
          unitSymbol: snap.unitSymbol || "MT",
          lockedRate: lockedRate,
          grossSaleValue,
          brokerCommission,
          netReceivable,
          paidAmount,
          outstandingAmount,
          dealStatus,
          settlementStatus,
          createdAt: b.createdAt.toISOString(),
          formattedDate: new Date(b.createdAt).toLocaleDateString("en-IN", {
            day: "2-digit",
            month: "short",
            year: "numeric",
          }),
        });
      }
    }

    // 4. Query Dispatches count
    const sellerDispatches = await db.query.dispatches.findMany({
      where: isPlatformAdmin ? undefined : eq(dispatches.sellerId, session.data.user.id),
    });
    const activeDispatchesCount = sellerDispatches.filter(
      (d) => d.status === "Dispatched" || d.status === "In Transit"
    ).length;

    // 5. Build Sorted Time Series Array
    const timeSeriesList: SalesTimeSeriesPointDTO[] = [];
    const sortedKeys = Array.from(timeSeriesMap.keys()).sort();

    for (const k of sortedKeys) {
      const item = timeSeriesMap.get(k)!;
      const d = new Date(k);
      const displayDate = d.toLocaleDateString("en-IN", {
        month: "short",
        day: "numeric",
      });

      timeSeriesList.push({
        date: k,
        displayDate,
        volume: item.volume,
        revenue: item.revenue,
        dealsCount: item.count,
      });
    }

    // 6. Build KPI DTO
    const kpis: SellerKpisDTO = {
      grossRevenue: Number(grossRevenue.toFixed(2)),
      netReceivables: Number(netReceivables.toFixed(2)),
      totalCollected: Number(totalCollected.toFixed(2)),
      totalOutstanding: Number(totalOutstanding.toFixed(2)),
      totalOverdue: Number(totalOverdue.toFixed(2)),
      totalCommission: Number(totalCommission.toFixed(2)),
      unitsSold: Number(unitsSold.toFixed(2)),
      totalOrdersCount,
      activeDispatchesCount: activeDispatchesCount || pipelineCounts.inTransit + pipelineCounts.dispatchPending,
    };

    const responseData: SellerAnalyticsData = {
      timeRange,
      kpis,
      inventory: inventoryDistribution,
      timeSeries: timeSeriesList,
      pipeline: pipelineCounts,
      recentTransactions,
      companyName,
    };

    return {
      success: true,
      data: responseData,
    };
  } catch (error: any) {
    console.error("getSellerAnalyticsAction error:", error);
    return {
      success: false,
      error: error.message || "Failed to calculate seller reports & analytics",
    };
  }
}
