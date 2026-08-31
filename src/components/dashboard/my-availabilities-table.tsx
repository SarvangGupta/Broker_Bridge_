"use client"

import { useState } from "react"
import { format } from "date-fns"
import { toast } from "sonner"
import { Loader2, MapPin, Calendar, PackageOpen, Tag, Ban } from "lucide-react"

import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { EmptyState } from "@/src/components/ui/empty-state"
import { cancelAvailabilityAction } from "@/src/server/actions/availability-actions"

interface AvailabilityRow {
  id: string
  quantity: number
  price: string
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
}

interface MyAvailabilitiesTableProps {
  availabilities: AvailabilityRow[]
}

export function MyAvailabilitiesTable({ availabilities }: MyAvailabilitiesTableProps) {
  const [cancellingId, setCancellingId] = useState<string | null>(null)

  async function handleCancel(id: string) {
    setCancellingId(id)
    try {
      const res = await cancelAvailabilityAction(id)
      if (res.success) {
        toast.success("Availability cancelled successfully")
      } else {
        toast.error(res.error || "Failed to cancel availability")
      }
    } catch (error: any) {
      toast.error(error.message || "An unexpected error occurred")
    } finally {
      setCancellingId(null)
    }
  }

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
      {availabilities.map((item) => {
        const isOpen = item.status === "Open"

        return (
          <div
            key={item.id}
            className="bg-white rounded-2xl border border-slate-200/80 p-5 sm:p-6 shadow-xs hover:shadow-md transition-all duration-200 flex flex-col justify-between relative group"
          >
            <div>
              {/* TOP HEADER: Breadcrumb • Commodity • Quality Parameter & Status Badge */}
              <div className="flex items-start justify-between gap-2 mb-4">
                <div>
                  {(item.industryName || item.categoryName) && (
                    <span className="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-0.5">
                      {[item.industryName, item.categoryName].filter(Boolean).join(" • ")}
                    </span>
                  )}
                  <span className="text-xs font-bold uppercase tracking-wider text-slate-700 block">
                    {item.commodityName || "Commodity"}
                  </span>
                  <h3 className="text-base sm:text-lg font-semibold text-slate-900 leading-tight">
                    {item.gradeName || "Standard Quality Parameter"}
                  </h3>
                </div>
                <Badge
                  variant="outline"
                  className={
                    isOpen
                      ? "bg-[#ECFDF5] text-[#047857] border-emerald-200/80 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full"
                      : "bg-slate-100 text-slate-600 border-slate-200 font-semibold px-2.5 py-1 text-xs shrink-0 rounded-full"
                  }
                >
                  {item.status}
                </Badge>
              </div>

              {/* STATS: Quantity & Asking Rate */}
              <div className="grid grid-cols-2 gap-3 py-3 px-3.5 bg-slate-50/80 rounded-xl border border-slate-100 mb-4">
                <div>
                  <span className="text-[11px] font-medium text-slate-400 uppercase tracking-wider block">
                    Available Stock
                  </span>
                  <span className="text-base sm:text-lg font-bold text-slate-900">
                    {item.quantity} {item.unitSymbol || "Units"}
                  </span>
                </div>
                <div>
                  <span className="text-[11px] font-medium text-slate-400 uppercase tracking-wider block">
                    Asking Rate
                  </span>
                  <span className="text-base sm:text-lg font-bold text-[#059669]">
                    ₹{item.price}
                  </span>
                </div>
              </div>

              {/* LOCATION & VALIDITY METADATA */}
              <div className="space-y-1.5 text-xs text-slate-500">
                <div className="flex items-center gap-1.5">
                  <MapPin className="h-3.5 w-3.5 text-slate-400 shrink-0" />
                  <span className="truncate">
                    {[item.districtName, item.stateName].filter(Boolean).join(", ") || "Location Unspecified"}
                  </span>
                </div>
                <div className="flex items-center gap-1.5">
                  <Calendar className="h-3.5 w-3.5 text-slate-400 shrink-0" />
                  <span className="font-medium text-slate-600">
                    Valid till {format(new Date(item.validUntil), "MMM d, yyyy")}
                  </span>
                </div>
              </div>
            </div>

            {/* ACTION FOOTER */}
            {isOpen && (
              <div className="pt-4 mt-4 border-t border-slate-100">
                <Button
                  variant="outline"
                  size="lg"
                  disabled={cancellingId === item.id}
                  onClick={() => handleCancel(item.id)}
                  className="w-full min-h-[48px] text-rose-600 hover:text-rose-700 hover:bg-rose-50 border-slate-200 hover:border-rose-200 font-semibold rounded-xl text-sm sm:text-base transition-colors flex items-center justify-center gap-2 cursor-pointer"
                >
                  {cancellingId === item.id ? (
                    <Loader2 className="h-4 w-4 animate-spin text-rose-600" />
                  ) : (
                    <>
                      <Ban className="h-4 w-4" />
                      Cancel Listing
                    </>
                  )}
                </Button>
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}
