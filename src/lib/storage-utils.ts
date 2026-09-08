import { createClient } from "@/lib/supabase/client"
import { uploadLabEvidenceAction } from "@/src/server/actions/lab-actions"
import { uploadFulfillmentDocumentAction } from "@/src/server/actions/document-actions"

/**
 * Standard document upload for deals.
 */
export async function uploadDocument(file: File, dealId: string): Promise<string> {
  const supabase = createClient()
  
  // Clean filename to avoid URL issues
  const cleanFileName = file.name.replace(/[^a-zA-Z0-9.-]/g, '_')
  const filePath = `${dealId}/${Date.now()}_${cleanFileName}`

  const { data, error } = await supabase
    .storage
    .from('brokerbridge_documents')
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: false
    })

  if (error) {
    throw new Error(`Upload failed: ${error.message}`)
  }

  return data.path
}

/**
 * Uploads a physical laboratory certificate / COA evidence file to the private 'brokerbridge_lab_evidence' bucket.
 * Routes through Server Action to guarantee SSR httpOnly cookie authentication and lot ownership.
 */
export async function uploadLabEvidence(file: File, availabilityId: string): Promise<string> {
  const formData = new FormData()
  formData.append("file", file)
  formData.append("availabilityId", availabilityId)

  const res = await uploadLabEvidenceAction(formData)

  if (!res.success || !res.data?.path) {
    throw new Error(`Lab evidence upload failed: ${res.error || "Unknown server error"}`)
  }

  return res.data.path
}

/**
 * Enterprise File Upload Utility (Micro-Sprint 19.3):
 * Uploads a physical fulfillment document (LR, Invoice, E-Way Bill, Weighment Slip, Loading Photo)
 * to the private 'brokerbridge_documents' bucket via Server Action with exponential backoff retry safety.
 *
 * Strict Path Structure: `${bookingId}/${dispatchId}/${Date.now()}_${sanitizedFileName}`
 *
 * @param file The physical PDF/Image file to upload
 * @param bookingId The Booking reference or UUID
 * @param dispatchId The Dispatch UUID
 * @param maxRetries Maximum retry attempts on network transient error
 * @returns The storage file path
 */
export async function uploadFulfillmentDocument(
  file: File,
  bookingId: string,
  dispatchId: string,
  maxRetries: number = 3
): Promise<string> {
  let attempt = 0
  let lastError: any = null

  while (attempt < maxRetries) {
    try {
      const formData = new FormData()
      formData.append("file", file)
      formData.append("bookingId", bookingId)
      formData.append("dispatchId", dispatchId)

      const res = await uploadFulfillmentDocumentAction(formData)

      if (!res.success || !res.data?.path) {
        throw new Error(res.error || "Failed to upload document to server storage.")
      }

      return res.data.path
    } catch (err: any) {
      attempt++
      lastError = err
      if (attempt >= maxRetries) {
        break
      }
      // Exponential backoff: 500ms, 1000ms, 2000ms
      await new Promise((resolve) => setTimeout(resolve, Math.pow(2, attempt) * 500))
    }
  }

  throw new Error(
    `Fulfillment document upload failed after ${maxRetries} attempts: ${lastError?.message || 'Network error'}`
  )
}
