import React from 'react';
import { createClient } from '@/lib/supabase/server';
import { db } from '@/src/server/db';
import { users, companies } from '@/src/server/db/schema';
import { eq } from 'drizzle-orm';
import { BrokerSidebar } from '@/src/components/dashboard/broker-sidebar';
import { BrokerMobileNav } from '@/src/components/dashboard/broker-mobile-nav';

export const dynamic = 'force-dynamic';

export default async function BrokerLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  let currentUser = null;
  let companyName = null;

  try {
    const supabase = await createClient();
    const {
      data: { user: authUser },
    } = await supabase.auth.getUser();

    if (authUser) {
      const dbUser = await db.query.users.findFirst({
        where: eq(users.id, authUser.id),
      });

      if (dbUser) {
        currentUser = {
          id: dbUser.id,
          name: dbUser.name || authUser.user_metadata?.name || 'Broker Partner',
          email: dbUser.email || authUser.email || null,
          role: dbUser.role || 'broker',
        };

        if (dbUser.companyId) {
          const comp = await db.query.companies.findFirst({
            where: eq(companies.id, dbUser.companyId),
          });
          if (comp) {
            companyName = comp.name;
          }
        }
      } else {
        currentUser = {
          id: authUser.id,
          name: authUser.user_metadata?.name || authUser.email?.split('@')[0] || 'Broker Partner',
          email: authUser.email || null,
          role: 'broker',
        };
      }
    }
  } catch (error) {
    console.error('Error loading broker layout session:', error);
  }

  return (
    <div className="flex h-screen overflow-hidden bg-[#F8FAFC]">
      {/* 1. Desktop Left Sidebar (hidden on mobile) */}
      <BrokerSidebar user={currentUser} companyName={companyName} />

      {/* 2. Main Scrollable Canvas with Mobile Header & Bottom Bar */}
      <main className="flex-1 overflow-y-auto pb-16 md:pb-0 flex flex-col h-full min-w-0 bg-[#F8FAFC]">
        {/* Mobile Header & Bottom Navigation Bar (md:hidden) */}
        <BrokerMobileNav user={currentUser} />

        {/* Page Viewport */}
        <div className="flex-1 w-full max-w-full overflow-x-hidden">
          {children}
        </div>
      </main>
    </div>
  );
}
