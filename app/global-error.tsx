'use client'

import { useEffect, useState } from "react"
import { AlertTriangle, RefreshCw, Home } from "lucide-react"
import { Button } from "@/components/ui/button"

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error("BrokerBridge Global Error:", error)
  }, [error])

  return (
    <html lang="en">
      <body className="min-h-screen w-full bg-[#F8FAFC] flex flex-col items-center justify-center p-4 sm:p-6 font-sans">
        <div className="w-full max-w-lg bg-white rounded-2xl border border-slate-200/90 shadow-sm p-6 sm:p-8 text-center space-y-6">
          <div className="flex flex-col items-center">
            <div className="w-14 h-14 rounded-2xl bg-rose-50 border border-rose-100 flex items-center justify-center text-rose-600 mb-4 shadow-xs">
              <AlertTriangle className="w-7 h-7 stroke-[2.2]" />
            </div>
            <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
              Application Error
            </h1>
            <p className="text-sm text-slate-500 mt-1.5 max-w-sm">
              A critical error occurred. Please try reloading the application.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-1">
            <Button
              onClick={() => reset()}
              className="w-full sm:w-auto min-h-[44px] bg-slate-900 hover:bg-slate-800 text-white font-semibold rounded-xl px-5 text-sm gap-2 shadow-xs cursor-pointer"
            >
              <RefreshCw className="w-4 h-4" />
              Try Again
            </Button>
            <Button
              variant="outline"
              onClick={() => window.location.href = "/"}
              className="w-full sm:w-auto min-h-[44px] border-slate-200 text-slate-700 hover:bg-slate-50 font-semibold rounded-xl px-5 text-sm gap-2 cursor-pointer"
            >
              <Home className="w-4 h-4" />
              Go to Dashboard
            </Button>
          </div>
        </div>
      </body>
    </html>
  )
}
