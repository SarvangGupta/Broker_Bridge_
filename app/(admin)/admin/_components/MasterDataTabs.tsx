'use client'

import { useState, useEffect } from 'react'
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { toast } from "sonner"
import { 
  Loader2, 
  Trash2, 
  Edit, 
  LogOut, 
  Package, 
  Ruler, 
  Map, 
  ShieldAlert, 
  ListChecks, 
  Scale, 
  MapPin, 
  Headphones, 
  Coins, 
  Handshake, 
  Users, 
  Building2, 
  Layers 
} from "lucide-react"
import { signOutAction } from "@/src/server/actions/auth-actions"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { DropdownMenu, DropdownMenuContent, DropdownMenuGroup, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { AdminProfileDialog } from "@/src/components/dialogs/admin-profile-dialog"
import { NotificationBell } from "@/src/components/layout/notification-bell"
import { getAdminKpisAction, AdminKpis } from "@/src/server/actions/analytics-actions"
import { KpiCard, KpiGrid } from "@/src/components/dashboard/kpi-cards"
import { formatIndianCurrency } from "@/lib/utils"

import {
  getIndustriesAction,
  addIndustryAction,
  updateIndustryAction,
  deleteIndustryAction,
  getCategoriesAction,
  addCategoryAction,
  updateCategoryAction,
  deleteCategoryAction,
  addCommodityAction,
  updateCommodityAction,
  getCommoditiesAction,
  softDeleteCommodityAction,
  addStateAction,
  getStatesAction,
  addDistrictAction,
  getDistrictsAction,
  getUnitsAction,
  addUnitAction,
  updateUnitAction,
  deleteUnitAction,
  getQualityParametersAction,
  deleteQualityParameterAction
} from "@/src/server/actions/master-data-actions"
import { CompanyApprovalQueue } from "./company-approval-queue"
import { BuyerGstVerificationQueue } from "./buyer-gst-verification-queue"
import { DealDeskQueue } from "./deal-desk-queue"
import { AdminDisputeQueue } from "./admin-dispute-queue"
import { AdminHelpDeskQueue } from "./admin-help-desk-queue"
import { AdminBrokersVault } from "./admin-brokers-vault"
import { QualityParameterDialog } from "./quality-parameter-dialog"
import { Badge } from "@/components/ui/badge"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"

export function MasterDataTabs() {
  const [activeTab, setActiveTab] = useState("commodities")
  const [isProfileOpen, setIsProfileOpen] = useState(false)
  const [industries, setIndustries] = useState<any[]>([])
  const [categories, setCategories] = useState<any[]>([])
  const [commodities, setCommodities] = useState<any[]>([])
  const [states, setStates] = useState<any[]>([])
  const [districts, setDistricts] = useState<any[]>([])
  const [units, setUnits] = useState<any[]>([])
  const [qualityParameters, setQualityParameters] = useState<any[]>([])
  const [adminKpis, setAdminKpis] = useState<AdminKpis | null>(null)
  
  const [loading, setLoading] = useState(false)
  
  // Modals state
  const [addIndustryOpen, setAddIndustryOpen] = useState(false)
  const [addCategoryOpen, setAddCategoryOpen] = useState(false)
  const [addCommodityOpen, setAddCommodityOpen] = useState(false)
  const [addStateOpen, setAddStateOpen] = useState(false)
  const [addDistrictOpen, setAddDistrictOpen] = useState(false)
  const [addUnitOpen, setAddUnitOpen] = useState(false)
  const [qualityParamDialogOpen, setQualityParamDialogOpen] = useState(false)

  // Edit states
  const [editIndustryId, setEditIndustryId] = useState<string | null>(null)
  const [editCategoryId, setEditCategoryId] = useState<string | null>(null)
  const [editCommodityId, setEditCommodityId] = useState<string | null>(null)
  const [editUnitId, setEditUnitId] = useState<string | null>(null)
  const [editingQualityParam, setEditingQualityParam] = useState<any | null>(null)

  // Forms state
  const [industryName, setIndustryName] = useState("")
  const [categoryName, setCategoryName] = useState("")
  const [categoryIndustryId, setCategoryIndustryId] = useState("")
  const [commodityName, setCommodityName] = useState("")
  const [commodityCategoryId, setCommodityCategoryId] = useState("")
  const [stateName, setStateName] = useState("")
  const [stateCode, setStateCode] = useState("")
  const [districtName, setDistrictName] = useState("")
  const [districtStateId, setDistrictStateId] = useState("")
  const [unitName, setUnitName] = useState("")
  const [unitSymbol, setUnitSymbol] = useState("")

  const loadData = async () => {
    setLoading(true)
    const [indRes, catRes, commRes, stateRes, distRes, unitsRes, qualityRes, kpisRes] = await Promise.all([
      getIndustriesAction(),
      getCategoriesAction(),
      getCommoditiesAction(),
      getStatesAction(),
      getDistrictsAction(),
      getUnitsAction(),
      getQualityParametersAction(),
      getAdminKpisAction(),
    ])
    
    if (indRes.success) setIndustries(indRes.data || [])
    if (catRes.success) setCategories(catRes.data || [])
    if (commRes.success) setCommodities(commRes.data || [])
    if (stateRes.success) setStates(stateRes.data || [])
    if (distRes.success) setDistricts(distRes.data || [])
    if (unitsRes.success) setUnits(unitsRes.data || [])
    if (qualityRes.success) setQualityParameters(qualityRes.data || [])
    if (kpisRes.success && kpisRes.data) setAdminKpis(kpisRes.data)
    
    setLoading(false)
  }

  useEffect(() => {
    loadData()
  }, [])

  // Industry handlers
  const handleIndustryModalChange = (open: boolean) => {
    setAddIndustryOpen(open)
    if (!open) { setEditIndustryId(null); setIndustryName(""); }
  }

  const openEditIndustry = (ind: any) => {
    setEditIndustryId(ind.id)
    setIndustryName(ind.name)
    setAddIndustryOpen(true)
  }

  const handleAddIndustry = async () => {
    if (!industryName.trim()) return
    const res = editIndustryId ? await updateIndustryAction(editIndustryId, industryName.trim()) : await addIndustryAction(industryName.trim())
    if (res.success) {
      toast.success(editIndustryId ? "Industry updated" : "Industry added")
      setAddIndustryOpen(false)
      setIndustryName("")
      setEditIndustryId(null)
      loadData()
    } else {
      toast.error(res.error || "Failed to save industry")
    }
  }

  const handleDeleteIndustry = async (id: string) => {
    const res = await deleteIndustryAction(id)
    if (res.success) {
      toast.success("Industry deleted successfully")
      loadData()
    } else {
      toast.error(res.error || "Failed to delete industry")
    }
  }

  // Category handlers
  const handleCategoryModalChange = (open: boolean) => {
    setAddCategoryOpen(open)
    if (!open) { setEditCategoryId(null); setCategoryName(""); setCategoryIndustryId(""); }
  }

  const openEditCategory = (cat: any) => {
    setEditCategoryId(cat.id)
    setCategoryName(cat.name)
    setCategoryIndustryId(cat.industryId || "")
    setAddCategoryOpen(true)
  }

  const handleAddCategory = async () => {
    if (!categoryName.trim()) return
    const res = editCategoryId 
      ? await updateCategoryAction(editCategoryId, categoryName.trim(), categoryIndustryId || undefined) 
      : await addCategoryAction(categoryName.trim(), categoryIndustryId || undefined)
    if (res.success) {
      toast.success(editCategoryId ? "Category updated" : "Category added")
      setAddCategoryOpen(false)
      setCategoryName("")
      setCategoryIndustryId("")
      setEditCategoryId(null)
      loadData()
    } else {
      toast.error(res.error || "Failed to save category")
    }
  }

  const handleDeleteCategory = async (id: string) => {
    const res = await deleteCategoryAction(id)
    if (res.success) {
      toast.success("Category deleted successfully")
      loadData()
    } else {
      toast.error(res.error || "Failed to delete category")
    }
  }

  // Commodity handlers
  const handleCommodityModalChange = (open: boolean) => {
    setAddCommodityOpen(open)
    if (!open) { setEditCommodityId(null); setCommodityName(""); setCommodityCategoryId(""); }
  }

  const openEditCommodity = (c: any) => {
    setEditCommodityId(c.id)
    setCommodityName(c.name)
    setCommodityCategoryId(c.categoryId || "")
    setAddCommodityOpen(true)
  }

  const handleAddCommodity = async () => {
    if (!commodityName.trim()) return
    const res = editCommodityId 
      ? await updateCommodityAction(editCommodityId, commodityName.trim(), commodityCategoryId || undefined) 
      : await addCommodityAction(commodityName.trim(), commodityCategoryId || undefined)
    if (res.success) {
      toast.success(editCommodityId ? "Commodity updated" : "Commodity added")
      setAddCommodityOpen(false)
      setCommodityName("")
      setCommodityCategoryId("")
      setEditCommodityId(null)
      loadData()
    } else {
      toast.error(res.error || "Failed to save commodity")
    }
  }

  const handleDeleteCommodity = async (id: string) => {
    const res = await softDeleteCommodityAction(id)
    if (res.success) {
      toast.success("Commodity deleted successfully")
      loadData()
    } else {
      toast.error(res.error || "Failed to delete commodity")
    }
  }

  // State handlers
  const handleAddState = async () => {
    if (!stateName.trim()) return
    const res = await addStateAction(stateName.trim(), stateCode.trim() || undefined)
    if (res.success) {
      toast.success("State added successfully")
      setAddStateOpen(false)
      setStateName("")
      setStateCode("")
      loadData()
    } else {
      toast.error(res.error || "Failed to add state")
    }
  }

  // District handlers
  const handleAddDistrict = async () => {
    if (!districtName.trim() || !districtStateId) return
    const res = await addDistrictAction(districtName.trim(), districtStateId)
    if (res.success) {
      toast.success("District added successfully")
      setAddDistrictOpen(false)
      setDistrictName("")
      setDistrictStateId("")
      loadData()
    } else {
      toast.error(res.error || "Failed to add district")
    }
  }

  // Unit handlers
  const handleUnitModalChange = (open: boolean) => {
    setAddUnitOpen(open)
    if (!open) { setEditUnitId(null); setUnitName(""); setUnitSymbol(""); }
  }

  const openEditUnit = (u: any) => {
    setEditUnitId(u.id)
    setUnitName(u.name)
    setUnitSymbol(u.symbol || "")
    setAddUnitOpen(true)
  }

  const handleAddUnit = async () => {
    if (!unitName.trim()) return
    const res = editUnitId ? await updateUnitAction(editUnitId, unitName.trim(), unitSymbol.trim() || undefined) : await addUnitAction(unitName.trim(), unitSymbol.trim() || undefined)
    if (res.success) {
      toast.success(editUnitId ? "Unit updated" : "Unit added")
      setAddUnitOpen(false)
      setUnitName("")
      setUnitSymbol("")
      setEditUnitId(null)
      loadData()
    } else {
      toast.error(res.error || "Failed to save unit")
    }
  }

  const handleDeleteUnit = async (id: string) => {
    const res = await deleteUnitAction(id)
    if (res.success) {
      toast.success("Unit deleted successfully")
      loadData()
    } else {
      toast.error(res.error || "Failed to delete unit")
    }
  }

  // Quality Parameter handlers
  const handleOpenAddQualityParam = () => {
    setEditingQualityParam(null)
    setQualityParamDialogOpen(true)
  }

  const handleOpenEditQualityParam = (param: any) => {
    setEditingQualityParam(param)
    setQualityParamDialogOpen(true)
  }

  const handleDeleteQualityParam = async (id: string) => {
    const res = await deleteQualityParameterAction(id)
    if (res.success) {
      toast.success("Quality parameter deleted successfully")
      loadData()
    } else {
      toast.error(res.error || "Failed to delete quality parameter")
    }
  }

  return (
    <Tabs defaultValue="approvals" orientation="vertical" className="flex flex-row h-screen w-full bg-[#F8FAFC] overflow-hidden">
      {/* Sidebar Navigation */}
      <aside className="w-64 flex-shrink-0 bg-white border-r border-slate-200 flex flex-col relative z-10 shadow-sm overflow-y-auto">
        <div className="h-16 flex items-center px-6 border-b border-slate-200 flex-shrink-0">
          <div className="w-8 h-8 rounded-lg bg-slate-900 flex items-center justify-center shadow-sm mr-3">
            <span className="text-white font-bold text-sm leading-none tracking-tighter">BB</span>
          </div>
          <span className="text-lg font-bold tracking-tight text-slate-900">Admin Mode</span>
        </div>

        <TabsList className="flex flex-col flex-1 bg-transparent p-4 justify-start items-stretch space-y-1 overflow-y-auto w-full h-auto">
          
          <div className="text-xs font-bold tracking-wider text-slate-400 mb-2 mt-2 px-3">OPERATIONS</div>
          <TabsTrigger value="approvals" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <ListChecks className="w-4 h-4" />
            Approvals
          </TabsTrigger>
          <TabsTrigger value="gst-verifications" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <ShieldAlert className="w-4 h-4 text-amber-600" />
            Buyer GST Verifications
          </TabsTrigger>
          <TabsTrigger value="brokers" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <Users className="w-4 h-4 text-emerald-600" />
            Brokers Vault
          </TabsTrigger>
          <TabsTrigger value="dealdesk" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <Scale className="w-4 h-4" />
            Deal Desk
          </TabsTrigger>
          <TabsTrigger value="disputes" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <ShieldAlert className="w-4 h-4" />
            Dispute Center
          </TabsTrigger>
          <TabsTrigger value="helpdesk" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <Headphones className="w-4 h-4" />
            Help Desk
          </TabsTrigger>

          <div className="text-xs font-bold tracking-wider text-slate-400 mb-2 mt-8 px-3">MASTER DATA</div>
          <TabsTrigger value="industries" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <Building2 className="w-4 h-4" />
            Industries
          </TabsTrigger>
          <TabsTrigger value="categories" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <Layers className="w-4 h-4" />
            Categories
          </TabsTrigger>
          <TabsTrigger value="commodities" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <Package className="w-4 h-4" />
            Commodities
          </TabsTrigger>
          <TabsTrigger value="grades" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <ListChecks className="w-4 h-4" />
            Quality Parameters
          </TabsTrigger>
          <TabsTrigger value="units" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <Ruler className="w-4 h-4" />
            Units
          </TabsTrigger>
          <TabsTrigger value="states" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <Map className="w-4 h-4" />
            States
          </TabsTrigger>
          <TabsTrigger value="districts" className="justify-start px-3 py-2 text-sm text-slate-600 data-[state=active]:bg-[#F1F5F9] data-[state=active]:text-[#334155] data-[state=active]:font-semibold rounded-md transition-colors w-full border-none shadow-none text-left flex items-center gap-2">
            <MapPin className="w-4 h-4" />
            Districts
          </TabsTrigger>
        </TabsList>
      </aside>

      {/* Main Workspace Area */}
      <div className="flex flex-col flex-1 overflow-hidden bg-[#F8FAFC]">
        {/* Workspace Header */}
        <header className="flex h-16 flex-shrink-0 items-center justify-between border-b border-slate-200 bg-white px-6 z-10 shadow-sm">
          <h2 className="text-sm font-semibold text-slate-500 tracking-wide uppercase">Tier 0 / System Console</h2>
          <div className="flex items-center gap-3">
            <NotificationBell />
            <DropdownMenu>
              <DropdownMenuTrigger render={<Button variant="ghost" className="relative h-10 w-10 rounded-full border border-slate-200 hover:bg-slate-100 p-0" />}>
                <Avatar className="h-9 w-9">
                  <AvatarFallback className="bg-slate-900 text-white font-semibold">A</AvatarFallback>
                </Avatar>
              </DropdownMenuTrigger>
            <DropdownMenuContent className="w-56" align="end">
              <DropdownMenuGroup>
                <DropdownMenuLabel className="font-normal">
                  <div className="flex flex-col space-y-1">
                    <p className="text-sm font-medium leading-none text-[#334155]">Administrator</p>
                    <p className="text-xs leading-none text-slate-500">Tier 0 Access</p>
                  </div>
                </DropdownMenuLabel>
              </DropdownMenuGroup>
              <DropdownMenuSeparator />
              <DropdownMenuItem 
                className="text-slate-600 font-medium cursor-pointer" 
                onClick={() => setIsProfileOpen(true)}
                onSelect={(e: any) => {
                  e.preventDefault()
                  setIsProfileOpen(true)
                }}
              >
                Profile Settings
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem className="p-0">
                <form action={signOutAction} className="w-full">
                  <button type="submit" className="flex w-full items-center text-red-600 hover:text-red-700 hover:bg-red-50 rounded-sm px-2 py-1.5 text-sm font-medium cursor-pointer transition-colors">
                    <LogOut className="mr-2 h-4 w-4" />
                    <span>Sign Out</span>
                  </button>
                </form>
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
          </div>
        </header>

        {/* Scrollable Content */}
        <main className="flex-1 overflow-auto p-6 md:p-8">
          <div className="max-w-6xl mx-auto space-y-6">

            {/* Admin KPI Overview Grid */}
            <KpiGrid className="grid-cols-1 sm:grid-cols-3 lg:grid-cols-3 xl:grid-cols-3">
              <KpiCard 
                title="Platform GMV" 
                value={formatIndianCurrency(adminKpis?.totalGmv ?? 0)}
                icon={Coins}
                badgeColor="indigo"
                description="Total non-cancelled deal volume"
              />
              <KpiCard 
                title="Active Deals" 
                value={adminKpis?.activeDealsCount ?? 0}
                icon={Handshake}
                badgeColor="emerald"
                description="Live transaction pipelines"
              />
              <KpiCard 
                title="Total Users" 
                value={adminKpis?.totalUsersCount ?? 0}
                icon={Users}
                badgeColor="blue"
                description="Registered platform members"
              />
            </KpiGrid>

            {/* INDUSTRIES TAB */}
            <TabsContent value="industries" className="m-0 outline-none">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Industries</h2>
                  <p className="text-sm text-slate-500 mt-1">Manage top-level business sectors and industries.</p>
                </div>
                <Dialog open={addIndustryOpen} onOpenChange={handleIndustryModalChange}>
                  <DialogTrigger render={<Button className="bg-[#334155] hover:bg-[#1e293b] text-white shadow-sm" />}>
                    Add Industry
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>{editIndustryId ? "Edit Industry" : "Add New Industry"}</DialogTitle>
                      <DialogDescription>Enter the name of the industry sector (e.g., Agriculture, Textiles, Chemicals).</DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="industryName" className="text-right">Name</Label>
                        <Input 
                          id="industryName" 
                          value={industryName} 
                          onChange={(e) => setIndustryName(e.target.value)} 
                          placeholder="e.g. Agriculture" 
                          className="col-span-3" 
                        />
                      </div>
                    </div>
                    <DialogFooter>
                      <Button onClick={handleAddIndustry}>Save</Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </div>
              
              <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                {loading ? (
                  <div className="flex justify-center p-12"><Loader2 className="animate-spin w-8 h-8 text-[#475569]" /></div>
                ) : (
                  <Table>
                    <TableHeader className="bg-slate-50 border-b border-slate-200">
                      <TableRow>
                        <TableHead className="text-slate-600 font-semibold">ID</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Industry Name</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Status</TableHead>
                        <TableHead className="text-right text-slate-600 font-semibold">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {industries.map((ind) => (
                        <TableRow key={ind.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                          <TableCell className="font-mono text-xs text-slate-500">{ind.id.substring(0, 8)}...</TableCell>
                          <TableCell className="font-medium text-[#334155]">{ind.name}</TableCell>
                          <TableCell>
                            <span className={`px-2.5 py-1 rounded-md text-[11px] font-bold uppercase tracking-wider ${ind.isActive ? 'bg-[#ECFDF5] text-[#047857] border border-[#A7F3D0]' : 'bg-red-50 text-red-700 border border-red-200'}`}>
                              {ind.isActive ? 'Active' : 'Inactive'}
                            </span>
                          </TableCell>
                          <TableCell className="text-right">
                            {ind.isActive && (
                              <div className="flex justify-end gap-2">
                                <Button variant="ghost" size="icon" onClick={() => openEditIndustry(ind)} className="text-slate-400 hover:text-blue-600">
                                  <Edit className="w-4 h-4" />
                                </Button>
                                <Button variant="ghost" size="icon" onClick={() => handleDeleteIndustry(ind.id)} className="text-slate-400 hover:text-red-600">
                                  <Trash2 className="w-4 h-4" />
                                </Button>
                              </div>
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                      {industries.length === 0 && (
                        <TableRow><TableCell colSpan={4} className="text-center text-slate-500 py-12">No industries found.</TableCell></TableRow>
                      )}
                    </TableBody>
                  </Table>
                )}
              </div>
            </TabsContent>

            {/* CATEGORIES TAB */}
            <TabsContent value="categories" className="m-0 outline-none">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Categories</h2>
                  <p className="text-sm text-slate-500 mt-1">Manage categories nested under industry sectors.</p>
                </div>
                <Dialog open={addCategoryOpen} onOpenChange={handleCategoryModalChange}>
                  <DialogTrigger render={<Button className="bg-[#334155] hover:bg-[#1e293b] text-white shadow-sm" />}>
                    Add Category
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>{editCategoryId ? "Edit Category" : "Add New Category"}</DialogTitle>
                      <DialogDescription>Link a category to a parent industry sector.</DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="categoryIndustryId" className="text-right">Industry</Label>
                        <div className="col-span-3">
                          <Select onValueChange={(val) => setCategoryIndustryId(val || "")} value={categoryIndustryId}>
                            <SelectTrigger>
                              <SelectValue placeholder="Select parent industry">
                                {categoryIndustryId ? industries.find(i => i.id === categoryIndustryId)?.name : null}
                              </SelectValue>
                            </SelectTrigger>
                            <SelectContent>
                              {industries.map((i) => (
                                <SelectItem key={i.id} value={i.id}>{i.name}</SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                      </div>
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="categoryName" className="text-right">Name</Label>
                        <Input 
                          id="categoryName" 
                          value={categoryName} 
                          onChange={(e) => setCategoryName(e.target.value)} 
                          placeholder="e.g. Grains & Cereals, Spices, Cotton"
                          className="col-span-3" 
                        />
                      </div>
                    </div>
                    <DialogFooter>
                      <Button onClick={handleAddCategory}>Save</Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </div>
              
              <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                {loading ? (
                  <div className="flex justify-center p-12"><Loader2 className="animate-spin w-8 h-8 text-[#475569]" /></div>
                ) : (
                  <Table>
                    <TableHeader className="bg-slate-50 border-b border-slate-200">
                      <TableRow>
                        <TableHead className="text-slate-600 font-semibold">ID</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Category Name</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Parent Industry</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Status</TableHead>
                        <TableHead className="text-right text-slate-600 font-semibold">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {categories.map((cat) => (
                        <TableRow key={cat.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                          <TableCell className="font-mono text-xs text-slate-500">{cat.id.substring(0, 8)}...</TableCell>
                          <TableCell className="font-medium text-[#334155]">{cat.name}</TableCell>
                          <TableCell className="font-medium text-slate-600">{cat.industryName || industries.find(i => i.id === cat.industryId)?.name || "-"}</TableCell>
                          <TableCell>
                            <span className={`px-2.5 py-1 rounded-md text-[11px] font-bold uppercase tracking-wider ${cat.isActive ? 'bg-[#ECFDF5] text-[#047857] border border-[#A7F3D0]' : 'bg-red-50 text-red-700 border border-red-200'}`}>
                              {cat.isActive ? 'Active' : 'Inactive'}
                            </span>
                          </TableCell>
                          <TableCell className="text-right">
                            {cat.isActive && (
                              <div className="flex justify-end gap-2">
                                <Button variant="ghost" size="icon" onClick={() => openEditCategory(cat)} className="text-slate-400 hover:text-blue-600">
                                  <Edit className="w-4 h-4" />
                                </Button>
                                <Button variant="ghost" size="icon" onClick={() => handleDeleteCategory(cat.id)} className="text-slate-400 hover:text-red-600">
                                  <Trash2 className="w-4 h-4" />
                                </Button>
                              </div>
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                      {categories.length === 0 && (
                        <TableRow><TableCell colSpan={5} className="text-center text-slate-500 py-12">No categories found.</TableCell></TableRow>
                      )}
                    </TableBody>
                  </Table>
                )}
              </div>
            </TabsContent>

            {/* COMMODITIES TAB */}
            <TabsContent value="commodities" className="m-0 outline-none">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Commodities</h2>
                  <p className="text-sm text-slate-500 mt-1">Manage active commodities linked to categories.</p>
                </div>
                <Dialog open={addCommodityOpen} onOpenChange={handleCommodityModalChange}>
                  <DialogTrigger render={<Button className="bg-[#334155] hover:bg-[#1e293b] text-white shadow-sm" />}>
                    Add Commodity
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>{editCommodityId ? "Edit Commodity" : "Add New Commodity"}</DialogTitle>
                      <DialogDescription>Enter the commodity details and select a parent category.</DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="commodityCategory" className="text-right">Category</Label>
                        <div className="col-span-3">
                          <Select onValueChange={(val) => setCommodityCategoryId(val || "")} value={commodityCategoryId}>
                            <SelectTrigger>
                              <SelectValue placeholder="Select parent category">
                                {commodityCategoryId ? categories.find(c => c.id === commodityCategoryId)?.name : null}
                              </SelectValue>
                            </SelectTrigger>
                            <SelectContent>
                              {categories.map((c) => (
                                <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </div>
                      </div>
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="name" className="text-right">Name</Label>
                        <Input id="name" value={commodityName} onChange={(e) => setCommodityName(e.target.value)} placeholder="e.g. Wheat, Jeera, Raw Cotton" className="col-span-3" />
                      </div>
                    </div>
                    <DialogFooter>
                      <Button onClick={handleAddCommodity}>Save</Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </div>
              
              <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                {loading ? (
                  <div className="flex justify-center p-12"><Loader2 className="animate-spin w-8 h-8 text-[#475569]" /></div>
                ) : (
                  <Table>
                    <TableHeader className="bg-slate-50 border-b border-slate-200">
                      <TableRow>
                        <TableHead className="text-slate-600 font-semibold">ID</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Commodity Name</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Category</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Status</TableHead>
                        <TableHead className="text-right text-slate-600 font-semibold">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {commodities.map((c) => (
                        <TableRow key={c.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                          <TableCell className="font-mono text-xs text-slate-500">{c.id.substring(0, 8)}...</TableCell>
                          <TableCell className="font-medium text-[#334155]">{c.name}</TableCell>
                          <TableCell className="font-medium text-slate-600">{c.categoryName || categories.find(cat => cat.id === c.categoryId)?.name || "-"}</TableCell>
                          <TableCell>
                            <span className={`px-2.5 py-1 rounded-md text-[11px] font-bold uppercase tracking-wider ${c.status ? 'bg-[#ECFDF5] text-[#047857] border border-[#A7F3D0]' : 'bg-red-50 text-red-700 border border-red-200'}`}>
                              {c.status ? 'Active' : 'Inactive'}
                            </span>
                          </TableCell>
                          <TableCell className="text-right">
                            {c.status && (
                              <div className="flex justify-end gap-2">
                                <Button variant="ghost" size="icon" onClick={() => openEditCommodity(c)} className="text-slate-400 hover:text-blue-600">
                                  <Edit className="w-4 h-4" />
                                </Button>
                                <Button variant="ghost" size="icon" onClick={() => handleDeleteCommodity(c.id)} className="text-slate-400 hover:text-red-600">
                                  <Trash2 className="w-4 h-4" />
                                </Button>
                              </div>
                            )}
                          </TableCell>
                        </TableRow>
                      ))}
                      {commodities.length === 0 && (
                        <TableRow><TableCell colSpan={5} className="text-center text-slate-500 py-12">No commodities found.</TableCell></TableRow>
                      )}
                    </TableBody>
                  </Table>
                )}
              </div>
            </TabsContent>

            {/* QUALITY PARAMETERS TAB */}
            <TabsContent value="grades" className="m-0 outline-none">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Quality Parameters</h2>
                  <p className="text-sm text-slate-500 mt-1">
                    Manage commodity quality parameters, mathematical tolerances, and lab specifications.
                  </p>
                </div>
                <Button 
                  onClick={handleOpenAddQualityParam}
                  className="bg-[#334155] hover:bg-[#1e293b] text-white shadow-sm"
                >
                  Add Quality Parameter
                </Button>
              </div>

              <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                {loading ? (
                  <div className="flex justify-center p-12"><Loader2 className="animate-spin w-8 h-8 text-[#475569]" /></div>
                ) : (
                  <Table>
                    <TableHeader className="bg-slate-50 border-b border-slate-200">
                      <TableRow>
                        <TableHead className="text-slate-600 font-semibold">ID</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Commodity</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Parameter Name</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Data Type</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Unit</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Tolerances & Targets</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Requirement</TableHead>
                        <TableHead className="text-right text-slate-600 font-semibold">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {qualityParameters.map((p) => (
                        <TableRow key={p.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                          <TableCell className="font-mono text-xs text-slate-500">{p.id.substring(0, 8)}...</TableCell>
                          <TableCell className="font-medium text-slate-700">
                            {p.commodityName || commodities.find((c) => c.id === p.commodityId)?.name || "-"}
                          </TableCell>
                          <TableCell className="font-semibold text-[#334155]">{p.name}</TableCell>
                          <TableCell>
                            <Badge
                              variant="outline"
                              className={
                                p.type === "numeric"
                                  ? "bg-blue-50 text-blue-700 border-blue-200 capitalize font-medium text-xs"
                                  : p.type === "boolean"
                                  ? "bg-purple-50 text-purple-700 border-purple-200 capitalize font-medium text-xs"
                                  : "bg-slate-100 text-slate-700 border-slate-200 capitalize font-medium text-xs"
                              }
                            >
                              {p.type}
                            </Badge>
                          </TableCell>
                          <TableCell>
                            {p.unit ? (
                              <span className="font-mono text-xs px-1.5 py-0.5 rounded bg-slate-100 text-slate-700 font-medium">
                                {p.unit}
                              </span>
                            ) : (
                              <span className="text-slate-400 text-xs">-</span>
                            )}
                          </TableCell>
                          <TableCell>
                            {p.type === "numeric" ? (
                              <div className="text-xs flex flex-wrap items-center gap-2 text-slate-600">
                                {p.minValue !== null && p.minValue !== undefined && (
                                  <span>Min: <strong className="font-medium text-slate-800">{p.minValue}</strong></span>
                                )}
                                {p.maxValue !== null && p.maxValue !== undefined && (
                                  <span>Max: <strong className="font-medium text-slate-800">{p.maxValue}</strong></span>
                                )}
                                {p.targetValue !== null && p.targetValue !== undefined && (
                                  <span className="text-emerald-700">Target: <strong className="font-medium">{p.targetValue}</strong></span>
                                )}
                                {p.minValue === null && p.maxValue === null && p.targetValue === null && (
                                  <span className="text-slate-400">No bounds</span>
                                )}
                              </div>
                            ) : (
                              <span className="text-xs text-slate-400">N/A</span>
                            )}
                          </TableCell>
                          <TableCell>
                            {p.isRequired ? (
                              <Badge variant="destructive" className="text-[11px] font-medium">
                                Mandatory
                              </Badge>
                            ) : (
                              <Badge variant="secondary" className="text-[11px] font-normal text-slate-500 bg-slate-100">
                                Optional
                              </Badge>
                            )}
                          </TableCell>
                          <TableCell className="text-right">
                            <div className="flex justify-end gap-2">
                              <Button
                                variant="ghost"
                                size="icon"
                                onClick={() => handleOpenEditQualityParam(p)}
                                className="text-slate-400 hover:text-blue-600"
                              >
                                <Edit className="w-4 h-4" />
                              </Button>
                              <Button
                                variant="ghost"
                                size="icon"
                                onClick={() => handleDeleteQualityParam(p.id)}
                                className="text-slate-400 hover:text-red-600"
                              >
                                <Trash2 className="w-4 h-4" />
                              </Button>
                            </div>
                          </TableCell>
                        </TableRow>
                      ))}
                      {qualityParameters.length === 0 && (
                        <TableRow>
                          <TableCell colSpan={8} className="text-center text-slate-500 py-12">
                            No quality parameters found. Click &quot;Add Quality Parameter&quot; to configure one.
                          </TableCell>
                        </TableRow>
                      )}
                    </TableBody>
                  </Table>
                )}
              </div>
            </TabsContent>

            {/* UNITS TAB (QUANTITY MEASUREMENTS) */}
            <TabsContent value="units" className="m-0 outline-none">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Units</h2>
                  <p className="text-sm text-slate-500 mt-1">Manage Quantity Measurements (e.g., Kg, Quintal, Tractor Load, Bales).</p>
                </div>
                <Dialog open={addUnitOpen} onOpenChange={handleUnitModalChange}>
                  <DialogTrigger render={<Button className="bg-[#334155] hover:bg-[#1e293b] text-white shadow-sm" />}>
                    Add Unit
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>{editUnitId ? "Edit Unit" : "Add New Unit"}</DialogTitle>
                      <DialogDescription>Enter the quantity measurement name and symbol (e.g. Kg, Quintal, Tractor Load, Bales).</DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="unitName" className="text-right">Name</Label>
                        <Input id="unitName" value={unitName} onChange={(e) => setUnitName(e.target.value)} className="col-span-3" placeholder="e.g. Quintal, Metric Tonnes, Bales" />
                      </div>
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="unitSymbol" className="text-right">Symbol</Label>
                        <Input id="unitSymbol" value={unitSymbol} onChange={(e) => setUnitSymbol(e.target.value)} className="col-span-3" placeholder="e.g. Qtl, MT, Bales" />
                      </div>
                    </div>
                    <DialogFooter>
                      <Button onClick={handleAddUnit}>Save</Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </div>

              <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                {loading ? (
                  <div className="flex justify-center p-12"><Loader2 className="animate-spin w-8 h-8 text-[#475569]" /></div>
                ) : (
                  <Table>
                    <TableHeader className="bg-slate-50 border-b border-slate-200">
                      <TableRow>
                        <TableHead className="text-slate-600 font-semibold">ID</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Name</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Symbol</TableHead>
                        <TableHead className="text-right text-slate-600 font-semibold">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {units.map((u) => (
                        <TableRow key={u.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                          <TableCell className="font-mono text-xs text-slate-500">{u.id.substring(0, 8)}...</TableCell>
                          <TableCell className="font-medium text-[#334155]">{u.name}</TableCell>
                          <TableCell>
                            <span className="px-2 py-1 bg-slate-100 rounded-md text-xs font-semibold text-slate-700">{u.symbol}</span>
                          </TableCell>
                          <TableCell className="text-right">
                            <div className="flex justify-end gap-2">
                              <Button variant="ghost" size="icon" onClick={() => openEditUnit(u)} className="text-slate-400 hover:text-blue-600">
                                <Edit className="w-4 h-4" />
                              </Button>
                              <Button variant="ghost" size="icon" onClick={() => handleDeleteUnit(u.id)} className="text-slate-400 hover:text-red-600">
                                <Trash2 className="w-4 h-4" />
                              </Button>
                            </div>
                          </TableCell>
                        </TableRow>
                      ))}
                      {units.length === 0 && (
                        <TableRow><TableCell colSpan={4} className="text-center text-slate-500 py-12">No units found.</TableCell></TableRow>
                      )}
                    </TableBody>
                  </Table>
                )}
              </div>
            </TabsContent>

            {/* STATES TAB */}
            <TabsContent value="states" className="m-0 outline-none">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-2xl font-bold tracking-tight text-[#334155]">States</h2>
                  <p className="text-sm text-slate-500 mt-1">Manage states in the system.</p>
                </div>
                <Dialog open={addStateOpen} onOpenChange={setAddStateOpen}>
                  <DialogTrigger render={<Button className="bg-[#334155] hover:bg-[#1e293b] text-white shadow-sm" />}>
                    Add State
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>Add New State</DialogTitle>
                      <DialogDescription>Enter the state name and code.</DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="stateName" className="text-right">Name</Label>
                        <Input id="stateName" value={stateName} onChange={(e) => setStateName(e.target.value)} className="col-span-3" />
                      </div>
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="stateCode" className="text-right">Code</Label>
                        <Input id="stateCode" value={stateCode} onChange={(e) => setStateCode(e.target.value)} className="col-span-3" />
                      </div>
                    </div>
                    <DialogFooter>
                      <Button onClick={handleAddState}>Save</Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </div>

              <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                {loading ? (
                  <div className="flex justify-center p-12"><Loader2 className="animate-spin w-8 h-8 text-[#475569]" /></div>
                ) : (
                  <Table>
                    <TableHeader className="bg-slate-50 border-b border-slate-200">
                      <TableRow>
                        <TableHead className="text-slate-600 font-semibold">ID</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Name</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Code</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {states.map((s) => (
                        <TableRow key={s.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                          <TableCell className="font-mono text-xs text-slate-500">{s.id.substring(0, 8)}...</TableCell>
                          <TableCell className="font-medium text-[#334155]">{s.name}</TableCell>
                          <TableCell>{s.code || '-'}</TableCell>
                        </TableRow>
                      ))}
                      {states.length === 0 && (
                        <TableRow><TableCell colSpan={3} className="text-center text-slate-500 py-12">No states found.</TableCell></TableRow>
                      )}
                    </TableBody>
                  </Table>
                )}
              </div>
            </TabsContent>

            {/* DISTRICTS TAB */}
            <TabsContent value="districts" className="m-0 outline-none">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Districts</h2>
                  <p className="text-sm text-slate-500 mt-1">Manage districts in the system.</p>
                </div>
                <Dialog open={addDistrictOpen} onOpenChange={setAddDistrictOpen}>
                  <DialogTrigger render={<Button className="bg-[#334155] hover:bg-[#1e293b] text-white shadow-sm" />}>
                    Add District
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>Add New District</DialogTitle>
                      <DialogDescription>Enter the district name and select a state.</DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="districtName" className="text-right">Name</Label>
                        <Input id="districtName" value={districtName} onChange={(e) => setDistrictName(e.target.value)} className="col-span-3" />
                      </div>
                      <div className="grid grid-cols-4 items-center gap-4">
                        <Label htmlFor="districtState" className="text-right">State ID</Label>
                        <Input id="districtState" value={districtStateId} onChange={(e) => setDistrictStateId(e.target.value)} placeholder="UUID of state" className="col-span-3" />
                      </div>
                    </div>
                    <DialogFooter>
                      <Button onClick={handleAddDistrict}>Save</Button>
                    </DialogFooter>
                  </DialogContent>
                </Dialog>
              </div>

              <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                {loading ? (
                  <div className="flex justify-center p-12"><Loader2 className="animate-spin w-8 h-8 text-[#475569]" /></div>
                ) : (
                  <Table>
                    <TableHeader className="bg-slate-50 border-b border-slate-200">
                      <TableRow>
                        <TableHead className="text-slate-600 font-semibold">ID</TableHead>
                        <TableHead className="text-slate-600 font-semibold">Name</TableHead>
                        <TableHead className="text-slate-600 font-semibold">State ID</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {districts.map((d) => (
                        <TableRow key={d.id} className="border-b border-slate-100 hover:bg-slate-50/50">
                          <TableCell className="font-mono text-xs text-slate-500">{d.id.substring(0, 8)}...</TableCell>
                          <TableCell className="font-medium text-[#334155]">{d.name}</TableCell>
                          <TableCell className="font-mono text-xs text-slate-500">{d.stateId?.substring(0, 8)}...</TableCell>
                        </TableRow>
                      ))}
                      {districts.length === 0 && (
                        <TableRow><TableCell colSpan={3} className="text-center text-slate-500 py-12">No districts found.</TableCell></TableRow>
                      )}
                    </TableBody>
                  </Table>
                )}
              </div>
            </TabsContent>

            {/* COMPANY APPROVALS TAB */}
            <TabsContent value="approvals" className="m-0 outline-none">
              <CompanyApprovalQueue />
            </TabsContent>

            {/* BUYER GST VERIFICATIONS TAB */}
            <TabsContent value="gst-verifications" className="m-0 outline-none">
              <BuyerGstVerificationQueue />
            </TabsContent>

            {/* DEAL DESK TAB */}
            <TabsContent value="dealdesk" className="m-0 outline-none">
              <DealDeskQueue />
            </TabsContent>

            {/* DISPUTES TAB */}
            <TabsContent value="disputes" className="m-0 outline-none">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-2xl font-bold tracking-tight text-[#334155]">Dispute Center</h2>
                  <p className="text-sm text-slate-500 mt-1">Manage and resolve open disputes as Tier 0 Admin.</p>
                </div>
              </div>
              <AdminDisputeQueue />
            </TabsContent>

            {/* HELP DESK TAB */}
            <TabsContent value="helpdesk" className="m-0 outline-none">
              <AdminHelpDeskQueue />
            </TabsContent>

            {/* BROKERS VAULT TAB */}
            <TabsContent value="brokers" className="m-0 outline-none">
              <AdminBrokersVault />
            </TabsContent>

          </div>
        </main>
      </div>
      
      <QualityParameterDialog
        open={qualityParamDialogOpen}
        onOpenChange={setQualityParamDialogOpen}
        commodities={commodities}
        editingParameter={editingQualityParam}
        onSuccess={loadData}
      />

      <AdminProfileDialog open={isProfileOpen} onOpenChange={setIsProfileOpen} />
    </Tabs>
  )
}
