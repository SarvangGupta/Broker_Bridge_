'use client';

import React from 'react';
import Link from 'next/link';
import {
  Layers,
  Truck,
  ChevronRight,
  Clock,
  Plus,
  PackageOpen,
  Inbox,
} from 'lucide-react';
import {
  BuyerRecentRequirement,
  BuyerActiveShipment,
} from '@/src/server/actions/buyer-dashboard-actions';
import { PostRequirementDialog } from '@/src/components/dialogs/post-requirement-dialog';

interface BuyerActivePipelineProps {
  recentRequirements: BuyerRecentRequirement[];
  activeShipments: BuyerActiveShipment[];
}

export function BuyerActivePipeline({
  recentRequirements,
  activeShipments,
}: BuyerActivePipelineProps) {
  const getRequirementStatusChip = (status: BuyerRecentRequirement['status']) => {
    switch (status) {
      case 'Sourcing':
        return 'bg-blue-50 text-blue-700 border-blue-200';
      case 'Matched':
        return 'bg-emerald-50 text-emerald-700 border-emerald-200';
      case 'Submitted':
        return 'bg-sky-50 text-[#0284C7] border-sky-200';
      default:
        return 'bg-slate-100 text-slate-700 border-slate-200';
    }
  };

  const getShipmentStatusChip = (status: BuyerActiveShipment['status']) => {
    switch (status) {
      case 'In Transit':
        return 'bg-sky-50 text-[#0284C7] border-sky-200';
      case 'Dispatched':
        return 'bg-amber-50 text-amber-700 border-amber-200';
      case 'Booked':
        return 'bg-emerald-50 text-emerald-700 border-emerald-200';
      default:
        return 'bg-slate-100 text-slate-700 border-slate-200';
    }
  };

  const hasRequirements = recentRequirements && recentRequirements.length > 0;
  const hasShipments = activeShipments && activeShipments.length > 0;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 select-none">
      {/* Left Column: Active Requirements */}
      <div className="bg-white border border-slate-200/80 rounded-2xl p-4 sm:p-6 shadow-2xs space-y-4 flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between gap-2 border-b border-slate-100 pb-3">
            <div className="flex items-center gap-2">
              <div className="p-2 rounded-xl bg-sky-50 text-[#0284C7]">
                <Layers className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-900 tracking-tight">
                  Active Requirements
                </h3>
                <p className="text-xs text-slate-500">Live demand mandates in market</p>
              </div>
            </div>
            <Link
              href="/buyer/requirements"
              className="text-xs font-bold text-[#0284C7] hover:text-[#0369A1] flex items-center gap-1 min-h-[48px] px-2"
            >
              <span>View All</span>
              <ChevronRight className="w-4 h-4" />
            </Link>
          </div>

          {/* Task 3 Empty State: Active Requirements */}
          {!hasRequirements ? (
            <div className="py-8 text-center space-y-3">
              <div className="w-12 h-12 rounded-full bg-slate-100 text-slate-400 mx-auto flex items-center justify-center">
                <Inbox className="w-6 h-6" />
              </div>
              <div>
                <p className="text-sm font-bold text-slate-800">No active requirements.</p>
                <p className="text-xs text-slate-500 mt-0.5">
                  Publish a commodity mandate to start receiving broker proposals.
                </p>
              </div>
              <div className="pt-1 flex justify-center">
                <PostRequirementDialog />
              </div>
            </div>
          ) : (
            <div className="space-y-3 pt-3">
              {recentRequirements.map((req) => (
                <div
                  key={req.id}
                  className="p-3.5 rounded-xl border border-slate-200/60 bg-slate-50/50 hover:bg-slate-50 transition-colors space-y-2"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <h4 className="text-sm font-bold text-slate-900 truncate">
                        {req.commodityName}
                      </h4>
                      <p className="text-xs text-slate-500 truncate">{req.gradeName}</p>
                    </div>
                    <span
                      className={`text-[10px] font-bold px-2 py-0.5 rounded-full border shrink-0 ${getRequirementStatusChip(
                        req.status
                      )}`}
                    >
                      {req.status}
                    </span>
                  </div>

                  <div className="flex items-center justify-between text-xs text-slate-700 pt-1 border-t border-slate-200/40">
                    <span className="font-semibold text-slate-900">
                      {req.quantityWithUnit}
                    </span>
                    <span className="font-bold text-[#0284C7]">{req.targetPrice}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Right Column: Live Shipments & Fulfillment */}
      <div className="bg-white border border-slate-200/80 rounded-2xl p-4 sm:p-6 shadow-2xs space-y-4 flex flex-col justify-between">
        <div>
          <div className="flex items-center justify-between gap-2 border-b border-slate-100 pb-3">
            <div className="flex items-center gap-2">
              <div className="p-2 rounded-xl bg-sky-50 text-[#0284C7]">
                <Truck className="w-4 h-4" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-900 tracking-tight">
                  Live Shipments & Fulfillment
                </h3>
                <p className="text-xs text-slate-500">In-transit vehicle tracking</p>
              </div>
            </div>
            <Link
              href="/buyer/orders"
              className="text-xs font-bold text-[#0284C7] hover:text-[#0369A1] flex items-center gap-1 min-h-[48px] px-2"
            >
              <span>View Orders</span>
              <ChevronRight className="w-4 h-4" />
            </Link>
          </div>

          {/* Task 3 Empty State: Live Shipments */}
          {!hasShipments ? (
            <div className="py-8 text-center space-y-3">
              <div className="w-12 h-12 rounded-full bg-slate-100 text-slate-400 mx-auto flex items-center justify-center">
                <PackageOpen className="w-6 h-6" />
              </div>
              <div>
                <p className="text-sm font-bold text-slate-800">
                  No active orders in transit.
                </p>
                <p className="text-xs text-slate-500 mt-0.5">
                  Shipment dispatches and vehicle ETAs will appear here once bookings are confirmed.
                </p>
              </div>
              <div className="pt-1">
                <Link
                  href="/buyer/orders"
                  className="inline-flex items-center justify-center gap-1 text-xs font-bold text-[#0284C7] hover:underline min-h-[48px] px-3"
                >
                  <span>Explore Order History</span>
                  <ChevronRight className="w-4 h-4" />
                </Link>
              </div>
            </div>
          ) : (
            <div className="space-y-3 pt-3">
              {activeShipments.map((shipment) => (
                <div
                  key={shipment.bookingId}
                  className="p-3.5 rounded-xl border border-slate-200/60 bg-slate-50/50 hover:bg-slate-50 transition-colors space-y-2.5"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <div className="text-xs font-mono font-bold text-slate-900">
                        {shipment.bookingId}
                      </div>
                      <div className="text-xs font-semibold text-slate-700">
                        {shipment.commodity} • {shipment.dispatchedQuantity}
                      </div>
                    </div>
                    <span
                      className={`text-[10px] font-bold px-2 py-0.5 rounded-full border shrink-0 ${getShipmentStatusChip(
                        shipment.status
                      )}`}
                    >
                      {shipment.status}
                    </span>
                  </div>

                  {/* Progress Visualizer Bar */}
                  <div className="space-y-1">
                    <div className="flex items-center justify-between text-[11px] text-slate-500">
                      <span>Transporter: {shipment.transporter}</span>
                      <span className="font-semibold text-slate-700 flex items-center gap-1">
                        <Clock className="w-3 h-3 text-[#0284C7]" />
                        <span>{shipment.eta}</span>
                      </span>
                    </div>
                    <div className="w-full bg-slate-200 rounded-full h-1.5 overflow-hidden">
                      <div
                        className={`h-1.5 rounded-full ${
                          shipment.status === 'In Transit'
                            ? 'bg-[#0284C7] w-3/4'
                            : 'bg-emerald-500 w-1/2'
                        }`}
                      ></div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
