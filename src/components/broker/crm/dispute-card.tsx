'use client';

import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  AlertTriangle,
  Clock,
  CheckCircle2,
  Building,
  Building2,
  FileText,
  ChevronRight,
  ShieldAlert,
  User,
} from 'lucide-react';
import { BrokerDisputeItem } from '@/src/server/actions/broker-dispute-actions';
import { DisputeResolutionModal } from './dispute-resolution-modal';

interface DisputeCardProps {
  dispute: BrokerDisputeItem;
  onDisputeResolved?: () => void;
}

export function DisputeCard({ dispute, onDisputeResolved }: DisputeCardProps) {
  const [isModalOpen, setIsModalOpen] = useState<boolean>(false);

  const getCategoryBadgeClass = (cat: string) => {
    switch (cat) {
      case 'Quality':
        return 'bg-red-100 text-red-800 border-red-300';
      case 'Delivery':
        return 'bg-amber-100 text-amber-800 border-amber-300';
      case 'Payment':
        return 'bg-purple-100 text-purple-800 border-purple-300';
      case 'Quantity':
        return 'bg-blue-100 text-blue-800 border-blue-300';
      default:
        return 'bg-teal-100 text-teal-800 border-teal-300';
    }
  };

  return (
    <Card className="border border-slate-200/80 bg-white shadow-xs hover:border-[#0D9488]/40 transition-all flex flex-col justify-between overflow-hidden">
      <CardContent className="p-4 sm:p-5 space-y-4">
        {/* HEADER: BOOKING ID & CATEGORY BADGE */}
        <div className="flex items-start justify-between gap-2 flex-wrap">
          <div className="flex items-center gap-2">
            <Badge className="bg-[#0D9488] text-white font-mono text-xs px-2.5 py-0.5">
              {dispute.bookingReference}
            </Badge>
            <Badge className={`text-xs font-bold ${getCategoryBadgeClass(dispute.category)}`}>
              {dispute.category}
            </Badge>
          </div>

          <Badge
            className={`text-[11px] font-bold ${
              dispute.status === 'Resolved'
                ? 'bg-emerald-100 text-emerald-800 border-emerald-300'
                : dispute.status === 'Under Broker Review'
                ? 'bg-amber-100 text-amber-800 border-amber-300'
                : 'bg-red-100 text-red-800 border-red-300 animate-pulse'
            }`}
          >
            {dispute.status === 'Resolved' && <CheckCircle2 className="w-3 h-3 mr-1 inline" />}
            {dispute.status !== 'Resolved' && <AlertTriangle className="w-3 h-3 mr-1 inline" />}
            {dispute.status}
          </Badge>
        </div>

        {/* COMMODITY & LOT */}
        <div>
          <h4 className="font-bold text-slate-900 text-sm">{dispute.commodityName}</h4>
          <p className="text-xs text-slate-500">Lot #{dispute.lotNumber}</p>
        </div>

        {/* FILED BY & AGE SUMMARY */}
        <div className="p-3 rounded-xl bg-slate-50 border border-slate-100 text-xs space-y-1.5">
          <div className="flex items-center justify-between text-[11px] text-slate-600">
            <span className="flex items-center gap-1 font-semibold">
              <Building className="w-3.5 h-3.5 text-slate-400" />
              Filed by: {dispute.filedByCompanyName}
            </span>
            <span className="flex items-center gap-1 text-slate-500 font-mono">
              <Clock className="w-3 h-3 text-slate-400" />
              {dispute.daysOpen}d Open
            </span>
          </div>
          <p className="text-slate-700 text-xs line-clamp-2 italic font-medium">
            "{dispute.description}"
          </p>
        </div>

        {/* COUNTERPARTIES DIRECTORY (PRIVACY PROTECTED - BROKER MEDIATED) */}
        <div className="grid grid-cols-2 gap-2 text-[11px] text-slate-500 pt-1 border-t border-slate-100">
          <div>
            <span className="block text-slate-400">Buyer:</span>
            <span className="font-bold text-slate-800 truncate block">{dispute.buyerCompanyName}</span>
          </div>
          <div>
            <span className="block text-slate-400">Seller:</span>
            <span className="font-bold text-slate-800 truncate block">{dispute.sellerCompanyName}</span>
          </div>
        </div>

        {/* ACTION BUTTON */}
        <div className="pt-2">
          <Button
            onClick={() => setIsModalOpen(true)}
            variant={dispute.status === 'Resolved' ? 'outline' : 'default'}
            className={`w-full font-semibold text-xs h-10 rounded-xl cursor-pointer ${
              dispute.status === 'Resolved'
                ? 'border-slate-300 text-slate-700 hover:bg-slate-100'
                : 'bg-[#0D9488] hover:bg-teal-700 text-white shadow-xs'
            }`}
          >
            <ShieldAlert className="w-4 h-4 mr-1.5" />
            {dispute.status === 'Resolved' ? 'View Resolution History' : 'Manage Dispute'}
          </Button>
        </div>
      </CardContent>

      {/* RESOLUTION MODAL */}
      <DisputeResolutionModal
        dispute={dispute}
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onResolved={onDisputeResolved}
      />
    </Card>
  );
}
