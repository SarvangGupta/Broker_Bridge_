import { NextResponse } from 'next/server'
import { db } from '@/src/server/db'
import { dispatches, deals } from '@/src/server/db/schema'
import { inArray, lt, and } from 'drizzle-orm'

// Developer Note: Add CRON_SECRET=your_secure_random_string to your .env.local file for local testing.

export async function GET(request: Request) {
  try {
    const configuredSecret = process.env.CRON_SECRET;
    if (!configuredSecret || configuredSecret.trim() === '') {
      console.error('[Cron: monitor-dispatches] CRON_SECRET is not configured in environment');
      return NextResponse.json(
        { error: 'Server misconfiguration: CRON_SECRET is not configured' },
        { status: 500 }
      );
    }

    const authHeader = request.headers.get('authorization');
    if (!authHeader || authHeader !== `Bearer ${configuredSecret}`) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const now = new Date()

    // 1. Find delayed dispatches
    const delayedRecords = await db
      .select({ id: dispatches.id, dealId: dispatches.dealId })
      .from(dispatches)
      .where(
        and(
          lt(dispatches.expectedDeliveryDate, now),
          inArray(dispatches.status, ['Dispatched', 'In Transit'])
        )
      )

    if (delayedRecords.length === 0) {
      return NextResponse.json({ success: true, delayedCount: 0 })
    }

    const dispatchIds = delayedRecords.map(r => r.id)
    const dealIds = delayedRecords.map(r => r.dealId)

    // 2. Update dispatches to 'Delayed'
    await db
      .update(dispatches)
      .set({ status: 'Delayed' })
      .where(inArray(dispatches.id, dispatchIds))

    // 3. Update associated deals to 'Delayed'
    await db
      .update(deals)
      .set({ status: 'Delayed' })
      .where(inArray(deals.id, dealIds))

    return NextResponse.json({ success: true, delayedCount: delayedRecords.length })
  } catch (error: any) {
    console.error('Error in monitor-dispatches cron:', error)
    return NextResponse.json(
      { success: false, error: 'Internal Server Error' },
      { status: 500 }
    )
  }
}
