'use server';

import { GoogleGenerativeAI } from '@google/generative-ai';
import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import { masterQualityParameters } from '@/src/server/db/schema';
import { eq, and } from 'drizzle-orm';

export interface GeminiOcrResultItem {
  parameter_id: string;
  measured_value: string;
}

export interface GeminiLabOcrData {
  laboratory_name?: string | null;
  laboratory_location?: string | null;
  report_number?: string | null;
  sample_id?: string | null;
  report_date?: string | null;
  test_date?: string | null;
  results: GeminiOcrResultItem[];
}

export interface OcrActionResponse {
  success: boolean;
  data?: GeminiLabOcrData;
  error?: string;
}

/**
 * Server Action: extractLabDataOcrAction
 * Integrates Google Gemini Vision (gemini-3.6-flash) to extract structured analytical laboratory
 * parameters directly from uploaded Certificate of Analysis (COA) images / PDFs.
 */
export async function extractLabDataOcrAction(
  formData: FormData,
  commodityId: string
): Promise<OcrActionResponse> {
  try {
    // 1. Authenticate user session
    const supabase = await createClient();
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return { success: false, error: 'Unauthorized: Authentication required.' };
    }

    if (!commodityId) {
      return { success: false, error: 'Commodity ID is required for OCR extraction.' };
    }

    // 2. Validate API Key (supports GEMINI_API_KEY, GOOGLE_AI_API_KEY, and GOOGLE_GENERATIVE_AI_API_KEY)
    const apiKey =
      process.env.GEMINI_API_KEY ||
      process.env.GOOGLE_AI_API_KEY ||
      process.env.GOOGLE_GENERATIVE_AI_API_KEY;

    if (!apiKey) {
      console.warn('GEMINI_API_KEY is not set in environment variables (.env.local).');
      return {
        success: false,
        error: 'Gemini API key is not configured in .env.local. Please enter data manually.',
      };
    }

    // 3. Extract File from FormData
    const file = formData.get('file') as File | null;
    if (!file) {
      return { success: false, error: 'No report document or image file provided.' };
    }

    // 4. Fetch the master_quality_parameters for the provided commodityId
    const params = await db
      .select()
      .from(masterQualityParameters)
      .where(
        and(
          eq(masterQualityParameters.commodityId, commodityId),
          eq(masterQualityParameters.isActive, true)
        )
      );

    const masterParams = params.map((p) => ({
      id: p.id,
      name: p.name,
      unit: p.unit,
      minValue: p.minValue,
      maxValue: p.maxValue,
      targetValue: p.targetValue,
      type: p.type,
    }));

    // 5. Convert File to Base64 payload for Gemini inlineData
    const arrayBuffer = await file.arrayBuffer();
    const base64Data = Buffer.from(arrayBuffer).toString('base64');
    const mimeType = file.type || 'image/jpeg';

    const inlineDataPart = {
      inlineData: {
        data: base64Data,
        mimeType: mimeType,
      },
    };

    // 6. Initialize GoogleGenerativeAI with latest Gemini Vision model (gemini-3.6-flash)
    const genAI = new GoogleGenerativeAI(apiKey);

    // Prioritize gemini-3.6-flash, with automatic fallbacks
    const candidateModels = [
      process.env.GEMINI_MODEL,
      'gemini-3.6-flash',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
    ].filter(Boolean) as string[];

    // 7. Prompt with strict selective extraction instructions
    const prompt = `You are a strict data extraction engine for agricultural lab reports. You will receive an image of a Certificate of Analysis. Extract the following fields into a JSON object:
- \`laboratory_name\`: The name of the testing facility or laboratory.
- \`laboratory_location\`: The FULL physical address of the LABORATORY from the "Name and address" box or testing facility details section (e.g., '96/134 A2 Supa Tower, Trichengode Road, Namakkal'). Do NOT extract the client's address or generic corporate header.
- \`report_number\`: Lab Ref, Certificate number, or Report number.
- \`sample_id\`: The Name of the Sample or Batch ID (e.g., 'Marigold Flower Extract').
- \`report_date\`: (YYYY-MM-DD) The date the report was issued/printed.
- \`test_date\`: (YYYY-MM-DD) The date the analysis was performed. IF NOT EXPLICITLY STATED, fallback to the 'Date of Receipt' or the 'Report Date'. NEVER guess, hallucinate, or use the current year.
- \`results\`: [{ parameter_id, measured_value }] matching EXACTLY these allowed parameters: ${JSON.stringify(masterParams)}`;

    // 8. Call Gemini Vision API across candidate models
    let responseText = '';
    let lastError: any = null;

    for (const modelName of candidateModels) {
      try {
        const model = genAI.getGenerativeModel({
          model: modelName,
          generationConfig: {
            responseMimeType: 'application/json',
          },
        });

        const responseResult = await model.generateContent([prompt, inlineDataPart]);
        const response = await responseResult.response;
        responseText = response.text();
        if (responseText) {
          break;
        }
      } catch (err: any) {
        console.warn(`Model ${modelName} invocation failed, checking next model...`, err.message);
        lastError = err;
      }
    }

    if (!responseText) {
      return {
        success: false,
        error: lastError?.message || 'Gemini returned an empty response. Please enter data manually.',
      };
    }

    // 9. Parse structured JSON response
    let cleanJson = responseText.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.replace(/^```json\s*/, '').replace(/\s*```$/, '');
    } else if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.replace(/^```\s*/, '').replace(/\s*```$/, '');
    }

    const parsedData: GeminiLabOcrData = JSON.parse(cleanJson);

    // Validate that results array exists
    if (!Array.isArray(parsedData.results)) {
      parsedData.results = [];
    }

    return {
      success: true,
      data: parsedData,
    };
  } catch (error: any) {
    console.error('Gemini OCR Extraction Action Error:', error);
    return {
      success: false,
      error: error.message || 'AI extraction failed, please enter manually.',
    };
  }
}
