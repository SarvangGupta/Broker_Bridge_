import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Search, Filter } from "lucide-react"

type MatchFilterBarProps = {
  scoreFilter: string;
  setScoreFilter: (val: any) => void;
  searchQuery: string;
  setSearchQuery: (val: string) => void;
}

export function MatchFilterBar({
  scoreFilter,
  setScoreFilter,
  searchQuery,
  setSearchQuery
}: MatchFilterBarProps) {
  return (
    <div className="flex flex-col sm:flex-row gap-3 bg-white p-3.5 sm:p-4 rounded-xl border border-[#E2E8F0] shadow-sm items-center">
      <div className="relative flex-1 w-full">
        <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
        <Input 
          placeholder="Filter matches by counterparty or company name..." 
          className="pl-10 bg-slate-50/50 border-[#E2E8F0] focus-visible:bg-white text-slate-900 placeholder:text-slate-400 h-10 rounded-lg"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </div>
      
      <div className="flex items-center gap-2 w-full sm:w-[240px]">
        <Filter className="h-4 w-4 text-slate-400 shrink-0 hidden sm:block" />
        <Select value={scoreFilter} onValueChange={setScoreFilter}>
          <SelectTrigger className="w-full bg-slate-50/50 border-[#E2E8F0] h-10 rounded-lg text-slate-700 font-medium">
            <SelectValue placeholder="Score Tier" />
          </SelectTrigger>
          <SelectContent align="end">
            <SelectItem value="All">All Score Tiers</SelectItem>
            <SelectItem value="Strong Match">Strong Match (90%+)</SelectItem>
            <SelectItem value="Good Match">Good Match (75-89%)</SelectItem>
            <SelectItem value="Partial">Partial (60-74%)</SelectItem>
          </SelectContent>
        </Select>
      </div>
    </div>
  )
}
