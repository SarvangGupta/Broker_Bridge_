'use client';

import { useRealtimeDeals } from "@/src/hooks/use-realtime-deals";

export function RealtimeDealsListener() {
  useRealtimeDeals();
  
  // This is a headless component, it renders nothing.
  return null;
}
