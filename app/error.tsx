'use client'

import { useEffect, useState } from "react"
import { AlertTriangle, RefreshCw, Home, ChevronDown, ChevronUp, Copy, Check } from "lucide-react"
import { Button } from "@/components/ui/button"

export default function RootError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  const [showDetails, setShowDetails] = useState(false)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    console.error("BrokerBridge Root Error:", error)
  }, [error])

  const copyError = () => {
    navigator.clipboard.writeText(error?.stack || error?.message || "Unknown error")
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div className="min-h-screen w-full bg-[#F8FAFC] flex flex-col items-center justify-center p-4 sm:p-6 font-sans">
      <div className="w-full max-w-lg bg-white rounded-2xl border border-slate-200/90 shadow-sm p-6 sm:p-8 text-center space-y-6">
        
        {/* Brand & Icon */}
        <div className="flex flex-col items-center">
          <div className="w-14 h-14 rounded-2xl bg-rose-50 border border-rose-100 flex items-center justify-center text-rose-600 mb-4 shadow-xs">
            <AlertTriangle className="w-7 h-7 stroke-[2.2]" />
          </div>
          <h1 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight">
            Something went wrong
          </h1>
          <p className="text-sm text-slate-500 mt-1.5 max-w-sm">
            We ran into an unexpected error while loading this page. You can try refreshing or returning to your dashboard.
          </p>
        </div>

        {/* Action Buttons */}
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

        {/* Error Diagnostics Drawer */}
        <div className="pt-2 border-t border-slate-100 text-left">
          <button
            onClick={() => setShowDetails(!showDetails)}
            className="flex items-center justify-between w-full text-xs font-semibold text-slate-500 hover:text-slate-800 transition-colors py-1 cursor-pointer"
          >
            <span>Error Diagnostic Info</span>
            {showDetails ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
          </button>

          {showDetails && (
            <div className="mt-3 p-3.5 bg-slate-50 rounded-xl border border-slate-200/80 text-xs font-mono space-y-2 relative">
              <div className="flex items-center justify-between text-slate-500 border-b border-slate-200 pb-2">
                <span className="font-semibold text-[11px]">Error Message</span>
                <button
                  onClick={copyError}
                  className="flex items-center gap-1 text-[11px] text-slate-600 hover:text-slate-900 cursor-pointer"
                >
                  {copied ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />}
                  <span>{copied ? "Copied" : "Copy"}</span>
                </button>
              </div>
              <p className="text-rose-600 font-semibold break-words">
                {error?.message || "Unknown error occurred"}
              </p>
              {error?.digest && (
                <p className="text-[10px] text-slate-400">Digest: {error.digest}</p>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
