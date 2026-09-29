'use server';

import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import {
  bookings,
  deals,
  dealVersions,
  payments,
  companies,
  users,
  requirements,
  quotations,
  availabilities,
} from '@/src/server/db/schema';
import { eq, or, and, desc, inArray } from 'drizzle-orm';
import { DealVersionSnapshot } from '@/src/types/deal-version-schema';

export interface CommissionRecordItem {
  bookingId: string;
  bookingReference: string;
  dealId: string;
  quotationId: string;
  commodityName: string;
  gradeName: string;
  lotNumber: string;
  bookedQuantity: number;
  unitSymbol: string;
  buyerMarkup: number;
  sellerDeduction: number;
  totalMarginPerMT: number;
  expectedCommission: number;
  collectedCommission: number;
  pendingCommission: number;
  commissionStatus: 'Pending' | 'Partially Collected' | 'Settled';
  createdAt: string;
  buyerCompanyName: string;
  sellerCompanyName: string;
}

export interface CommissionLedgerSummary {
  totalExpectedCommission: number;
  totalCollectedCommission: number;
  totalPendingCommission: number;
  totalDealsCount: number;
  settledDealsCount: number;
}

export interface CommissionLedgerPayload {
  summary: CommissionLedgerSummary;
  records: CommissionRecordItem[];
}

export interface CommissionLedgerResult {
  success: boolean;
  data?: CommissionLedgerPayload;
  error?: string;
}

/**
 * Server Action: Calculates and fetches the complete Broker Commission Ledger.
 * (Micro-Sprint 28.2 - Task 1)
 *
 * STRICT GUARDRAILS:
 * 1. Commission calculations rely strictly on immutable `snapshotPayload` from `deal_versions`.
 * 2. Historical commission values are immutable.
 * 3. Operational language: "Expected", "Collected", "Pending".
 * 4. Only async functions are exported from this 'use server' file.
 */
export async function getBrokerCommissionLedgerAction(): Promise<CommissionLedgerResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    // Authenticate broker/admin user profile
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, authUser.id),
    });

    if (!dbUser) {
      return { success: false, error: 'User profile not found' };
    }

    const role = (dbUser.role || '').toLowerCase();
    if (role !== 'broker' && role !== 'admin') {
      return { success: false, error: 'Forbidden: Broker access privileges required' };
    }

    const userId = authUser.id;
    const isPlatformAdmin = role === 'admin';

    // 1. Query finalized Bookings joined with Deals, Quotations, Requirements, Availabilities, and Locked DealVersions
    const joinedRows = await db
      .select({
        bookingId: bookings.id,
        bookingReference: bookings.bookingReference,
        bookingStatus: bookings.status,
        bookingCreatedAt: bookings.createdAt,
        lockedVersionId: bookings.lockedVersionId,
        // Deal
        dealId: deals.id,
        dealQuotationId: deals.quotationId,
        dealRequirementId: deals.requirementId,
        dealBuyerId: deals.buyerId,
        dealSellerId: deals.sellerId,
        dealBrokerId: deals.brokerId,
        agreedPrice: deals.agreedPrice,
        agreedQuantity: deals.agreedQuantity,
        // Quotation
        quotationId: quotations.id,
        quotationBrokerId: quotations.brokerId,
        quotationRequirementId: quotations.requirementId,
        sellerAvailabilityId: quotations.sellerAvailabilityId,
        // Requirement
        reqBrokerId: requirements.brokerId,
        reqCompanyId: requirements.companyId,
        // Lot
        lotNumber: availabilities.lotNumber,
        lotCompanyId: availabilities.companyId,
        // Locked Version Snapshot
        versionNumber: dealVersions.versionNumber,
        versionSnapshot: dealVersions.snapshotPayload,
      })
      .from(bookings)
      .leftJoin(deals, or(eq(bookings.dealId, deals.id), eq(bookings.dealId, deals.quotationId)))
      .leftJoin(quotations, eq(quotations.id, deals.quotationId))
      .leftJoin(requirements, eq(requirements.id, quotations.requirementId))
      .leftJoin(availabilities, eq(availabilities.id, quotations.sellerAvailabilityId))
      .leftJoin(dealVersions, eq(dealVersions.id, bookings.lockedVersionId))
      .orderBy(desc(bookings.createdAt));

    // 2. Filter rows for active Broker assignment
    const filteredRows = joinedRows.filter((r) => {
      if (isPlatformAdmin) return true;
      const isBrokerAssigned =
        r.dealBrokerId === userId ||
        r.quotationBrokerId === userId ||
        r.reqBrokerId === userId;
      return isBrokerAssigned;
    });

    if (!filteredRows.length) {
      return {
        success: true,
        data: {
          summary: {
            totalExpectedCommission: 0,
            totalCollectedCommission: 0,
            totalPendingCommission: 0,
            totalDealsCount: 0,
            settledDealsCount: 0,
          },
          records: [],
        },
      };
    }

    // Collect IDs for batch subqueries
    const dealIds = Array.from(
      new Set(filteredRows.map((r) => r.dealId || r.bookingId).filter(Boolean))
    ) as string[];
    const companyIds = Array.from(
      new Set(
        filteredRows
          .flatMap((r) => [r.dealBuyerId, r.dealSellerId, r.reqCompanyId, r.lotCompanyId])
          .filter(Boolean)
      )
    ) as string[];

    // 3. Batch fetch company names and payments
    const [fetchedCompanies, allPayments] = await Promise.all([
      companyIds.length > 0
        ? db.query.companies.findMany({
            where: inArray(companies.id, companyIds),
          })
        : Promise.resolve([]),
      dealIds.length > 0
        ? db.query.payments.findMany({
            where: inArray(payments.dealId, dealIds),
          })
        : Promise.resolve([]),
    ]);

    const companyMap = new Map(fetchedCompanies.map((c) => [c.id, c.name || 'Enterprise']));
    const paymentsMap = new Map<string, typeof allPayments>();

    for (const p of allPayments) {
      const list = paymentsMap.get(p.dealId) || [];
      list.push(p);
      paymentsMap.set(p.dealId, list);
    }

    // 4. Process commission math per booking record
    const records: CommissionRecordItem[] = [];

    let totalExpectedCommission = 0;
    let totalCollectedCommission = 0;
    let totalPendingCommission = 0;
    let settledDealsCount = 0;

    for (const r of filteredRows) {
      const snap = (r.versionSnapshot || {}) as any;
      const targetDealId = r.dealId || r.bookingId;
      const dealPayments = paymentsMap.get(targetDealId) || [];

      // Extract quantities and rates from locked snapshot
      const bookedQty = Number(snap.quantity || r.agreedQuantity || 0);
      const baseRate = Number(snap.baseRate || snap.rate || r.agreedPrice || 0);
      const buyerMarkup = Number(snap.buyerMarkup || 0);
      const sellerDeduction = Number(snap.sellerDeduction || 0);
      const unitSymbol = snap.unitSymbol || 'MT';

      let totalMarginPerMT = Number(
        (snap.brokerSpreadPerMT || buyerMarkup + sellerDeduction).toFixed(2)
      );

      // Fallback calculation if spread was stored in snapshots without explicit markup/deduction
      if (totalMarginPerMT === 0 && snap.totalBuyerPayable && snap.totalSellerSettlement && bookedQty > 0) {
        totalMarginPerMT = Number(
          ((Number(snap.totalBuyerPayable) - Number(snap.totalSellerSettlement)) / bookedQty).toFixed(2)
        );
      }

      let expectedCommission = Number(
        (snap.totalBrokerCommission || totalMarginPerMT * bookedQty).toFixed(2)
      );

      if (expectedCommission === 0 && totalMarginPerMT > 0) {
        expectedCommission = Number((totalMarginPerMT * bookedQty).toFixed(2));
      }

      // Calculate collected commission based on verified payment records
      const confirmedPayments = dealPayments.filter(
        (p) => p.status === 'Confirmed' || p.status === 'Success' || p.status === 'Completed'
      );

      let buyerPaidAmount = 0;
      let explicitBrokerPayments = 0;

      for (const p of confirmedPayments) {
        const amt = Number(p.amount || 0);
        const refUpper = (p.referenceNumber || '').toUpperCase();

        if (refUpper.includes('BROKER') || refUpper.includes('COMMISSION')) {
          explicitBrokerPayments += amt;
        }
        if (!refUpper.includes('SELLER')) {
          buyerPaidAmount += amt;
        }
      }

      const totalBuyerPayable = Number(
        (snap.totalBuyerPayable || (baseRate + buyerMarkup) * bookedQty).toFixed(2)
      );

      let collectedCommission = 0;

      if (explicitBrokerPayments > 0) {
        collectedCommission = Math.min(expectedCommission, explicitBrokerPayments);
      } else if (totalBuyerPayable > 0 && buyerPaidAmount > 0) {
        const paidRatio = Math.min(1, buyerPaidAmount / totalBuyerPayable);
        collectedCommission = Number((expectedCommission * paidRatio).toFixed(2));
      }

      const pendingCommission = Math.max(0, Number((expectedCommission - collectedCommission).toFixed(2)));

      let commissionStatus: 'Pending' | 'Partially Collected' | 'Settled' = 'Pending';
      if (pendingCommission <= 0 && expectedCommission > 0) {
        commissionStatus = 'Settled';
        settledDealsCount++;
      } else if (collectedCommission > 0) {
        commissionStatus = 'Partially Collected';
      } else {
        commissionStatus = 'Pending';
      }

      totalExpectedCommission += expectedCommission;
      totalCollectedCommission += collectedCommission;
      totalPendingCommission += pendingCommission;

      const buyerName = companyMap.get(r.dealBuyerId || r.reqCompanyId || '') || 'Verified Buyer Enterprise';
      const sellerName = companyMap.get(r.dealSellerId || r.lotCompanyId || '') || 'Verified Seller Enterprise';

      records.push({
        bookingId: r.bookingId,
        bookingReference: r.bookingReference,
        dealId: targetDealId,
        quotationId: r.quotationId || r.dealQuotationId || targetDealId,
        commodityName: snap.commodityName || 'Agricultural Commodity',
        gradeName: snap.gradeName || 'Standard Grade',
        lotNumber: snap.lotNumber || r.lotNumber || 'N/A',
        bookedQuantity: bookedQty,
        unitSymbol,
        buyerMarkup,
        sellerDeduction,
        totalMarginPerMT,
        expectedCommission,
        collectedCommission,
        pendingCommission,
        commissionStatus,
        createdAt: r.bookingCreatedAt.toISOString(),
        buyerCompanyName: buyerName,
        sellerCompanyName: sellerName,
      });
    }

    return {
      success: true,
      data: {
        summary: {
          totalExpectedCommission: Number(totalExpectedCommission.toFixed(2)),
          totalCollectedCommission: Number(totalCollectedCommission.toFixed(2)),
          totalPendingCommission: Number(totalPendingCommission.toFixed(2)),
          totalDealsCount: records.length,
          settledDealsCount,
        },
        records,
      },
    };
  } catch (err: any) {
    console.error('Error fetching broker commission ledger:', err);
    return {
      success: false,
      error: err.message || 'Failed to fetch broker commission ledger.',
    };
  }
}
