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
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { DealVersionSnapshot } from '@/src/types/deal-version-schema';

export interface PaymentRecordItem {
  id: string;
  amount: number;
  referenceNumber: string;
  direction: string;
  status: string;
  createdAt: string;
}

export interface BrokerFinancialLedgerPayload {
  bookingId: string;
  bookingReference: string;
  dealId: string;
  commodityName: string;
  gradeName: string;
  lotNumber: string;
  quantity: number;
  unitSymbol: string;
  baseRate: number;
  buyerMarkup: number;
  sellerDeduction: number;
  totalBuyerRate: number;
  totalSellerRate: number;
  buyerPayable: number;
  sellerSettlement: number;
  brokerCommission: number;
  brokerSpreadPerMT: number;
  buyerPaid: number;
  buyerOutstanding: number;
  sellerPaid: number;
  sellerOutstanding: number;
  totalPaidAmount: number;
  totalOutstanding: number;
  settlementStatus: 'Pending' | 'Part Paid' | 'Paid' | 'Overdue' | 'Disputed';
  buyerCompanyName: string;
  sellerCompanyName: string;
  payments: PaymentRecordItem[];
}

export interface LedgerActionResult {
  success: boolean;
  data?: BrokerFinancialLedgerPayload;
  error?: string;
}

/**
 * Server Action: Calculates and fetches the complete financial ledger for a Broker Order.
 * (Micro-Sprint 28.1 - Task 1)
 *
 * STRICT GUARDRAIL:
 * All financial math MUST be computed on the server.
 * Historical commission is immutable, extracted directly from the locked deal snapshot.
 */
export async function getBrokerFinancialLedgerAction(
  bookingIdOrRef: string
): Promise<LedgerActionResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    if (!bookingIdOrRef) {
      return { success: false, error: 'Booking ID or Reference is required' };
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

    const rawInput = bookingIdOrRef.trim();
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(rawInput);

    // 1. Resolve Booking record
    let bookingRecord = await db.query.bookings.findFirst({
      where: eq(bookings.bookingReference, rawInput.toUpperCase()),
    });

    if (!bookingRecord && isUuid) {
      bookingRecord = await db.query.bookings.findFirst({
        where: or(eq(bookings.id, rawInput), eq(bookings.dealId, rawInput)),
      });
    }

    if (!bookingRecord) {
      return { success: false, error: 'Booking record not found' };
    }

    // 2. Fetch Deal and locked version
    const dealRecord = await db.query.deals.findFirst({
      where: or(eq(deals.id, bookingRecord.dealId), eq(deals.quotationId, bookingRecord.dealId)),
    });

    const targetDealId = dealRecord?.id || bookingRecord.dealId;

    const lockedVersion = await db.query.dealVersions.findFirst({
      where: eq(dealVersions.id, bookingRecord.lockedVersionId),
    });

    if (!lockedVersion) {
      return { success: false, error: 'Locked deal version snapshot not found' };
    }

    // 3. Resolve Counterparties (Buyer & Seller Companies)
    let buyerCompanyName = 'Verified Buyer Enterprise';
    let sellerCompanyName = 'Verified Seller Enterprise';

    if (dealRecord?.buyerId) {
      const buyerComp = await db.query.companies.findFirst({
        where: eq(companies.id, dealRecord.buyerId),
      });
      if (buyerComp?.name) buyerCompanyName = buyerComp.name;
    }

    if (dealRecord?.sellerId) {
      const sellerComp = await db.query.companies.findFirst({
        where: eq(companies.id, dealRecord.sellerId),
      });
      if (sellerComp?.name) sellerCompanyName = sellerComp.name;
    }

    // 4. Extract locked snapshot math
    const snap = lockedVersion.snapshotPayload as any;

    const quantity = Number(snap.quantity || dealRecord?.agreedQuantity || 0);
    const baseRate = Number(snap.baseRate || snap.rate || dealRecord?.agreedPrice || 0);
    const buyerMarkup = Number(snap.buyerMarkup || 0);
    const sellerDeduction = Number(snap.sellerDeduction || 0);

    const totalBuyerRate = Number(snap.totalBuyerRate || (baseRate + buyerMarkup));
    const totalSellerRate = Number(snap.totalSellerRate || Math.max(0, baseRate - sellerDeduction));

    const buyerPayable = Number(
      (snap.totalBuyerPayable || (totalBuyerRate * quantity)).toFixed(2)
    );
    const sellerSettlement = Number(
      (snap.totalSellerSettlement || (totalSellerRate * quantity)).toFixed(2)
    );

    const brokerSpreadPerMT = Number(
      (snap.brokerSpreadPerMT || (buyerMarkup + sellerDeduction)).toFixed(2)
    );

    let brokerCommission = Number(
      (snap.totalBrokerCommission || (brokerSpreadPerMT * quantity)).toFixed(2)
    );

    // Fallback: If commission formula yields zero but there is a price differential
    if (brokerCommission === 0 && buyerPayable > sellerSettlement) {
      brokerCommission = Number((buyerPayable - sellerSettlement).toFixed(2));
    }

    // 5. Fetch logged payments for this deal
    const paymentRows = await db.query.payments.findMany({
      where: eq(payments.dealId, targetDealId),
      orderBy: [desc(payments.createdAt)],
    });

    const formattedPayments: PaymentRecordItem[] = paymentRows.map((p: any) => {
      // Parse direction from reference or field if present
      let direction = p.direction || 'Buyer to Broker';
      if (p.referenceNumber && p.referenceNumber.startsWith('[')) {
        const match = p.referenceNumber.match(/^\[(.*?)\]/);
        if (match && match[1]) {
          direction = match[1];
        }
      }

      const cleanRef = p.referenceNumber ? p.referenceNumber.replace(/^\[.*?\]\s*/, '') : 'N/A';

      return {
        id: p.id,
        amount: Number(p.amount || 0),
        referenceNumber: cleanRef,
        direction,
        status: p.status || 'Confirmed',
        createdAt: p.createdAt ? new Date(p.createdAt).toISOString() : new Date().toISOString(),
      };
    });

    // 6. Aggregate Payment Statistics
    const confirmedPayments = formattedPayments.filter(
      (p) => p.status === 'Confirmed' || p.status === 'Success' || p.status === 'Completed'
    );

    let buyerPaid = 0;
    let sellerPaid = 0;

    for (const p of confirmedPayments) {
      if (p.direction.toLowerCase().includes('seller')) {
        sellerPaid += p.amount;
      } else {
        buyerPaid += p.amount;
      }
    }

    buyerPaid = Number(buyerPaid.toFixed(2));
    sellerPaid = Number(sellerPaid.toFixed(2));
    const totalPaidAmount = Number((buyerPaid + sellerPaid).toFixed(2));

    const buyerOutstanding = Math.max(0, Number((buyerPayable - buyerPaid).toFixed(2)));
    const sellerOutstanding = Math.max(0, Number((sellerSettlement - sellerPaid).toFixed(2)));
    const totalOutstanding = Math.max(0, Number((buyerPayable - buyerPaid).toFixed(2)));

    let settlementStatus: 'Pending' | 'Part Paid' | 'Paid' | 'Overdue' | 'Disputed' = 'Pending';
    if (totalOutstanding <= 0 && buyerPayable > 0) {
      settlementStatus = 'Paid';
    } else if (buyerPaid > 0) {
      settlementStatus = 'Part Paid';
    } else {
      settlementStatus = 'Pending';
    }

    return {
      success: true,
      data: {
        bookingId: bookingRecord.id,
        bookingReference: bookingRecord.bookingReference,
        dealId: targetDealId,
        commodityName: snap.commodityName || 'Agricultural Commodity',
        gradeName: snap.gradeName || 'Standard Grade',
        lotNumber: snap.lotNumber || 'N/A',
        quantity,
        unitSymbol: snap.unitSymbol || 'MT',
        baseRate,
        buyerMarkup,
        sellerDeduction,
        totalBuyerRate,
        totalSellerRate,
        buyerPayable,
        sellerSettlement,
        brokerCommission,
        brokerSpreadPerMT,
        buyerPaid,
        buyerOutstanding,
        sellerPaid,
        sellerOutstanding,
        totalPaidAmount,
        totalOutstanding,
        settlementStatus,
        buyerCompanyName,
        sellerCompanyName,
        payments: formattedPayments,
      },
    };
  } catch (err: any) {
    console.error('Error fetching broker financial ledger:', err);
    return {
      success: false,
      error: err.message || 'Failed to fetch broker financial ledger.',
    };
  }
}

const logBrokerPaymentSchema = z.object({
  bookingId: z.string().min(1, 'Booking ID is required'),
  dealId: z.string().min(1, 'Deal ID is required'),
  amount: z.preprocess(
    (val) => (val === '' || val === null || val === undefined ? undefined : Number(val)),
    z.number({ invalid_type_error: 'Amount must be a valid number' }).positive('Amount must be positive')
  ),
  referenceNumber: z.string().min(1, 'Reference/UTR number is required'),
  direction: z.enum(['Buyer to Broker', 'Broker to Seller', 'Direct Settlement']).default('Buyer to Broker'),
  paymentDate: z.string().optional(),
});

export type LogBrokerPaymentInput = z.infer<typeof logBrokerPaymentSchema>;

/**
 * Server Action: Logs a new payment transaction into the payments ledger.
 * (Micro-Sprint 28.1 - Task 3)
 */
export async function logBrokerPaymentAction(
  input: LogBrokerPaymentInput
): Promise<{ success: boolean; data?: any; error?: string; message?: string }> {
  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !authUser) {
      return { success: false, error: 'Unauthorized: Valid broker session required' };
    }

    const validation = logBrokerPaymentSchema.safeParse(input);
    if (!validation.success) {
      const firstErr = validation.error.errors[0]?.message || 'Invalid payment entry';
      return { success: false, error: firstErr };
    }

    const data = validation.data;

    // Verify broker role
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

    // Embed direction into reference number string prefix for backwards compatibility
    const formattedRef = `[${data.direction}] ${data.referenceNumber.trim()}`;

    // Insert payment record
    const [insertedPayment] = await db
      .insert(payments)
      .values({
        dealId: data.dealId,
        amount: data.amount.toString(),
        referenceNumber: formattedRef,
        status: 'Confirmed',
      })
      .returning();

    revalidatePath(`/broker/orders/${data.bookingId}`);
    revalidatePath('/broker/orders');

    return {
      success: true,
      data: insertedPayment,
      message: 'Payment transaction logged successfully.',
    };
  } catch (err: any) {
    console.error('Error logging broker payment:', err);
    return {
      success: false,
      error: err.message || 'Failed to log payment transaction.',
    };
  }
}
