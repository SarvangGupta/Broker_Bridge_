import React from 'react';
import { Handshake } from 'lucide-react';
import { SprintPlaceholder } from '@/src/components/ui/sprint-placeholder';

export const dynamic = 'force-dynamic';

export default function BuyerProposalsPage() {
  return (
    <SprintPlaceholder
      title="Broker Proposals"
      sprintName="Coming in Sprint 35: Broker Proposals"
      description="You will review, compare, and respond to Broker-mediated proposals here."
      icon={<Handshake className="w-7 h-7 text-[#0284C7]" />}
    />
  );
}
