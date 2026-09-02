import { createClient } from "@/lib/supabase/client"

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

import { uploadLabEvidenceAction } from "@/src/server/actions/lab-actions"

/**
 * Uploads a physical laboratory certificate / COA evidence file to the private 'brokerbridge_lab_evidence' bucket.
 * Routes through Server Action to guarantee SSR httpOnly cookie authentication and lot ownership.
 *
 * @param file The physical PDF/Image file to upload
 * @param availabilityId The UUID of the supply lot availability
 * @returns The storage file path (e.g., '123e4567.../1788355_coa.pdf')
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
