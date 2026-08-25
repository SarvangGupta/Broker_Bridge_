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
