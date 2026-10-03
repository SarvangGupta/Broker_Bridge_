import React from 'react';
import { SlidersHorizontal } from 'lucide-react';
import { SprintPlaceholder } from '@/src/components/ui/sprint-placeholder';

export const dynamic = 'force-dynamic';

export default function BuyerMorePage() {
  return (
    <SprintPlaceholder
      title="Additional Tools"
      sprintName="Coming in Sprint 39: Quality, Payments & Disputes"
      description="Access transaction documents, view payable ledger, and manage disputes."
      icon={<SlidersHorizontal className="w-7 h-7 text-[#0284C7]" />}
    />
  );
}
