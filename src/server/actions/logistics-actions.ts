'use server'

import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { dispatches, invoices, deals, users } from "@/src/server/db/schema"
import { eq } from "drizzle-orm"
import { dispatchSchema, invoiceSchema, DispatchData, InvoiceData } from "@/src/types/logistics-schema"

export async function createDispatchAction(data: DispatchData) {
  try {
    // Validate payload against schema
    const parsedData = dispatchSchema.parse(data);
    
    // Verify the user session
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return { success: false, error: 'Unauthorized' };
    }
    
    const dbUserResults = await db.select().from(users).where(eq(users.id, user.id));
    const dbUser = dbUserResults[0];
    
    // Verify user is authorized seller for this deal
    const dealResults = await db.select().from(deals).where(eq(deals.id, parsedData.deal_id));
    const deal = dealResults[0];
    
    if (!deal) {
      return { success: false, error: 'Deal not found.' };
    }
    
    if (deal.sellerId !== user.id && (!dbUser || deal.sellerId !== dbUser.companyId)) {
      return { success: false, error: 'Unauthorized: Only the seller can dispatch this deal.' };
    }
    
    // Insert the record into the dispatches table
    const newDispatch = await db.insert(dispatches).values({
      dealId: parsedData.deal_id,
      sellerId: user.id,
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
    
    // Update the deals table status to 'In Transit'
    await db.update(deals).set({ status: 'In Transit' }).where(eq(deals.id, parsedData.deal_id));
    
    return { success: true, data: newDispatch[0] };
  } catch (error: any) {
    console.error('createDispatchAction error:', error);
    return { success: false, error: error.message || 'Failed to create dispatch.' };
  }
}

export async function createInvoiceAction(data: InvoiceData) {
  try {
    // Validate payload against schema
    const parsedData = invoiceSchema.parse(data);
    
    // Verify the user session
    const supabase = await createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return { success: false, error: 'Unauthorized' };
    }
    
    const dbUserResults = await db.select().from(users).where(eq(users.id, user.id));
    const dbUser = dbUserResults[0];
    
    // Verify user is authorized seller for this deal
    const dealResults = await db.select().from(deals).where(eq(deals.id, parsedData.deal_id));
    const deal = dealResults[0];
    
    if (!deal) {
      return { success: false, error: 'Deal not found.' };
    }
    
    if (deal.sellerId !== user.id && (!dbUser || deal.sellerId !== dbUser.companyId)) {
      return { success: false, error: 'Unauthorized: Only the seller can upload invoices for this deal.' };
    }
    
    // Insert the record into the invoices table
    const newInvoice = await db.insert(invoices).values({
      dealId: parsedData.deal_id,
      sellerId: user.id,
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
