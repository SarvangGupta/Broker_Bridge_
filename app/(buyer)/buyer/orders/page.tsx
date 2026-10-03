import React from 'react';
import { Truck } from 'lucide-react';
import { SprintPlaceholder } from '@/src/components/ui/sprint-placeholder';

export const dynamic = 'force-dynamic';

export default function BuyerOrdersPage() {
  return (
    <SprintPlaceholder
      title="Orders & Logistics"
      sprintName="Coming in Sprint 38: Orders, Booking & Delivery"
      description="Track your active dispatch lifecycle, vehicle details, and delivery ETAs."
      icon={<Truck className="w-7 h-7 text-[#0284C7]" />}
    />
  );
}
