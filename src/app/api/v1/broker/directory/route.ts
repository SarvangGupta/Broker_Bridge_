import { NextRequest, NextResponse } from 'next/server';
import {
  getBrokerDirectoryContactsAction,
  createBrokerContactAction,
  type CreateContactInput,
} from '@/src/server/actions/broker-directory-actions';

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

    const result = await getBrokerDirectoryContactsAction(
      { role, status, search },
      token
    );

    if (!result.success) {
      const isUnauth = result.error?.toLowerCase().includes('unauthorized') ||
        result.error?.toLowerCase().includes('session');
      return NextResponse.json(result, { status: isUnauth ? 401 : 400 });
    }

    return NextResponse.json(result, { status: 200 });
  } catch (error: any) {
    return NextResponse.json(
      { success: false, error: error.message || 'Internal server error' },
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
      const isUnauth = result.error?.toLowerCase().includes('unauthorized');
      return NextResponse.json(result, { status: isUnauth ? 401 : 400 });
    }

    return NextResponse.json(result, { status: 201 });
  } catch (error: any) {
    return NextResponse.json(
      { success: false, error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}
