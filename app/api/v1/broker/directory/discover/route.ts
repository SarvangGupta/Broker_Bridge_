import { NextRequest, NextResponse } from 'next/server';
import {
  addExistingBuyerAction,
  discoverBuyersAction,
} from '@/src/server/actions/broker-directory-actions';
import { directoryErrorStatus } from '@/src/server/utils/broker-directory-query';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function extractAuthToken(req: NextRequest): string | undefined {
  const authHeader = req.headers.get('authorization');
  return authHeader?.startsWith('Bearer ') ? authHeader.substring(7).trim() : undefined;
}

export async function GET(req: NextRequest) {
  try {
    const params = req.nextUrl.searchParams;
    const category = params.get('categoryId');
    const result = await discoverBuyersAction(
      {
        search: params.get('search') ?? '',
        categoryId: category && UUID_RE.test(category) ? category : undefined,
      },
      extractAuthToken(req)
    );
    return NextResponse.json(result, { status: result.success ? 200 : directoryErrorStatus(result.error) });
  } catch (error: any) {
    console.error('GET /broker/directory/discover error:', error);
    return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 });
  }
}

/** Adds an existing buyer to the broker's list. Body: `{ "buyerUserId": "<uuid>" }`. */
export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as { buyerUserId?: unknown };
    const result = await addExistingBuyerAction(String(body.buyerUserId ?? ''), extractAuthToken(req));
    return NextResponse.json(result, { status: result.success ? 200 : directoryErrorStatus(result.error) });
  } catch (error: any) {
    console.error('POST /broker/directory/discover error:', error);
    return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 });
  }
}
