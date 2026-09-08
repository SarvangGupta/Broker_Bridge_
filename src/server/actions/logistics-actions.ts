'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { dispatches, invoices, deals, users } from "@/src/server/db/schema"
import { eq } from "drizzle-orm"
import { dispatchSchema, invoiceSchema, DispatchData, InvoiceData } from "@/src/types/logistics-schema"
import { verifySellerSession } from "@/src/server/utils/seller-auth"

/**
 * Creates a shipment dispatch record for a booked deal.
 * Gated by verifySellerSession({ allowViewer: false }) and verifies company-level deal ownership.
 */
export async function createDispatchAction(data: DispatchData) {
  try {
    // 1. Authorize session & verify mutation permissions BEFORE execution
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    // 2. Validate payload against schema
    const parsedData = dispatchSchema.parse(data);
    
    // 3. Verify deal exists and caller's company is the authorized seller for this deal
    const dealResults = await db.select().from(deals).where(eq(deals.id, parsedData.deal_id));
    const deal = dealResults[0];
    
    if (!deal) {
      return { success: false, error: 'Deal not found.' };
    }
    
    const isAuthorizedSeller = 
      deal.sellerId === session.data.companyId || 
      deal.sellerId === session.data.user.id ||
      session.data.user.role === 'admin';

    if (!isAuthorizedSeller) {
      return { success: false, error: 'Unauthorized: Only the seller company can dispatch this deal.' };
    }

    // State Transition Guard: Only allowed if deal is in 'Dispatch Pending' or 'Confirmed' or 'In Transit'
    if (deal.status === 'Cancelled' || deal.status === 'Closed') {
      return { success: false, error: `Invalid state transition: Cannot dispatch a deal with status "${deal.status}".` };
    }
    
    // 4. Insert the record into the dispatches table
    const newDispatch = await db.insert(dispatches).values({
      dealId: parsedData.deal_id,
      sellerId: session.data.user.id,
      vehicleTypeId: parsedData.vehicle_type_id,
      vehicleNumber: parsedData.other_vehicle_type 
        ? `${parsedData.vehicle_number} (${parsedData.other_vehicle_type})` 
        : parsedData.vehicle_number,
      driverName: parsedData.driver_name,
      driverMobile: parsedData.driver_mobile,
      dispatchDate: parsedData.dispatch_date,
      expectedDeliveryDate: parsedData.expected_delivery_date,
      status: 'Dispatched'
    }).returning();
    
    // 5. Update the deals table status to 'In Transit'
    await db.update(deals).set({ status: 'In Transit' }).where(eq(deals.id, parsedData.deal_id));
    
    return { success: true, data: newDispatch[0] };
  } catch (error: any) {
    console.error('createDispatchAction error:', error);
    return { success: false, error: error.message || 'Failed to create dispatch.' };
  }
}

/**
 * Creates an invoice record attached to a booked deal.
 * Gated by verifySellerSession({ allowViewer: false }) and verifies company-level deal ownership.
 */
export async function createInvoiceAction(data: InvoiceData) {
  try {
    // 1. Authorize session & verify mutation permissions BEFORE execution
    const session = await verifySellerSession({ allowViewer: false });
    if (!session.success || !session.data) {
      return { success: false, error: session.error || "Unauthorized" };
    }

    // 2. Validate payload against schema
    const parsedData = invoiceSchema.parse(data);
    
    // 3. Verify deal exists and caller's company is the authorized seller for this deal
    const dealResults = await db.select().from(deals).where(eq(deals.id, parsedData.deal_id));
    const deal = dealResults[0];
    
    if (!deal) {
      return { success: false, error: 'Deal not found.' };
    }
    
    const isAuthorizedSeller = 
      deal.sellerId === session.data.companyId || 
      session.data.user.role === 'admin';

    if (!isAuthorizedSeller) {
      return { success: false, error: 'Unauthorized: Only the seller company can upload invoices for this deal.' };
    }
    
    // 4. Insert the record into the invoices table
    const newInvoice = await db.insert(invoices).values({
      dealId: parsedData.deal_id,
      sellerId: session.data.user.id,
      invoiceNo: parsedData.invoice_no,
      amount: parsedData.amount.toString(),
      fileUrl: parsedData.file_url,
      status: 'Pending'
    }).returning();
    
    return { success: true, data: newInvoice[0] };
  } catch (error: any) {
    console.error('createInvoiceAction error:', error);
    return { success: false, error: error.message || 'Failed to create invoice.' };
  }
}

/**
 * Generates a time-limited signed storage URL for transaction documents (Invoices, LRs, COAs).
 * Strictly requires request-time authorization: caller must be Seller, Buyer, assigned Broker, or Admin.
 * Enforces strict path traversal defenses and deal-scoped storage key validation.
 */
export async function getTransactionDocumentSignedUrlAction(dealId: string, filePath: string) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: "Access denied to transaction documents." };
    }

    if (!dealId || !filePath || typeof filePath !== "string") {
      return { success: false, error: "Deal ID and file path are required." };
    }

    // Path Traversal Defense: Reject directory traversal sequences
    if (filePath.includes('..') || filePath.includes('\\') || filePath.includes('\0')) {
      return { success: false, error: "Access denied to transaction documents: Invalid path format." };
    }

    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    if (!dbUser) {
      return { success: false, error: "Access denied to transaction documents." };
    }

    const dealResults = await db.select().from(deals).where(eq(deals.id, dealId));
    const deal = dealResults[0];

    if (!deal) {
      return { success: false, error: "Access denied to transaction documents." };
    }

    // Authorize caller based on deal participant relationships
    const isAuthorized = 
      dbUser.role === 'admin' ||
      (deal.brokerId && deal.brokerId === user.id) ||
      (dbUser.companyId && (deal.sellerId === dbUser.companyId || deal.buyerId === dbUser.companyId));

    if (!isAuthorized) {
      return { success: false, error: "Access denied to transaction documents." };
    }

    // Generate signed download URL valid for 1 hour (3600 seconds)
    const { data, error } = await supabase
      .storage
      .from('brokerbridge_documents')
      .createSignedUrl(filePath, 3600);

    if (error || !data?.signedUrl) {
      return { success: false, error: error?.message || "Failed to generate document access URL" };
    }

    return { success: true, data: { signedUrl: data.signedUrl } };
  } catch (error: any) {
    console.error('getTransactionDocumentSignedUrlAction error:', error);
    return { success: false, error: "Access denied to transaction documents." };
  }
}
