'use client'

import { useState } from "react"
import { useRouter } from "next/navigation"
import { LogOut, User, HelpCircle, ArrowLeftRight, Building2, ShieldCheck, ShieldAlert } from "lucide-react"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { SellerProfileDialog } from "@/src/components/dialogs/seller-profile-dialog"
import { SupportDialog } from "@/src/components/dialogs/support-dialog"
import { signOutAction } from "@/src/server/actions/auth-actions"
import { Badge } from "@/components/ui/badge"

interface SellerHeaderDropdownProps {
  profile: any
  fullProfile?: any
  role?: string
}

export function SellerHeaderDropdown({ profile, fullProfile, role = "SELLER_ADMIN" }: SellerHeaderDropdownProps) {
  const router = useRouter()
  const [isProfileOpen, setIsProfileOpen] = useState(false)
  const [isSupportOpen, setIsSupportOpen] = useState(false)

  const handleSignOut = async () => {
    await signOutAction()
  }

  const userName = fullProfile?.user?.name || profile?.name || "Seller User"
  const companyName = fullProfile?.company?.name || profile?.name || "Trading Organization"
  
  // Format Role Badge nicely (e.g. SELLER_ADMIN, SELLER_USER, SELLER_VIEWER)
  let displayRole = "SELLER_ADMIN"
  if (role) {
    const r = role.toUpperCase()
    if (r.includes("VIEWER")) displayRole = "SELLER_VIEWER"
    else if (r.includes("USER") || r.includes("OPERATOR")) displayRole = "SELLER_USER"
    else if (r.includes("ADMIN") || r.includes("SELLER")) displayRole = "SELLER_ADMIN"
  }

  const getInitials = (name: string) => {
    if (!name) return "S"
    const parts = name.trim().split(" ")
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase()
    }
    return name.substring(0, 2).toUpperCase()
  }

  return (
    <>
      <DropdownMenu>
        <div className="w-auto h-auto inline-block relative cursor-pointer outline-none">
          <DropdownMenuTrigger className="outline-none focus:ring-2 focus:ring-emerald-600 focus:ring-offset-2 rounded-full transition-all">
            <div className="flex h-10 w-10 sm:h-11 sm:w-11 items-center justify-center rounded-full bg-[#ECFDF5] hover:bg-emerald-100 border border-emerald-300 transition-colors shadow-xs">
              <span className="font-bold text-sm sm:text-base text-[#047857] tracking-tight">
                {getInitials(userName)}
              </span>
            </div>
          </DropdownMenuTrigger>
        </div>
        <DropdownMenuContent className="w-64 mt-1 shadow-xl border-slate-200/90 rounded-xl p-1.5" align="end">
          <DropdownMenuGroup>
            <DropdownMenuLabel className="font-normal p-2.5 bg-slate-50/80 rounded-lg mb-1 border border-slate-100">
              <div className="flex flex-col space-y-1.5">
                <div className="flex items-center justify-between gap-2">
                  <p className="text-sm font-bold text-slate-900 leading-tight truncate">
                    {userName}
                  </p>
                  <span className="shrink-0 px-2 py-0.5 rounded text-[10px] font-mono font-bold uppercase tracking-wider bg-emerald-100 text-[#047857] border border-emerald-200">
                    {displayRole}
                  </span>
                </div>
                
                <div className="flex items-center gap-1.5 text-xs text-slate-600">
                  <Building2 className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                  <span className="truncate font-medium">{companyName}</span>
                </div>
              </div>
            </DropdownMenuLabel>
          </DropdownMenuGroup>

          <DropdownMenuSeparator className="my-1" />

          {/* Switch to Buyer Workspace (Trader Dual-Profile Toggle) */}
          <DropdownMenuGroup>
            <DropdownMenuItem 
              className="cursor-pointer py-2.5 px-3 text-emerald-800 hover:text-emerald-900 focus:bg-emerald-50 focus:text-emerald-900 font-semibold rounded-lg transition-colors"
              onClick={() => router.push('/buyer')}
              onSelect={() => router.push('/buyer')}
            >
              <ArrowLeftRight className="mr-2.5 h-4 w-4 text-[#059669]" />
              <div className="flex flex-col">
                <span className="text-sm leading-snug">Switch to Buyer Workspace</span>
                <span className="text-[11px] font-normal text-slate-500">Access buyer requirements & deals</span>
              </div>
            </DropdownMenuItem>
          </DropdownMenuGroup>

          <DropdownMenuSeparator className="my-1" />

          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-slate-700 hover:text-slate-900 focus:bg-slate-50 rounded-lg transition-colors" 
            onClick={() => setIsProfileOpen(true)}
            onSelect={(e) => {
              e.preventDefault();
              setIsProfileOpen(true);
            }}
          >
            <User className="mr-2.5 h-4 w-4 text-slate-500" />
            <span className="font-medium text-sm">Organization & KYC Profile</span>
          </DropdownMenuItem>

          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-slate-700 hover:text-slate-900 focus:bg-slate-50 rounded-lg transition-colors" 
            onClick={() => setIsSupportOpen(true)}
            onSelect={(e) => {
              e.preventDefault();
              setIsSupportOpen(true);
            }}
          >
            <HelpCircle className="mr-2.5 h-4 w-4 text-slate-500" />
            <span className="font-medium text-sm">Help & Support Desk</span>
          </DropdownMenuItem>

          <DropdownMenuSeparator className="my-1" />

          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-rose-600 focus:text-rose-700 focus:bg-rose-50 font-medium rounded-lg transition-colors" 
            onClick={handleSignOut}
          >
            <LogOut className="mr-2.5 h-4 w-4" />
            <span className="text-sm">Sign out securely</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <SellerProfileDialog 
        open={isProfileOpen} 
        onOpenChange={setIsProfileOpen} 
        initialProfileData={fullProfile} 
      />
      <SupportDialog 
        open={isSupportOpen} 
        onOpenChange={setIsSupportOpen} 
      />
    </>
  )
}
