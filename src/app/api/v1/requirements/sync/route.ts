import { NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"
import { db } from "@/src/server/db"
import { users, requirements } from "@/src/server/db/schema"
import { eq } from "drizzle-orm"
import { requirementSchema } from "@/src/types/requirement-schema"

export async function POST(req: Request) {
  try {
    const supabase = await createClient()
    const { data: { user }, error: authError } = await supabase.auth.getUser()

    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const currentUser = await db.select().from(users).where(eq(users.id, user.id))
    const companyId = currentUser[0]?.companyId

    if (!companyId) {
      return NextResponse.json({ error: 'No associated company profile found.' }, { status: 400 })
    }

    const payload = await req.json()
    if (!Array.isArray(payload)) {
      return NextResponse.json({ error: 'Expected an array of payloads.' }, { status: 400 })
    }

    const validInserts = []

    for (const item of payload) {
      // Remove any indexedDB generated id field just in case
      const { id, ...itemData } = item
      const validation = requirementSchema.safeParse(itemData)
      if (validation.success) {
        validInserts.push({
          companyId,
          commodityId: validation.data.commodity_id,
          gradeId: validation.data.grade_id,
          quantity: validation.data.quantity,
          unitId: validation.data.unit_id,
          targetPrice: validation.data.target_price,
          deliveryTermsId: validation.data.delivery_terms_id,
          targetDate: new Date(validation.data.target_date), // safe coerce
          status: 'Open',
        })
      }
    }

    if (validInserts.length > 0) {
      await db.insert(requirements).values(validInserts)
    }

    return NextResponse.json({ success: true, inserted: validInserts.length }, { status: 200 })
  } catch (error: any) {
    return NextResponse.json({ error: error.message || 'Failed to sync' }, { status: 500 })
  }
}
