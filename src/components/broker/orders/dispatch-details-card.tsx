'use client';

import React, { useState, useEffect, useTransition } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  Truck,
  MapPin,
  Calendar,
  User,
  Phone,
  FileText,
  Clock,
  ShieldAlert,
  CheckCircle2,
  AlertTriangle,
  PlusCircle,
  ExternalLink,
  Loader2,
  RefreshCw,
  PackageCheck,
  Edit3,
} from 'lucide-react';
import { toast } from 'sonner';
import {
  getBrokerDispatchDetailsAction,
  updateBrokerDispatchTransitStatusAction,
  logBrokerDispatchAction,
  BrokerDispatchPayload,
  BrokerDispatchLogisticsItem,
} from '@/src/server/actions/broker-logistics-actions';

interface DispatchDetailsCardProps {
  bookingIdOrReference: string;
  initialData?: BrokerDispatchPayload | null;
}

export function DispatchDetailsCard({
  bookingIdOrReference,
  initialData,
}: DispatchDetailsCardProps) {
  const [data, setData] = useState<BrokerDispatchPayload | null>(initialData || null);
  const [isLoading, setIsLoading] = useState<boolean>(!initialData);
  const [isPending, startTransition] = useTransition();

  // Dialog States
  const [isManageModalOpen, setIsManageModalOpen] = useState<boolean>(false);
  const [isLogDispatchOpen, setIsLogDispatchOpen] = useState<boolean>(false);
  const [selectedDispatchId, setSelectedDispatchId] = useState<string | null>(null);

  // Manage Transit Status Form State
  const [etaInput, setEtaInput] = useState<string>('');
  const [statusInput, setStatusInput] = useState<'Dispatched' | 'In Transit' | 'Delivered' | 'Delayed' | 'Disputed'>('In Transit');
  const [notesInput, setNotesInput] = useState<string>('');

  // Log Dispatch Form State (On behalf of Seller)
  const [vehicleNumber, setVehicleNumber] = useState<string>('');
  const [driverName, setDriverName] = useState<string>('');
  const [driverMobile, setDriverMobile] = useState<string>('');
  const [dispatchDate, setDispatchDate] = useState<string>(new Date().toISOString().split('T')[0]);
  const [expectedDeliveryDate, setExpectedDeliveryDate] = useState<string>('');

  const loadLogistics = async () => {
    setIsLoading(true);
    const res = await getBrokerDispatchDetailsAction(bookingIdOrReference);
    if (res.success && res.data) {
      setData(res.data);
    } else if (res.error) {
      toast.error(res.error);
    }
    setIsLoading(false);
  };

  useEffect(() => {
    if (!initialData) {
      loadLogistics();
    }
  }, [bookingIdOrReference]);

  // Open Manage Status Modal for specific dispatch
  const handleOpenManageModal = (disp: BrokerDispatchLogisticsItem) => {
    setSelectedDispatchId(disp.id);
    setEtaInput(disp.expectedDeliveryDate ? disp.expectedDeliveryDate.split('T')[0] : '');
    setStatusInput((disp.status as any) || 'In Transit');
    setNotesInput('');
    setIsManageModalOpen(true);
  };

  // Submit Manage Transit Status Update
  const handleUpdateStatus = () => {
    if (!selectedDispatchId) return;

    startTransition(async () => {
      const res = await updateBrokerDispatchTransitStatusAction({
        dispatchId: selectedDispatchId,
        bookingIdOrReference,
        newEta: etaInput || undefined,
        newStatus: statusInput,
        notes: notesInput,
      });

      if (res.success) {
        toast.success(res.message || 'Transit status updated successfully!');
        setIsManageModalOpen(false);
        await loadLogistics();
      } else {
        toast.error(res.error || 'Failed to update transit status.');
      }
    });
  };

  // Submit Log Dispatch Form (Broker capturing on behalf of Seller)
  const handleLogDispatch = () => {
    if (!vehicleNumber || !driverName || !driverMobile || !expectedDeliveryDate) {
      toast.error('Please fill in all required fields: Vehicle Number, Driver Name, Mobile, and ETA.');
      return;
    }

    startTransition(async () => {
      const res = await logBrokerDispatchAction({
        bookingIdOrReference,
        vehicleNumber,
        driverName,
        driverMobile,
        dispatchDate,
        expectedDeliveryDate,
      });

      if (res.success) {
        toast.success(res.message || 'Dispatch logged successfully!');
        setIsLogDispatchOpen(false);
        // Reset form
        setVehicleNumber('');
        setDriverName('');
        setDriverMobile('');
        setExpectedDeliveryDate('');
        await loadLogistics();
      } else {
        toast.error(res.error || 'Failed to log dispatch details.');
      }
    });
  };

  if (isLoading) {
    return (
      <Card className="border-slate-200 bg-white p-6 space-y-4 animate-pulse">
        <div className="h-6 bg-slate-200 rounded-md w-1/3"></div>
        <div className="h-28 bg-slate-100 rounded-xl"></div>
        <div className="h-28 bg-slate-100 rounded-xl"></div>
      </Card>
    );
  }

  const dispatchesList = data?.dispatches || [];
  const hasDispatches = dispatchesList.length > 0;

  return (
    <Card className="border-slate-200/80 bg-white shadow-xs text-slate-900 w-full overflow-hidden">
      {/* HEADER */}
      <CardHeader className="bg-slate-900 text-white pb-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <CardTitle className="text-base sm:text-lg font-bold flex items-center gap-2">
              <Truck className="w-5 h-5 text-teal-400" />
              Dispatch & Logistics Capture Monitor (27.3)
            </CardTitle>
            <CardDescription className="text-xs text-slate-400 mt-0.5">
              Monitor vehicle dispatch details, transporter info, LR documents, and ETA updates.
            </CardDescription>
          </div>

          <div className="flex items-center gap-2 self-start sm:self-auto">
            <button
              onClick={loadLogistics}
              className="p-1.5 rounded-lg bg-slate-800 text-slate-300 hover:text-white transition-colors cursor-pointer"
              title="Refresh Logistics Data"
            >
              <RefreshCw className="w-4 h-4" />
            </button>
            <Button
              onClick={() => setIsLogDispatchOpen(true)}
              size="sm"
              className="bg-[#0D9488] hover:bg-[#0D9488]/90 text-white text-xs font-bold h-9 px-3 rounded-lg flex items-center gap-1.5 cursor-pointer"
            >
              <PlusCircle className="w-3.5 h-3.5" />
              <span>Log Dispatch</span>
            </Button>
          </div>
        </div>
      </CardHeader>

      <CardContent className="p-4 sm:p-6 space-y-6">
        {/* TASK 2: EMPTY STATE WHEN NO DISPATCH EXISTS YET */}
        {!hasDispatches ? (
          <div className="p-6 sm:p-8 text-center bg-slate-50/80 border-2 border-dashed border-slate-200 rounded-2xl space-y-3">
            <div className="w-12 h-12 rounded-full bg-teal-50 border border-teal-200 flex items-center justify-center text-[#0D9488] mx-auto">
              <Truck className="w-6 h-6" />
            </div>
            <div className="space-y-1 max-w-sm mx-auto">
              <h3 className="font-bold text-slate-800 text-base">
                Awaiting Dispatch Details from Seller
              </h3>
              <p className="text-xs text-slate-500 leading-relaxed">
                The Seller has not yet submitted vehicle loading details or uploaded the Lorry Receipt (LR) for this booking.
              </p>
            </div>
            <Button
              onClick={() => setIsLogDispatchOpen(true)}
              className="bg-[#0D9488] hover:bg-[#0D9488]/90 text-white text-xs font-bold h-12 px-4 rounded-xl shadow-xs inline-flex items-center gap-2 cursor-pointer min-h-[48px]"
            >
              <PlusCircle className="w-4 h-4" />
              <span>Log Dispatch Manually</span>
            </Button>
          </div>
        ) : (
          /* DISPATCH DETAILS CARDS LIST */
          <div className="space-y-5">
            {dispatchesList.map((disp, index) => {
              const statusLower = (disp.status || '').toLowerCase();
              const isDelayed = statusLower.includes('delay');
              const isDisputed = statusLower.includes('dispute');
              const isDelivered = statusLower.includes('deliver');

              return (
                <div
                  key={disp.id}
                  className="p-4 sm:p-5 rounded-2xl border border-slate-200/90 bg-linear-to-b from-white to-slate-50/40 space-y-4 shadow-xs"
                >
                  {/* DISPATCH HEADER */}
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-200/80 pb-3">
                    <div className="flex items-center gap-2.5">
                      <Badge className="bg-slate-900 text-white font-mono text-xs px-3 py-1 font-bold">
                        {disp.vehicleNumber}
                      </Badge>
                      <span className="text-xs font-bold text-slate-700">
                        Shipment #{index + 1}
                      </span>
                    </div>

                    <div className="flex items-center gap-2 self-start sm:self-auto">
                      <Badge
                        className={`text-xs font-bold px-2.5 py-1 ${
                          isDisputed
                            ? 'bg-rose-100 text-rose-800 border-rose-300'
                            : isDelayed
                            ? 'bg-amber-100 text-amber-800 border-amber-300'
                            : isDelivered
                            ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                            : 'bg-teal-100 text-teal-800 border-teal-300'
                        }`}
                      >
                        {isDisputed && <ShieldAlert className="w-3.5 h-3.5 mr-1 inline text-rose-600" />}
                        {isDelayed && <AlertTriangle className="w-3.5 h-3.5 mr-1 inline text-amber-600" />}
                        {isDelivered && <CheckCircle2 className="w-3.5 h-3.5 mr-1 inline text-emerald-600" />}
                        {!isDisputed && !isDelayed && !isDelivered && <Truck className="w-3.5 h-3.5 mr-1 inline text-[#0D9488]" />}
                        {disp.status}
                      </Badge>

                      {/* TASK 3: MANAGE TRANSIT STATUS BUTTON */}
                      <Button
                        onClick={() => handleOpenManageModal(disp)}
                        variant="outline"
                        size="sm"
                        className="h-8 px-2.5 text-xs font-semibold border-slate-300 text-slate-700 hover:bg-slate-100 rounded-lg flex items-center gap-1 cursor-pointer"
                      >
                        <Edit3 className="w-3.5 h-3.5 text-slate-500" />
                        <span>Manage Transit</span>
                      </Button>
                    </div>
                  </div>

                  {/* OPERATIONAL DATA GROUPS (360px MOBILE-RESPONSIVE STACKED GRID) */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 text-xs">
                    {/* GROUP 1: TRANSIT INFO */}
                    <div className="space-y-2 p-3 rounded-xl bg-slate-50 border border-slate-200/60">
                      <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 flex items-center gap-1">
                        <Calendar className="w-3.5 h-3.5 text-teal-600" />
                        Transit Schedule & Route
                      </span>
                      <div className="space-y-1">
                        <div>
                          <span className="text-slate-500">Dispatch Date:</span>{' '}
                          <span className="font-semibold text-slate-900">
                            {new Date(disp.dispatchDate).toLocaleDateString('en-IN')}
                          </span>
                        </div>
                        <div>
                          <span className="text-slate-500">Expected Delivery (ETA):</span>{' '}
                          <span className="font-semibold font-mono text-teal-800">
                            {new Date(disp.expectedDeliveryDate).toLocaleDateString('en-IN')}
                          </span>
                        </div>
                        <div>
                          <span className="text-slate-500">Origin Loading:</span>{' '}
                          <span className="font-medium text-slate-800">{data?.loadingLocation}</span>
                        </div>
                        <div>
                          <span className="text-slate-500">Destination:</span>{' '}
                          <span className="font-medium text-slate-800">{data?.destinationLocation}</span>
                        </div>
                      </div>
                    </div>

                    {/* GROUP 2: VEHICLE & TRANSPORTER INFO */}
                    <div className="space-y-2 p-3 rounded-xl bg-slate-50 border border-slate-200/60">
                      <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 flex items-center gap-1">
                        <Truck className="w-3.5 h-3.5 text-blue-600" />
                        Vehicle & Transporter
                      </span>
                      <div className="space-y-1">
                        <div>
                          <span className="text-slate-500">Vehicle Number:</span>{' '}
                          <span className="font-mono font-bold text-slate-900">{disp.vehicleNumber}</span>
                        </div>
                        <div>
                          <span className="text-slate-500">Driver / Transporter:</span>{' '}
                          <span className="font-semibold text-slate-900">{disp.driverName}</span>
                        </div>
                        <div>
                          <span className="text-slate-500">Driver Mobile:</span>{' '}
                          <span className="font-mono font-medium text-slate-800">{disp.driverMobile}</span>
                        </div>
                        <div>
                          <span className="text-slate-500">Shipment Volume:</span>{' '}
                          <span className="font-mono font-bold text-teal-800">
                            {disp.dispatchedQuantity} {data?.unitSymbol || 'MT'}
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* GROUP 3: CLICKABLE FULFILLMENT DOCUMENTS */}
                    <div className="space-y-2 p-3 rounded-xl bg-slate-50 border border-slate-200/60 sm:col-span-2 lg:col-span-1">
                      <span className="text-[10px] font-bold uppercase tracking-wider text-slate-500 flex items-center gap-1">
                        <FileText className="w-3.5 h-3.5 text-purple-600" />
                        Fulfillment Documents ({disp.allDocuments.length})
                      </span>

                      <div className="space-y-2 pt-0.5">
                        {/* Lorry Receipt (LR) Link */}
                        {disp.lrDocument?.signedUrl ? (
                          <a
                            href={disp.lrDocument.signedUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center justify-between w-full p-2 rounded-lg bg-white border border-teal-200 text-teal-900 hover:bg-teal-50 transition-colors font-semibold text-xs min-h-[38px]"
                          >
                            <span className="flex items-center gap-1.5">
                              📄 View Lorry Receipt (LR)
                            </span>
                            <ExternalLink className="w-3.5 h-3.5 text-teal-700" />
                          </a>
                        ) : (
                          <div className="p-2 rounded-lg bg-slate-100 text-slate-500 text-[11px]">
                            Lorry Receipt (LR) Not Uploaded Yet
                          </div>
                        )}

                        {/* E-Way Bill Link */}
                        {disp.ewayBillDocument?.signedUrl ? (
                          <a
                            href={disp.ewayBillDocument.signedUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center justify-between w-full p-2 rounded-lg bg-white border border-purple-200 text-purple-900 hover:bg-purple-50 transition-colors font-semibold text-xs min-h-[38px]"
                          >
                            <span className="flex items-center gap-1.5">
                              📋 View E-Way Bill
                            </span>
                            <ExternalLink className="w-3.5 h-3.5 text-purple-700" />
                          </a>
                        ) : null}

                        {/* Other Attached Documents */}
                        {disp.invoiceDocument?.signedUrl && (
                          <a
                            href={disp.invoiceDocument.signedUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center justify-between w-full p-2 rounded-lg bg-white border border-blue-200 text-blue-900 hover:bg-blue-50 transition-colors font-semibold text-xs min-h-[38px]"
                          >
                            <span className="flex items-center gap-1.5">
                              🧾 View Commercial Invoice
                            </span>
                            <ExternalLink className="w-3.5 h-3.5 text-blue-700" />
                          </a>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </CardContent>

      {/* MODAL 1: MANAGE TRANSIT STATUS & ETA DIALOG */}
      <Dialog open={isManageModalOpen} onOpenChange={setIsManageModalOpen}>
        <DialogContent className="sm:max-w-md bg-white text-slate-900">
          <DialogHeader>
            <DialogTitle className="text-base font-bold flex items-center gap-2">
              <Truck className="w-5 h-5 text-[#0D9488]" />
              Manage Transit Status & ETA
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              Update expected delivery date or flag transport exceptions (Delayed / Disputed).
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2 text-xs">
            <div className="space-y-1.5">
              <Label htmlFor="transit-status" className="font-semibold text-slate-700">
                Fulfillment Status
              </Label>
              <select
                id="transit-status"
                value={statusInput}
                onChange={(e) => setStatusInput(e.target.value as any)}
                className="w-full h-10 px-3 rounded-lg border border-slate-300 bg-white text-xs font-semibold focus:ring-2 focus:ring-teal-500"
              >
                <option value="Dispatched">Dispatched (Vehicle Loaded)</option>
                <option value="In Transit">In Transit (Moving to Destination)</option>
                <option value="Delayed">Delayed (Transit Exception / Weather / Checkpoint)</option>
                <option value="Disputed">Disputed (Quality / Damage Issue)</option>
                <option value="Delivered">Delivered (Buyer Received)</option>
              </select>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="eta-date" className="font-semibold text-slate-700">
                Expected Delivery Date (ETA)
              </Label>
              <Input
                id="eta-date"
                type="date"
                value={etaInput}
                onChange={(e) => setEtaInput(e.target.value)}
                className="h-10 text-xs"
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="notes-input" className="font-semibold text-slate-700">
                Operational Log Notes (Optional)
              </Label>
              <Input
                id="notes-input"
                placeholder="e.g., Delayed at state border checkpoint"
                value={notesInput}
                onChange={(e) => setNotesInput(e.target.value)}
                className="h-10 text-xs"
              />
            </div>
          </div>

          <DialogFooter className="gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setIsManageModalOpen(false)}
              className="h-10 text-xs font-semibold"
            >
              Cancel
            </Button>
            <Button
              onClick={handleUpdateStatus}
              disabled={isPending}
              className="h-10 bg-[#0D9488] hover:bg-[#0D9488]/90 text-white text-xs font-bold px-4 flex items-center gap-1.5 cursor-pointer"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Updating...</span>
                </>
              ) : (
                <span>Save Status Update</span>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* MODAL 2: LOG DISPATCH MANUALLY DIALOG (ON BEHALF OF SELLER) */}
      <Dialog open={isLogDispatchOpen} onOpenChange={setIsLogDispatchOpen}>
        <DialogContent className="sm:max-w-lg bg-white text-slate-900">
          <DialogHeader>
            <DialogTitle className="text-base font-bold flex items-center gap-2">
              <PlusCircle className="w-5 h-5 text-[#0D9488]" />
              Log Vehicle Dispatch Manually
            </DialogTitle>
            <DialogDescription className="text-xs text-slate-500">
              Capture vehicle loading & driver details on behalf of the Seller to update logistics tracking.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3.5 py-2 text-xs">
            <div className="space-y-1.5">
              <Label htmlFor="veh-num" className="font-semibold text-slate-700">
                Vehicle Registration Number *
              </Label>
              <Input
                id="veh-num"
                placeholder="e.g. MH 12 AB 1234"
                value={vehicleNumber}
                onChange={(e) => setVehicleNumber(e.target.value)}
                className="h-10 text-xs uppercase font-mono"
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label htmlFor="drv-name" className="font-semibold text-slate-700">
                  Driver / Transporter Name *
                </Label>
                <Input
                  id="drv-name"
                  placeholder="Full Name"
                  value={driverName}
                  onChange={(e) => setDriverName(e.target.value)}
                  className="h-10 text-xs"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="drv-mobile" className="font-semibold text-slate-700">
                  Driver Mobile Number *
                </Label>
                <Input
                  id="drv-mobile"
                  placeholder="10-digit mobile"
                  value={driverMobile}
                  onChange={(e) => setDriverMobile(e.target.value)}
                  className="h-10 text-xs font-mono"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label htmlFor="disp-date" className="font-semibold text-slate-700">
                  Dispatch Date
                </Label>
                <Input
                  id="disp-date"
                  type="date"
                  value={dispatchDate}
                  onChange={(e) => setDispatchDate(e.target.value)}
                  className="h-10 text-xs"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="eta-date-log" className="font-semibold text-slate-700">
                  Expected Delivery Date (ETA) *
                </Label>
                <Input
                  id="eta-date-log"
                  type="date"
                  value={expectedDeliveryDate}
                  onChange={(e) => setExpectedDeliveryDate(e.target.value)}
                  className="h-10 text-xs"
                />
              </div>
            </div>
          </div>

          <DialogFooter className="gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setIsLogDispatchOpen(false)}
              className="h-10 text-xs font-semibold"
            >
              Cancel
            </Button>
            <Button
              onClick={handleLogDispatch}
              disabled={isPending}
              className="h-10 bg-[#0D9488] hover:bg-[#0D9488]/90 text-white text-xs font-bold px-4 flex items-center gap-1.5 cursor-pointer"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Logging Dispatch...</span>
                </>
              ) : (
                <span>Log Vehicle Dispatch</span>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
}
