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
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Shield, Loader2, Save, KeyRound, Smartphone } from "lucide-react"
import { toast } from "sonner"
import { 
  getAdminProfileDetailsAction, 
  updateAdminProfileAction, 
  updateAdminPasswordAction 
} from "@/src/server/actions/admin-profile-actions"
import { PwaInstallCard } from "@/src/components/pwa/pwa-install-card"


interface AdminProfileDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function AdminProfileDialog({ open, onOpenChange }: AdminProfileDialogProps) {
  const [activeTab, setActiveTab] = useState("general")
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  // Profile State
  const [name, setName] = useState("")
  const [mobile, setMobile] = useState("")
  const [email, setEmail] = useState("")

  // Security State
  const [password, setPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")

  useEffect(() => {
    if (open) {
      loadProfile()
    }
  }, [open])

  async function loadProfile() {
    setLoading(true)
    const result = await getAdminProfileDetailsAction()
    if (result.success && result.data) {
      setName(result.data.name || "")
      setMobile(result.data.mobile || "")
      setEmail(result.data.email || "")
    } else {
      toast.error(result.error || "Failed to load profile details")
    }
    setLoading(false)
  }

  async function handleSaveProfile(e: React.FormEvent) {
    e.preventDefault()
    if (name.length < 2) {
      toast.error("Name must be at least 2 characters")
      return
    }
    setSaving(true)
    const result = await updateAdminProfileAction({ name, mobile })
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
    const result = await updateAdminPasswordAction(password)
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
      <DialogContent className="sm:max-w-[520px] p-0 overflow-hidden rounded-xl border-slate-200 shadow-xl">
        <DialogHeader className="p-6 pb-2">
          <DialogTitle className="text-xl font-semibold text-[#334155]">Profile Settings</DialogTitle>
          <DialogDescription className="text-slate-500">
            Manage your administrator identity and security preferences.
          </DialogDescription>
        </DialogHeader>

        {loading ? (
          <div className="flex flex-col items-center justify-center p-12 space-y-4">
            <Loader2 className="h-8 w-8 animate-spin text-slate-400" />
            <p className="text-sm text-slate-500">Loading profile data...</p>
          </div>
        ) : (
          <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
            <div className="px-6 border-b border-slate-100">
              <TabsList className="w-full justify-start bg-transparent p-0 h-10 space-x-6 border-none">
                <TabsTrigger 
                  value="general" 
                  className="data-[state=active]:bg-transparent data-[state=active]:shadow-none data-[state=active]:border-b-2 data-[state=active]:border-[#334155] data-[state=active]:text-[#334155] rounded-none px-0 pb-2 pt-2 text-slate-500 hover:text-slate-700 font-medium"
                >
                  General Details
                </TabsTrigger>
                <TabsTrigger 
                  value="security" 
                  className="data-[state=active]:bg-transparent data-[state=active]:shadow-none data-[state=active]:border-b-2 data-[state=active]:border-[#334155] data-[state=active]:text-[#334155] rounded-none px-0 pb-2 pt-2 text-slate-500 hover:text-slate-700 font-medium"
                >
                  Security
                </TabsTrigger>
                <TabsTrigger 
                  value="app" 
                  className="data-[state=active]:bg-transparent data-[state=active]:shadow-none data-[state=active]:border-b-2 data-[state=active]:border-[#334155] data-[state=active]:text-[#334155] rounded-none px-0 pb-2 pt-2 text-slate-500 hover:text-slate-700 font-medium flex items-center gap-1.5"
                >
                  <Smartphone className="w-3.5 h-3.5 text-slate-700" />
                  <span>Install App</span>
                </TabsTrigger>
              </TabsList>
            </div>

            <TabsContent value="general" className="p-6 m-0 outline-none">
              <div className="flex items-center space-x-4 mb-8 p-4 bg-[#F8FAFC] rounded-lg border border-slate-100">
                <Avatar className="h-14 w-14 border-2 border-white shadow-sm">
                  <AvatarFallback className="bg-slate-900 text-white text-lg font-bold">
                    {name ? name.charAt(0).toUpperCase() : 'A'}
                  </AvatarFallback>
                </Avatar>
                <div className="flex flex-col">
                  <h3 className="font-semibold text-slate-900">{name || "Administrator"}</h3>
                  <div className="flex items-center mt-1">
                    <span className="inline-flex items-center px-2 py-0.5 rounded-md bg-[#F1F5F9] text-[#334155] text-xs font-semibold uppercase tracking-wider border border-slate-200">
                      <Shield className="w-3 h-3 mr-1" />
                      Tier 0 God Mode
                    </span>
                  </div>
                </div>
              </div>

              <form onSubmit={handleSaveProfile} className="space-y-5">
                <div className="space-y-2">
                  <Label htmlFor="name" className="text-sm font-medium text-slate-700">Full Name</Label>
                  <Input 
                    id="name" 
                    value={name} 
                    onChange={(e) => setName(e.target.value)} 
                    placeholder="Enter your full name"
                    className="focus-visible:ring-[#334155]"
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="mobile" className="text-sm font-medium text-slate-700">Escalation Mobile (WhatsApp)</Label>
                  <Input 
                    id="mobile" 
                    value={mobile} 
                    onChange={(e) => setMobile(e.target.value)} 
                    placeholder="Enter mobile number"
                    className="focus-visible:ring-[#334155]"
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="email" className="text-sm font-medium text-slate-700">Email Address</Label>
                  <Input 
                    id="email" 
                    value={email} 
                    readOnly 
                    className="bg-slate-50 text-slate-500 focus-visible:ring-0 cursor-not-allowed border-slate-200"
                  />
                  <p className="text-xs text-slate-400 mt-1">Contact IT Support to change your primary admin email.</p>
                </div>

                <div className="pt-4 flex justify-end">
                  <Button type="submit" disabled={saving} className="bg-[#334155] hover:bg-slate-800 text-white font-medium px-6">
                    {saving ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Save className="w-4 h-4 mr-2" />}
                    Save Changes
                  </Button>
                </div>
              </form>
            </TabsContent>

            <TabsContent value="security" className="p-6 m-0 outline-none">
              <form onSubmit={handleUpdatePassword} className="space-y-5">
                <div className="p-4 bg-orange-50 border border-orange-100 rounded-lg mb-4">
                  <h4 className="text-sm font-medium text-orange-800 flex items-center">
                    <KeyRound className="w-4 h-4 mr-2" />
                    Security Notice
                  </h4>
                  <p className="text-xs text-orange-700 mt-1">
                    Updating your Tier 0 password will immediately invalidate all active sessions across other devices. You will need to sign in again.
                  </p>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="new-password" className="text-sm font-medium text-slate-700">New Password</Label>
                  <Input 
                    id="new-password" 
                    type="password"
                    value={password} 
                    onChange={(e) => setPassword(e.target.value)} 
                    placeholder="Minimum 6 characters"
                    className="focus-visible:ring-[#334155]"
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="confirm-password" className="text-sm font-medium text-slate-700">Confirm Password</Label>
                  <Input 
                    id="confirm-password" 
                    type="password"
                    value={confirmPassword} 
                    onChange={(e) => setConfirmPassword(e.target.value)} 
                    placeholder="Re-enter your new password"
                    className="focus-visible:ring-[#334155]"
                  />
                </div>

                <div className="pt-4 flex justify-end">
                  <Button type="submit" disabled={saving || !password || !confirmPassword} className="bg-[#334155] hover:bg-slate-800 text-white font-medium px-6">
                    {saving ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <KeyRound className="w-4 h-4 mr-2" />}
                    Update Password
                  </Button>
                </div>
              </form>
            </TabsContent>

            <TabsContent value="app" className="p-6 m-0 outline-none">
              <PwaInstallCard role="ADMIN" />
            </TabsContent>
          </Tabs>
        )}
      </DialogContent>
    </Dialog>
  )
}
