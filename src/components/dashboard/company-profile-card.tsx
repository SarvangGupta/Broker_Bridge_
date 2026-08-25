'use client'

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Building2, MapPin, Receipt, Component } from "lucide-react"

interface CompanyProfileCardProps {
  profile: any
}

export function CompanyProfileCard({ profile }: CompanyProfileCardProps) {
  if (!profile) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>My Profile</CardTitle>
          <CardDescription>No profile data available.</CardDescription>
        </CardHeader>
      </Card>
    )
  }

  return (
    <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden p-6 max-w-2xl">
      <div className="flex items-center gap-4 border-b border-slate-100 pb-6 mb-6">
        <div className="bg-[#EFF6FF] p-4 rounded-full">
          <Building2 className="w-8 h-8 text-[#1D4ED8]" />
        </div>
        <div>
          <h2 className="text-2xl font-bold text-slate-900">{profile.name}</h2>
          <p className="text-slate-500 font-medium">Registered Buyer</p>
        </div>
      </div>

      <div className="space-y-6">
        <div>
          <p className="text-sm text-slate-500 font-medium uppercase tracking-wider mb-1">GST Number</p>
          <p className="text-lg font-medium text-slate-900">{profile.gst || "N/A"}</p>
        </div>
        
        <div>
          <p className="text-sm text-slate-500 font-medium uppercase tracking-wider mb-1">Registered Location</p>
          <p className="text-lg font-medium text-slate-900">
            {profile.districtId && profile.stateId 
              ? `District ID: ${profile.districtId}, State ID: ${profile.stateId}` 
              : "Location details pending"}
          </p>
        </div>
      </div>
    </div>
  )
}
