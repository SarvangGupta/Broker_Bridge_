'use client'

import { useState, useEffect } from 'react'
import { EnrichedMatchResult, runAiMatchWithDetailsAction } from "@/src/server/actions/ui-match-actions"
import { MatchFilterBar } from "./match-filter-bar"
import { MatchResultCard } from "./match-result-card"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { AlertCircle, Target, Sparkles, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"

export function AiMatchWorkspace({ requirements }: { requirements: any[] }) {
  const [selectedRequirementId, setSelectedRequirementId] = useState<string | null>(null)

  const [matches, setMatches] = useState<EnrichedMatchResult[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [hasRunMatch, setHasRunMatch] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [scoreFilter, setScoreFilter] = useState("All")
  const [searchQuery, setSearchQuery] = useState("")

  const fetchMatches = async () => {
    if (!selectedRequirementId) return

    setIsLoading(true)
    setError(null)
    setHasRunMatch(true)

    try {
      const result = await runAiMatchWithDetailsAction(selectedRequirementId)

      if (result.success && result.data) {
        setMatches(result.data as EnrichedMatchResult[])
      } else {
        setMatches([])
        if (!result.success) setError(result.error || "Failed to fetch matches")
      }
    } catch (err: any) {
      setError(err.message || "An unexpected error occurred.")
      setMatches([])
    } finally {
      setIsLoading(false)
    }
  }

  // Initial fetch on mount if there's a selected requirement
  useEffect(() => {
    if (selectedRequirementId) {
      fetchMatches()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedRequirementId])

  // Filter logic
  const filteredMatches = matches.filter(match => {
    // 1. Score Filter
    if (scoreFilter !== "All" && match.classification !== scoreFilter) {
      return false
    }

    // 2. Search Filter
    if (searchQuery.trim() !== "") {
      const query = searchQuery.toLowerCase()
      if (!match.companyName.toLowerCase().includes(query)) {
        return false
      }
    }

    return true
  })

  if (requirements.length === 0) {
    return (
      <div className="border-2 border-dashed border-gray-200 bg-gray-50/50 rounded-xl p-12 flex flex-col items-center justify-center text-center">
        <Target className="w-12 h-12 text-slate-400 mb-3" />
        <h4 className="font-semibold text-slate-800 text-base mb-1">No Requirements Assigned</h4>
        <p className="text-sm text-slate-500 max-w-md">
          Assign buyer requirements from the Admin Deal Desk or check back soon to run AI matching.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* SEARCH / REQUIREMENT SELECTION HERO BAR */}
      <div className="bg-white p-4 sm:p-5 rounded-2xl border border-[#E2E8F0] shadow-sm flex flex-col md:flex-row gap-4 items-stretch md:items-center justify-between">
        <div className="flex flex-col sm:flex-row gap-3 items-start sm:items-center flex-1">
          <label className="text-sm font-semibold text-slate-700 whitespace-nowrap shrink-0">
            Active Requirement:
          </label>
          <div className="w-full flex-1">
            <Select
              value={selectedRequirementId || ""}
              onValueChange={setSelectedRequirementId}
            >
              <SelectTrigger className="w-full bg-slate-50/50 border-[#E2E8F0] h-11 rounded-xl text-slate-800 font-medium focus-visible:bg-white transition-colors">
                <SelectValue placeholder="Choose a requirement to match...">
                  {(() => {
                    const selectedReq = requirements.find(r => (r.requirementId || r.id) === selectedRequirementId)
                    if (!selectedReq) return null
                    const hierarchy = [selectedReq.industryName, selectedReq.categoryName].filter(Boolean).join(" • ")
                    const name = selectedReq.commodityName || selectedReq.requirement?.commodity?.name || `Requirement ID: ${(selectedReq.requirementId || selectedReq.id).substring(0, 8)}`
                    const qty = selectedReq.requirement?.quantity || selectedReq.quantity || ''
                    return `${hierarchy ? `${hierarchy} | ` : ''}${name} ${qty ? `(${qty})` : ''}`
                  })()}
                </SelectValue>
              </SelectTrigger>
              <SelectContent alignItemWithTrigger={false} className="max-h-[300px]">
                {requirements.map((req) => {
                  const id = req.requirementId || req.id;
                  const hierarchy = [req.industryName, req.categoryName].filter(Boolean).join(" • ");
                  const name = req.commodityName || req.requirement?.commodity?.name || `Requirement ID: ${id.substring(0, 8)}`;
                  const qty = req.requirement?.quantity || req.quantity || '';
                  const fullLabel = `${hierarchy ? `${hierarchy} | ` : ''}${name} ${qty ? `(${qty})` : ''}`;
                  return (
                    <SelectItem key={id} value={id} label={fullLabel}>
                      <div className="flex items-center justify-between w-full gap-4">
                        <div className="flex flex-col text-left">
                          {hierarchy && (
                            <span className="text-[10px] uppercase font-semibold text-slate-400">
                              {hierarchy}
                            </span>
                          )}
                          <span className="font-medium text-slate-800">{name}</span>
                        </div>
                        {qty && <span className="text-xs font-semibold px-2 py-0.5 rounded bg-slate-100 text-slate-600">{qty}</span>}
                      </div>
                    </SelectItem>
                  )
                })}
              </SelectContent>
            </Select>
          </div>
        </div>

        {/* PRIMARY CTA: Find Matches */}
        <Button 
          onClick={fetchMatches} 
          disabled={isLoading || !selectedRequirementId}
          className="bg-[#0D9488] hover:bg-[#0F766E] text-white font-semibold shadow-sm hover:shadow transition-all duration-200 min-h-[44px] md:min-h-[44px] px-6 rounded-xl flex items-center justify-center gap-2 text-sm sm:text-base cursor-pointer shrink-0"
        >
          {isLoading ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" />
              Scanning Pool...
            </>
          ) : (
            <>
              <Sparkles className="h-4 w-4" />
              Find Matches
            </>
          )}
        </Button>
      </div>

      {/* FILTER CONTROLS */}
      {hasRunMatch && matches.length > 0 && (
        <MatchFilterBar
          scoreFilter={scoreFilter}
          setScoreFilter={setScoreFilter}
          searchQuery={searchQuery}
          setSearchQuery={setSearchQuery}
        />
      )}

      {error && (
        <div className="p-4 rounded-xl border border-red-200 bg-red-50 text-red-700 flex items-center gap-2 text-sm font-medium">
          <AlertCircle className="w-5 h-5 shrink-0" />
          <p>{error}</p>
        </div>
      )}

      {/* MATCH RESULTS / LOADING / EMPTY STATES */}
      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1, 2, 3].map((i) => (
            <div key={i} className="p-6 bg-white rounded-2xl border border-slate-200/80 space-y-4">
              <Skeleton className="h-[100px] w-full rounded-xl" />
              <div className="space-y-2">
                <Skeleton className="h-4 w-[220px]" />
                <Skeleton className="h-4 w-[160px]" />
              </div>
            </div>
          ))}
        </div>
      ) : !hasRunMatch ? (
        <div className="border-2 border-dashed border-gray-200 bg-gray-50/50 rounded-xl p-12 flex flex-col items-center justify-center text-center">
          <Target className="w-12 h-12 text-slate-400 mb-3" />
          <h4 className="font-semibold text-slate-800 text-base mb-1">Select a Requirement</h4>
          <p className="text-sm text-slate-500 max-w-sm">
            Pick a buyer requirement above and click &ldquo;Find Matches&rdquo; to analyze the seller inventory pool.
          </p>
        </div>
      ) : matches.length === 0 ? (
        <div className="border-2 border-dashed border-gray-200 bg-gray-50/50 rounded-xl p-12 flex flex-col items-center justify-center text-center">
          <Target className="w-12 h-12 text-slate-400 mb-3" />
          <h4 className="font-semibold text-slate-800 text-base mb-1">No Strong Matches Found</h4>
          <p className="text-sm text-slate-500 max-w-md">
            The AI match engine couldn&apos;t find any seller availabilities in the global or private pool matching this requirement with a confidence score of 60% or higher.
          </p>
        </div>
      ) : filteredMatches.length === 0 ? (
        <div className="border-2 border-dashed border-gray-200 bg-gray-50/50 rounded-xl p-12 flex flex-col items-center justify-center text-center">
          <Target className="w-12 h-12 text-slate-400 mb-3" />
          <h4 className="font-semibold text-slate-800 text-base mb-1">No Filter Results</h4>
          <p className="text-sm text-slate-500 max-w-sm">
            No matches meet the current score tier or company search filters. Try adjusting your criteria.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredMatches.map(match => (
            <MatchResultCard key={match.availabilityId} match={match} />
          ))}
        </div>
      )}
    </div>
  )
}
