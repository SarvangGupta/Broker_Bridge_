import { NextResponse } from 'next/server';

export async function GET(request: Request) {
  const url = new URL(request.url);
  const mode = url.searchParams.get('hub.mode');
  const token = url.searchParams.get('hub.verify_token');
  const challenge = url.searchParams.get('hub.challenge');

  const verifyToken = process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN;
  if (!verifyToken || verifyToken.trim() === '') {
    console.error('[WhatsApp Webhook] WHATSAPP_WEBHOOK_VERIFY_TOKEN is not configured');
    return new NextResponse('Server configuration error: Webhook verify token missing', { status: 500 });
  }

  if (mode === 'subscribe' && token === verifyToken) {
    console.log('WEBHOOK_VERIFIED');
    return new NextResponse(challenge, { status: 200 });
  } else {
    return new NextResponse('Forbidden', { status: 403 });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    
    // Log the incoming payload from WhatsApp (read receipts, delivery status, replies)
    console.log('--- WHATSAPP WEBHOOK RECEIVED ---');
    console.log(JSON.stringify(body, null, 2));
    console.log('---------------------------------');

    return NextResponse.json({ status: "received" }, { status: 200 });
  } catch (error) {
    console.error('Error processing webhook payload:', error);
    return new NextResponse('Internal Server Error', { status: 500 });
  }
}
