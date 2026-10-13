import React from 'react';
import { verifyBuyerSession } from '@/src/server/utils/buyer-auth';
import { BuyerSidebar } from '@/src/components/buyer/dashboard/buyer-sidebar';
import { BuyerMobileNav } from '@/src/components/buyer/dashboard/buyer-mobile-nav';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function BuyerLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const sessionRes = await verifyBuyerSession();

  // If session verification fails or user is not linked to a valid company, render in basic centered layout
  if (!sessionRes.success || !sessionRes.data?.company) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#F8FAFC] px-4 py-12">
        {children}
      </div>
    );
  }

  const { user, company } = sessionRes.data;

  return (
    <div className="fixed inset-0 flex h-dvh overflow-hidden bg-[#F8FAFC] w-full max-w-full">
      {/* Desktop Sidebar (md:flex) */}
      <BuyerSidebar user={user} company={company} />

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col h-full overflow-hidden min-w-0">
        {/* Mobile Nav Header (md:hidden) */}
        <BuyerMobileNav user={user} company={company} />

        {/* Scrollable Viewport Main Container */}
        <main className="flex-1 overflow-y-auto pb-16 md:pb-0 w-full max-w-full">
          {children}
        </main>
      </div>
    </div>
  );
}
