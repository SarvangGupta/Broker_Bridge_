'use client'

import { useState } from "react"
import { LogOut, User, HelpCircle, Smartphone } from "lucide-react"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { BrokerProfileDialog } from "@/src/components/dialogs/broker-profile-dialog"
import { SupportDialog } from "@/src/components/dialogs/support-dialog"
import { signOutAction } from "@/src/server/actions/auth-actions"

interface BrokerHeaderDropdownProps {
  profile: any
  fullProfile?: any
}

export function BrokerHeaderDropdown({ profile, fullProfile }: BrokerHeaderDropdownProps) {
  const [isProfileOpen, setIsProfileOpen] = useState(false)
  const [profileTab, setProfileTab] = useState("profile")
  const [isSupportOpen, setIsSupportOpen] = useState(false)

  const handleSignOut = async () => {
    await signOutAction()
  }

  const getInitials = (name: string) => {
    if (!name) return "B"
    return name.substring(0, 2).toUpperCase()
  }

  return (
    <>
      <DropdownMenu>
        <div className="w-auto h-auto inline-block relative cursor-pointer outline-none">
          <DropdownMenuTrigger className="outline-none">
            <div className="flex h-11 w-11 items-center justify-center rounded-full bg-[#CCFBF1] hover:bg-teal-100 border border-teal-200/80 transition-colors shadow-sm">
              <span className="font-bold text-base text-[#0D9488] tracking-tight">{getInitials(profile?.name)}</span>
            </div>
          </DropdownMenuTrigger>
        </div>
        <DropdownMenuContent className="w-56 mt-1 shadow-lg border-slate-200" align="end">
          <DropdownMenuGroup>
            <DropdownMenuLabel className="font-normal p-3">
              <div className="flex flex-col space-y-1">
                <p className="text-sm font-semibold text-slate-900 leading-none">{profile?.name || "Broker"}</p>
                <p className="text-xs text-muted-foreground mt-0.5">Broker Account</p>
              </div>
            </DropdownMenuLabel>
          </DropdownMenuGroup>
          <DropdownMenuSeparator />
          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-slate-700 hover:text-slate-900 focus:bg-slate-50" 
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
            <User className="mr-2 h-4 w-4 text-slate-500" />
            <span className="font-medium text-sm">Profile Settings</span>
          </DropdownMenuItem>

          <DropdownMenuItem 
            className="cursor-pointer py-2.5 px-3 text-teal-800 hover:text-teal-900 focus:bg-teal-50 font-medium" 
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
            <Smartphone className="mr-2 h-4 w-4 text-teal-600" />
            <span className="font-medium text-sm">Install Mobile App</span>
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

      <BrokerProfileDialog 
        open={isProfileOpen} 
        onOpenChange={setIsProfileOpen} 
        initialProfileData={fullProfile} 
        defaultTab={profileTab}
      />
      <SupportDialog open={isSupportOpen} onOpenChange={setIsSupportOpen} />
    </>
  )
}
