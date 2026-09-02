"use client";

import { useState } from "react";
import { Card, CardContent, CardFooter, CardHeader } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { EnrichedMatchResult } from "@/src/server/actions/ui-match-actions"
import { CheckCircle2, AlertTriangle, Percent, Activity, FlaskConical } from "lucide-react"

import { VerificationBadge, TrustScore } from "@/src/components/ui/trust-badge"
import { QualityStatusBadge } from "@/src/components/dashboard/quality-status-badge"
import { LabReviewDialog } from "@/src/components/broker/lab-review-dialog"

export function MatchResultCard({ match }: { match: EnrichedMatchResult }) {
  const [labReviewOpen, setLabReviewOpen] = useState(false);

  const getBadgeColor = (classification: string) => {
    switch (classification) {
      case 'Strong Match': return 'bg-green-500 hover:bg-green-600 text-white'
      case 'Good Match': return 'bg-yellow-500 hover:bg-yellow-600 text-white'
      case 'Partial': return 'bg-slate-400 hover:bg-slate-500 text-white'
      default: return 'bg-slate-200 text-slate-800'
    }
  }

  return (
    <Card className="flex flex-col h-full border-border">
      <CardHeader className="pb-3 border-b flex flex-row items-start justify-between space-y-0">
        <div className="space-y-1.5 min-w-0 flex-1">
          {(match.industryName || match.categoryName || match.commodityName) && (
            <div className="flex items-center gap-1.5 text-[11px] font-semibold text-slate-500 uppercase tracking-wide">
              <span>{[match.industryName, match.categoryName].filter(Boolean).join(" • ") || "General"}</span>
              {match.commodityName && (
                <>
                  <span className="text-slate-300">|</span>
                  <span className="text-slate-900 font-bold">{match.commodityName}</span>
                </>
              )}
            </div>
          )}
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="font-semibold text-lg line-clamp-1">{match.companyName}</h3>
            {match.isVerified && <VerificationBadge compact />}
            <TrustScore score={match.trustScore} compact />
            {match.qualityStatus && (
              <QualityStatusBadge
                status={match.qualityStatus}
                validUntil={match.labTestValidUntil}
              />
            )}
          </div>
          <p className="text-xs text-muted-foreground text-ellipsis overflow-hidden">
            {match.recommendedAction}
          </p>
        </div>
        <Badge className={`${getBadgeColor(match.classification)} whitespace-nowrap ml-2 shrink-0`}>
          {match.classification}
        </Badge>
      </CardHeader>
      
      <CardContent className="flex-1 pt-4">
        {/* Score & Main Metrics */}
        <div className="flex items-center gap-4 mb-6">
          <div className="flex flex-col items-center justify-center bg-primary/10 rounded-full h-16 w-16 shrink-0 border border-primary/20">
            <span className="text-xl font-bold text-primary">{match.totalScore}</span>
            <span className="text-[10px] uppercase font-semibold text-primary/70">Score</span>
          </div>
          
          <div className="grid grid-cols-2 gap-3 flex-1">
            <div className="flex flex-col p-2 bg-muted rounded-md">
              <span className="text-xs text-muted-foreground flex items-center gap-1"><Percent className="w-3 h-3"/> Coverage</span>
              <span className="font-medium text-sm mt-1">{match.quantity.coveragePercent.toFixed(0)}%</span>
            </div>
            <div className="flex flex-col p-2 bg-muted rounded-md">
              <span className="text-xs text-muted-foreground flex items-center gap-1"><Activity className="w-3 h-3"/> Price Diff</span>
              <span className={`font-medium text-sm mt-1 ${match.price.differencePercent > 0 ? 'text-red-500' : 'text-green-600'}`}>
                {match.price.differencePercent > 0 ? '+' : ''}{match.price.differencePercent.toFixed(1)}%
              </span>
            </div>
          </div>
        </div>

        {/* Explainability Section */}
        <div className="space-y-3">
          {match.reasons.length > 0 && (
            <div className="space-y-1.5">
              <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">Pros</span>
              {match.reasons.map((reason, idx) => (
                <div key={idx} className="flex items-start gap-2 text-sm">
                  <CheckCircle2 className="w-4 h-4 text-green-500 shrink-0 mt-0.5" />
                  <span className="text-slate-700 dark:text-slate-300 line-clamp-2">{reason.replace('✅ ', '')}</span>
                </div>
              ))}
            </div>
          )}
          
          {match.risks.length > 0 && (
            <div className="space-y-1.5 pt-2">
              <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">Risks</span>
              {match.risks.map((risk, idx) => (
                <div key={idx} className="flex items-start gap-2 text-sm">
                  <AlertTriangle className="w-4 h-4 text-yellow-500 shrink-0 mt-0.5" />
                  <span className="text-slate-700 dark:text-slate-300 line-clamp-2">{risk.replace('⚠ ', '').replace('❌ ', '')}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </CardContent>

      <CardFooter className="pt-4 border-t flex flex-col sm:flex-row gap-2.5">
        <Button className="w-full min-h-[48px] h-12 text-sm font-semibold" size="sm">
          Create Quote
        </Button>
        {match.labTestId ? (
          <Button
            variant="outline"
            onClick={() => setLabReviewOpen(true)}
            className="w-full min-h-[48px] h-12 text-sm font-semibold text-slate-700 hover:text-slate-900 border-slate-300 flex items-center justify-center gap-1.5"
            size="sm"
          >
            <FlaskConical className="w-4 h-4 text-primary" />
            Audit Lab Test
          </Button>
        ) : (
          <Button variant="outline" className="w-full min-h-[48px] h-12 text-sm font-semibold" size="sm">
            View Details
          </Button>
        )}
      </CardFooter>

      {/* Broker Lab Review Modal */}
      {match.labTestId && (
        <LabReviewDialog
          labTestId={match.labTestId}
          availabilityId={match.availabilityId}
          open={labReviewOpen}
          onOpenChange={setLabReviewOpen}
        />
      )}
    </Card>
  )
}
