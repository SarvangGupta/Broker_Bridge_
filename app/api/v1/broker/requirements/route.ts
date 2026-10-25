import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/src/server/db';
import { getAuthenticatedBroker } from '@/src/server/actions/broker-directory-actions';
import {
  decodeDirectoryCursor,
  directoryErrorStatus,
  parseDirectoryLimit,
} from '@/src/server/utils/broker-directory-query';
import { queryBrokerRequirements } from '@/src/server/utils/broker-requirements-query';

function extractAuthToken(req: NextRequest): string | undefined {
  const authHeader = req.headers.get('authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  return undefined;
}

/** Requirements assigned to the signed-in broker (broker_id = broker). */
export async function GET(req: NextRequest) {
  try {
    const auth = await getAuthenticatedBroker(extractAuthToken(req));
    if (!auth.success) {
      return NextResponse.json(auth, { status: directoryErrorStatus(auth.error) });
    }

    const searchParams = req.nextUrl.searchParams;
    const limit = parseDirectoryLimit(searchParams.get('limit'));
    const cursorParam = searchParams.get('cursor');
    const cursor = decodeDirectoryCursor(cursorParam);
    if (cursorParam && !cursor) {
      return NextResponse.json({ success: false, error: 'Invalid page cursor' }, { status: 400 });
    }

    const page = await queryBrokerRequirements(db as any, auth.brokerId, { limit, after: cursor });
    return NextResponse.json(
      {
        success: true,
        data: {
          requirements: page.requirements,
          pageInfo: { hasMore: page.hasMore, nextCursor: page.nextCursor },
        },
      },
      { status: 200 }
    );
  } catch (error: any) {
    console.error('GET /broker/requirements error:', error?.message ?? error);
    return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 });
  }
}
