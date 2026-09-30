'use client'

import { useState, useEffect } from 'react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { toast } from "sonner"
import { Loader2, CheckCircle2, XCircle } from "lucide-react"

import {
  getPendingCompaniesAction,
  approveCompanyAction,
  rejectCompanyAction
} from "@/src/server/actions/company-actions"

export function CompanyApprovalQueue() {
  const [companies, setCompanies] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [processingId, setProcessingId] = useState<string | null>(null)

  const loadCompanies = async () => {
    setLoading(true)
    const res = await getPendingCompaniesAction()
    if (res.success) {
      setCompanies(res.data || [])
    } else {
      toast.error(res.error || "Failed to load approval queue.")
    }
    setLoading(false)
  }

  useEffect(() => {
    loadCompanies()
  }, [])

  const handleApprove = async (id: string) => {
    setProcessingId(id)
    const res = await approveCompanyAction(id)
    if (res.success) {
      toast.success("Company approved successfully.")
      await loadCompanies()
    } else {
      toast.error(res.error || "Failed to approve company.")
    }
    setProcessingId(null)
  }

  const handleReject = async (id: string) => {
    setProcessingId(id)
    const res = await rejectCompanyAction(id)
    if (res.success) {
      toast.error("Company Rejected", {
        description: "The company profile has been rejected."
      })
      await loadCompanies()
    } else {
      toast.error(res.error || "Failed to reject company.")
    }
    setProcessingId(null)
  }

  const getStatusBadge = (item: any) => {
    if (item.company.status === true || item.company.isVerified === true) {
      return (
        <span className="px-2.5 py-1 rounded-md text-[11px] font-bold uppercase tracking-wider bg-[#ECFDF5] text-[#047857] border border-[#A7F3D0]">
          Approved
        </span>
      )
    }
    if (item.user?.status === false) {
      return (
        <span className="px-2.5 py-1 rounded-md text-[11px] font-bold uppercase tracking-wider bg-rose-50 text-rose-700 border border-rose-200">
          Rejected
        </span>
      )
    }
    return (
      <span className="px-2.5 py-1 rounded-md text-[11px] font-bold uppercase tracking-wider bg-amber-50 text-amber-700 border border-amber-200">
        Pending
      </span>
    )
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Company Approvals</h2>
          <p className="text-sm text-slate-500 mt-1">Review and approve new company registrations.</p>
        </div>
        <Button variant="outline" size="sm" onClick={loadCompanies} disabled={loading}>
          Refresh Queue
        </Button>
      </div>

      <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
        {loading ? (
          <div className="flex justify-center p-12"><Loader2 className="animate-spin w-8 h-8 text-[#475569]" /></div>
        ) : (
          <Table>
            <TableHeader className="bg-slate-50 border-b border-slate-200">
              <TableRow>
                <TableHead className="text-slate-600 font-semibold">Company Name</TableHead>
                <TableHead className="text-slate-600 font-semibold">GST Number</TableHead>
                <TableHead className="text-slate-600 font-semibold">Location</TableHead>
                <TableHead className="text-slate-600 font-semibold">User (Owner)</TableHead>
                <TableHead className="text-slate-600 font-semibold">Status</TableHead>
                <TableHead className="text-right text-slate-600 font-semibold">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {companies.map((item) => {
                const isApproved = item.company.status === true || item.company.isVerified === true
                const isRejected = item.user?.status === false && !isApproved
                const isProcessing = processingId === item.company.id

                return (
                  <TableRow key={item.company.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                    <TableCell className="font-medium text-[#334155]">{item.company.name}</TableCell>
                    <TableCell className="text-slate-600">{item.company.gst || 'N/A'}</TableCell>
                    <TableCell className="text-slate-600">
                      {item.districtName ? `${item.districtName}, ` : ''}{item.stateName || 'N/A'}
                    </TableCell>
                    <TableCell>
                      <div className="text-[#334155] font-medium">{item.user?.name}</div>
                      <div className="text-xs text-slate-500">{item.user?.email}</div>
                    </TableCell>
                    <TableCell>
                      {getStatusBadge(item)}
                    </TableCell>
                    <TableCell className="text-right space-x-2">
                      <Button 
                        variant="outline" 
                        size="sm"
                        onClick={() => handleApprove(item.company.id)}
                        disabled={isProcessing || isApproved}
                        className="text-green-700 border-green-200 bg-green-50 hover:bg-green-100 hover:text-green-800"
                      >
                        {isProcessing ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4 mr-1" />}
                        Approve
                      </Button>
                      <Button 
                        variant="outline" 
                        size="sm"
                        onClick={() => handleReject(item.company.id)}
                        disabled={isProcessing || isRejected}
                        className="text-red-700 border-red-200 bg-red-50 hover:bg-red-100 hover:text-red-800"
                      >
                        {isProcessing ? <Loader2 className="w-4 h-4 animate-spin" /> : <XCircle className="w-4 h-4 mr-1" />}
                        Reject
                      </Button>
                    </TableCell>
                  </TableRow>
                )
              })}
              {companies.length === 0 && (
                <TableRow><TableCell colSpan={6} className="text-center text-slate-500 py-12">No companies found in queue.</TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>
    </div>
  )
}
