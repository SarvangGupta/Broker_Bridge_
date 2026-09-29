'use client';

import React, { useState, useEffect, useTransition } from 'react';
import Link from 'next/link';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet';
import {
  Handshake,
  Search,
  Building2,
  Building,
  PackageCheck,
  ArrowRight,
  RefreshCw,
  SlidersHorizontal,
  Lock,
  IndianRupee,
  Clock,
  Sparkles,
  ShieldCheck,
  CheckCircle2,
  XCircle,
  ArrowUpDown,
  FileEdit,
  User,
  TrendingUp,
  FileCheck2,
} from 'lucide-react';
import {
  getBrokerActiveNegotiationsAction,
  getSellerNegotiationDetailsAction,
  getBrokerMasterTimelineAction,
} from '@/src/server/actions/broker-negotiation-actions';
import {
  getBuyerNegotiationDetailsAction,
  getBuyerNegotiationTimelineAction,
} from '@/src/server/actions/broker-buyer-actions';
import { getNegotiationTimelineAction } from '@/src/server/actions/version-actions';
import { SellerNegotiationPanel } from '@/src/components/broker/work/seller-negotiation-panel';
import { BuyerNegotiationPanel } from '@/src/components/broker/work/buyer-negotiation-panel';
import { BrokerMasterTimeline, type MarginSpreadInfo, type MasterTimelineItem } from '@/src/components/broker/work/broker-master-timeline';
import type { SellerNegotiationDetails } from '@/src/types/negotiation-schema';
import type { BuyerNegotiationDetails } from '@/src/types/buyer-negotiation-schema';
import type { NegotiationTimelineItem } from '@/src/types/deal-version-schema';

export function BrokerNegotiationsHub() {
  const [items, setItems] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isRefreshing, startTransition] = useTransition();
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('all');

  // Selected negotiation modal & channel tab state
  const [selectedItem, setSelectedItem] = useState<any | null>(null);
  const [channelTab, setChannelTab] = useState<'seller' | 'buyer' | 'master'>('seller');

  // Seller channel state
  const [sellerDetails, setSellerDetails] = useState<SellerNegotiationDetails | null>(null);
  const [sellerTimeline, setSellerTimeline] = useState<NegotiationTimelineItem[]>([]);

  // Buyer channel state
  const [buyerDetails, setBuyerDetails] = useState<BuyerNegotiationDetails | null>(null);
  const [buyerTimeline, setBuyerTimeline] = useState<NegotiationTimelineItem[]>([]);

  // Master timeline state (Broker eyes only)
  const [masterTimeline, setMasterTimeline] = useState<MasterTimelineItem[]>([]);
  const [marginSpread, setMarginSpread] = useState<MarginSpreadInfo | null>(null);

  const [isDetailLoading, setIsDetailLoading] = useState<boolean>(false);
  const [isSheetOpen, setIsSheetOpen] = useState<boolean>(false);

  const fetchNegotiations = async () => {
    setIsLoading(true);
    const res = await getBrokerActiveNegotiationsAction();
    if (res.success && res.data) {
      setItems(res.data);
    }
    setIsLoading(false);
  };

  useEffect(() => {
    fetchNegotiations();
  }, []);

  const handleRefresh = () => {
    startTransition(async () => {
      await fetchNegotiations();
      if (selectedItem) {
        await loadTabChannelData(selectedItem, channelTab);
      }
    });
  };

  const loadTabChannelData = async (item: any, tab: 'seller' | 'buyer' | 'master') => {
    if (!item) return;
    setIsDetailLoading(true);
    const requestId = item.requestId;
    const requirementId = item.requirementId;

    try {
      if (tab === 'seller') {
        const [selDetRes, selTimeRes] = await Promise.all([
          getSellerNegotiationDetailsAction(requestId),
          getNegotiationTimelineAction(requestId),
        ]);
        if (selDetRes.success && selDetRes.data) setSellerDetails(selDetRes.data);
        if (selTimeRes.success && selTimeRes.data) setSellerTimeline(selTimeRes.data);
      } else if (tab === 'buyer') {
        const [buyDetRes, buyTimeRes] = await Promise.all([
          getBuyerNegotiationDetailsAction(requirementId),
          getBuyerNegotiationTimelineAction(requirementId),
        ]);
        if (buyDetRes.success && buyDetRes.data) setBuyerDetails(buyDetRes.data);
        if (buyTimeRes.success && buyTimeRes.data) setBuyerTimeline(buyTimeRes.data);
      } else if (tab === 'master') {
        const masterRes = await getBrokerMasterTimelineAction(requestId);
        if (masterRes.success && masterRes.data) {
          setMasterTimeline(masterRes.data.timeline || []);
          setMarginSpread(masterRes.data.marginSpread || null);
        }
      }
    } catch (err) {
      console.error('[LAZY_TAB_LOAD_ERROR]', err);
    } finally {
      setIsDetailLoading(false);
    }
  };

  const handleOpenChannelDrawer = (item: any, defaultTab: 'seller' | 'buyer' | 'master' = 'seller') => {
    setSelectedItem(item);
    setChannelTab(defaultTab);
    setIsSheetOpen(true);
    loadTabChannelData(item, defaultTab);
  };

  const handleTabSwitch = (tab: 'seller' | 'buyer' | 'master') => {
    setChannelTab(tab);
    if (selectedItem) {
      loadTabChannelData(selectedItem, tab);
    }
  };

  // Filter negotiations by search & status filter
  const filteredItems = items.filter((item) => {
    const q = searchQuery.toLowerCase().trim();
    const matchesSearch =
      !q ||
      item.sellerCompanyName?.toLowerCase().includes(q) ||
      item.commodityName?.toLowerCase().includes(q) ||
      item.lotNumber?.toLowerCase().includes(q) ||
      item.requestId?.toLowerCase().includes(q);

    const matchesStatus =
      statusFilter === 'all' ||
      (statusFilter === 'countered' && item.status?.toLowerCase().includes('counter')) ||
      (statusFilter === 'proposed' && item.status?.toLowerCase().includes('propos')) ||
      (statusFilter === 'accepted' && item.status?.toLowerCase().includes('accept')) ||
      (statusFilter === 'sent' && item.status?.toLowerCase().includes('sent'));

    return matchesSearch && matchesStatus;
  });

  return (
    <div className="w-full space-y-6">
      {/* Search & Filter Header Toolbar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 absolute left-3 top-3.5 text-slate-400" />
          <Input
            type="text"
            placeholder="Search seller, commodity, or lot number..."
            className="pl-9 h-11 text-xs sm:text-sm border-slate-200 bg-white focus-visible:ring-[#0D9488]"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>

        <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
          <Button
            variant="outline"
            size="sm"
            onClick={handleRefresh}
            disabled={isRefreshing}
            className="h-11 px-3 text-xs font-medium border-slate-200 text-slate-700 hover:bg-slate-50 shrink-0"
          >
            <RefreshCw className={`w-3.5 h-3.5 mr-1.5 ${isRefreshing ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </Button>

          <div className="flex items-center gap-1 bg-slate-100 p-1 rounded-lg border border-slate-200/70 text-xs shrink-0">
            {['all', 'countered', 'proposed', 'accepted'].map((st) => (
              <button
                key={st}
                onClick={() => setStatusFilter(st)}
                className={`px-3 py-1.5 rounded-md font-semibold text-xs transition-all capitalize whitespace-nowrap ${
                  statusFilter === st
                    ? 'bg-white text-[#0D9488] shadow-2xs font-bold'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {st}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Loading Skeleton */}
      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <Card key={i} className="border border-slate-200 animate-pulse p-4 space-y-3">
              <div className="h-4 bg-slate-200 rounded-md w-1/2"></div>
              <div className="h-3 bg-slate-200 rounded-md w-3/4"></div>
              <div className="h-8 bg-slate-200 rounded-md"></div>
            </Card>
          ))}
        </div>
      ) : filteredItems.length === 0 ? (
        /* Empty State */
        <Card className="border-dashed border-2 border-slate-200 bg-white/70">
          <CardContent className="p-8 sm:p-12 text-center space-y-4">
            <div className="mx-auto w-12 h-12 rounded-full bg-teal-50 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
              <Handshake className="w-6 h-6" />
            </div>
            <div className="space-y-1 max-w-sm mx-auto">
              <h3 className="font-bold text-slate-800 text-base">No Active Commercial Negotiations</h3>
              <p className="text-xs sm:text-sm text-slate-500">
                {searchQuery || statusFilter !== 'all'
                  ? 'No negotiations match your active search filters.'
                  : 'Start a commercial proposal from the Matches tab to initiate negotiation.'}
              </p>
            </div>
          </CardContent>
        </Card>
      ) : (
        /* Negotiations Cards Grid */
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredItems.map((item) => {
            const unitSym = item.unitSymbol || 'MT';
            const isCountered = item.status?.toLowerCase().includes('counter');
            const isAccepted = item.status?.toLowerCase().includes('accept');

            return (
              <Card
                key={item.requestId}
                className="border border-slate-200/90 shadow-2xs hover:shadow-md transition-all bg-white flex flex-col justify-between overflow-hidden group"
              >
                <CardHeader className="p-4 sm:p-5 pb-3 border-b border-slate-100 bg-slate-50/50">
                  <div className="flex items-start justify-between gap-2">
                    <div className="space-y-1">
                      <div className="flex items-center gap-2 flex-wrap">
                        <Badge
                          variant="outline"
                          className={`text-[10px] font-semibold ${
                            isCountered
                              ? 'bg-amber-50 text-amber-700 border-amber-200'
                              : isAccepted
                              ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                              : 'bg-teal-50 text-teal-700 border-teal-200'
                          }`}
                        >
                          {isCountered ? (
                            <ArrowUpDown className="w-3 h-3 mr-1 inline" />
                          ) : isAccepted ? (
                            <CheckCircle2 className="w-3 h-3 mr-1 inline" />
                          ) : (
                            <Sparkles className="w-3 h-3 mr-1 inline" />
                          )}
                          {item.status || 'Active Proposal'}
                        </Badge>
                      </div>

                      <h4 className="font-bold text-sm sm:text-base text-slate-900 flex items-center gap-1.5 pt-0.5">
                        <Building2 className="w-4 h-4 text-[#0D9488] shrink-0" />
                        <span>{item.sellerCompanyName}</span>
                        {item.sellerCompanyVerified && (
                          <ShieldCheck className="w-3.5 h-3.5 text-teal-600 shrink-0" />
                        )}
                      </h4>
                    </div>

                    <div className="text-right font-mono text-[11px] text-slate-500">
                      <span>Lot: {item.lotNumber}</span>
                    </div>
                  </div>
                </CardHeader>

                <CardContent className="p-4 sm:p-5 space-y-3 flex-1">
                  {/* Sector & Commodity details */}
                  <div className="flex items-center gap-2 text-xs font-semibold text-slate-700 bg-slate-100/70 p-2.5 rounded-lg">
                    <PackageCheck className="w-4 h-4 text-[#0D9488] shrink-0" />
                    <span className="truncate">{item.commodityName}</span>
                    <span className="text-slate-400">•</span>
                    <span className="text-slate-500 font-mono text-[11px] truncate">{item.gradeName}</span>
                  </div>

                  {/* Commercial Metrics Strip */}
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div className="p-2 bg-slate-50 rounded-md border border-slate-100">
                      <span className="text-[10px] text-slate-400 font-mono block">Seller Asking</span>
                      <span className="font-bold text-slate-800">
                        ₹{Number(item.askingPrice).toLocaleString('en-IN')}/{unitSym}
                      </span>
                    </div>

                    <div className="p-2 bg-teal-50/60 rounded-md border border-teal-100">
                      <span className="text-[10px] text-teal-700 font-mono block">Broker Offered Rate</span>
                      <span className="font-bold text-teal-900">
                        ₹{Number(item.offeredPrice).toLocaleString('en-IN')}/{unitSym}
                      </span>
                    </div>
                  </div>

                  {/* Confidential Minimum Floor (Broker Eyes Only) */}
                  {item.confidentialMinimumPrice && (
                    <div className="flex items-center justify-between px-2.5 py-1.5 rounded-md bg-purple-50 border border-purple-100 text-[11px]">
                      <span className="text-purple-700 font-medium flex items-center gap-1">
                        <Lock className="w-3 h-3 text-purple-600" />
                        <span>Seller Min Floor:</span>
                      </span>
                      <span className="font-mono font-bold text-purple-900">
                        ₹{Number(item.confidentialMinimumPrice).toLocaleString('en-IN')}/{unitSym}
                      </span>
                    </div>
                  )}

                  {/* Remarks */}
                  {item.counterNotes && (
                    <p className="text-[11px] text-slate-500 italic line-clamp-2 bg-slate-50 p-2 rounded-md">
                      &ldquo;{item.counterNotes}&rdquo;
                    </p>
                  )}
                </CardContent>

                {/* Card Action Triad */}
                <div className="p-4 pt-0 grid grid-cols-3 gap-1.5 pb-2">
                  <Button
                    onClick={() => handleOpenChannelDrawer(item, 'seller')}
                    className="min-h-[48px] h-12 bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold text-[11px] sm:text-xs rounded-xl transition-all shadow-2xs px-2 border border-slate-200"
                  >
                    <Building2 className="w-3.5 h-3.5 mr-1 shrink-0 text-teal-700" />
                    <span>Seller</span>
                  </Button>

                  <Button
                    onClick={() => handleOpenChannelDrawer(item, 'buyer')}
                    variant="outline"
                    className="min-h-[48px] h-12 border-blue-300 text-blue-800 hover:bg-blue-50 font-bold text-[11px] sm:text-xs rounded-xl transition-all shadow-2xs px-2"
                  >
                    <Building className="w-3.5 h-3.5 mr-1 text-blue-600 shrink-0" />
                    <span>Buyer</span>
                  </Button>

                  <Button
                    onClick={() => handleOpenChannelDrawer(item, 'master')}
                    variant="secondary"
                    className="min-h-[48px] h-12 bg-slate-900 hover:bg-slate-800 text-white font-bold text-[11px] sm:text-xs rounded-xl transition-all shadow-2xs px-2"
                  >
                    <TrendingUp className="w-3.5 h-3.5 mr-1 text-teal-400 shrink-0" />
                    <span>Master</span>
                  </Button>
                </div>

                {/* Task 4: Proceed to Final Contract UI Routing Hotfix */}
                <div className="p-4 pt-0">
                  <Link href={`/broker/deals/${item.requestId}`} className="w-full block">
                    <Button
                      className="w-full min-h-[48px] h-12 bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-bold text-xs rounded-xl shadow-xs flex items-center justify-center gap-1.5 cursor-pointer"
                    >
                      <FileCheck2 className="w-4 h-4" />
                      <span>Proceed to Final Contract</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </Button>
                  </Link>
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* DETAILED DUAL-CHANNEL NEGOTIATION SHEET / DRAWER */}
      <Sheet open={isSheetOpen} onOpenChange={setIsSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-2xl overflow-y-auto p-4 sm:p-6 bg-slate-50">
          <SheetHeader className="pb-4 border-b border-slate-200 space-y-3">
            <div className="flex items-center justify-between">
              <SheetTitle className="text-lg font-bold text-slate-900 flex items-center gap-2">
                <Handshake className="w-5 h-5 text-[#0D9488]" />
                <span>Commercial Negotiation Workspace</span>
              </SheetTitle>
            </div>
            <SheetDescription className="text-xs text-slate-500">
              Zero shared conversation object. Manage Seller-Broker and Buyer-Broker streams independently.
            </SheetDescription>

            {/* TRIPLE CHANNEL TAB SWITCHER */}
            <div className="grid grid-cols-3 gap-1.5 p-1 bg-slate-200/80 rounded-xl">
              <button
                onClick={() => handleTabSwitch('seller')}
                className={`py-2 px-1.5 sm:px-2.5 rounded-lg text-[11px] sm:text-xs font-bold transition-all flex items-center justify-center gap-1 min-w-0 ${
                  channelTab === 'seller'
                    ? 'bg-slate-900 text-white shadow-xs'
                    : 'text-slate-700 hover:text-slate-900 hover:bg-white/50'
                }`}
              >
                <Building2 className="w-3.5 h-3.5 text-teal-400 shrink-0" />
                <span className="truncate">Seller (25.1)</span>
              </button>

              <button
                onClick={() => handleTabSwitch('buyer')}
                className={`py-2 px-1.5 sm:px-2.5 rounded-lg text-[11px] sm:text-xs font-bold transition-all flex items-center justify-center gap-1 min-w-0 ${
                  channelTab === 'buyer'
                    ? 'bg-blue-900 text-white shadow-xs'
                    : 'text-slate-700 hover:text-slate-900 hover:bg-white/50'
                }`}
              >
                <Building className="w-3.5 h-3.5 text-blue-400 shrink-0" />
                <span className="truncate">Buyer (25.2)</span>
              </button>

              <button
                onClick={() => handleTabSwitch('master')}
                className={`py-2 px-1.5 sm:px-2.5 rounded-lg text-[11px] sm:text-xs font-bold transition-all flex items-center justify-center gap-1 min-w-0 ${
                  channelTab === 'master'
                    ? 'bg-teal-900 text-white shadow-xs'
                    : 'text-slate-700 hover:text-slate-900 hover:bg-white/50'
                }`}
              >
                <TrendingUp className="w-3.5 h-3.5 text-teal-300 shrink-0" />
                <span className="truncate">Master (25.3)</span>
              </button>
            </div>
          </SheetHeader>

          <div className="mt-6">
            {isDetailLoading ? (
              <div className="space-y-4 py-8 animate-pulse">
                <div className="h-6 bg-slate-200 rounded-md w-1/2"></div>
                <div className="h-32 bg-slate-200 rounded-xl"></div>
                <div className="h-48 bg-slate-200 rounded-xl"></div>
              </div>
            ) : channelTab === 'seller' ? (
              sellerDetails ? (
                <SellerNegotiationPanel
                  details={sellerDetails}
                  timeline={sellerTimeline}
                  onRefresh={handleRefresh}
                />
              ) : (
                <p className="text-xs text-slate-500 text-center py-6">
                  Seller details unavailable for this request.
                </p>
              )
            ) : channelTab === 'buyer' ? (
              buyerDetails ? (
                <BuyerNegotiationPanel
                  details={buyerDetails}
                  timeline={buyerTimeline}
                  onRefresh={handleRefresh}
                />
              ) : (
                <p className="text-xs text-slate-500 text-center py-6">
                  Buyer details unavailable for this requirement.
                </p>
              )
            ) : (
              <div className="space-y-4">
                {selectedItem?.requestId && (
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-3.5 bg-gradient-to-r from-teal-950 via-slate-900 to-slate-950 text-white rounded-xl border border-teal-800/80 shadow-xs">
                    <div className="text-xs space-y-0.5">
                      <span className="font-bold text-teal-300 flex items-center gap-1.5">
                        <Sparkles className="w-3.5 h-3.5 text-teal-400" />
                        Ready to Structure Final Deal?
                      </span>
                      <p className="text-slate-300 text-[11px]">
                        Open the Deal Builder to set commission spread and freeze the version snapshot.
                      </p>
                    </div>
                    <Link href={`/broker/deals/${selectedItem.requestId}`}>
                      <Button size="sm" className="bg-[#0D9488] hover:bg-[#0D9488]/90 text-white font-bold text-xs h-10 px-3.5 gap-1.5 shrink-0 min-h-[40px] w-full sm:w-auto">
                        <FileCheck2 className="w-4 h-4" />
                        <span>Open Deal Builder</span>
                        <ArrowRight className="w-3.5 h-3.5" />
                      </Button>
                    </Link>
                  </div>
                )}
                <BrokerMasterTimeline
                  marginSpread={marginSpread}
                  timeline={masterTimeline}
                />
              </div>
            )}
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
