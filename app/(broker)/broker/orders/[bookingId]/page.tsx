import React from 'react';
import Link from 'next/link';
import { ArrowLeft, Truck, ShieldCheck, Building, Building2, MapPin, Calendar, FileText, AlertCircle, PackageCheck, FileCheck2 } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { getBrokerOrderDetailsAction } from '@/src/server/actions/broker-order-actions';
import { LogisticsTracker } from '@/src/components/broker/orders/logistics-tracker';
import { DispatchDetailsCard } from '@/src/components/broker/orders/dispatch-details-card';

export const dynamic = 'force-dynamic';

interface BrokerOrderDetailPageProps {
  params: Promise<{ bookingId: string }> | { bookingId: string };
}

export default async function BrokerOrderDetailPage({ params }: BrokerOrderDetailPageProps) {
  const resolvedParams = await params;
  const bookingIdOrRef = resolvedParams.bookingId;

  const res = await getBrokerOrderDetailsAction(bookingIdOrRef);

  if (!res.success || !res.data) {
    return (
      <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
        <Link
          href="/broker/orders"
          className="inline-flex items-center gap-1.5 text-xs sm:text-sm font-semibold text-teal-700 hover:text-teal-900 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to Orders Workspace
        </Link>

        <Card className="border-red-200 bg-red-50/50">
          <CardContent className="p-6 text-center space-y-4">
            <div className="mx-auto w-12 h-12 rounded-full bg-red-100 flex items-center justify-center text-red-600">
              <AlertCircle className="w-6 h-6" />
            </div>
            <div className="space-y-1 max-w-md mx-auto">
              <h3 className="font-bold text-slate-900 text-base">Unable to Load Order Logistics</h3>
              <p className="text-xs sm:text-sm text-slate-600">
                {res.error || 'The requested booking reference could not be found or you do not have permission to view it.'}
              </p>
            </div>
            <Link href="/broker/orders">
              <Button className="bg-slate-900 text-white hover:bg-slate-800 text-xs font-semibold h-10 px-4">
                Return to Orders List
              </Button>
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  const { order, deal, booking, lockedVersion, loadingReadiness, dispatches } = res.data;
  const snap = lockedVersion.snapshot;

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-6 w-full max-w-7xl mx-auto overflow-x-hidden">
      {/* Top Header & Navigation */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <Link
            href="/broker/orders"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-teal-700 hover:text-teal-900 transition-colors mb-2"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Orders & Logistics Workspace
          </Link>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight flex items-center gap-2">
              <Truck className="w-7 h-7 text-[#0D9488]" />
              Order Logistics Tracking
            </h1>
            <Badge className="bg-[#0D9488] text-white font-mono text-xs px-2.5 py-0.5">
              {order.bookingReference}
            </Badge>
          </div>
          <p className="text-xs sm:text-sm text-slate-500 mt-1">
            Real-time physical fulfillment state machine, loading readiness, and LR vehicle dispatch logs.
          </p>
        </div>

        <Link href={`/broker/deals/${order.quotationId}`}>
          <Button variant="outline" className="border-slate-300 text-slate-700 hover:bg-slate-100 text-xs font-semibold h-10 px-4 cursor-pointer self-start sm:self-auto">
            <FileText className="w-4 h-4 mr-1.5 text-slate-500" />
            View Contract Snapshot
          </Button>
        </Link>
      </div>

      {/* TASK 3: LOGISTICS STATE MACHINE TRACKER STEPPER COMPONENT */}
      <LogisticsTracker
        bookingReference={order.bookingReference}
        fulfillmentStage={order.fulfillmentStage}
        exceptionFlag={order.exceptionFlag}
        agreedQuantity={order.agreedQuantity}
        dispatchedQuantity={order.dispatchedQuantity}
        unitSymbol={order.unitSymbol}
        lastUpdated={order.createdAt}
      />

      {/* TASK 2 & 3: BROKER DISPATCH CAPTURE & MONITORING CARD */}
      <DispatchDetailsCard bookingIdOrReference={bookingIdOrRef} />

      {/* 2-COLUMN OPERATIONAL DETAILS SECTION */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* LEFT 2 COLUMNS: COMMERCIAL TERMS */}
        <div className="lg:col-span-2 space-y-6">
          {/* COMMERCIAL SUMMARY CARD */}
          <Card className="border-slate-200/80 bg-white shadow-xs">
            <CardHeader className="pb-3 border-b border-slate-100">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <FileCheck2 className="w-5 h-5 text-[#0D9488]" />
                Locked Commercial Terms
              </CardTitle>
              <CardDescription className="text-xs">
                Frozen contract terms from deal version {lockedVersion.versionNumber}
              </CardDescription>
            </CardHeader>
            <CardContent className="p-4 sm:p-6 space-y-4">
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 text-xs">
                <div>
                  <span className="text-slate-500 block">Commodity</span>
                  <span className="font-bold text-slate-900 text-sm">{snap.commodityName}</span>
                </div>
                <div>
                  <span className="text-slate-500 block">Grade</span>
                  <span className="font-bold text-slate-900 text-sm">{snap.gradeName || 'Standard'}</span>
                </div>
                <div>
                  <span className="text-slate-500 block">Lot Number</span>
                  <span className="font-mono font-bold text-slate-900 text-sm">#{order.lotNumber}</span>
                </div>
                <div>
                  <span className="text-slate-500 block">Booked Quantity</span>
                  <span className="font-mono font-bold text-slate-900 text-sm">
                    {order.agreedQuantity} {order.unitSymbol}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block">Agreed Rate</span>
                  <span className="font-mono font-bold text-slate-900 text-sm">
                    ₹{order.agreedPrice.toLocaleString('en-IN')}/{order.unitSymbol}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block">Total Contract Value</span>
                  <span className="font-mono font-bold text-teal-800 text-sm">
                    ₹{order.totalValuation.toLocaleString('en-IN')}
                  </span>
                </div>
              </div>

              <div className="border-t border-slate-100 pt-3 text-xs space-y-1.5 text-slate-600">
                <div className="flex items-start gap-2">
                  <MapPin className="w-4 h-4 text-slate-400 shrink-0 mt-0.5" />
                  <span><strong>Destination:</strong> {order.deliveryLocation}</span>
                </div>
                <div className="flex items-start gap-2">
                  <Calendar className="w-4 h-4 text-slate-400 shrink-0 mt-0.5" />
                  <span><strong>Payment Terms:</strong> {order.paymentTerms}</span>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* RIGHT 1 COLUMN: LOADING READINESS & COUNTERPARTIES */}
        <div className="space-y-6">
          {/* SELLER LOADING READINESS CARD */}
          <Card className="border-slate-200/80 bg-white shadow-xs">
            <CardHeader className="pb-3 border-b border-slate-100">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <PackageCheck className="w-5 h-5 text-[#0D9488]" />
                Seller Loading Readiness
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4 sm:p-5 space-y-3 text-xs">
              <div className="flex items-center justify-between">
                <span className="text-slate-500">Lot Loading Status</span>
                <Badge
                  className={`text-xs font-bold ${
                    loadingReadiness?.status === 'Ready'
                      ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                      : 'bg-amber-100 text-amber-800 border-amber-300'
                  }`}
                >
                  {loadingReadiness?.status || 'Not Ready'}
                </Badge>
              </div>

              {loadingReadiness?.capacity ? (
                <div>
                  <span className="text-slate-500 block">Daily Loading Capacity</span>
                  <span className="font-mono font-bold text-slate-900">
                    {loadingReadiness.capacity} MT / day
                  </span>
                </div>
              ) : null}

              {loadingReadiness?.remarks && (
                <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-200/60 text-slate-700">
                  <span className="font-bold block mb-0.5 text-[11px] text-slate-800">Seller Loading Remarks:</span>
                  {loadingReadiness.remarks}
                </div>
              )}
            </CardContent>
          </Card>

          {/* COUNTERPARTIES INFO CARD */}
          <Card className="border-slate-200/80 bg-white shadow-xs">
            <CardHeader className="pb-3 border-b border-slate-100">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-[#0D9488]" />
                Counterparty Directory
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4 sm:p-5 space-y-4 text-xs">
              <div className="p-3 rounded-xl bg-blue-50/60 border border-blue-200/60 space-y-1">
                <span className="text-[10px] font-bold uppercase tracking-wider text-blue-700 flex items-center gap-1">
                  <Building className="w-3.5 h-3.5" />
                  Buyer Enterprise
                </span>
                <p className="font-bold text-slate-900">{order.buyerCompanyName}</p>
                <p className="text-[11px] text-slate-500">Digitally signed & confirmed contract terms</p>
              </div>

              <div className="p-3 rounded-xl bg-teal-50/60 border border-teal-200/60 space-y-1">
                <span className="text-[10px] font-bold uppercase tracking-wider text-teal-700 flex items-center gap-1">
                  <Building2 className="w-3.5 h-3.5" />
                  Seller Enterprise
                </span>
                <p className="font-bold text-slate-900">{order.sellerCompanyName}</p>
                <p className="text-[11px] text-slate-500">Digitally signed & confirmed contract terms</p>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
