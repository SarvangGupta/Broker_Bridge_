import { NextRequest, NextResponse } from 'next/server';
import {
  getBrokerContactDetailsAction,
  updateBrokerContactAction,
  type UpdateContactInput,
} from '@/src/server/actions/broker-directory-actions';

function extractAuthToken(req: NextRequest): string | undefined {
  const authHeader = req.headers.get('authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  return undefined;
}

export async function GET(
  req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  try {
    const token = extractAuthToken(req);
    const { id } = await context.params;

    const result = await getBrokerContactDetailsAction(id, token);

    if (!result.success) {
      const isUnauth = result.error?.toLowerCase().includes('unauthorized');
      const isNotFound = result.error?.toLowerCase().includes('not found');
      return NextResponse.json(
        result,
        { status: isUnauth ? 401 : isNotFound ? 404 : 400 }
      );
    }

    return NextResponse.json(result, { status: 200 });
  } catch (error: any) {
    return NextResponse.json(
      { success: false, error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function PUT(
  req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  try {
    const token = extractAuthToken(req);
    const { id } = await context.params;
    const body = (await req.json()) as UpdateContactInput;

    const result = await updateBrokerContactAction(id, body, token);

    if (!result.success) {
      const isUnauth = result.error?.toLowerCase().includes('unauthorized');
      const isNotFound = result.error?.toLowerCase().includes('not found');
      return NextResponse.json(
        result,
        { status: isUnauth ? 401 : isNotFound ? 404 : 400 }
      );
    }

    return NextResponse.json(result, { status: 200 });
  } catch (error: any) {
    return NextResponse.json(
      { success: false, error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}
