import { NextRequest, NextResponse } from 'next/server';
import {
  getBrokerDirectoryContactsAction,
  createBrokerContactAction,
  type CreateContactInput,
} from '@/src/server/actions/broker-directory-actions';
import {
  decodeDirectoryCursor,
  directoryErrorStatus,
  parseDirectoryLimit,
} from '@/src/server/utils/broker-directory-query';

function extractAuthToken(req: NextRequest): string | undefined {
  const authHeader = req.headers.get('authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  return undefined;
}

export async function GET(req: NextRequest) {
  try {
    const token = extractAuthToken(req);
    const searchParams = req.nextUrl.searchParams;
    const roleParam = searchParams.get('role');
    const searchParam = searchParams.get('search');
    const statusParam = searchParams.get('status');

    const role =
      roleParam === 'buyer' || roleParam === 'seller' ? roleParam : 'all';
    const status =
      statusParam === 'active' || statusParam === 'inactive' ? statusParam : 'all';
    const search = searchParam || undefined;
    const limit = parseDirectoryLimit(searchParams.get('limit'));
    const cursorParam = searchParams.get('cursor');
    const cursor = decodeDirectoryCursor(cursorParam);
    if (cursorParam && !cursor) {
      return NextResponse.json({ success: false, error: 'Invalid page cursor' }, { status: 400 });
    }

    const result = await getBrokerDirectoryContactsAction(
      { role, status, search, limit, cursor },
      token
    );

    if (!result.success) {
      return NextResponse.json(result, { status: directoryErrorStatus(result.error) });
    }

    return NextResponse.json(result, { status: 200 });
  } catch (error: any) {
    console.error('GET /broker/directory error:', error);
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    const token = extractAuthToken(req);
    const body = (await req.json()) as CreateContactInput;

    const result = await createBrokerContactAction(body, token);

    if (!result.success) {
      if (result.isDuplicate) {
        return NextResponse.json(result, { status: 409 });
      }
      return NextResponse.json(result, { status: directoryErrorStatus(result.error) });
    }

    return NextResponse.json(result, { status: 201 });
  } catch (error: any) {
    console.error('POST /broker/directory error:', error);
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    );
  }
}
