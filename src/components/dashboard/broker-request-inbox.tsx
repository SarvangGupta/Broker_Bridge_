"use client";

import { useState, useEffect } from "react";
import { format, formatDistanceToNowStrict, isPast } from "date-fns";
import {
  Handshake,
  Clock,
  CheckCircle2,
  XCircle,
  ArrowUpDown,
  AlertCircle,
  Truck,
  Sparkles,
  Layers,
  Building2,
  Calendar,
  MessageSquare,
  ShieldCheck,
  Loader2,
  PlusCircle,
  BadgePercent,
  Check,
  X,
  Send,
  HelpCircle,
  MapPin,
  History,
  FileCheck2,
} from "lucide-react";
import Link from "next/link";
import { toast } from "sonner";
import { useRouter, useSearchParams } from "next/navigation";
import { useQueryClient } from "@tanstack/react-query";
import { cn, formatIndianCurrency } from "@/lib/utils";
import { useMediaQuery } from "@/src/hooks/use-media-query";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { NegotiationTimeline } from "@/src/components/dashboard/negotiation-timeline";

import {
  SellerBrokerRequestItem,
  BrokerResponsePayload,
} from "@/src/types/broker-request-schema";
import {
  respondToBrokerRequestAction,
} from "@/src/server/actions/broker-request-actions";

interface BrokerRequestInboxProps {
  initialRequests: SellerBrokerRequestItem[];
}

export const ACCEPTED_PROPOSAL_STATES = [
  "Seller Confirmed",
  "Buyer Confirmed",
  "Broker Finalized",
  "Booked",
  "Confirmed",
  "Dispatch Pending",
  "Seller Accepted",
  "Accepted",
];

export const PENDING_PROPOSAL_STATES = [
  "Open",
  "Proposed",
  "Countered",
  "Pending",
  "Sent",
];

const QUICK_REJECTION_REASONS = [
  "Price is below minimum profitable margin",
  "Insufficient available inventory for requested quantity",
  "Delivery schedule cannot be accommodated",
  "Quality specifications cannot be guaranteed",
  "Payment terms unacceptable",
  "Warehouse loading capacity fully booked",
];

export function BrokerRequestInbox({ initialRequests }: BrokerRequestInboxProps) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const searchParams = useSearchParams();
  const deepLinkedRequestId = searchParams?.get("requestId");

  const [requests, setRequests] = useState<SellerBrokerRequestItem[]>(initialRequests);
  const [activeTab, setActiveTab] = useState<string>("all");

  // Timeline Sheet State (Micro-Sprint 17.5)
  const [timelineRequest, setTimelineRequest] = useState<SellerBrokerRequestItem | null>(null);
  const isDesktop = useMediaQuery("(min-width: 768px)");

  // Response Modals State
  const [selectedRequest, setSelectedRequest] = useState<SellerBrokerRequestItem | null>(null);
  const [actionType, setActionType] = useState<"accept" | "reject" | "counter" | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Auto-Focus / Deep Link Handler (Sprint 16.4)
  useEffect(() => {
    if (deepLinkedRequestId) {
      const target = requests.find((r) => r.id === deepLinkedRequestId);
      if (target) {
        // Adjust active tab to ensure the target card is rendered
        if (ACCEPTED_PROPOSAL_STATES.includes(target.status)) {
          setActiveTab("accepted");
        } else if (target.status === "Seller Countered" || target.status === "Countered") {
          setActiveTab("countered");
        } else if (target.status === "Seller Rejected" || target.status === "Rejected") {
          setActiveTab("rejected");
        } else if (target.status === "Expired") {
          setActiveTab("expired");
        } else {
          setActiveTab("pending");
        }

        // Smooth scroll to card
        setTimeout(() => {
          const el = document.getElementById(`request-card-${deepLinkedRequestId}`);
          if (el) {
            el.scrollIntoView({ behavior: "smooth", block: "center" });
          }
        }, 150);
      }
    }
  }, [deepLinkedRequestId, requests]);

  // Rejection Form State
  const [rejectionReason, setRejectionReason] = useState("");

  // Counter Form State
  const [counterPrice, setCounterPrice] = useState<number | undefined>(undefined);
  const [counterQuantity, setCounterQuantity] = useState<number | undefined>(undefined);
  const [counterDeliveryDate, setCounterDeliveryDate] = useState<string>("");
  const [counterRemarks, setCounterRemarks] = useState("");

  // Filter requests based on tab
  const filteredRequests = requests.filter((item) => {
    if (activeTab === "pending") {
      return PENDING_PROPOSAL_STATES.includes(item.status);
    }
    if (activeTab === "accepted") {
      return ACCEPTED_PROPOSAL_STATES.includes(item.status);
    }
    if (activeTab === "countered") {
      return item.status === "Seller Countered" || item.status === "Countered";
    }
    if (activeTab === "rejected") {
      return item.status === "Seller Rejected" || item.status === "Rejected";
    }
    if (activeTab === "expired") {
      return item.status === "Expired";
    }
    return true;
  });

  // Open Accept Modal
  const handleOpenAccept = (req: SellerBrokerRequestItem) => {
    setSelectedRequest(req);
    setActionType("accept");
  };

  // Open Reject Modal
  const handleOpenReject = (req: SellerBrokerRequestItem) => {
    setSelectedRequest(req);
    setActionType("reject");
    setRejectionReason("");
  };

  // Open Counter Modal
  const handleOpenCounter = (req: SellerBrokerRequestItem) => {
    setSelectedRequest(req);
    setActionType("counter");
    setCounterPrice(req.proposedRate);
    setCounterQuantity(req.requestedQuantity);
    setCounterDeliveryDate(req.targetDate ? format(new Date(req.targetDate), "yyyy-MM-dd") : "");
    setCounterRemarks("");
  };

  const handleCloseModals = () => {
    setSelectedRequest(null);
    setActionType(null);
    setIsSubmitting(false);
  };

  // Submit Accept
  async function handleSubmitAccept() {
    if (!selectedRequest) return;
    setIsSubmitting(true);
    try {
      const res = await respondToBrokerRequestAction({
        requestId: selectedRequest.id,
        action: "accept",
        expectedVersionNumber: selectedRequest.latestVersionNumber ?? 1,
      });
      if (res.success) {
        toast.success(res.message || "Proposal accepted successfully!");
        handleCloseModals();
        router.refresh();
      } else {
        if (res.error?.includes("STALE_VERSION_DETECTED")) {
          toast.error("Stale terms detected.", {
            description: "The Broker updated this proposal while you were viewing it. Refreshing terms...",
            action: {
              label: "Refresh Deal",
              onClick: () => {
                queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
                router.refresh();
              },
            },
          });
          handleCloseModals();
          queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
          router.refresh();
        } else {
          toast.error(res.error || "Failed to accept proposal");
        }
      }
    } catch (error: any) {
      if (error.message?.includes("STALE_VERSION_DETECTED")) {
        toast.error("Stale terms detected.", {
          description: "The Broker updated this proposal while you were viewing it. Refreshing terms...",
          action: {
            label: "Refresh Deal",
            onClick: () => {
              queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
              router.refresh();
            },
          },
        });
        handleCloseModals();
        queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
        router.refresh();
      } else {
        toast.error(error.message || "An unexpected error occurred");
      }
    } finally {
      setIsSubmitting(false);
    }
  }

  // Submit Reject
  async function handleSubmitReject() {
    if (!selectedRequest) return;
    if (!rejectionReason.trim() || rejectionReason.trim().length < 5) {
      toast.error("Please provide a valid rejection reason (minimum 5 characters)");
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await respondToBrokerRequestAction({
        requestId: selectedRequest.id,
        action: "reject",
        rejectionReason: rejectionReason.trim(),
        expectedVersionNumber: selectedRequest.latestVersionNumber ?? 1,
      });
      if (res.success) {
        toast.success(res.message || "Proposal rejected with notes.");
        handleCloseModals();
        router.refresh();
      } else {
        if (res.error?.includes("STALE_VERSION_DETECTED")) {
          toast.error("Stale terms detected.", {
            description: "The Broker updated this proposal while you were viewing it. Refreshing terms...",
            action: {
              label: "Refresh Deal",
              onClick: () => {
                queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
                router.refresh();
              },
            },
          });
          handleCloseModals();
          queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
          router.refresh();
        } else {
          toast.error(res.error || "Failed to reject proposal");
        }
      }
    } catch (error: any) {
      if (error.message?.includes("STALE_VERSION_DETECTED")) {
        toast.error("Stale terms detected.", {
          description: "The Broker updated this proposal while you were viewing it. Refreshing terms...",
          action: {
            label: "Refresh Deal",
            onClick: () => {
              queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
              router.refresh();
            },
          },
        });
        handleCloseModals();
        queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
        router.refresh();
      } else {
        toast.error(error.message || "An unexpected error occurred");
      }
    } finally {
      setIsSubmitting(false);
    }
  }

  // Submit Counter
  async function handleSubmitCounter() {
    if (!selectedRequest) return;
    setIsSubmitting(true);
    try {
      const res = await respondToBrokerRequestAction({
        requestId: selectedRequest.id,
        action: "counter",
        counterPrice,
        counterQuantity,
        counterDeliveryDate: counterDeliveryDate || undefined,
        counterRemarks: counterRemarks.trim() || undefined,
        expectedVersionNumber: selectedRequest.latestVersionNumber ?? 1,
      });
      if (res.success) {
        toast.success(res.message || "Counter-proposal submitted to Broker!");
        handleCloseModals();
        router.refresh();
      } else {
        if (res.error?.includes("STALE_VERSION_DETECTED")) {
          toast.error("Stale terms detected.", {
            description: "The Broker updated this proposal while you were viewing it. Refreshing terms...",
            action: {
              label: "Refresh Deal",
              onClick: () => {
                queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
                router.refresh();
              },
            },
          });
          handleCloseModals();
          queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
          router.refresh();
        } else {
          toast.error(res.error || "Failed to submit counter-proposal");
        }
      }
    } catch (error: any) {
      if (error.message?.includes("STALE_VERSION_DETECTED")) {
        toast.error("Stale terms detected.", {
          description: "The Broker updated this proposal while you were viewing it. Refreshing terms...",
          action: {
            label: "Refresh Deal",
            onClick: () => {
              queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
              router.refresh();
            },
          },
        });
        handleCloseModals();
        queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
        router.refresh();
      } else {
        toast.error(error.message || "An unexpected error occurred");
      }
    } finally {
      setIsSubmitting(false);
    }
  }



  // Helper to format countdown tag
  function renderDeadlineBadge(expiresAt: Date | string, status: string) {
    const exp = new Date(expiresAt);
    const expired = isPast(exp) || status === "Expired";

    if (expired) {
      return (
        <Badge variant="outline" className="bg-rose-50 text-rose-700 border-rose-200 font-semibold px-2 py-0.5 text-[11px] gap-1">
          <Clock className="h-3 w-3" />
          <span>Expired</span>
        </Badge>
      );
    }

    const diffHours = (exp.getTime() - Date.now()) / (1000 * 60 * 60);

    if (diffHours <= 24) {
      return (
        <Badge variant="outline" className="bg-amber-50 text-amber-700 border-amber-200 font-semibold px-2 py-0.5 text-[11px] gap-1 animate-pulse">
          <Clock className="h-3 w-3" />
          <span>{Math.max(1, Math.round(diffHours))}h remaining</span>
        </Badge>
      );
    }

    return (
      <Badge variant="outline" className="bg-emerald-50 text-[#047857] border-emerald-200 font-semibold px-2 py-0.5 text-[11px] gap-1">
        <Clock className="h-3 w-3" />
        <span>{formatDistanceToNowStrict(exp)} left</span>
      </Badge>
    );
  }

  return (
    <div className="space-y-6">
      
      {/* 1. TOP HEADER RIBBON */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 bg-white p-5 sm:p-6 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <h2 className="text-2xl sm:text-3xl font-semibold text-slate-900 tracking-tight">
            Trade Offers
          </h2>
          <p className="text-sm sm:text-base text-slate-600 mt-1">
            Review and respond to price offers from your broker.
          </p>
        </div>
      </div>

      {/* 2. FILTER TABS */}
      {(() => {
        const allCount = requests.length;
        const pendingCount = requests.filter(r => PENDING_PROPOSAL_STATES.includes(r.status)).length;
        const acceptedCount = requests.filter(r => ACCEPTED_PROPOSAL_STATES.includes(r.status)).length;
        const counteredCount = requests.filter(r => r.status === 'Seller Countered' || r.status === 'Countered').length;
        const rejectedCount = requests.filter(r => r.status === 'Seller Rejected' || r.status === 'Rejected').length;

        return (
          <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
            <TabsList className="group-data-horizontal/tabs:h-auto h-auto w-full sm:w-auto inline-flex flex-wrap bg-slate-200/80 p-1.5 rounded-2xl gap-1.5 border border-slate-300/70 shadow-2xs">
              <TabsTrigger value="all" className="rounded-xl min-h-[44px] sm:min-h-[48px] py-2.5 px-4 text-sm sm:text-base font-bold cursor-pointer text-slate-700 data-active:bg-white data-active:text-slate-900 data-active:shadow-sm transition-all">
                All {allCount > 0 && <span className="ml-1.5 rounded-full bg-slate-100 text-slate-900 px-2 py-0.5 text-xs font-bold border border-slate-300/60">{allCount}</span>}
              </TabsTrigger>
              <TabsTrigger value="pending" className="rounded-xl min-h-[44px] sm:min-h-[48px] py-2.5 px-4 text-sm sm:text-base font-bold cursor-pointer text-slate-700 data-active:bg-white data-active:text-slate-900 data-active:shadow-sm transition-all">
                Pending {pendingCount > 0 && <span className="ml-1.5 rounded-full bg-amber-100 text-amber-900 px-2 py-0.5 text-xs font-bold border border-amber-300/60">{pendingCount}</span>}
              </TabsTrigger>
              <TabsTrigger value="accepted" className="rounded-xl min-h-[44px] sm:min-h-[48px] py-2.5 px-4 text-sm sm:text-base font-bold cursor-pointer text-slate-700 data-active:bg-white data-active:text-slate-900 data-active:shadow-sm transition-all">
                Accepted {acceptedCount > 0 && <span className="ml-1.5 rounded-full bg-emerald-100 text-emerald-900 px-2 py-0.5 text-xs font-bold border border-emerald-300/60">{acceptedCount}</span>}
              </TabsTrigger>
              <TabsTrigger value="countered" className="rounded-xl min-h-[44px] sm:min-h-[48px] py-2.5 px-4 text-sm sm:text-base font-bold cursor-pointer text-slate-700 data-active:bg-white data-active:text-slate-900 data-active:shadow-sm transition-all">
                Countered {counteredCount > 0 && <span className="ml-1.5 rounded-full bg-sky-100 text-sky-900 px-2 py-0.5 text-xs font-bold border border-sky-300/60">{counteredCount}</span>}
              </TabsTrigger>
              <TabsTrigger value="rejected" className="rounded-xl min-h-[44px] sm:min-h-[48px] py-2.5 px-4 text-sm sm:text-base font-bold cursor-pointer text-slate-700 data-active:bg-white data-active:text-slate-900 data-active:shadow-sm transition-all">
                Rejected {rejectedCount > 0 && <span className="ml-1.5 rounded-full bg-rose-100 text-rose-900 px-2 py-0.5 text-xs font-bold border border-rose-300/60">{rejectedCount}</span>}
              </TabsTrigger>
            </TabsList>
          </Tabs>
        );
      })()}

      {/* 3. REQUEST CARDS LIST */}
      {filteredRequests.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200/80 p-8 sm:p-12 text-center flex flex-col items-center justify-center shadow-xs">
          <div className="h-12 w-12 rounded-2xl bg-slate-100 flex items-center justify-center text-slate-400 mb-3">
            <Handshake className="h-6 w-6 stroke-[1.75]" />
          </div>
          <h3 className="text-lg sm:text-xl font-bold text-slate-900">No active offers right now</h3>
          <p className="text-sm sm:text-base text-slate-600 max-w-md mt-1 leading-relaxed">
            When a broker sends a price offer for your inventory, it will appear here.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6">
          {filteredRequests.map((req) => {
            const isPending = PENDING_PROPOSAL_STATES.includes(req.status);
            const isAccepted = ACCEPTED_PROPOSAL_STATES.includes(req.status);
            const isCountered = req.status === "Seller Countered" || req.status === "Countered";
            const isRejected = req.status === "Seller Rejected" || req.status === "Rejected";
            const isExpired = req.status === "Expired";
            const isDeepLinked = req.id === deepLinkedRequestId;
            const totalValue = req.proposedRate * req.requestedQuantity;

            return (
              <div
                key={req.id}
                id={`request-card-${req.id}`}
                className={cn(
                  "bg-white rounded-2xl border p-5 sm:p-6 shadow-xs flex flex-col justify-between transition-all duration-300 relative group scroll-mt-24",
                  isDeepLinked
                    ? "ring-2 ring-emerald-500 ring-offset-2 border-emerald-400 bg-emerald-50/15 shadow-md"
                    : isPending
                    ? "border-emerald-200/90 hover:border-emerald-300 hover:shadow-md"
                    : "border-slate-200/80"
                )}
              >
                <div>
                  {/* TOP HEADER: Request ID, Commodity Breadcrumb, Deadline Badge */}
                  <div className="flex items-start justify-between gap-2 mb-3">
                    <div>
                      <div className="flex items-center gap-1.5 flex-wrap mb-1">
                        <span className="text-[11px] font-mono font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-100">
                          #REQ-{req.id.slice(0, 6).toUpperCase()}
                        </span>
                        <button
                          type="button"
                          onClick={() => setTimelineRequest(req)}
                          className="inline-flex items-center gap-1 text-[11px] font-mono font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 px-2 py-0.5 rounded border border-slate-200 transition-colors cursor-pointer"
                          title="Click to view full negotiation timeline"
                        >
                          <History className="h-3 w-3 text-slate-500" />
                          <span>v{req.latestVersionNumber || 1}</span>
                        </button>
                        {req.lotNumber && (
                          <span className="text-[11px] font-mono text-slate-500 bg-slate-100 px-1.5 py-0.5 rounded border border-slate-200">
                            Lot #{req.lotNumber}
                          </span>
                        )}
                        {isDeepLinked && (
                          <span className="text-[10px] font-bold text-emerald-800 bg-emerald-100/90 border border-emerald-300 px-2 py-0.5 rounded-md inline-flex items-center gap-1">
                            <MapPin className="h-3 w-3 text-emerald-600" />
                            <span>Linked Request</span>
                          </span>
                        )}
                      </div>
                      <span className="text-xs font-bold uppercase tracking-wider text-slate-700 block">
                        {req.commodityName}
                      </span>
                      <h3 className="text-base sm:text-lg font-semibold text-slate-900 leading-tight">
                        {req.gradeName}
                      </h3>
                    </div>

                    <div className="flex flex-col items-end gap-1.5 shrink-0">
                      {/* Status Badge */}
                      <Badge
                        variant="outline"
                        className={cn(
                          "font-semibold text-xs px-2.5 py-0.5 rounded-full shrink-0 shadow-2xs",
                          isPending && "bg-emerald-50 text-[#047857] border-emerald-200 font-bold",
                          isAccepted && "bg-emerald-50 text-emerald-700 border-emerald-200",
                          isCountered && "bg-sky-50 text-sky-700 border-sky-200",
                          isRejected && "bg-rose-50 text-rose-700 border-rose-200",
                          isExpired && "bg-slate-100 text-slate-600 border-slate-200"
                        )}
                      >
                        {req.status}
                      </Badge>

                      {/* Deadline Remaining */}
                      {isPending && renderDeadlineBadge(req.expiresAt, req.status)}
                    </div>
                  </div>

                  {/* BROKER PROVENANCE & HUMAN MEDIATION PILL */}
                  <div className="flex items-center gap-2.5 px-3 py-2 bg-emerald-50/80 border border-emerald-200/90 rounded-xl mb-3.5 text-xs">
                    <ShieldCheck className="h-4 w-4 text-emerald-600 shrink-0 stroke-[2.2]" />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="font-bold text-emerald-900 truncate">
                          {req.brokerName || "Verified Broker Desk"}
                        </span>
                        {req.brokerCompany && (
                          <span className="text-[11px] text-emerald-700 font-medium truncate">
                            • {req.brokerCompany}
                          </span>
                        )}
                        {req.isBrokerVerified && (
                          <Badge variant="outline" className="bg-white text-[#047857] border-emerald-300 text-[10px] font-bold px-1.5 py-0 shadow-2xs">
                            Verified Desk
                          </Badge>
                        )}
                      </div>
                      <span className="text-[10px] text-emerald-700/90 block leading-tight mt-0.5">
                        Human-Mediated Proposal (Zero Autonomous AI Execution)
                      </span>
                    </div>
                  </div>

                  {/* COMMERCIAL HIGHLIGHTS GRID */}
                  <div className="grid grid-cols-2 gap-3 p-3.5 bg-slate-50/90 rounded-xl border border-slate-100 mb-4">
                    <div>
                      <span className="text-[11px] font-medium text-slate-400 uppercase tracking-wider block">
                        Requested Quantity
                      </span>
                      <span className="text-base sm:text-lg font-bold text-slate-900">
                        {req.requestedQuantity} {req.unitSymbol}
                      </span>
                      {req.askingPrice && (
                        <span className="text-[11px] text-slate-400 block mt-0.5">
                          Asking: ₹{req.askingPrice}/{req.unitSymbol}
                        </span>
                      )}
                    </div>
                    <div>
                      <span className="text-[11px] font-medium text-slate-400 uppercase tracking-wider block">
                        Proposed Rate
                      </span>
                      <span className="text-base sm:text-lg font-bold text-[#059669]">
                        ₹{req.proposedRate}/{req.unitSymbol}
                      </span>
                      <span className="text-[11px] font-semibold text-slate-500 block mt-0.5">
                        Est: ₹{formatIndianCurrency(totalValue)}
                      </span>
                    </div>
                  </div>

                  {/* SPECIFICATIONS STRIP */}
                  <div className="space-y-2 text-xs text-slate-600 mb-4">
                    <div className="flex items-center gap-2">
                      <Truck className="h-3.5 w-3.5 text-slate-400 shrink-0" />
                      <span className="font-medium text-slate-700">Delivery:</span>
                      <span className="truncate">{req.deliveryTerms}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <ShieldCheck className="h-3.5 w-3.5 text-slate-400 shrink-0" />
                      <span className="font-medium text-slate-700">Settlement:</span>
                      <span className="truncate">{req.paymentTerms}</span>
                    </div>
                    {req.targetDate && (
                      <div className="flex items-center gap-2">
                        <Calendar className="h-3.5 w-3.5 text-slate-400 shrink-0" />
                        <span className="font-medium text-slate-700">Target Date:</span>
                        <span>{format(new Date(req.targetDate), "MMM d, yyyy")}</span>
                      </div>
                    )}
                  </div>

                  {/* BROKER REMARKS / CONTEXT */}
                  {req.brokerNotes && (
                    <div className="p-3 bg-emerald-50/40 rounded-xl border border-emerald-100/80 mb-4 text-xs">
                      <div className="flex items-center gap-1.5 font-bold text-emerald-800 mb-1">
                        <MessageSquare className="h-3.5 w-3.5 text-emerald-600" />
                        <span>Broker Context:</span>
                      </div>
                      <p className="text-slate-600 italic leading-relaxed">
                        &ldquo;{req.brokerNotes}&rdquo;
                      </p>
                    </div>
                  )}

                  {/* REJECTION REASON DISPLAY (IF REJECTED) */}
                  {isRejected && req.rejectionReason && (
                    <div className="p-3 bg-rose-50/60 rounded-xl border border-rose-100 mb-4 text-xs">
                      <span className="font-bold text-rose-800 block mb-0.5">Rejection Reason:</span>
                      <p className="text-slate-600 italic">&ldquo;{req.rejectionReason}&rdquo;</p>
                    </div>
                  )}

                  {/* COUNTER TERMS DISPLAY (IF COUNTERED) */}
                  {isCountered && (
                    <div className="p-3 bg-sky-50/60 rounded-xl border border-sky-100 mb-4 text-xs space-y-1">
                      <span className="font-bold text-sky-900 block mb-0.5">Your Counter Terms:</span>
                      {req.counterPrice && (
                        <div>Counter Rate: <span className="font-bold text-sky-800">₹{req.counterPrice}/{req.unitSymbol}</span></div>
                      )}
                      {req.counterNotes && (
                        <p className="text-slate-600 italic">&ldquo;{req.counterNotes}&rdquo;</p>
                      )}
                    </div>
                  )}
                </div>

                {/* 4. ACTIONS FOOTER (FOR PENDING PROPOSALS) */}
                {isPending ? (
                  <div className="pt-4 mt-2 border-t border-slate-100 space-y-2">
                    <div className="grid grid-cols-2 gap-2.5">
                      <Button
                        type="button"
                        size="lg"
                        onClick={() => handleOpenAccept(req)}
                        className="w-full min-h-[48px] h-12 bg-[#059669] hover:bg-[#047857] text-white font-bold rounded-xl text-sm sm:text-base transition-colors flex items-center justify-center gap-2 cursor-pointer shadow-xs"
                      >
                        <Check className="h-4 w-4 stroke-[3]" />
                        <span>Accept Proposal</span>
                      </Button>

                      <Button
                        type="button"
                        variant="outline"
                        size="lg"
                        onClick={() => handleOpenCounter(req)}
                        className="w-full min-h-[48px] h-12 border-slate-300 text-slate-800 hover:bg-slate-50 font-semibold rounded-xl text-sm sm:text-base transition-colors flex items-center justify-center gap-2 cursor-pointer shadow-xs"
                      >
                        <ArrowUpDown className="h-4 w-4 text-sky-600" />
                        <span>Counter Terms</span>
                      </Button>
                    </div>

                    <div className="grid grid-cols-2 gap-2 pt-1">
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => handleOpenReject(req)}
                        className="w-full min-h-[38px] h-9 text-rose-600 hover:text-rose-700 hover:bg-rose-50 text-xs font-semibold rounded-xl cursor-pointer"
                      >
                        <X className="h-3.5 w-3.5 mr-1" />
                        <span>Decline</span>
                      </Button>

                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => setTimelineRequest(req)}
                        className="w-full min-h-[38px] h-9 text-slate-600 hover:text-slate-900 hover:bg-slate-100/80 text-xs font-semibold rounded-xl cursor-pointer gap-1.5"
                      >
                        <History className="h-3.5 w-3.5 text-slate-500" />
                        <span>View History</span>
                      </Button>
                    </div>
                  </div>
                ) : (
                  <div className="pt-3 mt-2 border-t border-slate-100 flex flex-col sm:flex-row gap-2">
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() => setTimelineRequest(req)}
                      className="w-full sm:w-1/2 min-h-[40px] h-10 border-slate-200 hover:border-slate-300 text-slate-700 hover:text-slate-900 bg-slate-50 hover:bg-slate-100 text-xs font-semibold rounded-xl gap-1.5 cursor-pointer transition-colors shadow-2xs"
                    >
                      <History className="h-4 w-4 text-emerald-600 shrink-0" />
                      <span>Timeline & Versions</span>
                    </Button>
                    <Link
                      href={`/seller/deals/${req.id}/confirm`}
                      className="w-full sm:w-1/2 min-h-[40px] h-10 border border-emerald-200 text-[#047857] bg-emerald-50 hover:bg-emerald-100/90 text-xs font-bold rounded-xl gap-1.5 flex items-center justify-center transition-colors shadow-2xs"
                    >
                      <FileCheck2 className="h-4 w-4 text-[#047857] shrink-0" />
                      <span>Review Terms Snapshot</span>
                    </Link>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* ========================================================================= */}
      {/* 5. ACCEPT CONFIRMATION MODAL                                              */}
      {/* ========================================================================= */}
      <Dialog open={actionType === "accept"} onOpenChange={handleCloseModals}>
        <DialogContent className="sm:max-w-[500px] p-0 rounded-2xl border-slate-200">
          <DialogHeader className="p-6 pb-4 border-b border-slate-100 bg-slate-50/70">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-xl bg-emerald-100 text-[#047857] flex items-center justify-center shrink-0">
                <CheckCircle2 className="h-5 w-5 stroke-[2.2]" />
              </div>
              <div>
                <DialogTitle className="text-lg font-bold text-slate-900">
                  Confirm Proposal Acceptance
                </DialogTitle>
                <DialogDescription className="text-xs text-slate-500 mt-0.5">
                  #REQ-{selectedRequest?.id.slice(0, 6).toUpperCase()} • {selectedRequest?.commodityName}
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>

          <div className="p-6 space-y-4">
            <div className="p-4 bg-slate-50 rounded-xl border border-slate-100 space-y-2 text-sm">
              <div className="flex justify-between">
                <span className="text-slate-500">Agreed Quantity:</span>
                <span className="font-bold text-slate-900">{selectedRequest?.requestedQuantity} {selectedRequest?.unitSymbol}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Proposed Rate:</span>
                <span className="font-bold text-[#059669]">₹{selectedRequest?.proposedRate}/{selectedRequest?.unitSymbol}</span>
              </div>
              <div className="flex justify-between pt-2 border-t border-slate-200/80 font-bold">
                <span className="text-slate-700">Estimated Total:</span>
                <span className="text-slate-900">
                  ₹{selectedRequest ? formatIndianCurrency(selectedRequest.proposedRate * selectedRequest.requestedQuantity) : 0}
                </span>
              </div>
            </div>

            <p className="text-xs text-slate-500 leading-relaxed">
              Accepting this proposal notifies the Broker Desk to generate the final deal confirmation. Confirmed deal terms are immutable once locked into a formal Booking.
            </p>
          </div>

          <DialogFooter className="p-4 bg-slate-50/50 border-t border-slate-100 gap-2">
            <Button
              type="button"
              variant="outline"
              size="lg"
              disabled={isSubmitting}
              onClick={handleCloseModals}
              className="min-h-[48px] h-12 rounded-xl text-sm font-semibold cursor-pointer"
            >
              Cancel
            </Button>
            <Button
              type="button"
              size="lg"
              disabled={isSubmitting}
              onClick={handleSubmitAccept}
              className="min-h-[48px] h-12 bg-[#059669] hover:bg-[#047857] text-white font-bold rounded-xl text-sm px-6 cursor-pointer shadow-xs"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                  Accepting...
                </>
              ) : (
                "Confirm & Accept Proposal"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ========================================================================= */}
      {/* 6. REJECT PROPOSAL MODAL                                                  */}
      {/* ========================================================================= */}
      <Dialog open={actionType === "reject"} onOpenChange={handleCloseModals}>
        <DialogContent className="sm:max-w-[540px] p-0 rounded-2xl border-slate-200">
          <DialogHeader className="p-6 pb-4 border-b border-slate-100 bg-slate-50/70">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-xl bg-rose-100 text-rose-700 flex items-center justify-center shrink-0">
                <XCircle className="h-5 w-5 stroke-[2.2]" />
              </div>
              <div>
                <DialogTitle className="text-lg font-bold text-slate-900">
                  Decline Broker Proposal
                </DialogTitle>
                <DialogDescription className="text-xs text-slate-500 mt-0.5">
                  #REQ-{selectedRequest?.id.slice(0, 6).toUpperCase()} • Document reason for Broker records
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>

          <div className="p-6 space-y-4">
            <div>
              <Label className="text-xs font-bold text-slate-800 block mb-2">
                Quick Rejection Chips (Click to select):
              </Label>
              <div className="flex flex-wrap gap-1.5">
                {QUICK_REJECTION_REASONS.map((reason) => (
                  <button
                    key={reason}
                    type="button"
                    onClick={() => setRejectionReason(reason)}
                    className={cn(
                      "text-[11px] px-2.5 py-1.5 rounded-lg border text-left transition-colors cursor-pointer",
                      rejectionReason === reason
                        ? "bg-rose-50 text-rose-800 border-rose-300 font-semibold"
                        : "bg-white text-slate-600 border-slate-200 hover:bg-slate-50"
                    )}
                  >
                    {reason}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <Label className="text-xs font-bold text-slate-800 block mb-1.5">
                Rejection Note / Feedback <span className="text-rose-500">*</span>
              </Label>
              <Textarea
                placeholder="Explain why this proposal is declined (e.g. rate below viable threshold, warehouse logistics blocked)..."
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                className="min-h-[96px] rounded-xl border-slate-200 text-sm p-3 shadow-2xs resize-none"
              />
              <span className="text-[11px] text-slate-400 block mt-1">
                Minimum 5 characters. Sent to the Broker Desk for record-keeping.
              </span>
            </div>
          </div>

          <DialogFooter className="p-4 bg-slate-50/50 border-t border-slate-100 gap-2">
            <Button
              type="button"
              variant="outline"
              size="lg"
              disabled={isSubmitting}
              onClick={handleCloseModals}
              className="min-h-[48px] h-12 rounded-xl text-sm font-semibold cursor-pointer"
            >
              Cancel
            </Button>
            <Button
              type="button"
              size="lg"
              disabled={isSubmitting || rejectionReason.trim().length < 5}
              onClick={handleSubmitReject}
              className="min-h-[48px] h-12 bg-rose-600 hover:bg-rose-700 text-white font-bold rounded-xl text-sm px-6 cursor-pointer shadow-xs"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                  Declining...
                </>
              ) : (
                "Decline Proposal"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ========================================================================= */}
      {/* 7. COUNTER PROPOSAL MODAL                                                 */}
      {/* ========================================================================= */}
      <Dialog open={actionType === "counter"} onOpenChange={handleCloseModals}>
        <DialogContent className="sm:max-w-[580px] p-0 rounded-2xl border-slate-200">
          <DialogHeader className="p-6 pb-4 border-b border-slate-100 bg-slate-50/70">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-xl bg-sky-100 text-sky-800 flex items-center justify-center shrink-0">
                <ArrowUpDown className="h-5 w-5 stroke-[2.2]" />
              </div>
              <div>
                <DialogTitle className="text-lg font-bold text-slate-900">
                  Submit Counter-Proposal
                </DialogTitle>
                <DialogDescription className="text-xs text-slate-500 mt-0.5">
                  #REQ-{selectedRequest?.id.slice(0, 6).toUpperCase()} • Negotiate commercial or dispatch parameters
                </DialogDescription>
              </div>
            </div>
          </DialogHeader>

          <div className="p-6 space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              
              {/* Counter Rate */}
              <div>
                <Label className="text-xs font-bold text-slate-800 block mb-1.5">
                  Counter Rate (₹ per {selectedRequest?.unitSymbol})
                </Label>
                <div className="relative flex items-center">
                  <span className="absolute left-3.5 text-xs font-semibold text-slate-400">₹</span>
                  <Input
                    type="number"
                    inputMode="decimal"
                    placeholder="e.g. 3550"
                    value={counterPrice ?? ""}
                    onChange={(e) => setCounterPrice(e.target.value === "" ? undefined : Number(e.target.value))}
                    className="min-h-[48px] h-12 pl-8 pr-3 rounded-xl border-slate-200 text-sm font-semibold shadow-2xs"
                  />
                </div>
                <span className="text-[11px] text-slate-400 block mt-1">
                  Broker proposed: ₹{selectedRequest?.proposedRate}
                </span>
              </div>

              {/* Counter Quantity */}
              <div>
                <Label className="text-xs font-bold text-slate-800 block mb-1.5">
                  Counter Quantity ({selectedRequest?.unitSymbol})
                </Label>
                <Input
                  type="number"
                  inputMode="numeric"
                  placeholder="e.g. 40"
                  value={counterQuantity ?? ""}
                  onChange={(e) => setCounterQuantity(e.target.value === "" ? undefined : Number(e.target.value))}
                  className="min-h-[48px] h-12 rounded-xl border-slate-200 text-sm font-semibold shadow-2xs"
                />
                <span className="text-[11px] text-slate-400 block mt-1">
                  Broker requested: {selectedRequest?.requestedQuantity} {selectedRequest?.unitSymbol}
                </span>
              </div>

            </div>

            {/* Counter Delivery Date */}
            <div>
              <Label className="text-xs font-bold text-slate-800 block mb-1.5">
                Earliest Expected Dispatch / Delivery Date (Optional)
              </Label>
              <Input
                type="date"
                value={counterDeliveryDate}
                onChange={(e) => setCounterDeliveryDate(e.target.value)}
                className="min-h-[48px] h-12 rounded-xl border-slate-200 text-sm shadow-2xs"
              />
            </div>

            {/* Counter Remarks */}
            <div>
              <Label className="text-xs font-bold text-slate-800 block mb-1.5">
                Note to Broker (Commercial rationale)
              </Label>
              <Textarea
                placeholder="Explain the basis of your counter-proposal (e.g. higher quality parameter moisture, transportation surcharge, batch sizing)..."
                value={counterRemarks}
                onChange={(e) => setCounterRemarks(e.target.value)}
                className="min-h-[96px] rounded-xl border-slate-200 text-sm p-3 shadow-2xs resize-none"
              />
            </div>
          </div>

          <DialogFooter className="p-4 bg-slate-50/50 border-t border-slate-100 gap-2">
            <Button
              type="button"
              variant="outline"
              size="lg"
              disabled={isSubmitting}
              onClick={handleCloseModals}
              className="min-h-[48px] h-12 rounded-xl text-sm font-semibold cursor-pointer"
            >
              Cancel
            </Button>
            <Button
              type="button"
              size="lg"
              disabled={isSubmitting}
              onClick={handleSubmitCounter}
              className="min-h-[48px] h-12 bg-sky-700 hover:bg-sky-800 text-white font-bold rounded-xl text-sm px-6 cursor-pointer shadow-xs"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                  Submitting Counter...
                </>
              ) : (
                "Send Counter-Proposal"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ========================================================================= */}
      {/* 8. NEGOTIATION TIMELINE & AUDIT SHEET (MICRO-SPRINT 17.5)                */}
      {/* ========================================================================= */}
      <Sheet open={!!timelineRequest} onOpenChange={(open) => !open && setTimelineRequest(null)}>
        <SheetContent
          side={isDesktop ? "right" : "bottom"}
          className={cn(
            "bg-white overflow-y-auto z-50",
            isDesktop ? "w-full sm:max-w-xl p-6" : "h-[90vh] p-4 rounded-t-2xl"
          )}
        >
          <SheetHeader className="p-0 pb-4 border-b border-slate-100 text-left">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-xl bg-emerald-100 text-[#047857] flex items-center justify-center shrink-0">
                <History className="h-5 w-5 stroke-[2.2]" />
              </div>
              <div>
                <SheetTitle className="text-lg font-bold text-slate-900">
                  Negotiation Timeline & Audit
                </SheetTitle>
                <SheetDescription className="text-xs text-slate-500 mt-0.5">
                  {timelineRequest
                    ? `#REQ-${timelineRequest.id.slice(0, 6).toUpperCase()} • ${timelineRequest.commodityName} (${timelineRequest.gradeName})`
                    : "Commercial negotiation history"}
                </SheetDescription>
              </div>
            </div>
          </SheetHeader>

          <div className="py-4">
            {timelineRequest && (
              <NegotiationTimeline
                requestId={timelineRequest.id}
                onRefresh={() => {
                  queryClient.invalidateQueries({ queryKey: ["seller-broker-requests"] });
                }}
              />
            )}
          </div>
        </SheetContent>
      </Sheet>

    </div>
  );
}
