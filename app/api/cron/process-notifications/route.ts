import { NextRequest, NextResponse } from 'next/server'
import { dispatchPendingNotifications } from '@/src/server/notifications/dispatcher'

export async function GET(request: NextRequest) {
  return handleCronRequest(request)
}

export async function POST(request: NextRequest) {
  return handleCronRequest(request)
}

async function handleCronRequest(request: NextRequest) {
  try {
    const configuredSecret = process.env.CRON_SECRET

    // 1. Strict zero-fallback configuration guardrail
    if (!configuredSecret || configuredSecret.trim() === '') {
      console.error('[Cron: process-notifications] CRON_SECRET is not configured in environment')
      return NextResponse.json(
        { error: 'Server misconfiguration: CRON_SECRET is not configured' },
        { status: 500 }
      )
    }

    // 2. Validate Authorization header
    const authHeader = request.headers.get('authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: 'Unauthorized: Missing or malformed Bearer token' },
        { status: 401 }
      )
    }

    const providedToken = authHeader.replace(/^Bearer\s+/i, '').trim()
    if (providedToken !== configuredSecret) {
      return NextResponse.json(
        { error: 'Unauthorized: Invalid CRON_SECRET' },
        { status: 401 }
      )
    }

    // 3. Execute atomic background dispatcher
    const result = await dispatchPendingNotifications(50)

    return NextResponse.json(
      {
        success: result.success,
        claimedCount: result.claimedCount,
        sentCount: result.sentCount,
        failedCount: result.failedCount,
        errors: result.errors,
      },
      { status: 200 }
    )
  } catch (error: any) {
    console.error('[Cron: process-notifications] Execution error:', error)
    return NextResponse.json(
      { error: error.message || 'Internal server error processing notifications' },
      { status: 500 }
    )
  }
}
