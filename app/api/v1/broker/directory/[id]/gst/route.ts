import { NextRequest, NextResponse } from 'next/server';
import { submitContactGstAction } from '@/src/server/actions/broker-directory-actions';
import { directoryErrorStatus } from '@/src/server/utils/broker-directory-query';

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const authHeader = req.headers.get('authorization');
    const token = authHeader?.startsWith('Bearer ') ? authHeader.substring(7).trim() : undefined;
    const result = await submitContactGstAction(id, await req.json(), token);
    return NextResponse.json(result, { status: result.success ? 200 : directoryErrorStatus(result.error) });
  } catch (error: any) {
    console.error('POST /broker/directory/[id]/gst error:', error);
    return NextResponse.json({ success: false, error: 'Internal server error' }, { status: 500 });
  }
}
