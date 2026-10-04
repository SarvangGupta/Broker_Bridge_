'use client'

import React, { useState, useMemo } from 'react'
import Link from 'next/link'
import { 
  Plus, 
  Search, 
  ClipboardList, 
  PackageX 
} from 'lucide-react'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { RequirementCard } from '@/src/components/buyer/requirements/requirement-card'
import { CancelRequirementDialog } from '@/src/components/buyer/requirements/cancel-requirement-dialog'

interface RequirementFeedProps {
  initialItems: any[]
}

const FORTY_EIGHT_HOURS_MS = 48 * 60 * 60 * 1000

function isCancelledWithin48Hours(timestamp?: Date | string): boolean {
  if (!timestamp) return true
  const elapsed = Date.now() - new Date(timestamp).getTime()
  return elapsed < FORTY_EIGHT_HOURS_MS
}

function EmptyState({ title, description }: { title: string; description: string }) {
  return (
    <div className="bg-white rounded-2xl border border-slate-200 p-10 text-center flex flex-col items-center justify-center space-y-4 my-6">
      <div className="w-16 h-16 rounded-full bg-sky-50 text-[#0284C7] flex items-center justify-center border border-sky-100">
        <PackageX className="w-8 h-8" />
      </div>

      <div className="space-y-1 max-w-sm">
        <h3 className="text-base font-bold text-slate-900">{title}</h3>
        <p className="text-xs text-slate-500 leading-relaxed">{description}</p>
      </div>

      <Link
        href="/buyer/requirements/new"
        className="inline-flex items-center justify-center min-h-[48px] px-6 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs font-bold shadow-sm transition-all"
      >
        <Plus className="w-4 h-4 mr-2 stroke-[2.5]" />
        Post New Requirement
      </Link>
    </div>
  )
}

export function BuyerRequirementsFeed({ initialItems }: RequirementFeedProps) {
  const [items, setItems] = useState<any[]>(initialItems)
  const [activeTab, setActiveTab] = useState<'active' | 'drafts' | 'history'>('active')
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedStatus, setSelectedStatus] = useState('ALL')

  // Cancel dialog state
  const [cancelDialogOpen, setCancelDialogOpen] = useState(false)
  const [selectedCancelId, setSelectedCancelId] = useState<string>('')
  const [selectedCancelTitle, setSelectedCancelTitle] = useState<string>('')

  // Categorize all items into Active, Drafts, History
  const { activeRequirements, draftRequirements, historyRequirements } = useMemo(() => {
    const active: any[] = []
    const draft: any[] = []
    const history: any[] = []

    items.forEach((item) => {
      const status = (item.requirement?.status || '').toLowerCase()
      const timestamp = (item.requirement as any)?.updatedAt || (item.requirement as any)?.updated_at || item.requirement?.createdAt

      if (status === 'draft') {
        draft.push(item)
      } else if (status === 'cancelled') {
        // 48-hour auto-hide rule: Only show in history if within 48 hours of cancellation/creation
        if (isCancelledWithin48Hours(timestamp)) {
          history.push(item)
        }
      } else if (status === 'closed') {
        history.push(item)
      } else {
        // Active: Open, Sourcing, Negotiating, Booked, Accepted, Fulfilled, etc.
        active.push(item)
      }
    })

    return {
      activeRequirements: active,
      draftRequirements: draft,
      historyRequirements: history,
    }
  }, [items])

  // Get raw items for current active tab
  const currentTabItems = useMemo(() => {
    if (activeTab === 'active') return activeRequirements
    if (activeTab === 'drafts') return draftRequirements
    return historyRequirements
  }, [activeTab, activeRequirements, draftRequirements, historyRequirements])

  // Filter current tab items by Search and Status Filter Dropdown
  const filteredItems = useMemo(() => {
    const q = searchTerm.toLowerCase().trim()
    return currentTabItems.filter((item) => {
      const req = item.requirement
      const commodityName = (item.commodityName || '').toLowerCase()
      const gradeName = (item.gradeName || '').toLowerCase()
      const reqId = (req.id || '').toLowerCase()

      const matchesSearch = !q || 
        commodityName.includes(q) || 
        gradeName.includes(q) || 
        reqId.includes(q)

      const statusNormalized = (req.status || '').toLowerCase()
      let matchesStatus = true

      if (selectedStatus !== 'ALL') {
        if (selectedStatus === 'open') {
          matchesStatus = statusNormalized === 'open' || statusNormalized === 'sourcing'
        } else if (selectedStatus === 'booked') {
          matchesStatus = statusNormalized === 'booked' || statusNormalized === 'accepted' || statusNormalized === 'fulfilled'
        } else {
          matchesStatus = statusNormalized === selectedStatus.toLowerCase()
        }
      }

      return matchesSearch && matchesStatus
    })
  }, [currentTabItems, searchTerm, selectedStatus])

  // Status Filter Options for Dropdown based on active tab
  const STATUS_FILTER_OPTIONS = useMemo(() => {
    if (activeTab === 'active') {
      return [
        { value: 'ALL', label: 'All Active Statuses' },
        { value: 'open', label: 'Finding supply (Open)' },
        { value: 'negotiating', label: 'Negotiation in progress' },
        { value: 'booked', label: 'Order confirmed' },
      ]
    } else if (activeTab === 'drafts') {
      return [
        { value: 'ALL', label: 'All Drafts' },
        { value: 'draft', label: 'Drafts' },
      ]
    } else {
      return [
        { value: 'ALL', label: 'All History' },
        { value: 'cancelled', label: 'Cancelled' },
        { value: 'closed', label: 'Closed' },
      ]
    }
  }, [activeTab])

  const handleOpenCancelDialog = (id: string, title: string) => {
    setSelectedCancelId(id)
    setSelectedCancelTitle(title)
    setCancelDialogOpen(true)
  }

  const handleCancelSuccess = () => {
    setItems((prev) => 
      prev.map((item) => 
        item.requirement.id === selectedCancelId
          ? { 
              ...item, 
              requirement: { 
                ...item.requirement, 
                status: 'Cancelled',
                updatedAt: new Date().toISOString()
              } 
            }
          : item
      )
    )
  }

  return (
    <div className="w-full max-w-full overflow-x-hidden min-h-screen bg-slate-50/50 pb-20">
      {/* Header Bar */}
      <div className="bg-white border-b border-slate-200 px-4 py-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 sticky top-0 z-30 shadow-xs">
        <div className="flex items-center gap-3">
          <div className="p-2.5 rounded-xl bg-sky-50 text-[#0284C7] border border-sky-100">
            <ClipboardList className="w-6 h-6" />
          </div>
          <div>
            <h1 className="text-lg font-extrabold text-slate-900 tracking-tight">
              My Requirements Inbox
            </h1>
            <p className="text-xs text-slate-500">
              Track active demand requirements, draft specs, and seller matches
            </p>
          </div>
        </div>

        <Link
          href="/buyer/requirements/new"
          className="inline-flex items-center justify-center min-h-[48px] px-5 rounded-xl bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs font-bold shadow-sm transition-all w-full sm:w-auto"
        >
          <Plus className="w-4 h-4 mr-1.5 stroke-[2.5]" />
          Post New Requirement
        </Link>
      </div>

      <div className="max-w-7xl mx-auto px-4 py-5 space-y-5">
        {/* Navigation & Control Panel */}
        <div className="bg-white p-3 sm:p-4 rounded-2xl border border-slate-200 shadow-xs flex flex-col space-y-4">
          {/* Top Row: Clean Navigation Tab Pills */}
          <div className="flex items-center gap-2 border-b border-slate-100 pb-3 overflow-x-auto">
            <button
              type="button"
              onClick={() => { setActiveTab('active'); setSelectedStatus('ALL'); }}
              className={`min-h-[40px] px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
                activeTab === 'active'
                  ? 'bg-[#0284C7] text-white shadow-xs'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              Active Requirements
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-extrabold ${
                activeTab === 'active' ? 'bg-white/20 text-white' : 'bg-slate-200 text-slate-700'
              }`}>
                {activeRequirements.length}
              </span>
            </button>

            <button
              type="button"
              onClick={() => { setActiveTab('drafts'); setSelectedStatus('ALL'); }}
              className={`min-h-[40px] px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
                activeTab === 'drafts'
                  ? 'bg-[#0284C7] text-white shadow-xs'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              Draft Specs
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-extrabold ${
                activeTab === 'drafts' ? 'bg-white/20 text-white' : 'bg-slate-200 text-slate-700'
              }`}>
                {draftRequirements.length}
              </span>
            </button>

            <button
              type="button"
              onClick={() => { setActiveTab('history'); setSelectedStatus('ALL'); }}
              className={`min-h-[40px] px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 whitespace-nowrap cursor-pointer ${
                activeTab === 'history'
                  ? 'bg-[#0284C7] text-white shadow-xs'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              History & Cancelled
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-extrabold ${
                activeTab === 'history' ? 'bg-white/20 text-white' : 'bg-slate-200 text-slate-700'
              }`}>
                {historyRequirements.length}
              </span>
            </button>
          </div>

          {/* Bottom Row: Search Bar & Restored Status Dropdown Filter */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {/* Search Input */}
            <div className="sm:col-span-2 relative">
              <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-4" />
              <Input
                placeholder="Search by Requirement ID, Commodity, or Grade..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10 min-h-[48px] bg-slate-50/50 text-sm border-slate-300 focus:bg-white"
              />
            </div>

            {/* Restored Status Dropdown Filter */}
            <Select value={selectedStatus} onValueChange={(val: string | null) => setSelectedStatus(val || 'ALL')}>
              <SelectTrigger className="min-h-[48px] bg-slate-50/50 border-slate-300 text-xs font-semibold">
                <SelectValue placeholder="Filter by Status" />
              </SelectTrigger>
              <SelectContent>
                {STATUS_FILTER_OPTIONS.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value} className="text-xs font-medium min-h-[44px]">
                    {opt.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>

        {/* Requirements Feed Grid */}
        {filteredItems.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {filteredItems.map((item) => (
              <RequirementCard
                key={item.requirement.id}
                item={item}
                onCancelRequest={handleOpenCancelDialog}
              />
            ))}
          </div>
        ) : (
          <EmptyState
            title={
              searchTerm || selectedStatus !== 'ALL'
                ? "No matching requirements found"
                : activeTab === 'active'
                ? "No active requirements"
                : activeTab === 'drafts'
                ? "No saved drafts"
                : "No requirement history"
            }
            description={
              searchTerm || selectedStatus !== 'ALL'
                ? "Try adjusting your search terms or status filter."
                : activeTab === 'active'
                ? "Post your commodity procurement requirements to receive verified match proposals from Deal Desk."
                : activeTab === 'drafts'
                ? "Draft specs saved prior to publication will appear here for easy editing."
                : "Cancelled requirements are automatically hidden after 48 hours to keep your workspace clean."
            }
          />
        )}
      </div>

      {/* Cancel Confirmation Dialog */}
      <CancelRequirementDialog
        open={cancelDialogOpen}
        onOpenChange={setCancelDialogOpen}
        requirementId={selectedCancelId}
        requirementTitle={selectedCancelTitle}
        onSuccess={handleCancelSuccess}
      />
    </div>
  )
}
