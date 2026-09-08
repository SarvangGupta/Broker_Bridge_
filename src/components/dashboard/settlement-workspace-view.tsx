"use client";

import React, { useEffect, useState, useTransition } from "react";
import { SettlementSummary, TransactionSettlementRecord } from "@/src/types/settlement-schema";
import { getSellerSettlementOverviewAction } from "@/src/server/actions/settlement-actions";
import { SettlementSummaryCards } from "@/src/components/dashboard/settlement-summary-cards";
import { SettlementLedgerTable } from "@/src/components/dashboard/settlement-ledger-table";
import { toast } from "sonner";

interface SettlementWorkspaceViewProps {
  initialSummary?: SettlementSummary | null;
  initialRecords?: TransactionSettlementRecord[];
  className?: string;
}

export function SettlementWorkspaceView({
  initialSummary,
  initialRecords,
  className = "",
}: SettlementWorkspaceViewProps) {
  const [summary, setSummary] = useState<SettlementSummary | null>(initialSummary || null);
  const [records, setRecords] = useState<TransactionSettlementRecord[]>(initialRecords || []);
  const [isLoading, setIsLoading] = useState<boolean>(!initialSummary && !initialRecords);
  const [isPending, startTransition] = useTransition();

  const fetchSettlementData = async () => {
    try {
      const res = await getSellerSettlementOverviewAction();
      if (res.success && res.data) {
        setSummary(res.data.summary);
        setRecords(res.data.records);
      } else {
        toast.error(res.error || "Failed to load settlement overview.");
      }
    } catch (err: any) {
      console.error("Error loading settlement data:", err);
      toast.error("Network error while loading settlement ledger.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!initialSummary && !initialRecords) {
      fetchSettlementData();
    }
  }, []);

  const handleRefresh = () => {
    startTransition(async () => {
      await fetchSettlementData();
      toast.success("Settlement ledger refreshed.");
    });
  };

  return (
    <div className={`space-y-6 ${className}`}>
      {/* 1. FINANCIAL SUMMARY KPI CARDS */}
      <SettlementSummaryCards summary={summary} isLoading={isLoading || isPending} />

      {/* 2. SETTLEMENT LEDGER TABLE & DETAIL SHEET */}
      <SettlementLedgerTable
        records={records}
        onRefresh={handleRefresh}
        isLoading={isLoading || isPending}
      />
    </div>
  );
}
