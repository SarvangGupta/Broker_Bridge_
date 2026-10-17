'use server';

import { db } from '@/src/server/db';
import {
  bookings,
  deals,
  dealVersions,
  payments,
  requirements,
  masterCommodities,
  masterGrades,
  disputes,
} from '@/src/server/db/schema';
import { eq, or, and, desc } from 'drizzle-orm';
import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';
import {
  BuyerPayableItem,
  BuyerPayableLedgerData,
  BuyerPayableLedgerResponse,
  BuyerPayablesOverview,
  BuyerPaymentRecord,
  BuyerPaymentStatus,
} from '@/src/types/buyer-payment-types';

/**
 * Server-side currency formatter using standard Indian Rupee notation.
 */
function formatINR(val: number): string {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(Math.round(val));
}

/**
 * Task 2 (Micro-Sprint 39.3): Financial Ledger Server Action.
 * 
 * Retrieves Buyer payable ledger and financial status with server-side math engine.
 * 
 * Strict Security Guardrails:
 * 1. Server-Side Math Engine: All financial arithmetic is computed on the server.
 *    UI receives pre-calculated numbers to prevent floating-point discrepancies.
 * 2. Multi-Tenant Organization Isolation: Validates that calling Buyer company owns the booking/deal.
 * 3. Nodal Escrow Model: Strip all Seller bank credentials, internal notes, and direct contact info.
 *    The Buyer pays the platform nodal account.
 * 4. Read-Only Invariant: Zero payment mutation or creation paths in this action file.
 */
export async function getBuyerPayableLedgerAction(
  bookingIdOrRef?: string
): Promise<BuyerPayableLedgerResponse> {
  try {
    if (bookingIdOrRef !== undefined && typeof bookingIdOrRef === 'string' && bookingIdOrRef.trim() === '') {
      return {
        success: false,
        error: 'Booking identifier cannot be empty.',
      };
    }

    const rawInput = bookingIdOrRef ? bookingIdOrRef.trim() : '';

    // Authenticate Buyer Session via @supabase/ssr
    const sessionRes = await verifyBuyerSession();
    if (!sessionRes.success || !sessionRes.data?.companyId) {
      return {
        success: true,
        data: {
          singlePayable: null,
          overview: {
            totalActiveOrders: 0,
            totalGrossPayable: 0,
            formattedTotalGrossPayable: '₹ 0',
            totalAmountPaid: 0,
            formattedTotalAmountPaid: '₹ 0',
            totalOutstandingBalance: 0,
            formattedTotalOutstandingBalance: '₹ 0',
            overdueCount: 0,
          },
          payables: [],
          lastUpdated: new Date().toISOString(),
        },
      };
    }

    const { companyId: buyerCompanyId } = sessionRes.data;
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(rawInput);

    // 3. Query Database for Bookings & Associated Deals
    let targetBookings: any[] = [];

    if (rawInput) {
      let bRecord = await db.query.bookings.findFirst({
        where: eq(bookings.bookingReference, rawInput.toUpperCase()),
      });

      if (!bRecord && isUuid) {
        bRecord = await db.query.bookings.findFirst({
          where: or(eq(bookings.id, rawInput), eq(bookings.dealId, rawInput)),
        });
      }

      if (bRecord) {
        targetBookings = [bRecord];
      }
    } else {
      // Query all bookings for this buyer's company
      const buyerDeals = await db.query.deals.findMany({
        where: eq(deals.buyerId, buyerCompanyId),
        orderBy: [desc(deals.createdAt)],
      });

      const dealIds = buyerDeals.map((d) => d.id);
      if (dealIds.length > 0) {
        targetBookings = await db.query.bookings.findMany({
          where: or(...dealIds.map((id) => eq(bookings.dealId, id))),
          orderBy: [desc(bookings.createdAt)],
        });
      }
    }

    // Fallback to mock dataset if no seeded database records exist yet in dev
    if (targetBookings.length === 0) {
      if (rawInput) {
        // If an explicit booking ID was queried that doesn't exist in DB or mock
        return {
          success: false,
          error: 'Booking record not found or access restricted under organization boundary.',
        };
      }
      return {
        success: true,
        data: {
          singlePayable: null,
          overview: {
            totalActiveOrders: 0,
            totalGrossPayable: 0,
            formattedTotalGrossPayable: '₹ 0',
            totalAmountPaid: 0,
            formattedTotalAmountPaid: '₹ 0',
            totalOutstandingBalance: 0,
            formattedTotalOutstandingBalance: '₹ 0',
            overdueCount: 0,
          },
          payables: [],
          lastUpdated: new Date().toISOString(),
        },
      };
    }

    const payableItems: BuyerPayableItem[] = [];

    for (const b of targetBookings) {
      const dealRecord = await db.query.deals.findFirst({
        where: eq(deals.id, b.dealId),
      });

      if (!dealRecord) continue;

      // Tenant isolation verification
      if (dealRecord.buyerId !== buyerCompanyId) {
        continue;
      }

      // Fetch locked commercial snapshot from deal_versions (Task 2)
      let finalQuantity = Number(dealRecord.agreedQuantity || 0);
      let lockedBaseRate = Number(dealRecord.agreedPrice || 0);

      if (dealRecord.requirementId) {
        const lockedVersion = await db.query.dealVersions.findFirst({
          where: and(
            eq(dealVersions.requestId, dealRecord.requirementId),
            eq(dealVersions.status, 'LOCKED')
          ),
          orderBy: [desc(dealVersions.versionNumber)],
        });

        if (lockedVersion?.snapshotPayload) {
          const snap =
            typeof lockedVersion.snapshotPayload === 'string'
              ? JSON.parse(lockedVersion.snapshotPayload)
              : (lockedVersion.snapshotPayload as any);
          if (snap.quantity) finalQuantity = Number(snap.quantity);
          if (snap.pricePerUnit) lockedBaseRate = Number(snap.pricePerUnit);
          else if (snap.agreedPrice) lockedBaseRate = Number(snap.agreedPrice);
        }
      }

      // Resolve requirement record for commodity/grade
      const requirementRecord = dealRecord.requirementId
        ? await db.query.requirements.findFirst({
            where: eq(requirements.id, dealRecord.requirementId),
          })
        : null;

      let commodityName = 'Agricultural Commodity';
      let gradeName = 'Standard Commercial Grade';

      if (requirementRecord?.commodityId) {
        const c = await db.query.masterCommodities.findFirst({
          where: eq(masterCommodities.id, requirementRecord.commodityId),
        });
        if (c) commodityName = c.name;
      }

      if (requirementRecord?.gradeId) {
        const g = await db.query.masterGrades.findFirst({
          where: eq(masterGrades.id, requirementRecord.gradeId),
        });
        if (g) gradeName = g.gradeName;
      }

      // Fetch confirmed payments for this deal
      const paymentRows = await db.query.payments.findMany({
        where: eq(payments.dealId, dealRecord.id),
        orderBy: [desc(payments.createdAt)],
      });

      // Check for active dispute
      const disputeRecord = await db.query.disputes.findFirst({
        where: and(eq(disputes.dealId, dealRecord.id), eq(disputes.status, 'Open')),
      });

      // SERVER-SIDE MATH ENGINE:
      const baseAmount = Math.round(finalQuantity * lockedBaseRate);

      // Statutory taxes & buyer charges (mandi cess, platform brokerage: 2.5%)
      const chargesAndTaxes = Math.round(baseAmount * 0.025);
      const grossPayable = baseAmount + chargesAndTaxes;

      // Sum all confirmed payments
      const confirmedPayments = paymentRows.filter(
        (p) => p.status === 'Confirmed' || p.status === 'Completed'
      );
      const totalPaid = confirmedPayments.reduce(
        (sum, p) => sum + Number(p.amount || 0),
        0
      );

      const outstandingBalance = Math.max(0, grossPayable - totalPaid);

      // Payment Status calculation
      let paymentStatus: BuyerPaymentStatus = 'Pending';
      if (disputeRecord) {
        paymentStatus = 'Disputed';
      } else if (outstandingBalance <= 0) {
        paymentStatus = 'Paid';
      } else if (totalPaid > 0) {
        paymentStatus = 'Part Paid';
      } else {
        paymentStatus = 'Pending';
      }

      const paymentRecords: BuyerPaymentRecord[] = paymentRows.map((p) => ({
        id: p.id,
        referenceNumber: p.referenceNumber,
        amount: Number(p.amount),
        formattedAmount: formatINR(Number(p.amount)),
        status: p.status === 'Confirmed' ? 'Confirmed' : 'Processing',
        paymentDate: p.createdAt ? p.createdAt.toISOString() : new Date().toISOString(),
        paymentMethod: 'NEFT / RTGS Escrow',
      }));

      const escrowVirtualAccount = `BB-NODAL-${b.bookingReference.replace(/[^A-Z0-9]/gi, '')}`;

      payableItems.push({
        bookingId: b.bookingReference,
        dealId: dealRecord.id,
        dealReference: `DEAL-${dealRecord.id.substring(0, 8).toUpperCase()}`,
        commodityName,
        gradeName,
        finalQuantity,
        unitSymbol: 'MT',
        lockedBaseRate,
        formattedLockedBaseRate: formatINR(lockedBaseRate),
        baseAmount,
        formattedBaseAmount: formatINR(baseAmount),
        chargesAndTaxes,
        formattedChargesAndTaxes: formatINR(chargesAndTaxes),
        grossPayable,
        formattedGrossPayable: formatINR(grossPayable),
        totalPaid,
        formattedTotalPaid: formatINR(totalPaid),
        outstandingBalance,
        formattedOutstandingBalance: formatINR(outstandingBalance),
        paymentStatus,
        isOverdue: false,
        paymentRecords,
        nodalAccountName: 'BrokerBridge Trade Settlement Escrow (HDFC Bank Nodal Account)',
        escrowReference: escrowVirtualAccount,
        disclaimer:
          'Payments are held securely in the regulated BrokerBridge Nodal Escrow account and disbursed to the Seller strictly upon physical delivery verification. Do not transfer funds to private seller accounts.',
      });
    }

    // Compute Global Overview Aggregations
    const totalActiveOrders = payableItems.length;
    const totalGrossPayable = payableItems.reduce((acc, i) => acc + i.grossPayable, 0);
    const totalAmountPaid = payableItems.reduce((acc, i) => acc + i.totalPaid, 0);
    const totalOutstandingBalance = payableItems.reduce((acc, i) => acc + i.outstandingBalance, 0);
    const overdueCount = payableItems.filter((i) => i.isOverdue).length;

    const overview: BuyerPayablesOverview = {
      totalActiveOrders,
      totalGrossPayable,
      formattedTotalGrossPayable: formatINR(totalGrossPayable),
      totalAmountPaid,
      formattedTotalAmountPaid: formatINR(totalAmountPaid),
      totalOutstandingBalance,
      formattedTotalOutstandingBalance: formatINR(totalOutstandingBalance),
      overdueCount,
    };

    const singlePayable =
      rawInput && payableItems.length > 0 ? payableItems[0] : null;

    return {
      success: true,
      data: {
        singlePayable,
        overview,
        payables: payableItems,
        lastUpdated: new Date().toISOString(),
      },
    };
  } catch (err: any) {
    console.error('getBuyerPayableLedgerAction error:', err);
    return {
      success: false,
      error: err.message || 'Failed to retrieve buyer payable ledger.',
    };
  }
}


