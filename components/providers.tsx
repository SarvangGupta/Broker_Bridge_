'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'
import { PwaProvider } from '@/src/components/pwa/pwa-provider'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            refetchOnWindowFocus: true, // ensure it refetches when switching tabs
          },
        },
      })
  )

  return (
    <QueryClientProvider client={queryClient}>
      <PwaProvider>
        {children}
      </PwaProvider>
    </QueryClientProvider>
  )
}

