"use client"

import { PackageOpen } from "lucide-react"
import { EmptyState } from "@/src/components/ui/empty-state"
import { InventoryCard } from "@/src/components/dashboard/inventory-card"

interface AvailabilityRow {
  id: string
  commodityId?: string | null
  quantity: number | string
  price: string | number
  status: string
  createdAt: Date | string
  validUntil: Date | string
  commodityName: string | null
  categoryName?: string | null
  industryName?: string | null
  gradeName: string | null
  unitSymbol: string | null
  stateName: string | null
  districtName: string | null
  lotNumber?: string | null
  labTestStatus?: string | null
  labTestValidUntil?: Date | string | null
  labTestTestDate?: Date | string | null
  labTestId?: string | null
  loadingStatus?: string | null
  loadingDuration?: number | null
  loadingStartDate?: Date | string | null
  loadingCapacity?: string | number | null
  loadingRemarks?: string | null
  loadingUpdatedAt?: Date | string | null
}

interface MyAvailabilitiesTableProps {
  availabilities: AvailabilityRow[]
}

export function MyAvailabilitiesTable({ availabilities }: MyAvailabilitiesTableProps) {
  if (availabilities.length === 0) {
    return (
      <EmptyState
        icon={PackageOpen}
        title="No Active Inventory"
        description="You have not posted any commodity stock yet. Click &ldquo;Post Availability&rdquo; to publish your inventory to the market."
        className="bg-white border-slate-200/80 shadow-xs"
      />
    )
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
      {availabilities.map((item) => (
        <InventoryCard key={item.id} item={item} />
      ))}
    </div>
  )
}

