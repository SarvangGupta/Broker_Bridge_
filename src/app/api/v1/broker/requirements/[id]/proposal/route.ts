import { NextRequest, NextResponse } from 'next/server';
import { createClient as createSupabaseClient } from '@supabase/supabase-js';
import { db } from '@/src/server/db';
import { users, requirements } from '@/src/server/db/schema';
import { eq } from 'drizzle-orm';
import {
  getBuyerNegotiationDetailsAction,
  getBuyerNegotiationTimelineAction,
  sendProposalToBuyerAction,
} from '@/src/server/actions/broker-buyer-actions';
import { sendProposalToBuyerSchema } from '@/src/types/buyer-negotiation-schema';

function extractAuthToken(req: NextRequest): string | undefined {
  const authHeader = req.headers.get('authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  return undefined;
}

async function authenticateBroker(req: NextRequest) {
  const token = extractAuthToken(req);
  if (!token) {
    return { error: 'Unauthorized: Missing bearer token', status: 401 };
  }

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
  const supabase = createSupabaseClient(supabaseUrl, supabaseAnonKey);

  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    return { error: 'Unauthorized: Invalid or expired session', status: 401 };
  }

  const dbUser = await db.query.users.findFirst({
    where: eq(users.id, user.id),
  });

  if (!dbUser) {
    return { error: 'User profile not found', status: 404 };
  }

  const role = (dbUser.role || '').toLowerCase();
  if (role !== 'broker' && role !== 'admin') {
    return { error: 'Forbidden: Broker desk access privileges required', status: 403 };
  }

  return { user: dbUser };
}

/**
 * GET /api/v1/broker/requirements/[id]/proposal
 * Returns current proposal details & negotiation timeline for the specified requirement.
 */
export async function GET(
  req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  try {
    const auth = await authenticateBroker(req);
    if ('error' in auth) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }

    const { id } = await context.params;

    // Check requirement existence & assignment
    const reqRow = await db.query.requirements.findFirst({
      where: eq(requirements.id, id),
    });

    if (!reqRow) {
      return NextResponse.json({ success: false, error: 'Buyer requirement not found' }, { status: 404 });
    }

    // Verify broker assignment
    if (auth.user.role !== 'admin' && reqRow.brokerId !== auth.user.id) {
      return NextResponse.json(
        { success: false, error: 'Forbidden: You are not assigned to this buyer requirement' },
        { status: 403 }
      );
    }

    const token = extractAuthToken(req);
    const [detailsRes, timelineRes] = await Promise.all([
      getBuyerNegotiationDetailsAction(id, token),
      getBuyerNegotiationTimelineAction(id, token),
    ]);

    if (!detailsRes.success) {
      return NextResponse.json({ success: false, error: detailsRes.error }, { status: 400 });
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          details: detailsRes.data,
          timeline: timelineRes.data || [],
        },
      },
      { status: 200 }
    );
  } catch (error: any) {
    console.error('Error in GET /broker/requirements/[id]/proposal:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}

/**
 * POST /api/v1/broker/requirements/[id]/proposal
 * Submits a broker commercial proposal to the buyer.
 */
export async function POST(
  req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  try {
    const auth = await authenticateBroker(req);
    if ('error' in auth) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }

    const { id } = await context.params;

    // Verify requirement assignment
    const reqRow = await db.query.requirements.findFirst({
      where: eq(requirements.id, id),
    });

    if (!reqRow) {
      return NextResponse.json({ success: false, error: 'Buyer requirement not found' }, { status: 404 });
    }

    if (auth.user.role !== 'admin' && reqRow.brokerId !== auth.user.id) {
      return NextResponse.json(
        { success: false, error: 'Forbidden: You are not authorized to negotiate on this unassigned requirement' },
        { status: 403 }
      );
    }

    const body = await req.json();
    const payload = {
      ...body,
      requirement_id: id,
    };

    const validation = sendProposalToBuyerSchema.safeParse(payload);
    if (!validation.success) {
      const firstErr = validation.error.errors[0]?.message || 'Invalid proposal payload';
      return NextResponse.json({ success: false, error: firstErr }, { status: 400 });
    }

    const token = extractAuthToken(req);
    const result = await sendProposalToBuyerAction(validation.data, token);

    if (!result.success) {
      return NextResponse.json({ success: false, error: result.error }, { status: 400 });
    }

    // Return updated details & timeline
    const [detailsRes, timelineRes] = await Promise.all([
      getBuyerNegotiationDetailsAction(id, token),
      getBuyerNegotiationTimelineAction(id, token),
    ]);

    return NextResponse.json(
      {
        success: true,
        newVersion: result.newVersion,
        message: result.message,
        data: {
          details: detailsRes.data,
          timeline: timelineRes.data || [],
        },
      },
      { status: 200 }
    );
  } catch (error: any) {
    console.error('Error in POST /broker/requirements/[id]/proposal:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}
