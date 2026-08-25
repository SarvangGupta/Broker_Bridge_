export async function sendQuotationWhatsAppNotification({
  recipientPhone,
  quotationId,
  buyerName,
  commodityName,
  price,
  pdfUrl,
}: {
  recipientPhone: string;
  quotationId: string;
  buyerName: string;
  commodityName: string;
  price: number;
  pdfUrl: string;
}) {
  try {
    const token = process.env.WHATSAPP_API_TOKEN;
    const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID;

    if (!token || !phoneId) {
      console.log('--- MOCK WHATSAPP NOTIFICATION ---');
      console.log(`To: ${recipientPhone}`);
      console.log(`Payload: Quotation ${quotationId} for ${buyerName} - ${commodityName} @ ₹${price}`);
      console.log(`Link: ${pdfUrl}`);
      console.log('----------------------------------');
      return { success: true, mocked: true, messageId: `mock_msg_${Date.now()}` };
    }

    const abortController = new AbortController();
    const timeout = setTimeout(() => abortController.abort(), 5000);

    const payload = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: recipientPhone,
      type: 'template',
      template: {
        name: 'quotation_dispatch',
        language: { code: 'en_US' },
        components: [
          {
            type: 'header',
            parameters: [
              {
                type: 'document',
                document: {
                  link: pdfUrl,
                  filename: `Quotation-${quotationId.split('-')[0]}.pdf`,
                },
              },
            ],
          },
          {
            type: 'body',
            parameters: [
              { type: 'text', text: buyerName },
              { type: 'text', text: commodityName },
              { type: 'text', text: price.toString() },
            ],
          },
        ],
      },
    };

    const response = await fetch(`https://graph.facebook.com/v19.0/${phoneId}/messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: abortController.signal,
    });

    clearTimeout(timeout);

    if (!response.ok) {
      const errorData = await response.json();
      console.error('WhatsApp API Error:', errorData);
      return { success: false, error: 'Failed to dispatch WhatsApp message' };
    }

    const data = await response.json();
    return { success: true, mocked: false, messageId: data.messages?.[0]?.id };
  } catch (error: any) {
    console.error('WhatsApp Service Error:', error);
    return { success: false, error: 'Network error communicating with WhatsApp' };
  }
}
