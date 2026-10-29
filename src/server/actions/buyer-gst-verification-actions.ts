'use server'

import { createClient } from "@/lib/supabase/server"
import { revalidatePath } from "next/cache"

/**
 * Admin review of Buyer GST verifications (migration 0054).
 *
 * Uses the admin's own Supabase session, never Drizzle/DATABASE_URL: RLS
 * (`is_admin()`) decides what is visible, and `review_buyer_gst_verification`
 * records `auth.uid()` as the reviewer in the append-only history.
 */

const CERTIFICATE_BUCKET = 'brokerbridge_buyer_gst_certificates'
const PREVIEW_SECONDS = 60

export type BuyerGstVerificationRow = {
  id: string
  company_id: string
  submitted_by: string
  status: 'pending' | 'approved' | 'rejected' | 'superseded'
  gstin: string
  legal_name: string
  trade_name: string | null
  constitution: string | null
  principal_address: string
  pin_code: string
  registration_type: string | null
  registration_date: string | null
  validity_from: string | null
  validity_to: string | null
  issue_date: string | null
  ocr_values: Record<string, string | null>
  edited_fields: string[]
  certificate_path: string
  seller_gstin_conflict: boolean
  submitted_at: string
  reviewed_at: string | null
  rejection_reason: string | null
  companies: { name: string; gst: string | null; is_verified: boolean } | null
}

export async function getBuyerGstVerificationsAction(status: 'pending' | 'all' = 'pending') {
  try {
    const supabase = await createClient()
    let query = supabase
      .from('buyer_gst_verifications')
      .select('*, companies(name, gst, is_verified)')
      .order('submitted_at', { ascending: true })
    if (status === 'pending') query = query.eq('status', 'pending')
    const { data, error } = await query
    if (error) return { success: false as const, error: error.message }
    return { success: true as const, data: (data ?? []) as BuyerGstVerificationRow[] }
  } catch (error: any) {
    return { success: false as const, error: error.message || 'Failed to load GST verifications' }
  }
}

/** Short-lived preview link, issued only if the admin's session can read the object. */
export async function getGstCertificatePreviewAction(certificatePath: string) {
  try {
    const supabase = await createClient()
    const { data, error } = await supabase.storage
      .from(CERTIFICATE_BUCKET)
      .createSignedUrl(certificatePath, PREVIEW_SECONDS)
    if (error || !data?.signedUrl) return { success: false as const, error: error?.message || 'Preview unavailable' }
    return { success: true as const, url: data.signedUrl, expiresInSeconds: PREVIEW_SECONDS }
  } catch (error: any) {
    return { success: false as const, error: error.message || 'Preview unavailable' }
  }
}

export async function reviewBuyerGstVerificationAction(
  id: string,
  decision: 'approve' | 'reject',
  reason?: string,
) {
  try {
    if (decision === 'reject' && !reason?.trim()) {
      return { success: false as const, error: 'A rejection reason is required.' }
    }
    const supabase = await createClient()
    const { data, error } = await supabase.rpc('review_buyer_gst_verification', {
      p_id: id,
      p_decision: decision,
      p_reason: decision === 'reject' ? reason!.trim() : null,
    })
    if (error) return { success: false as const, error: error.message }
    revalidatePath('/admin')
    return { success: true as const, data }
  } catch (error: any) {
    return { success: false as const, error: error.message || 'Review failed' }
  }
}
