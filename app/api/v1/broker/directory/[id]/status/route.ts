import { NextRequest, NextResponse } from 'next/server';
import { toggleContactStatusAction } from '@/src/server/actions/broker-directory-actions';
import { directoryErrorStatus } from '@/src/server/utils/broker-directory-query';

function extractAuthToken(req: NextRequest): string | undefined {
  const authHeader = req.headers.get('authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  return undefined;
}

export async function PATCH(
  req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  try {
    const token = extractAuthToken(req);
    const { id } = await context.params;

    const result = await toggleContactStatusAction(id, token);

    if (!result.success) {
      return NextResponse.json(result, { status: directoryErrorStatus(result.error) });
    }

    return NextResponse.json(result, { status: 200 });
  } catch (error: any) {
    console.error('PATCH /broker/directory/[id]/status error:', error);
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    );
  }
}
