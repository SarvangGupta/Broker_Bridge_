'use client'

import { useState, useEffect } from 'react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { toast } from "sonner"
import { Loader2 } from "lucide-react"

import {
  getUnassignedRequirementsAction,
  getActiveBrokersAction,
  assignBrokerToRequirementAction
} from "@/src/server/actions/admin-actions"

import { RoleBadge } from "./role-badge"

export function DealDeskQueue() {
  const [requirements, setRequirements] = useState<any[]>([])
  const [brokers, setBrokers] = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [assigningId, setAssigningId] = useState<string | null>(null)

  const loadData = async () => {
    setLoading(true)
    const [reqRes, brokerRes] = await Promise.all([
      getUnassignedRequirementsAction(),
      getActiveBrokersAction()
    ])
    
    if (reqRes.success) setRequirements(reqRes.data || [])
    if (brokerRes.success) setBrokers(brokerRes.data || [])
    
    setLoading(false)
  }

  useEffect(() => {
    loadData()
  }, [])

  const handleAssignBroker = async (requirementId: string, brokerId: string) => {
    setAssigningId(requirementId)
    const res = await assignBrokerToRequirementAction(requirementId, brokerId)
    setAssigningId(null)

    if (res.success) {
      toast.success("Broker assigned successfully")
      // Remove from the local state list
      setRequirements(prev => prev.filter(r => r.id !== requirementId))
    } else {
      toast.error(res.error || "Failed to assign broker")
    }
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Deal Desk Queue</h2>
          <p className="text-sm text-slate-500 mt-1">Assign unassigned buyer requirements and seller availabilities to active brokers.</p>
        </div>
      </div>

      <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
        {loading ? (
          <div className="flex justify-center p-12"><Loader2 className="animate-spin w-8 h-8 text-[#475569]" /></div>
        ) : (
          <Table>
            <TableHeader className="bg-slate-50 border-b border-slate-200">
              <TableRow>
                <TableHead className="text-slate-600 font-semibold">Date</TableHead>
                <TableHead className="text-slate-600 font-semibold">Type</TableHead>
                <TableHead className="text-slate-600 font-semibold">Company</TableHead>
                <TableHead className="text-slate-600 font-semibold">Commodity</TableHead>
                <TableHead className="text-slate-600 font-semibold">Quantity</TableHead>
                <TableHead className="text-slate-600 font-semibold">Target Price</TableHead>
                <TableHead className="text-right text-slate-600 font-semibold">Assign Broker</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {requirements.map((req) => (
                <TableRow key={req.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                  <TableCell className="text-slate-600 text-sm">
                    {new Date(req.createdAt).toLocaleDateString()}
                  </TableCell>
                  <TableCell>
                    <RoleBadge role={req.type === 'Buyer Requirement' ? 'buyer' : 'seller'} className="whitespace-nowrap" />
                  </TableCell>
                  <TableCell className="font-medium text-[#334155]">{req.companyName || "-"}</TableCell>
                  <TableCell className="text-slate-600">{req.commodityName || "-"}</TableCell>
                  <TableCell className="text-slate-600">{req.quantity}</TableCell>
                  <TableCell className="text-slate-600 font-medium">₹{req.targetPrice}</TableCell>
                  <TableCell className="text-right">
                    <div className="flex justify-end items-center gap-2">
                      {assigningId === req.id && <Loader2 className="w-4 h-4 animate-spin text-slate-400" />}
                      <Select 
                        disabled={assigningId === req.id}
                        onValueChange={(brokerId: any) => handleAssignBroker(req.id as string, brokerId as string)}
                      >
                        <SelectTrigger className="w-[180px] bg-white border-slate-200 text-slate-700">
                          <SelectValue placeholder="Select broker" />
                        </SelectTrigger>
                        <SelectContent>
                          {brokers.map((broker) => (
                            <SelectItem key={broker.id} value={broker.id}>
                              {broker.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
              {requirements.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center text-slate-500 py-12">
                    No unassigned requirements or availabilities found.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        )}
      </div>
    </div>
  )
}
