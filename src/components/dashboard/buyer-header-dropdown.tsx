'use client'

import { useState } from "react"
import { useRouter } from "next/navigation"
import { LogOut, User, HelpCircle, ArrowLeftRight, Smartphone } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { BuyerProfileDialog } from "@/src/components/dialogs/buyer-profile-dialog"
import { SupportDialog } from "@/src/components/dialogs/support-dialog"
import { signOutAction } from "@/src/server/actions/auth-actions"

interface BuyerHeaderDropdownProps {
  profile: any
  fullProfile?: any
}

export function BuyerHeaderDropdown({ profile, fullProfile }: BuyerHeaderDropdownProps) {
  const router = useRouter()
  const [isProfileOpen, setIsProfileOpen] = useState(false)
  const [profileTab, setProfileTab] = useState("profile")
  const [isSupportOpen, setIsSupportOpen] = useState(false)

  const handleSignOut = async () => {
    await signOutAction()
  }

  const getInitials = (name: string) => {
    if (!name) return "U"
    return name.substring(0, 2).toUpperCase()
  }

  return (
    <>
      <DropdownMenu>
        <div className="w-auto h-auto inline-block relative cursor-pointer outline-none">
          <DropdownMenuTrigger>
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-[#EFF6FF] hover:bg-blue-100 border border-blue-200">
              <span className="font-bold text-lg text-[#1D4ED8]">{getInitials(profile?.name)}</span>
            </div>
          </DropdownMenuTrigger>
        </div>
        <DropdownMenuContent className="w-56" align="end">
          <DropdownMenuGroup>
            <DropdownMenuLabel className="font-normal">
              <div className="flex flex-col space-y-1">
                <p className="text-sm font-medium leading-none">{profile?.name || "User"}</p>
                <p className="text-xs leading-none text-muted-foreground">Buyer Account</p>
              </div>
            </DropdownMenuLabel>
          </DropdownMenuGroup>
          <DropdownMenuSeparator />
          <DropdownMenuGroup>
            <DropdownMenuItem 
              className="cursor-pointer py-3 text-blue-700 hover:text-blue-800 focus:bg-blue-50 focus:text-blue-800 font-medium"
              onClick={() => { window.location.href = '/seller'; }}
              onSelect={() => { window.location.href = '/seller'; }}
            >
              <ArrowLeftRight className="mr-2 h-4 w-4 text-blue-600" />
              <span>Switch to Seller Workspace</span>
            </DropdownMenuItem>
          </DropdownMenuGroup>
          <DropdownMenuSeparator />
          <DropdownMenuItem 
            className="cursor-pointer py-3" 
            onClick={() => {
              setProfileTab("profile");
              setIsProfileOpen(true);
            }}
            onSelect={(e) => {
              e.preventDefault();
              setProfileTab("profile");
              setIsProfileOpen(true);
            }}
          >
            <User className="mr-2 h-4 w-4" />
            <span className="font-medium">Profile Settings</span>
          </DropdownMenuItem>

          <DropdownMenuItem 
            className="cursor-pointer py-3 text-blue-700 hover:text-blue-800 focus:bg-blue-50 font-medium" 
            onClick={() => {
              setProfileTab("app");
              setIsProfileOpen(true);
            }}
            onSelect={(e) => {
              e.preventDefault();
              setProfileTab("app");
              setIsProfileOpen(true);
            }}
          >
            <Smartphone className="mr-2 h-4 w-4 text-blue-600" />
            <span className="font-medium">Install Mobile App</span>
          </DropdownMenuItem>

          <DropdownMenuItem 
            className="cursor-pointer py-3 text-slate-700 hover:text-slate-900" 
            onClick={() => setIsSupportOpen(true)}
            onSelect={(e) => {
              e.preventDefault();
              setIsSupportOpen(true);
            }}
          >
            <HelpCircle className="mr-2 h-4 w-4 text-slate-500" />
            <span className="font-medium">Help & Support</span>
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem className="cursor-pointer py-3 text-red-600 focus:text-red-700 focus:bg-red-50" onClick={handleSignOut}>
            <LogOut className="mr-2 h-4 w-4" />
            <span className="font-medium">Sign out securely</span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <BuyerProfileDialog 
        open={isProfileOpen} 
        onOpenChange={setIsProfileOpen} 
        initialProfileData={fullProfile} 
        defaultTab={profileTab}
      />
      <SupportDialog open={isSupportOpen} onOpenChange={setIsSupportOpen} />
    </>
  )
}
