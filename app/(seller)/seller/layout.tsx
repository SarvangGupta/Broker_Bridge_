import React, { Suspense } from "react"
import { getCompanyProfile } from "@/src/server/actions/company-actions"
import { SellerSidebar, SellerMobileHeader } from "@/src/components/dashboard/seller-sidebar"

export const dynamic = "force-dynamic"
export const revalidate = 0

export default async function SellerLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const profileRes = await getCompanyProfile()

  const profile = profileRes.success && profileRes.data ? profileRes.data : null
  const dbUser = profileRes.user || null
  const userRole = dbUser?.role || "SELLER_ADMIN"

  const onboardingStatus = profileRes.status || 'NONE'
  const isApproved = onboardingStatus === 'APPROVED' && Boolean(profile?.id)

  // 1. STRICT FOCUS MODE FORK:
  // If user does NOT have a valid companyId or status is NOT 'APPROVED':
  // Return Focus Mode container with ONLY children, and ABSOLUTELY NO navigation elements.
  if (!isApproved) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#F8FAFC] px-4 py-12 w-full overflow-x-hidden">
        {children}
      </div>
    )
  }

  // 2. FULL WORKSPACE MODE:
  // Render standard layout with Desktop Sidebar, Mobile Header, and scrollable Canvas
  return (
    <div className="flex h-screen overflow-hidden bg-[#F8FAFC]">
      {/* 1. Desktop Fixed Left Sidebar */}
      <Suspense fallback={<div className="hidden md:flex w-64 border-r border-slate-200 bg-white h-screen shrink-0" />}>
        <SellerSidebar 
          profile={profile}
          fullProfile={{ user: dbUser, company: profile }}
          userRole={userRole}
        />
      </Suspense>

      {/* 2. Main Content Canvas with Mobile Header */}
      <div className="flex-1 flex flex-col h-full overflow-hidden min-w-0">
        {/* Mobile Slim Top Header (md:hidden) */}
        <Suspense fallback={<div className="md:hidden h-16 w-full border-b border-slate-200 bg-white shrink-0" />}>
          <SellerMobileHeader 
            profile={profile}
            fullProfile={{ user: dbUser, company: profile }}
            userRole={userRole}
          />
        </Suspense>

        {/* Scrollable Main Viewport with Mobile Bottom Nav Padding */}
        <main className="flex-1 overflow-y-auto focus:outline-none bg-[#F8FAFC] pb-20 md:pb-6">
          {children}
        </main>
      </div>
    </div>
  )
}
