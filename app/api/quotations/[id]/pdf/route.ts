import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import { quotations, masterCommodities, availabilities, requirements, users } from '@/src/server/db/schema';
import { eq } from 'drizzle-orm';
import { generateQuotationPdf } from '@/src/lib/pdf-generator';

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    
    if (!user) {
      return new NextResponse('Unauthorized', { status: 401 });
    }

    const { id } = await params;

    const result = await db
      .select({
        id: quotations.id,
        brokerId: quotations.brokerId,
        offeredPrice: quotations.offeredPrice,
        validUntil: quotations.validUntil,
        quantity: availabilities.quantity,
        commodityName: masterCommodities.name,
        buyerCompanyId: requirements.companyId,
      })
      .from(quotations)
      .where(eq(quotations.id, id))
      .leftJoin(availabilities, eq(availabilities.id, quotations.sellerAvailabilityId))
      .leftJoin(requirements, eq(requirements.id, quotations.requirementId))
      .leftJoin(masterCommodities, eq(masterCommodities.id, availabilities.commodityId))
      .limit(1);

    if (!result || result.length === 0) {
      return new NextResponse('Quotation not found', { status: 404 });
    }

    const quoteData = result[0];

    // Authorization check
    const dbUser = await db.query.users.findFirst({
      where: eq(users.id, user.id),
    });

    const isAuthorized = 
      dbUser?.role === 'admin' || 
      quoteData.brokerId === user.id || 
      (dbUser?.companyId && quoteData.buyerCompanyId === dbUser.companyId);

    if (!isAuthorized) {
      return new NextResponse('Forbidden: Access denied to quotation PDF', { status: 403 });
    }

    const pdfBuffer = await generateQuotationPdf(quoteData);

    return new NextResponse(pdfBuffer as any, {
      status: 200,
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="quotation-${id.split('-')[0]}.pdf"`,
      },
    });
  } catch (error: any) {
    console.error('PDF Generation Error:', error);
    return new NextResponse('Internal Server Error', { status: 500 });
  }
}
