'use client';

import React, { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Card, CardContent } from '@/components/ui/card';
import {
  Sparkles,
  FileText,
  SlidersHorizontal,
  Handshake,
  ArrowRight,
  Search,
} from 'lucide-react';
import { BrokerRequirementsInbox } from './broker-requirements-inbox';
import { MatchesView } from './matches-view';
import { BrokerQualityHub } from './broker-quality-hub';
import type { BrokerAssignedRequirement } from '@/src/server/actions/broker-work-actions';

interface BrokerWorkWorkspaceProps {
  initialRequirements: BrokerAssignedRequirement[];
  error?: string;
}

export function BrokerWorkWorkspace({
  initialRequirements = [],
  error,
}: BrokerWorkWorkspaceProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const urlTab = searchParams.get('tab');
  const urlReqId = searchParams.get('reqId');
  const [activeTab, setActiveTab] = useState<string>(urlTab || 'requirements');
  const [selectedReqId, setSelectedReqId] = useState<string | null>(urlReqId || null);

  useEffect(() => {
    if (urlTab && ['requirements', 'matches', 'quality', 'negotiations'].includes(urlTab)) {
      setActiveTab(urlTab);
    }
    if (urlReqId) {
      setSelectedReqId(urlReqId);
    }
  }, [urlTab, urlReqId]);

  const handleTabChange = (newTab: string) => {
    setActiveTab(newTab);
    const params = new URLSearchParams(searchParams.toString());
    params.set('tab', newTab);
    router.replace(`/broker/work?${params.toString()}`, { scroll: false });
  };

  const handleNavigateToMatches = (reqId: string) => {
    setActiveTab('matches');
    setSelectedReqId(reqId);
    router.replace(`/broker/work?tab=matches&reqId=${reqId}`, { scroll: false });
  };

  return (
    <div className="w-full space-y-6">
      <Tabs value={activeTab} onValueChange={handleTabChange} className="w-full space-y-6">
        {/* MOBILE LOOPHOLE FIX: w-full justify-start overflow-x-auto touch-pan-x flex-nowrap */}
        <div className="w-full overflow-x-auto touch-pan-x pb-1 scrollbar-none">
          <TabsList className="w-full min-w-max justify-start overflow-x-auto touch-pan-x flex-nowrap bg-slate-100/80 p-1 rounded-xl h-12 border border-slate-200/60">
            <TabsTrigger
              value="requirements"
              className="min-h-[40px] px-4 rounded-lg font-semibold text-xs sm:text-sm data-active:bg-white data-active:text-[#0D9488] data-active:shadow-xs transition-all whitespace-nowrap flex items-center gap-1.5"
            >
              <FileText className="w-4 h-4 shrink-0" />
              <span>Requirements</span>
              {initialRequirements.length > 0 && (
                <span className="text-[10px] px-1.5 py-0.2 rounded-full font-mono bg-teal-100 text-teal-800 font-bold ml-0.5">
                  {initialRequirements.length}
                </span>
              )}
            </TabsTrigger>

            <TabsTrigger
              value="matches"
              className="min-h-[40px] px-4 rounded-lg font-semibold text-xs sm:text-sm data-active:bg-white data-active:text-[#0D9488] data-active:shadow-xs transition-all whitespace-nowrap flex items-center gap-1.5"
            >
              <Sparkles className="w-4 h-4 shrink-0" />
              <span>Matches</span>
            </TabsTrigger>

            <TabsTrigger
              value="quality"
              className="min-h-[40px] px-4 rounded-lg font-semibold text-xs sm:text-sm data-active:bg-white data-active:text-[#0D9488] data-active:shadow-xs transition-all whitespace-nowrap flex items-center gap-1.5"
            >
              <SlidersHorizontal className="w-4 h-4 shrink-0" />
              <span>Quality</span>
            </TabsTrigger>

            <TabsTrigger
              value="negotiations"
              className="min-h-[40px] px-4 rounded-lg font-semibold text-xs sm:text-sm data-active:bg-white data-active:text-[#0D9488] data-active:shadow-xs transition-all whitespace-nowrap flex items-center gap-1.5"
            >
              <Handshake className="w-4 h-4 shrink-0" />
              <span>Negotiations</span>
            </TabsTrigger>
          </TabsList>
        </div>

        {/* Tab Content: Requirements (Micro-Sprint 23.1 LIVE) */}
        <TabsContent value="requirements" className="mt-0 focus-visible:outline-hidden">
          <BrokerRequirementsInbox
            initialRequirements={initialRequirements}
            error={error}
          />
        </TabsContent>

        {/* Tab Content: Matches (Micro-Sprint 24.1 LIVE) */}
        <TabsContent value="matches" className="mt-0 focus-visible:outline-hidden">
          <MatchesView
            availableRequirements={initialRequirements}
            initialRequirementId={selectedReqId}
          />
        </TabsContent>

        {/* Tab Content: Quality (Micro-Sprint 24.2 LIVE) */}
        <TabsContent value="quality" className="mt-0 focus-visible:outline-hidden">
          <BrokerQualityHub
            requirements={initialRequirements}
            onNavigateToMatches={handleNavigateToMatches}
          />
        </TabsContent>

        {/* Tab Content: Negotiations (Sprint 26) */}
        <TabsContent value="negotiations" className="mt-0 focus-visible:outline-hidden">
          <Card className="border-dashed border-2 border-slate-200 bg-white/60">
            <CardContent className="p-8 sm:p-12 text-center space-y-4">
              <div className="mx-auto w-12 h-12 rounded-full bg-teal-50 border border-teal-200/80 flex items-center justify-center text-[#0D9488]">
                <Handshake className="w-6 h-6" />
              </div>
              <div className="space-y-1 max-w-sm mx-auto">
                <h3 className="font-bold text-slate-800 text-base">Commercial Negotiations</h3>
                <p className="text-xs sm:text-sm text-slate-500">
                  Versioned deal proposals, counter-offers, and multi-party commercial revisions.
                </p>
              </div>
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-mono font-medium text-teal-700 bg-teal-50/80 border border-teal-200/60">
                <span>Module scheduled for Sprint 26</span>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
