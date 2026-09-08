"use client";

import React, { useEffect, useState, useTransition } from "react";
import Link from "next/link";
import {
  Truck,
  Lock,
  Copy,
  Check,
  Search,
  Calendar,
  MapPin,
  Package,
  ArrowRight,
  ShieldCheck,
  RefreshCw,
  AlertCircle,
  FileCheck2,
  ExternalLink,
  Layers,
  IndianRupee,
  Clock,
  Sparkles,
  CheckCircle2,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "sonner";
import {
  getSellerBookedOrdersAction,
  BookedOrderSummary,
} from "@/src/server/actions/booking-actions";
import { format } from "date-fns";

interface BookedOrdersTableProps {
  initialOrders?: BookedOrderSummary[];
  className?: string;
  onRefresh?: () => void;
}

export function BookedOrdersTable({
  initialOrders,
  className = "",
  onRefresh,
}: BookedOrdersTableProps) {
  const [orders, setOrders] = useState<BookedOrderSummary[]>(initialOrders || []);
  const [isLoading, setIsLoading] = useState<boolean>(!initialOrders);
  const [searchTerm, setSearchTerm] = useState("");
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    if (!initialOrders) {
      loadOrders();
    }
  }, [initialOrders]);

  async function loadOrders() {
    setIsLoading(true);
    try {
      const res = await getSellerBookedOrdersAction();
      if (res.success && res.data) {
        setOrders(res.data);
      } else {
        toast.error(res.error || "Failed to load booked orders.");
      }
    } catch (err: any) {
      toast.error(err.message || "Failed to fetch booked orders.");
    } finally {
      setIsLoading(false);
    }
  }

  const handleRefresh = () => {
    startTransition(async () => {
      await loadOrders();
      onRefresh?.();
      toast.success("Booked orders refreshed");
    });
  };

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    toast.success(`Booking ID ${text} copied to clipboard!`);
    setTimeout(() => setCopiedId(null), 2500);
  };

  // Filter orders by search query
  const filteredOrders = orders.filter((order) => {
    const term = searchTerm.toLowerCase().trim();
    if (!term) return true;
    return (
      order.bookingReference.toLowerCase().includes(term) ||
      order.commodityName.toLowerCase().includes(term) ||
      order.gradeName.toLowerCase().includes(term) ||
      order.lotNumber.toLowerCase().includes(term) ||
      order.deliveryLocation.toLowerCase().includes(term)
    );
  });

  const pendingDispatchesCount = orders.filter((o) => !o.hasDispatched).length;
  const inTransitCount = orders.filter((o) => o.hasDispatched).length;
  const totalBookedTonnage = orders.reduce((sum, o) => sum + (o.bookedQuantity || 0), 0);

  if (isLoading) {
    return (
      <div className={`space-y-4 ${className}`}>
        {/* Skeleton Header */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="space-y-2">
            <Skeleton className="h-6 w-48" />
            <Skeleton className="h-4 w-72" />
          </div>
          <Skeleton className="h-10 w-32 rounded-xl" />
        </div>

        {/* Skeleton Cards */}
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Card key={i} className="border-slate-200">
              <CardContent className="p-5 space-y-4">
                <div className="flex justify-between">
                  <Skeleton className="h-6 w-36 rounded-lg" />
                  <Skeleton className="h-6 w-24 rounded-full" />
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                  <Skeleton className="h-14 w-full rounded-xl" />
                  <Skeleton className="h-14 w-full rounded-xl" />
                  <Skeleton className="h-14 w-full rounded-xl" />
                  <Skeleton className="h-14 w-full rounded-xl" />
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className={`space-y-6 ${className}`}>
      {/* 1. TOP CONTROL & METRICS BAR */}
      <div className="bg-white rounded-2xl border border-slate-200/90 p-5 sm:p-6 shadow-xs space-y-4">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-xl bg-emerald-100 flex items-center justify-center text-[#047857]">
                <Truck className="w-4 h-4" />
              </div>
              <h2 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                Booked Orders & Dispatch Gate
              </h2>
            </div>
            <p className="text-xs sm:text-sm text-slate-500 mt-1">
              Authoritative commercial bookings ready for vehicle assignment, driver details, and gate dispatch.
            </p>
          </div>

          <div className="flex items-center gap-2.5 flex-wrap">
            <Badge
              variant="outline"
              className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs gap-1.5 px-3 py-1"
            >
              <ShieldCheck className="w-3.5 h-3.5 text-[#047857]" />
              <span>Zero-Buyer PII Shield</span>
            </Badge>

            <Button
              onClick={handleRefresh}
              variant="outline"
              size="sm"
              disabled={isPending}
              className="border-slate-200 text-slate-700 hover:bg-slate-50 rounded-xl font-bold gap-1.5 h-9"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${isPending ? "animate-spin" : ""}`} />
              <span>Refresh</span>
            </Button>
          </div>
        </div>

        {/* METRICS ROW */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
          <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-200/70 flex items-center justify-between">
            <div className="space-y-0.5">
              <span className="text-[11px] uppercase font-bold text-slate-400">
                Active Bookings
              </span>
              <div className="text-lg font-black text-slate-900">
                {orders.length} <span className="text-xs font-normal text-slate-500">Orders</span>
              </div>
            </div>
            <div className="w-9 h-9 rounded-xl bg-white border border-slate-200 flex items-center justify-center text-slate-700">
              <Package className="w-4 h-4" />
            </div>
          </div>

          <div className="p-3.5 bg-emerald-50/60 rounded-xl border border-emerald-200/70 flex items-center justify-between">
            <div className="space-y-0.5">
              <span className="text-[11px] uppercase font-bold text-emerald-800">
                Pending Dispatch
              </span>
              <div className="text-lg font-black text-emerald-950">
                {pendingDispatchesCount} <span className="text-xs font-normal text-emerald-700">Awaiting Trucks</span>
              </div>
            </div>
            <div className="w-9 h-9 rounded-xl bg-white border border-emerald-200 flex items-center justify-center text-emerald-700">
              <Clock className="w-4 h-4 text-[#047857]" />
            </div>
          </div>

          <div className="p-3.5 bg-blue-50/60 rounded-xl border border-blue-200/70 flex items-center justify-between">
            <div className="space-y-0.5">
              <span className="text-[11px] uppercase font-bold text-blue-800">
                Booked Volume
              </span>
              <div className="text-lg font-black text-blue-950">
                {totalBookedTonnage.toLocaleString("en-IN")}{" "}
                <span className="text-xs font-normal text-blue-700">MT Total</span>
              </div>
            </div>
            <div className="w-9 h-9 rounded-xl bg-white border border-blue-200 flex items-center justify-center text-blue-700">
              <Layers className="w-4 h-4" />
            </div>
          </div>
        </div>

        {/* SEARCH BAR */}
        <div className="pt-2">
          <div className="relative">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <Input
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Filter by Booking ID, Commodity, Lot Number, or Destination..."
              className="pl-10 h-11 bg-white rounded-xl border-slate-200 focus-visible:ring-emerald-500 text-sm"
            />
          </div>
        </div>
      </div>

      {/* 2. BOOKED ORDERS LIST / CARDS */}
      {filteredOrders.length === 0 ? (
        <Card className="border-slate-200/90 rounded-2xl bg-white shadow-xs">
          <CardContent className="py-14 text-center space-y-4">
            <div className="w-14 h-14 rounded-2xl bg-slate-100 flex items-center justify-center mx-auto text-slate-400">
              <Truck className="w-7 h-7 stroke-[1.5]" />
            </div>
            <div className="space-y-1 max-w-md mx-auto">
              <h3 className="text-base font-bold text-slate-900">
                {searchTerm
                  ? "No Booked Orders Match Search Criteria"
                  : "No Active Booked Orders Awaiting Dispatch"}
              </h3>
              <p className="text-xs sm:text-sm text-slate-500 leading-relaxed">
                {searchTerm
                  ? "Try adjusting your filter terms or clear search to view all booked orders."
                  : "Once Broker Finalization approves your confirmed deal terms and generates a unique Booking ID, your booked orders will appear here ready for transport dispatch."}
              </p>
            </div>
            {searchTerm ? (
              <Button
                onClick={() => setSearchTerm("")}
                variant="outline"
                className="font-bold rounded-xl text-xs h-9 mt-2"
              >
                Clear Search Filter
              </Button>
            ) : (
              <Link href="/seller?tab=deals">
                <Button
                  variant="outline"
                  className="font-bold rounded-xl text-xs h-9 mt-2 gap-1.5 border-slate-300"
                >
                  <FileCheck2 className="w-3.5 h-3.5" />
                  <span>View Negotiation & Deals</span>
                </Button>
              </Link>
            )}
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {filteredOrders.map((order) => {
            const formattedDate = order.bookingCreatedAt
              ? format(new Date(order.bookingCreatedAt), "dd MMM yyyy, hh:mm a")
              : "Recent";

            const isCopied = copiedId === order.id;

            return (
              <Card
                key={order.id}
                className="border-slate-200/90 rounded-2xl bg-white shadow-xs hover:border-slate-300 transition-all overflow-hidden"
              >
                {/* STATUS BAR ACCENT */}
                <div
                  className={`h-1.5 w-full ${
                    order.hasDispatched
                      ? "bg-gradient-to-r from-blue-500 to-indigo-600"
                      : "bg-gradient-to-r from-emerald-500 to-teal-600"
                  }`}
                />

                <CardContent className="p-5 sm:p-6 space-y-4">
                  {/* CARD HEADER: BOOKING ID & BADGES */}
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
                    <div className="flex items-center gap-2.5 flex-wrap">
                      <div className="flex items-center gap-1 bg-slate-900 text-white font-mono font-bold text-xs sm:text-sm px-3 py-1 rounded-xl shadow-xs">
                        <Lock className="w-3.5 h-3.5 text-emerald-400" />
                        <span>{order.bookingReference}</span>
                      </div>

                      <Button
                        onClick={() => copyToClipboard(order.bookingReference, order.id)}
                        variant="ghost"
                        size="sm"
                        className="h-8 px-2 text-slate-500 hover:text-slate-900 rounded-lg"
                        title="Copy Booking Reference"
                      >
                        {isCopied ? (
                          <Check className="w-3.5 h-3.5 text-[#047857]" />
                        ) : (
                          <Copy className="w-3.5 h-3.5" />
                        )}
                      </Button>

                      <Badge
                        variant="outline"
                        className="bg-slate-50 text-slate-700 border-slate-200 font-semibold text-xs"
                      >
                        Lot #{order.lotNumber}
                      </Badge>

                      <span className="text-xs text-slate-400 hidden md:inline">•</span>
                      <span className="text-xs text-slate-500 hidden md:inline">
                        Booked {formattedDate}
                      </span>
                    </div>

                    <div className="flex items-center gap-2">
                      {order.isFullyDispatched ? (
                        <Badge className="bg-indigo-50 text-indigo-700 border-indigo-200 font-bold text-xs gap-1.5 px-3 py-1">
                          <Truck className="w-3.5 h-3.5 text-indigo-600" />
                          <span>Fully Dispatched ({order.dispatchesCount})</span>
                        </Badge>
                      ) : order.alreadyDispatchedQuantity > 0 ? (
                        <Badge className="bg-amber-50 text-amber-800 border-amber-300 font-bold text-xs gap-1.5 px-3 py-1">
                          <Truck className="w-3.5 h-3.5 text-amber-600" />
                          <span>Partially Dispatched ({order.remainingQuantity} {order.unitSymbol} Left)</span>
                        </Badge>
                      ) : (
                        <Badge className="bg-emerald-50 text-[#047857] border-emerald-300 font-bold text-xs gap-1.5 px-3 py-1">
                          <CheckCircle2 className="w-3.5 h-3.5 text-[#047857]" />
                          <span>Ready for Dispatch</span>
                        </Badge>
                      )}
                    </div>
                  </div>

                  {/* COMMERCIAL GRID (4 TILES) */}
                  <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
                    {/* 1. Commodity & Grade */}
                    <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
                      <div className="text-[10px] uppercase font-bold text-slate-400">
                        Commodity & Grade
                      </div>
                      <div className="text-sm font-bold text-slate-900 truncate">
                        {order.commodityName}
                      </div>
                      <div className="text-xs text-slate-500 truncate">
                        {order.gradeName}
                      </div>
                    </div>

                    {/* 2. Booked & Remaining Quantity */}
                    <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
                      <div className="text-[10px] uppercase font-bold text-slate-400">
                        {order.alreadyDispatchedQuantity > 0 ? "Remaining / Booked" : "Agreed Volume"}
                      </div>
                      <div className="text-sm font-black text-slate-900">
                        {order.alreadyDispatchedQuantity > 0 ? (
                          <>
                            {order.remainingQuantity.toLocaleString("en-IN")}{" "}
                            <span className="text-xs font-semibold text-emerald-700">
                              / {order.bookedQuantity} {order.unitSymbol}
                            </span>
                          </>
                        ) : (
                          <>
                            {order.bookedQuantity.toLocaleString("en-IN")}{" "}
                            <span className="text-xs font-semibold text-slate-600">
                              {order.unitSymbol}
                            </span>
                          </>
                        )}
                      </div>
                      <div className="text-xs text-[#047857] font-semibold flex items-center gap-1">
                        {order.isFullyDispatched ? (
                          <CheckCircle2 className="w-3 h-3" />
                        ) : (
                          <Lock className="w-3 h-3" />
                        )}
                        <span>
                          {order.isFullyDispatched
                            ? "All Tonnage Dispatched"
                            : order.alreadyDispatchedQuantity > 0
                            ? `${order.alreadyDispatchedQuantity} ${order.unitSymbol} Sent`
                            : "Inventory Locked"}
                        </span>
                      </div>
                    </div>

                    {/* 3. Locked Rate & Total */}
                    <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
                      <div className="text-[10px] uppercase font-bold text-slate-400">
                        Locked Rate & Valuation
                      </div>
                      <div className="text-sm font-bold text-slate-900">
                        ₹{order.lockedRate.toLocaleString("en-IN")}{" "}
                        <span className="text-xs text-slate-500 font-normal">
                          /{order.unitSymbol}
                        </span>
                      </div>
                      <div className="text-xs font-bold text-[#059669]">
                        ₹{order.totalValuation.toLocaleString("en-IN", { maximumFractionDigits: 0 })}
                      </div>
                    </div>

                    {/* 4. Delivery Info */}
                    <div className="p-3.5 bg-slate-50 rounded-xl border border-slate-100 space-y-1">
                      <div className="text-[10px] uppercase font-bold text-slate-400 flex items-center gap-1">
                        <MapPin className="w-3 h-3 text-slate-400" />
                        <span>Destination</span>
                      </div>
                      <div className="text-sm font-bold text-slate-900 truncate" title={order.deliveryLocation}>
                        {order.deliveryLocation}
                      </div>
                      <div className="text-xs text-slate-500 truncate">
                        {order.deliveryTerms}
                      </div>
                    </div>
                  </div>

                  {/* CARD FOOTER ACTIONS */}
                  <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 pt-2">
                    <div className="flex items-center gap-2 text-xs text-slate-500">
                      <Calendar className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                      <span>
                        Target Delivery:{" "}
                        <span className="font-semibold text-slate-700">
                          {order.expectedDeliveryDate
                            ? format(new Date(order.expectedDeliveryDate), "dd MMM yyyy")
                            : "Per Contract Terms"}
                        </span>
                      </span>
                    </div>

                    <div className="flex items-center gap-3">
                      <Link
                        href={`/seller/deals/${order.dealId}`}
                        className="text-xs font-bold text-slate-600 hover:text-slate-900 inline-flex items-center gap-1 py-2 px-3 rounded-lg hover:bg-slate-100 transition-colors"
                      >
                        <FileCheck2 className="w-3.5 h-3.5 text-slate-500" />
                        <span>View Deal Terms</span>
                      </Link>

                      {/* PRIMARY DISPATCH ACTION (48px Touch Target) */}
                      {order.remainingQuantity <= 0 || order.isFullyDispatched || order.bookingStatus === "Fully Dispatched" ? (
                        <Link href={`/seller/dispatch/${order.bookingReference}`}>
                          <Button
                            variant="outline"
                            className="min-h-[48px] h-12 px-6 bg-slate-50 hover:bg-slate-100 text-slate-800 font-bold rounded-xl border-slate-200 shadow-2xs flex items-center gap-2 transition-all cursor-pointer"
                          >
                            <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                            <span>View Shipments & Documents</span>
                            <ArrowRight className="w-4 h-4 text-slate-400" />
                          </Button>
                        </Link>
                      ) : (
                        <Link href={`/seller/dispatch/${order.bookingReference}`}>
                          <Button
                            className="min-h-[48px] h-12 px-6 bg-[#059669] hover:bg-[#047857] text-white font-bold rounded-xl shadow-xs flex items-center gap-2 transition-all hover:scale-[1.02] active:scale-[0.98] cursor-pointer"
                          >
                            <Truck className="w-4 h-4 text-white" />
                            <span>Initiate Dispatch</span>
                            <ArrowRight className="w-4 h-4 text-emerald-200" />
                          </Button>
                        </Link>
                      )}
                    </div>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
