"use server";

import { cache } from "react";
import { createClient } from "@/lib/supabase/server";
import { db } from "@/src/server/db";
import {
  bookings,
  deals,
  quotations,
  dealVersions,
  availabilities,
  payments,
  disputes,
  users,
} from "@/src/server/db/schema";
import { eq, or, and, desc, inArray } from "drizzle-orm";
import { verifySellerSession } from "@/src/server/utils/seller-auth";
import {
  SettlementStatus,
  SettlementSummary,
  TransactionSettlementRecord,
  PaymentItem,
  DisputeItem,
  SellerSettlementOverviewResponse,
} from "@/src/types/settlement-schema";
import { DealVersionSnapshot } from "@/src/types/deal-version-schema";

/**
 * Server Action: Calculates and fetches the complete financial settlement overview for the Seller.
 * 
 * PERFORMANCE OPTIMIZATION (Task 1 & Task 3):
 * 1. Single Joined Batch Query instead of N+1 sequential loops.
 * 2. Parallel Subqueries using Promise.all for payments & disputes.
 * 3. Wrapped in React cache() for request deduplication across component lifecycle.
 * 4. Strict tenant isolation preserved.
 */
export const getSellerSettlementOverviewAction = cache(
  async function getSellerSettlementOverviewAction(): Promise<SellerSettlementOverviewResponse> {
    try {
      // 1. Authorize Seller Session
      const session = await verifySellerSession({ allowViewer: true });
      if (!session.success || !session.data) {
        return {
          success: false,
          error: session.error || "Unauthorized: Valid seller session required.",
        };
      }

      const sellerCompanyId = session.data.companyId;
      const userId = session.data.user.id;
      const isPlatformAdmin =
        session.data.user.role === "admin" || session.data.user.role === "ADMIN";

      // 2. Single Joined Query: Bookings + Deals + Quotations + Availabilities + Locked Version
      const joinedRows = await db
        .select({
          bookingId: bookings.id,
          bookingReference: bookings.bookingReference,
          dealId: bookings.dealId,
          lockedVersionId: bookings.lockedVersionId,
          bookingStatus: bookings.status,
          bookingCreatedAt: bookings.createdAt,
          // Deal details
          realDealId: deals.id,
          agreedPrice: deals.agreedPrice,
          agreedQuantity: deals.agreedQuantity,
          dealStatus: deals.status,
          dealSellerId: deals.sellerId,
          dealQuotationId: deals.quotationId,
          // Quotation details
          quotationId: quotations.id,
          sellerAvailabilityId: quotations.sellerAvailabilityId,
          // Availability details
          lotNumber: availabilities.lotNumber,
          lotCompanyId: availabilities.companyId,
          // Version details
          versionSnapshot: dealVersions.snapshotPayload,
        })
        .from(bookings)
        .leftJoin(deals, or(eq(bookings.dealId, deals.id), eq(bookings.dealId, deals.quotationId)))
        .leftJoin(quotations, eq(quotations.id, deals.quotationId))
        .leftJoin(availabilities, eq(availabilities.id, quotations.sellerAvailabilityId))
        .leftJoin(dealVersions, eq(dealVersions.id, bookings.lockedVersionId))
        .orderBy(desc(bookings.createdAt));

      if (!joinedRows.length) {
        return {
          success: true,
          data: {
            summary: {
              totalReceivables: 0,
              totalCollected: 0,
              totalOutstanding: 0,
              totalOverdue: 0,
              totalCommission: 0,
              totalRecords: 0,
              paidCount: 0,
              partPaidCount: 0,
              pendingCount: 0,
              overdueCount: 0,
              disputedCount: 0,
            },
            records: [],
          },
        };
      }

      // Filter by Tenant Isolation
      const filtered = joinedRows.filter((r) => {
        if (isPlatformAdmin) return true;
        return (
          r.dealSellerId === sellerCompanyId ||
          r.dealSellerId === userId ||
          r.lotCompanyId === sellerCompanyId
        );
      });

      if (!filtered.length) {
        return {
          success: true,
          data: {
            summary: {
              totalReceivables: 0,
              totalCollected: 0,
              totalOutstanding: 0,
              totalOverdue: 0,
              totalCommission: 0,
              totalRecords: 0,
              paidCount: 0,
              partPaidCount: 0,
              pendingCount: 0,
              overdueCount: 0,
              disputedCount: 0,
            },
            records: [],
          },
        };
      }

      // Collect target deal IDs for batch subqueries
      const dealIds = Array.from(
        new Set(filtered.map((r) => r.realDealId || r.dealId).filter(Boolean))
      ) as string[];

      // 3. Batch Subqueries for Payments & Disputes (Parallel)
      const [allPayments, allDisputes] = dealIds.length > 0
        ? await Promise.all([
            db.query.payments.findMany({
              where: inArray(payments.dealId, dealIds),
              orderBy: desc(payments.createdAt),
            }),
            db.query.disputes.findMany({
              where: inArray(disputes.dealId, dealIds),
              orderBy: desc(disputes.createdAt),
            }),
          ])
        : [[], []];

      const paymentsMap = new Map<string, typeof allPayments>();
      for (const p of allPayments) {
        const list = paymentsMap.get(p.dealId) || [];
        list.push(p);
        paymentsMap.set(p.dealId, list);
      }

      const disputesMap = new Map<string, typeof allDisputes>();
      for (const d of allDisputes) {
        const list = disputesMap.get(d.dealId) || [];
        list.push(d);
        disputesMap.set(d.dealId, list);
      }

      // 4. In-Memory Record Synthesis
      const records: TransactionSettlementRecord[] = [];
      const now = new Date();

      for (const r of filtered) {
        const targetDealId = r.realDealId || r.dealId;
        const snap = (r.versionSnapshot || {}) as DealVersionSnapshot;

        const dealPayments = paymentsMap.get(targetDealId) || [];
        const dealDisputes = disputesMap.get(targetDealId) || [];

        const bookedQty = Number(r.agreedQuantity || snap.quantity || 0);
        const lockedRate = Number(r.agreedPrice || snap.rate || 0);
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

        let dueDateObj: Date;
        if (snap.deliveryDate) {
          dueDateObj = new Date(snap.deliveryDate);
        } else {
          dueDateObj = new Date(r.bookingCreatedAt);
          dueDateObj.setDate(dueDateObj.getDate() + 7);
        }

        const diffTime = dueDateObj.getTime() - now.getTime();
        const dueDaysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        const isPastDue = now > dueDateObj;

        const openDispute = dealDisputes.find((d) => d.status === "Open");

        let status: SettlementStatus;
        if (openDispute) {
          status = "Disputed";
        } else if (outstandingAmount <= 0 && netReceivable > 0) {
          status = "Paid";
        } else if (paidAmount > 0 && outstandingAmount > 0) {
          status = "Part Paid";
        } else if (isPastDue && outstandingAmount > 0) {
          status = "Overdue";
        } else {
          status = "Pending";
        }

        const formattedPaymentsList: PaymentItem[] = dealPayments.map((p) => ({
          id: p.id,
          amount: Number(p.amount),
          referenceNumber: p.referenceNumber,
          status: p.status,
          confirmedAt: p.createdAt.toISOString(),
        }));

        const formattedDispute: DisputeItem | null = openDispute
          ? {
              id: openDispute.id,
              reason: openDispute.reason,
              description: openDispute.description || null,
              status: openDispute.status,
              createdAt: openDispute.createdAt.toISOString(),
            }
          : null;

        records.push({
          bookingId: r.bookingId,
          bookingReference: r.bookingReference,
          dealId: targetDealId,
          quotationId: r.quotationId || r.dealQuotationId || undefined,
          commodityName: snap.commodityName || "Agricultural Commodity",
          gradeName: snap.gradeName || "Standard Grade",
          lotNumber: snap.lotNumber || r.lotNumber || "N/A",
          bookedQuantity: bookedQty,
          unitSymbol: snap.unitSymbol || "MT",
          lockedRate: lockedRate,
          grossSaleValue,
          brokerCommissionRate,
          brokerCommission,
          otherCharges,
          netReceivable,
          paidAmount,
          outstandingAmount,
          dueDate: dueDateObj.toISOString(),
          dueDaysRemaining,
          status,
          dealStatus: r.dealStatus || "Confirmed",
          dispute: formattedDispute,
          paymentsList: formattedPaymentsList,
        });
      }

      // 5. Global Aggregates Calculation
      const totalReceivables = Number(records.reduce((sum, r) => sum + r.netReceivable, 0).toFixed(2));
      const totalCollected = Number(records.reduce((sum, r) => sum + r.paidAmount, 0).toFixed(2));
      const totalOutstanding = Number(records.reduce((sum, r) => sum + r.outstandingAmount, 0).toFixed(2));
      const totalOverdue = Number(
        records
          .filter((r) => r.status === "Overdue")
          .reduce((sum, r) => sum + r.outstandingAmount, 0)
          .toFixed(2)
      );
      const totalCommission = Number(records.reduce((sum, r) => sum + r.brokerCommission, 0).toFixed(2));

      const summary: SettlementSummary = {
        totalReceivables,
        totalCollected,
        totalOutstanding,
        totalOverdue,
        totalCommission,
        totalRecords: records.length,
        paidCount: records.filter((r) => r.status === "Paid").length,
        partPaidCount: records.filter((r) => r.status === "Part Paid").length,
        pendingCount: records.filter((r) => r.status === "Pending").length,
        overdueCount: records.filter((r) => r.status === "Overdue").length,
        disputedCount: records.filter((r) => r.status === "Disputed").length,
      };

      return {
        success: true,
        data: {
          summary,
          records,
        },
      };
    } catch (error: any) {
      console.error("getSellerSettlementOverviewAction error:", error);
      return {
        success: false,
        error: error.message || "Failed to load settlement ledger.",
      };
    }
  }
);
