'use client'

import { useState } from "react"
import { useRouter } from "next/navigation"
import { LogOut, User, HelpCircle, ArrowLeftRight } from "lucide-react"
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

interface SellerHeaderDropdownProps {
  profile: any
  fullProfile?: any
}

export function SellerHeaderDropdown({ profile, fullProfile }: SellerHeaderDropdownProps) {
  const router = useRouter()
  const [isProfileOpen, setIsProfileOpen] = useState(false)
  const [isSupportOpen, setIsSupportOpen] = useState(false)

  const handleSignOut = async () => {
    await signOutAction()
  }

  const getInitials = (name: string) => {
    if (!name) return "S"
    return name.substring(0, 2).toUpperCase()
  }

  return (
    <>
      <DropdownMenu>
        <div className="w-auto h-auto inline-block relative cursor-pointer outline-none">
          <DropdownMenuTrigger className="outline-none">
            <div className="flex h-11 w-11 items-center justify-center rounded-full bg-[#ECFDF5] hover:bg-emerald-100 border border-emerald-200/80 transition-colors shadow-sm">
              <span className="font-bold text-base text-[#047857] tracking-tight">{getInitials(profile?.name)}</span>
            </div>
          </DropdownMenuTrigger>
        </div>
        <DropdownMenuContent className="w-56 mt-1 shadow-lg border-slate-200" align="end">
          <DropdownMenuGroup>
            <DropdownMenuLabel className="font-normal p-3">
              <div className="flex flex-col space-y-1">
                <p className="text-sm font-semibold text-slate-900 leading-none">{profile?.name || "Seller"}</p>
                <p className="text-xs text-muted-foreground mt-0.5">Seller Account</p>
              </div>
            </DropdownMenuLabel>
          </DropdownMenuGroup>
          <DropdownMenuSeparator />
          <DropdownMenuGroup>
            <DropdownMenuItem 
              className="cursor-pointer py-2.5 px-3 text-emerald-700 hover:text-emerald-800 focus:bg-emerald-50 focus:text-emerald-800 font-medium"
              onClick={() => router.push('/buyer')}
              onSelect={() => router.push('/buyer')}
            >
              <ArrowLeftRight className="mr-2 h-4 w-4 text-emerald-600" />
              <span className="text-sm">Switch to Buyer Workspace</span>
            </DropdownMenuItem>
          </DropdownMenuGroup>
          <DropdownMenuSeparator />
          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-slate-700 hover:text-slate-900 focus:bg-slate-50" 
            onClick={() => setIsProfileOpen(true)}
            onSelect={(e) => {
              e.preventDefault();
              setIsProfileOpen(true);
            }}
          >
            <User className="mr-2 h-4 w-4 text-slate-500" />
            <span className="font-medium text-sm">Profile Settings</span>
          </DropdownMenuItem>
          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-slate-700 hover:text-slate-900 focus:bg-slate-50" 
            onClick={() => setIsSupportOpen(true)}
            onSelect={(e) => {
              e.preventDefault();
              setIsSupportOpen(true);
            }}
          >
            <HelpCircle className="mr-2 h-4 w-4 text-slate-500" />
            <span className="font-medium text-sm">Help & Support</span>
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-rose-600 focus:text-rose-700 focus:bg-rose-50" 
            onClick={handleSignOut}
          >
            <LogOut className="mr-2 h-4 w-4" />
            <span className="font-medium text-sm">Sign out securely</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <SellerProfileDialog open={isProfileOpen} onOpenChange={setIsProfileOpen} initialProfileData={fullProfile} />
      <SupportDialog open={isSupportOpen} onOpenChange={setIsSupportOpen} />
    </>
  )
}
