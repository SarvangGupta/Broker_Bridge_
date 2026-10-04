import React from 'react'
import { getBuyerRequirementsListAction } from '@/src/server/actions/buyer-requirement-actions'
import { BuyerRequirementsFeed } from '@/src/components/buyer/requirements/buyer-requirements-feed'

export const dynamic = 'force-dynamic'

export default async function BuyerRequirementsPage() {
  const res = await getBuyerRequirementsListAction()
  const initialItems = res.success && res.data ? res.data : []

  return <BuyerRequirementsFeed initialItems={initialItems} />
}
