'use client'

import { useEffect, useState } from "react"
import { format } from "date-fns"
import { toast } from "sonner"
import { Loader2, CheckCircle2, Headphones, Building2, User, Phone, Mail, AlertCircle } from "lucide-react"

import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"

import { getOpenTicketsAction, resolveTicketAction } from "@/src/server/actions/support-actions"
import { RoleBadge } from "./role-badge"

export function AdminHelpDeskQueue() {
  const [tickets, setTickets] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [resolvingId, setResolvingId] = useState<string | null>(null)
  const [viewTicket, setViewTicket] = useState<any | null>(null)

  const loadTickets = async () => {
    setIsLoading(true)
    const res = await getOpenTicketsAction()
    if (res.success && res.data) {
      setTickets(res.data)
    } else {
      toast.error(res.error || "Failed to load support tickets.")
    }
    setIsLoading(false)
  }

  useEffect(() => {
    loadTickets()
  }, [])

  const handleResolve = async (id: string) => {
    setResolvingId(id)
    try {
      const res = await resolveTicketAction(id)
      if (res.success) {
        toast.success("Ticket marked as resolved.")
        loadTickets()
        if (viewTicket?.id === id) {
          setViewTicket(null)
        }
      } else {
        toast.error(res.error || "Failed to resolve ticket.")
      }
    } catch (e) {
      toast.error("Unexpected error occurred.")
    } finally {
      setResolvingId(null)
    }
  }

  const getIssueBadge = (type: string) => {
    switch (type) {
      case "Technical Bug":
        return <Badge variant="outline" className="bg-rose-50 text-rose-700 border-rose-200 text-xs font-semibold">Technical Bug</Badge>
      case "Deal Issue":
        return <Badge variant="outline" className="bg-amber-50 text-amber-700 border-amber-200 text-xs font-semibold">Deal Issue</Badge>
      case "Master Data Request":
        return <Badge variant="outline" className="bg-blue-50 text-blue-700 border-blue-200 text-xs font-semibold">Master Data Request</Badge>
      case "Account & KYC":
        return <Badge variant="outline" className="bg-purple-50 text-purple-700 border-purple-200 text-xs font-semibold">Account & KYC</Badge>
      default:
        return <Badge variant="outline" className="bg-slate-50 text-slate-600 border-slate-200 text-xs font-semibold">{type || "General"}</Badge>
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Help Desk & Support Queue</h2>
          <p className="text-sm text-slate-500 mt-1">Review, manage, and resolve tickets escalated by Buyers, Sellers, and Brokers.</p>
        </div>
        <Button variant="outline" size="sm" onClick={loadTickets} disabled={isLoading} className="cursor-pointer">
          {isLoading && <Loader2 className="w-3.5 h-3.5 animate-spin mr-1.5" />}
          Refresh Queue
        </Button>
      </div>

      <Card className="border border-slate-200 bg-white shadow-xs rounded-2xl overflow-hidden">
        <CardHeader className="p-5 border-b border-slate-100 bg-slate-50/50">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Headphones className="w-5 h-5 text-slate-600" />
              <CardTitle className="text-base font-semibold text-slate-900">Support Requests</CardTitle>
            </div>
            <Badge variant="outline" className="bg-white border-slate-200 text-slate-700 font-medium">
              {tickets.filter(t => t.status === 'Open').length} Open Tickets
            </Badge>
          </div>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex justify-center p-12">
              <Loader2 className="h-8 w-8 animate-spin text-slate-600" />
            </div>
          ) : tickets.length === 0 ? (
            <div className="flex flex-col items-center justify-center p-12 text-center">
              <Headphones className="h-12 w-12 text-slate-300 mb-3" />
              <p className="text-base font-semibold text-slate-800">No Support Tickets</p>
              <p className="text-xs text-slate-500 max-w-sm mt-1">
                There are no open help tickets requiring administrative assistance right now.
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader className="bg-slate-50/80">
                  <TableRow>
                    <TableHead className="w-[130px] font-bold text-slate-700 text-xs">Date</TableHead>
                    <TableHead className="font-bold text-slate-700 text-xs">User / Enterprise</TableHead>
                    <TableHead className="font-bold text-slate-700 text-xs">Role</TableHead>
                    <TableHead className="font-bold text-slate-700 text-xs">Issue Category</TableHead>
                    <TableHead className="font-bold text-slate-700 text-xs max-w-[320px]">Description</TableHead>
                    <TableHead className="font-bold text-slate-700 text-xs text-center">Status</TableHead>
                    <TableHead className="font-bold text-slate-700 text-xs text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {tickets.map((ticket) => {
                    const isResolved = ticket.status === "Resolved"
                    return (
                      <TableRow key={ticket.id} className={isResolved ? "bg-slate-50/50 opacity-75" : "hover:bg-slate-50/80"}>
                        <TableCell className="text-xs text-slate-600 font-medium">
                          {ticket.createdAt ? format(new Date(ticket.createdAt), "MMM d, yyyy") : "N/A"}
                          <div className="text-[10px] text-slate-400">
                            {ticket.createdAt ? format(new Date(ticket.createdAt), "h:mm a") : ""}
                          </div>
                        </TableCell>
                        <TableCell className="min-w-[160px]">
                          <div className="flex flex-col">
                            <span className="font-semibold text-sm text-slate-900 flex items-center gap-1">
                              <User className="w-3.5 h-3.5 text-slate-400" />
                              {ticket.userName || "Unknown User"}
                            </span>
                            <span className="text-xs text-slate-500 flex items-center gap-1 mt-0.5">
                              <Building2 className="w-3 h-3 text-slate-400" />
                              {ticket.companyName || "Direct Individual"}
                            </span>
                          </div>
                        </TableCell>
                        <TableCell>
                          <RoleBadge role={ticket.role} />
                        </TableCell>
                        <TableCell>
                          {getIssueBadge(ticket.issueType)}
                        </TableCell>
                        <TableCell className="max-w-[320px]">
                          <p 
                            className="text-xs text-slate-700 truncate cursor-pointer hover:text-slate-900 transition-colors"
                            onClick={() => setViewTicket(ticket)}
                            title="Click to view full description"
                          >
                            {ticket.description}
                          </p>
                        </TableCell>
                        <TableCell className="text-center">
                          {isResolved ? (
                            <Badge variant="outline" className="bg-emerald-50 text-emerald-700 border-emerald-200 text-xs font-semibold">
                              Resolved
                            </Badge>
                          ) : (
                            <Badge variant="outline" className="bg-amber-50 text-amber-700 border-amber-200 text-xs font-semibold">
                              Open
                            </Badge>
                          )}
                        </TableCell>
                        <TableCell className="text-right">
                          <div className="flex items-center justify-end gap-2">
                            <Button
                              variant="ghost"
                              size="sm"
                              className="text-xs h-8 text-slate-600 hover:text-slate-900 cursor-pointer"
                              onClick={() => setViewTicket(ticket)}
                            >
                              View
                            </Button>
                            {!isResolved && (
                              <Button
                                size="sm"
                                variant="outline"
                                className="h-8 text-xs text-emerald-700 border-emerald-300 bg-emerald-50/50 hover:bg-emerald-100 hover:text-emerald-800 font-semibold cursor-pointer gap-1"
                                disabled={resolvingId === ticket.id}
                                onClick={() => handleResolve(ticket.id)}
                              >
                                {resolvingId === ticket.id ? (
                                  <Loader2 className="w-3.5 h-3.5 animate-spin" />
                                ) : (
                                  <CheckCircle2 className="w-3.5 h-3.5" />
                                )}
                                Mark Resolved
                              </Button>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Ticket Details Dialog */}
      <Dialog open={!!viewTicket} onOpenChange={(open) => !open && setViewTicket(null)}>
        <DialogContent className="sm:max-w-[520px] p-6 bg-white rounded-2xl">
          <DialogHeader className="text-left pb-2">
            <div className="flex items-center gap-2">
              {viewTicket && getIssueBadge(viewTicket.issueType)}
              <DialogTitle className="text-lg font-bold text-slate-900">Support Ticket Details</DialogTitle>
            </div>
            <DialogDescription className="text-xs text-slate-500">
              Submitted on {viewTicket?.createdAt ? format(new Date(viewTicket.createdAt), "MMMM d, yyyy 'at' h:mm a") : ""}
            </DialogDescription>
          </DialogHeader>

          {viewTicket && (
            <div className="space-y-4 pt-2">
              <div className="p-4 bg-slate-50 rounded-xl border border-slate-200/80 space-y-2">
                <div className="flex items-center justify-between text-xs text-slate-600">
                  <span className="font-semibold text-slate-700">Reporter:</span>
                  <span>{viewTicket.userName || "Unknown"} ({viewTicket.role})</span>
                </div>
                <div className="flex items-center justify-between text-xs text-slate-600">
                  <span className="font-semibold text-slate-700">Company:</span>
                  <span>{viewTicket.companyName || "Direct Individual"}</span>
                </div>
                {viewTicket.userEmail && (
                  <div className="flex items-center justify-between text-xs text-slate-600">
                    <span className="font-semibold text-slate-700">Email:</span>
                    <span>{viewTicket.userEmail}</span>
                  </div>
                )}
                {viewTicket.userMobile && (
                  <div className="flex items-center justify-between text-xs text-slate-600">
                    <span className="font-semibold text-slate-700">Mobile:</span>
                    <span>{viewTicket.userMobile}</span>
                  </div>
                )}
              </div>

              <div>
                <h4 className="text-xs font-semibold text-slate-700 mb-1.5">Issue Description:</h4>
                <div className="p-4 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 whitespace-pre-wrap leading-relaxed">
                  {viewTicket.description}
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <Button variant="outline" onClick={() => setViewTicket(null)} className="cursor-pointer">
                  Close
                </Button>
                {viewTicket.status !== "Resolved" && (
                  <Button
                    className="bg-emerald-600 hover:bg-emerald-700 text-white cursor-pointer gap-1.5"
                    disabled={resolvingId === viewTicket.id}
                    onClick={() => handleResolve(viewTicket.id)}
                  >
                    {resolvingId === viewTicket.id ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <CheckCircle2 className="w-4 h-4" />
                    )}
                    Mark Resolved
                  </Button>
                )}
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}
