import { NextRequest, NextResponse } from 'next/server';
import { checkContactDuplicateAction } from '@/src/server/actions/broker-directory-actions';

function extractAuthToken(req: NextRequest): string | undefined {
  const authHeader = req.headers.get('authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  return undefined;
}

export async function POST(req: NextRequest) {
  try {
    const token = extractAuthToken(req);
    const body = await req.json();

    const mobile = body?.mobile?.toString() || '';
    const companyName = body?.companyName?.toString() || '';

    const result = await checkContactDuplicateAction(
      { mobile, companyName },
      token
    );

    return NextResponse.json(result, { status: 200 });
  } catch (error: any) {
    return NextResponse.json(
      { isDuplicate: false, error: error.message || 'Duplicate check failed' },
      { status: 500 }
    );
  }
}
