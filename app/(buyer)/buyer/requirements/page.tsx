import React from 'react';
import { ClipboardList } from 'lucide-react';
import { SprintPlaceholder } from '@/src/components/ui/sprint-placeholder';

export const dynamic = 'force-dynamic';

export default function BuyerRequirementsPage() {
  return (
    <SprintPlaceholder
      title="Requirements Module"
      sprintName="Coming in Sprint 33: Requirements (Create & Manage)"
      description="You will be able to create, edit, and track procurement requirements here."
      icon={<ClipboardList className="w-7 h-7 text-[#0284C7]" />}
    />
  );
}
