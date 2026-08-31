'use client'

import React from 'react'
import { Menu, ShieldCheck, Clock, AlertCircle } from 'lucide-react'
import { NotificationBell } from "@/src/components/layout/notification-bell"
import { SellerHeaderDropdown } from "@/src/components/dashboard/seller-header-dropdown"
import { Button } from "@/components/ui/button"

interface SellerHeaderProps {
  profile: any
  fullProfile?: any
  userRole?: string
  onMobileMenuToggle?: () => void
}

export function SellerHeader({
  profile,
  fullProfile,
  userRole = "SELLER_ADMIN",
  onMobileMenuToggle,
}: SellerHeaderProps) {
  const company = fullProfile?.company || profile
  const isVerified = company?.isVerified === true && company?.status === true
  const isPending = company && company.status === false
  const isActionRequired = !company

  return (
    <header className="w-full bg-white border-b border-slate-200/90 h-16 sticky top-0 z-40 shadow-[0_1px_3px_rgba(0,0,0,0.02)]">
      <div className="w-full max-w-screen-2xl mx-auto px-4 sm:px-6 lg:px-8 flex items-center justify-between h-full">
        
        {/* LEFT SECTION: Hamburger Toggle + Logo & Workspace Indicator */}
        <div className="flex items-center gap-3">
          {/* Mobile Menu Hamburger Trigger */}
          <Button
            variant="ghost"
            size="icon"
            onClick={onMobileMenuToggle}
            className="md:hidden h-10 w-10 text-slate-700 hover:text-slate-900 hover:bg-slate-100 rounded-xl cursor-pointer"
            aria-label="Open navigation menu"
          >
            <Menu className="w-5 h-5 stroke-[2]" />
          </Button>

          {/* Brand Logo & Workspace Subtitle */}
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-slate-900 flex items-center justify-center shadow-xs shrink-0">
              <span className="text-white font-black text-xs tracking-tighter">BB</span>
            </div>
            <div className="flex flex-col">
              <div className="flex items-center gap-2">
                <span className="font-extrabold text-slate-900 tracking-tight text-base sm:text-lg leading-none">
                  BrokerBridge
                </span>
                <span className="hidden sm:inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-emerald-50 text-[#047857] border border-emerald-200/80">
                  Seller Workspace
                </span>
              </div>
              <span className="text-[11px] text-slate-500 font-medium sm:hidden">
                Seller Workspace
              </span>
            </div>
          </div>
        </div>

        {/* RIGHT SECTION: KYC Badge + Notifications + User Avatar Dropdown */}
        <div className="flex items-center gap-2.5 sm:gap-3.5">
          {/* KYC / Verification Status Badge */}
          {isVerified && (
            <div className="hidden sm:inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-[#ECFDF5] text-[#047857] border border-[#A7F3D0] shadow-2xs">
              <ShieldCheck className="w-3.5 h-3.5 text-[#047857] stroke-[2.25]" />
              <span>Verified Entity</span>
            </div>
          )}

          {isPending && (
            <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-[#FFFBEB] text-[#B45309] border border-[#FDE68A] shadow-2xs">
              <Clock className="w-3.5 h-3.5 text-[#B45309] stroke-[2.25]" />
              <span className="hidden xs:inline">Pending KYC</span>
            </div>
          )}

          {isActionRequired && (
            <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-[#FEF2F2] text-[#B91C1C] border border-[#FECACA] shadow-2xs">
              <AlertCircle className="w-3.5 h-3.5 text-[#B91C1C] stroke-[2.25]" />
              <span className="hidden xs:inline">Action Required</span>
            </div>
          )}

          {/* Unified Notification Bell */}
          <NotificationBell />

          {/* User Avatar Dropdown with Trader Toggle & KYC Menu */}
          <SellerHeaderDropdown 
            profile={profile} 
            fullProfile={fullProfile} 
            role={userRole} 
          />
        </div>

      </div>
    </header>
  )
}
