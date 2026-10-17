import { getCompanyProfile } from '@/src/server/actions/company-actions';
import { BuyerSidebar } from '@/src/components/buyer/dashboard/buyer-sidebar';
import { BuyerMobileNav } from '@/src/components/buyer/dashboard/buyer-mobile-nav';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function BuyerLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const profileRes = await getCompanyProfile();
  const profile = profileRes.success && profileRes.data ? profileRes.data : null;
  const dbUser = profileRes.user || null;
  const onboardingStatus = profileRes.status || 'NONE';
  const isApproved = onboardingStatus === 'APPROVED' && Boolean(profile?.id);

  // If user does not have a company or is NOT approved yet (NONE / PENDING / REJECTED),
  // render in focus mode centered layout without sidebar navigation
  if (!isApproved || !profile || !dbUser) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#F8FAFC] px-4 py-12 w-full overflow-x-hidden">
        {children}
      </div>
    );
  }

  const user = dbUser;
  const company = profile;

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
