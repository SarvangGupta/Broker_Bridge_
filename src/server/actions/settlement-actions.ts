"use server";

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
import { eq, or, and, desc } from "drizzle-orm";
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
 * Server Action: Calculates and fetches the complete financial settlement overview for the Seller (Micro-Sprint 19.4).
 * 
 * STRICT PRIVACY & FINANCIAL INTEGRITY RULES:
 * 1. Authenticates Seller session and enforces strict tenant isolation.
 * 2. Zero Buyer PII: Strips all buyer contact/personal/banking details at the query boundary.
 * 3. Exact Server-Side Math: Pre-calculates gross values, commissions, net receivables, and outstanding balances.
 * 4. Read-only queries to payments and disputes tables.
 */
export async function getSellerSettlementOverviewAction(): Promise<SellerSettlementOverviewResponse> {
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
    const isPlatformAdmin =
      session.data.user.role === "admin" || session.data.user.role === "ADMIN";

    // 2. Fetch all Bookings
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

    if (!allBookings.length) {
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

    const records: TransactionSettlementRecord[] = [];
    const now = new Date();

    for (const b of allBookings) {
      // 3. Resolve Deal Record
      let dealRecord = await db.query.deals.findFirst({
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

      // Tenant Authorization Check
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

      // 4. Resolve Finalized Version Snapshot
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

      // 5. Query Payments & Disputes (Sprint 11 Tables)
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

      // 6. SERVER-SIDE FINANCIAL MATH ENGINE
      const bookedQty = Number(dealRecord?.agreedQuantity || snap.quantity || 0);
      const lockedRate = Number(dealRecord?.agreedPrice || snap.rate || 0);
      const grossSaleValue = Number((bookedQty * lockedRate).toFixed(2));

      // Commission: Read from snapshot payload or standard ₹25/MT rule
      const brokerCommissionRate = Number(
        (snap as any).commissionRate || (snap as any).brokerCommission || 25
      );
      const brokerCommission = Number((bookedQty * brokerCommissionRate).toFixed(2));
      const otherCharges = Number((snap as any).otherCharges || 0);

      const netReceivable = Math.max(
        0,
        Number((grossSaleValue - brokerCommission - otherCharges).toFixed(2))
      );

      // Sum confirmed payments
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

      // Due Date Calculation (Default: 7 business days from booking or snap.deliveryDate)
      let dueDateObj: Date;
      if (snap.deliveryDate) {
        dueDateObj = new Date(snap.deliveryDate);
      } else {
        dueDateObj = new Date(b.createdAt);
        dueDateObj.setDate(dueDateObj.getDate() + 7);
      }

      const diffTime = dueDateObj.getTime() - now.getTime();
      const dueDaysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      const isPastDue = now > dueDateObj;

      // Check open dispute
      const openDispute = dealDisputes.find((d) => d.status === "Open");

      // Deterministic Status State Machine
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
        bookingId: b.id,
        bookingReference: b.bookingReference,
        dealId: targetDealId,
        quotationId: quotationRecord?.id,
        commodityName: snap.commodityName || "Agricultural Commodity",
        gradeName: snap.gradeName || "Standard Grade",
        lotNumber: snap.lotNumber || lotRecord?.lotNumber || "N/A",
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
        dealStatus: dealRecord?.status || "Confirmed",
        dispute: formattedDispute,
        paymentsList: formattedPaymentsList,
      });
    }

    // 7. Calculate Global Aggregate Summaries
    const totalReceivables = Number(
      records.reduce((sum, r) => sum + r.netReceivable, 0).toFixed(2)
    );
    const totalCollected = Number(
      records.reduce((sum, r) => sum + r.paidAmount, 0).toFixed(2)
    );
    const totalOutstanding = Number(
      records.reduce((sum, r) => sum + r.outstandingAmount, 0).toFixed(2)
    );
    const totalOverdue = Number(
      records
        .filter((r) => r.status === "Overdue")
        .reduce((sum, r) => sum + r.outstandingAmount, 0)
        .toFixed(2)
    );
    const totalCommission = Number(
      records.reduce((sum, r) => sum + r.brokerCommission, 0).toFixed(2)
    );

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
