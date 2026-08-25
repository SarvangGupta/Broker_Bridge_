'use client'

import { useEffect, useState } from "react"
import { format } from "date-fns"
import { toast } from "sonner"
import { Loader2, XCircle } from "lucide-react"

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"

import { getMyRequirementsAction, cancelRequirementAction } from "@/src/server/actions/requirement-actions"

export function MyRequirementsTable() {
  const [requirements, setRequirements] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [cancellingId, setCancellingId] = useState<string | null>(null)

  const loadRequirements = async () => {
    setIsLoading(true)
    const res = await getMyRequirementsAction()
    if (res.success && res.data) {
      setRequirements(res.data)
    } else {
      toast.error(res.error || "Failed to load requirements.")
    }
    setIsLoading(false)
  }

  useEffect(() => {
    loadRequirements()
  }, [])

  const handleCancel = async (id: string) => {
    if (!confirm("Are you sure you want to cancel this requirement?")) return

    setCancellingId(id)
    const res = await cancelRequirementAction(id)
    if (res.success) {
      toast.success("Requirement cancelled successfully")
      await loadRequirements()
    } else {
      toast.error(res.error || "Failed to cancel requirement")
    }
    setCancellingId(null)
  }

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-48 border rounded-lg bg-card text-card-foreground shadow-sm">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    )
  }

  if (requirements.length === 0) {
    return (
      <div className="flex flex-col justify-center items-center h-48 border rounded-lg bg-card text-card-foreground shadow-sm gap-2">
        <p className="text-muted-foreground font-medium">No requirements found.</p>
        <p className="text-sm text-muted-foreground">Post a new requirement to get started.</p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="hidden md:block rounded-md border bg-card text-card-foreground shadow-sm overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Date Posted</TableHead>
              <TableHead>Commodity</TableHead>
              <TableHead>Quality Parameter</TableHead>
              <TableHead className="text-right">Qty</TableHead>
              <TableHead className="text-right">Target Price</TableHead>
              <TableHead className="text-center">Status</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {requirements.map((row) => {
              const req = row.requirement
              const canCancel = req.status === "Open" || req.status === "Draft"
              const isCancelling = cancellingId === req.id

              return (
                <TableRow key={req.id}>
                  <TableCell className="font-medium text-slate-600">
                    {format(new Date(req.createdAt), "MMM d, yyyy")}
                  </TableCell>
                  <TableCell>
                    <div className="flex flex-col">
                      {(row.industryName || row.categoryName) && (
                        <span className="text-[11px] font-semibold text-slate-400 tracking-wide uppercase">
                          {[row.industryName, row.categoryName].filter(Boolean).join(" • ")}
                        </span>
                      )}
                      <span className="font-semibold text-slate-800">{row.commodityName}</span>
                    </div>
                  </TableCell>
                  <TableCell className="text-slate-700 font-medium">{row.gradeName}</TableCell>
                  <TableCell className="text-right font-medium">{req.quantity}</TableCell>
                  <TableCell className="text-right font-bold text-slate-900">₹{req.targetPrice}</TableCell>
                  <TableCell className="text-center">
                    <Badge 
                      variant={req.status === "Open" ? "default" : req.status === "Cancelled" ? "destructive" : "secondary"}
                    >
                      {req.status}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-right">
                    {canCancel && (
                      <Button 
                        variant="ghost" 
                        size="sm" 
                        onClick={() => handleCancel(req.id)}
                        disabled={isCancelling}
                        className="text-destructive hover:text-destructive hover:bg-destructive/10"
                      >
                        {isCancelling ? (
                          <Loader2 className="h-4 w-4 animate-spin mr-2" />
                        ) : (
                          <XCircle className="h-4 w-4 mr-2" />
                        )}
                        Cancel
                      </Button>
                    )}
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </div>

      <div className="md:hidden flex flex-col space-y-4">
        {requirements.map((row) => {
          const req = row.requirement
          const canCancel = req.status === "Open" || req.status === "Draft"
          const isCancelling = cancellingId === req.id
          
          return (
            <div key={req.id} className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
              <div className="p-4 flex flex-col gap-3">
                <div className="flex justify-between items-start">
                  <div className="flex flex-col">
                    {(row.industryName || row.categoryName) && (
                      <span className="text-[10px] font-bold text-slate-400 tracking-wide uppercase mb-0.5">
                        {[row.industryName, row.categoryName].filter(Boolean).join(" • ")}
                      </span>
                    )}
                    <span className="text-slate-700 text-sm font-semibold">{row.commodityName} &bull; {row.gradeName}</span>
                    <span className="text-slate-900 font-bold text-lg mt-0.5">{req.quantity} &bull; ₹{req.targetPrice}</span>
                  </div>
                  <Badge 
                    variant={req.status === "Open" ? "default" : req.status === "Cancelled" ? "destructive" : "secondary"}
                  >
                    {req.status}
                  </Badge>
                </div>
                <div className="text-slate-400 text-xs font-medium uppercase tracking-wider">
                  Posted {format(new Date(req.createdAt), "MMM d, yyyy")}
                </div>
              </div>
              {canCancel && (
                <div className="border-t border-slate-100 bg-slate-50 p-2">
                  <Button 
                    variant="ghost" 
                    onClick={() => handleCancel(req.id)}
                    disabled={isCancelling}
                    className="w-full text-destructive hover:text-destructive hover:bg-destructive/10 min-h-[44px]"
                  >
                    {isCancelling ? (
                      <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    ) : (
                      <XCircle className="h-4 w-4 mr-2" />
                    )}
                    Cancel Requirement
                  </Button>
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}
