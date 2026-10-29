'use client'

import { useState, useEffect } from 'react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { toast } from "sonner"
import { Loader2, CheckCircle2, XCircle, Eye, AlertTriangle } from "lucide-react"

import {
  getBuyerGstVerificationsAction,
  getGstCertificatePreviewAction,
  reviewBuyerGstVerificationAction,
  type BuyerGstVerificationRow,
} from "@/src/server/actions/buyer-gst-verification-actions"

const FIELDS: Array<[label: string, ocrKey: string, column: keyof BuyerGstVerificationRow]> = [
  ['GSTIN', 'gstin', 'gstin'],
  ['Legal name', 'legalName', 'legal_name'],
  ['Trade name', 'tradeName', 'trade_name'],
  ['Constitution', 'constitution', 'constitution'],
  ['Principal address', 'address', 'principal_address'],
  ['PIN code', 'pinCode', 'pin_code'],
  ['Registration type', 'registrationType', 'registration_type'],
  ['Date of liability', 'registrationDate', 'registration_date'],
  ['Valid from', 'validityFrom', 'validity_from'],
  ['Valid to', 'validityTo', 'validity_to'],
  ['Issue date', 'issueDate', 'issue_date'],
]

export function BuyerGstVerificationQueue() {
  const [rows, setRows] = useState<BuyerGstVerificationRow[]>([])
  const [loading, setLoading] = useState(false)
  const [selected, setSelected] = useState<BuyerGstVerificationRow | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [reason, setReason] = useState('')
  const [processing, setProcessing] = useState(false)

  const load = async () => {
    setLoading(true)
    const res = await getBuyerGstVerificationsAction('pending')
    if (res.success) setRows(res.data)
    else toast.error(res.error || 'Failed to load GST verifications.')
    setLoading(false)
  }

  useEffect(() => {
    load()
  }, [])

  const open = async (row: BuyerGstVerificationRow) => {
    setSelected(row)
    setReason('')
    setPreviewUrl(null)
    const res = await getGstCertificatePreviewAction(row.certificate_path)
    if (res.success) setPreviewUrl(res.url)
    else toast.error(res.error || 'Certificate preview unavailable.')
  }

  const decide = async (decision: 'approve' | 'reject') => {
    if (!selected) return
    if (decision === 'reject' && !reason.trim()) {
      toast.error('Enter a rejection reason.')
      return
    }
    setProcessing(true)
    const res = await reviewBuyerGstVerificationAction(selected.id, decision, reason)
    setProcessing(false)
    if (!res.success) {
      toast.error(res.error || 'Review failed.')
      return
    }
    toast.success(decision === 'approve' ? 'GST verification approved.' : 'GST verification rejected.')
    setSelected(null)
    await load()
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Buyer GST Verifications</h2>
          <p className="text-sm text-slate-500 mt-1">
            Compare each certificate with the Buyer&apos;s reviewed values. Only an approval here marks a Buyer company verified.
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={load} disabled={loading}>
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
                <TableHead className="text-slate-600 font-semibold">Company</TableHead>
                <TableHead className="text-slate-600 font-semibold">GSTIN</TableHead>
                <TableHead className="text-slate-600 font-semibold">Legal name</TableHead>
                <TableHead className="text-slate-600 font-semibold">Flags</TableHead>
                <TableHead className="text-slate-600 font-semibold">Submitted</TableHead>
                <TableHead className="text-right text-slate-600 font-semibold">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((row) => (
                <TableRow key={row.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                  <TableCell className="font-medium text-[#334155]">{row.companies?.name ?? row.company_id.substring(0, 8)}</TableCell>
                  <TableCell className="font-mono text-xs text-slate-600">{row.gstin}</TableCell>
                  <TableCell className="text-slate-600">{row.legal_name}</TableCell>
                  <TableCell className="space-x-1">
                    {row.edited_fields.length > 0 && (
                      <span className="px-2 py-0.5 rounded-md text-[11px] font-bold bg-amber-50 text-amber-700 border border-amber-200">
                        {row.edited_fields.length} edited
                      </span>
                    )}
                    {row.seller_gstin_conflict && (
                      <span className="px-2 py-0.5 rounded-md text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">
                        Seller GSTIN conflict
                      </span>
                    )}
                  </TableCell>
                  <TableCell className="text-xs text-slate-500">{new Date(row.submitted_at).toLocaleString()}</TableCell>
                  <TableCell className="text-right">
                    <Button variant="outline" size="sm" onClick={() => open(row)}>
                      <Eye className="w-4 h-4 mr-1" /> Review
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
              {rows.length === 0 && (
                <TableRow><TableCell colSpan={6} className="text-center text-slate-500 py-12">No pending GST verifications.</TableCell></TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>

      <Dialog open={selected !== null} onOpenChange={(o) => { if (!o) setSelected(null) }}>
        <DialogContent className="max-w-5xl">
          <DialogHeader>
            <DialogTitle>Review GST certificate</DialogTitle>
            <DialogDescription>
              {selected?.companies?.name} · stored GSTIN {selected?.companies?.gst || 'none'}. The company name is not changed by approval.
            </DialogDescription>
          </DialogHeader>
          {selected && (
            <div className="grid grid-cols-2 gap-6">
              <div className="border border-slate-200 rounded-lg p-2 bg-slate-50 min-h-[320px] flex items-center justify-center">
                {previewUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={previewUrl} alt="GST certificate" className="max-h-[520px] object-contain" />
                ) : (
                  <span className="text-sm text-slate-500">Loading preview (link expires in 60 s)…</span>
                )}
              </div>
              <div>
                {selected.seller_gstin_conflict && (
                  <div className="mb-3 flex items-center gap-2 text-sm text-rose-700">
                    <AlertTriangle className="w-4 h-4" /> This GSTIN is also on a Seller company. Confirm before approving.
                  </div>
                )}
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-left text-slate-500">
                      <th className="py-1 pr-2">Field</th><th className="py-1 pr-2">Read by OCR</th><th className="py-1">Submitted</th>
                    </tr>
                  </thead>
                  <tbody>
                    {FIELDS.map(([label, ocrKey, column]) => {
                      const edited = selected.edited_fields.includes(ocrKey)
                      return (
                        <tr key={ocrKey} className={edited ? 'bg-amber-50' : ''}>
                          <td className="py-1 pr-2 text-slate-500">{label}</td>
                          <td className="py-1 pr-2 text-slate-600">{selected.ocr_values?.[ocrKey] ?? '—'}</td>
                          <td className="py-1 font-medium text-[#334155]">
                            {String(selected[column] ?? '—')}{edited && <span className="ml-1 text-[11px] text-amber-700">(edited)</span>}
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
                <div className="mt-4">
                  <Label htmlFor="gst-reject-reason">Rejection reason (required to reject)</Label>
                  <textarea
                    id="gst-reject-reason"
                    value={reason}
                    onChange={(e) => setReason(e.target.value)}
                    className="mt-1 w-full rounded-md border border-slate-300 p-2 text-sm"
                    rows={3}
                  />
                </div>
              </div>
            </div>
          )}
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => decide('reject')}
              disabled={processing}
              className="text-red-700 border-red-200 bg-red-50 hover:bg-red-100"
            >
              {processing ? <Loader2 className="w-4 h-4 animate-spin" /> : <XCircle className="w-4 h-4 mr-1" />} Reject
            </Button>
            <Button
              onClick={() => decide('approve')}
              disabled={processing}
              className="bg-emerald-700 hover:bg-emerald-800 text-white"
            >
              {processing ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4 mr-1" />} Approve
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
