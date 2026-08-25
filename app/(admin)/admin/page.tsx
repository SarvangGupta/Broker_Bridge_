import { signOutAction } from "@/src/server/actions/auth-actions"
import { Button } from "@/components/ui/button"
import { MasterDataTabs } from "./_components/MasterDataTabs"
import { LogOut, ShieldAlert } from "lucide-react"

export default function AdminDashboard() {
  return (
    <>
      {/* Mobile blocker */}
      <div className="lg:hidden flex flex-col items-center justify-center min-h-screen p-8 bg-[#F1F5F9] text-center">
        <ShieldAlert className="w-16 h-16 text-[#334155] mb-4" />
        <h1 className="text-2xl font-bold text-[#334155] mb-2">Desktop Only</h1>
        <p className="text-slate-600 max-w-md">
          Admin God Mode is strictly optimized for desktop environments to maximize information density. Please access this portal on a screen larger than 1024px.
        </p>
        <form action={signOutAction} className="mt-8">
          <Button type="submit" variant="outline" className="text-[#334155] border-slate-300 bg-white">
            <LogOut className="w-4 h-4 mr-2" />
            Sign Out Securely
          </Button>
        </form>
      </div>

      {/* Desktop layout */}
      <div className="hidden lg:block min-h-screen bg-[#F1F5F9]">
        <MasterDataTabs />
      </div>
    </>
  )
}
