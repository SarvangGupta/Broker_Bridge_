'use client'

import React, { useState, useEffect } from 'react'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Loader2, Save, KeyRound } from "lucide-react"
import { toast } from "sonner"
import { 
  getFullBuyerProfileDetailsAction, 
  updateBuyerProfileDetailsAction, 
  updateUserPasswordAction 
} from "@/src/server/actions/user-profile-actions"
import { useStates, useDistricts } from "@/src/hooks/use-master-data"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { KycStatusBadge } from "@/src/components/shared/kyc-status-badge"

interface SellerProfileDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  initialProfileData?: any
}

export function SellerProfileDialog({ open, onOpenChange, initialProfileData }: SellerProfileDialogProps) {
  const [activeTab, setActiveTab] = useState("profile")
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  // Profile State
  const [personalName, setPersonalName] = useState("")
  const [mobile, setMobile] = useState("")
  const [email, setEmail] = useState("") // readonly
  const [companyName, setCompanyName] = useState("")
  const [gst, setGst] = useState("")
  const [stateId, setStateId] = useState("")
  const [districtId, setDistrictId] = useState("")
  const [isVerified, setIsVerified] = useState<boolean>(false)
  const [status, setStatus] = useState<string>("PENDING")

  // Security State
  const [password, setPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")

  // Master Data
  const { data: states = [] } = useStates()
  const { data: districts = [] } = useDistricts()
  
  const filteredDistricts = districts.filter((d: any) => d.stateId === stateId)

  useEffect(() => {
    if (open) {
      if (initialProfileData) {
        populateProfile(initialProfileData)
        setLoading(false)
      } else {
        loadProfile()
      }
    }
  }, [open, initialProfileData])

  function populateProfile(data: any) {
    if (data.user) {
      setPersonalName(data.user.name || "")
      setMobile(data.user.mobile || "")
      setEmail(data.user.email || "")
    }
    if (data.company) {
      setCompanyName(data.company.name || "")
      setGst(data.company.gst || "")
      setStateId(data.company.stateId || "")
      setDistrictId(data.company.districtId || "")
      setIsVerified(Boolean(data.company.isVerified))
      setStatus(
        data.company.onboardingStatus ||
        (data.company.isVerified || data.company.status ? 'APPROVED' : 'PENDING')
      )
    }
  }

  async function loadProfile() {
    setLoading(true)
    const result = await getFullBuyerProfileDetailsAction()
    if (result.success && result.data) {
      populateProfile(result.data)
    } else {
      toast.error(result.error || "Failed to load profile")
    }
    setLoading(false)
  }

  async function handleSaveProfile(e: React.FormEvent) {
    e.preventDefault()
    if (personalName.length < 2 || companyName.length < 2) {
      toast.error("Name and Company Name must be at least 2 characters")
      return
    }
    
    setSaving(true)
    const result = await updateBuyerProfileDetailsAction({ 
      personalName, 
      mobile, 
      companyName, 
      gst, 
      stateId, 
      districtId 
    })
    
    if (result.success) {
      toast.success("Profile updated successfully")
    } else {
      toast.error(result.error || "Failed to update profile")
    }
    setSaving(false)
  }

  async function handleUpdatePassword(e: React.FormEvent) {
    e.preventDefault()
    if (password.length < 6) {
      toast.error("Password must be at least 6 characters")
      return
    }
    if (password !== confirmPassword) {
      toast.error("Passwords do not match")
      return
    }
    setSaving(true)
    const result = await updateUserPasswordAction(password)
    if (result.success) {
      toast.success("Password updated successfully")
      setPassword("")
      setConfirmPassword("")
    } else {
      toast.error(result.error || "Failed to update password")
    }
    setSaving(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[600px] p-0 overflow-hidden bg-white">
        <DialogHeader className="px-6 py-4 border-b">
          <DialogTitle className="text-xl font-semibold text-slate-900">Seller Profile Settings</DialogTitle>
          <DialogDescription className="sr-only">
            Manage your personal and company profile details.
          </DialogDescription>
        </DialogHeader>

        {loading ? (
          <div className="flex justify-center items-center h-64">
            <Loader2 className="h-8 w-8 animate-spin text-emerald-600" />
          </div>
        ) : (
          <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
            <div className="px-6 pt-4">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="profile">Profile Details</TabsTrigger>
                <TabsTrigger value="security">Security</TabsTrigger>
              </TabsList>
            </div>

            <div className="p-6 max-h-[70vh] overflow-y-auto">
              <TabsContent value="profile" className="mt-0 space-y-6">
                <form onSubmit={handleSaveProfile} className="space-y-6">
                  
                  {/* Personal Section */}
                  <div className="space-y-4">
                    <h3 className="text-sm font-semibold text-slate-900 border-b pb-2">Personal Details</h3>
                    
                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor="personalName">Full Name</Label>
                        <Input 
                          id="personalName" 
                          value={personalName} 
                          onChange={(e) => setPersonalName(e.target.value)} 
                          placeholder="Your Name" 
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="email">Email</Label>
                        <Input 
                          id="email" 
                          value={email} 
                          disabled 
                          className="bg-slate-50 text-slate-500" 
                        />
                      </div>
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor="mobile">Mobile Number</Label>
                      <Input 
                        id="mobile" 
                        value={mobile} 
                        onChange={(e) => setMobile(e.target.value)} 
                        placeholder="Enter mobile number" 
                      />
                    </div>
                  </div>

                    {/* Company Section */}
                  <div className="space-y-4 pt-4">
                    <div className="flex items-center justify-between border-b pb-2">
                      <h3 className="text-sm font-semibold text-slate-900">Company Details</h3>
                      <KycStatusBadge isVerified={isVerified} status={status} size="sm" />
                    </div>
                    
                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label htmlFor="companyName">Company Name</Label>
                        <Input 
                          id="companyName" 
                          value={companyName} 
                          onChange={(e) => setCompanyName(e.target.value)} 
                          placeholder="Business Name" 
                        />
                      </div>
                      <div className="space-y-2">
                        <Label htmlFor="gst">GST Number</Label>
                        <Input 
                          id="gst" 
                          value={gst} 
                          onChange={(e) => setGst(e.target.value)} 
                          placeholder="GSTIN (Optional)" 
                        />
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>State</Label>
                        <Select value={stateId} onValueChange={(val) => { setStateId(val || ""); setDistrictId("") }}>
                          <SelectTrigger>
                            <SelectValue placeholder="Select State">
                              {stateId && states.find((s: any) => s.id === stateId)?.name}
                            </SelectValue>
                          </SelectTrigger>
                          <SelectContent alignItemWithTrigger={false}>
                            {states.map((s: any) => (
                              <SelectItem key={s.id} value={s.id}>{s.name}</SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                      
                      <div className="space-y-2">
                        <Label>District</Label>
                        <Select value={districtId} onValueChange={(val) => setDistrictId(val || "")} disabled={!stateId}>
                          <SelectTrigger>
                            <SelectValue placeholder="Select District">
                              {districtId && districts.find((d: any) => d.id === districtId)?.name}
                            </SelectValue>
                          </SelectTrigger>
                          <SelectContent alignItemWithTrigger={false}>
                            {filteredDistricts.map((d: any) => (
                              <SelectItem key={d.id} value={d.id}>{d.name}</SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                    </div>
                  </div>

                  <div className="flex justify-end pt-4 border-t">
                    <Button 
                      type="submit" 
                      disabled={saving}
                      className="bg-[#059669] hover:bg-[#047857] text-white"
                    >
                      {saving ? (
                        <>
                          <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                          Saving...
                        </>
                      ) : (
                        <>
                          <Save className="mr-2 h-4 w-4" />
                          Save Changes
                        </>
                      )}
                    </Button>
                  </div>
                </form>
              </TabsContent>

              <TabsContent value="security" className="mt-0">
                <form onSubmit={handleUpdatePassword} className="space-y-6">
                  <div className="space-y-2">
                    <Label htmlFor="newPassword">New Password</Label>
                    <Input 
                      id="newPassword" 
                      type="password" 
                      value={password} 
                      onChange={(e) => setPassword(e.target.value)} 
                      placeholder="Minimum 6 characters" 
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="confirmPassword">Confirm Password</Label>
                    <Input 
                      id="confirmPassword" 
                      type="password" 
                      value={confirmPassword} 
                      onChange={(e) => setConfirmPassword(e.target.value)} 
                      placeholder="Re-enter new password" 
                    />
                  </div>
                  
                  <div className="flex justify-end pt-4 border-t">
                    <Button 
                      type="submit" 
                      disabled={saving || !password || !confirmPassword}
                      className="bg-[#059669] hover:bg-[#047857] text-white"
                    >
                      {saving ? (
                        <>
                          <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                          Updating...
                        </>
                      ) : (
                        <>
                          <KeyRound className="mr-2 h-4 w-4" />
                          Update Password
                        </>
                      )}
                    </Button>
                  </div>
                </form>
              </TabsContent>
            </div>
          </Tabs>
        )}
      </DialogContent>
    </Dialog>
  )
}
