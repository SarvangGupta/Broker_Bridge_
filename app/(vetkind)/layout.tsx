import React from 'react';
import { VetKindHeader } from '@/src/components/vetkind/vetkind-header';
import { VetKindFooter } from '@/src/components/vetkind/vetkind-footer';

export const metadata = {
  title: 'VetKind Animal Health India | Veterinary Therapeutics & Dairy Nutrition',
  description:
    'Dedicated to advanced animal healthcare, bovine therapeutics, and dairy sector productivity across India. ISO 9001 and GMP certified veterinary solutions.',
};

export default function VetKindLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen flex flex-col bg-slate-50/50 text-slate-900 selection:bg-emerald-100 selection:text-emerald-900">
      <VetKindHeader />
      <main className="flex-1 w-full max-w-full overflow-x-hidden">
        {children}
      </main>
      <VetKindFooter />
    </div>
  );
}
