'use client'

import React, { useState } from 'react'
import Image from 'next/image'
import { 
  Download, 
  Smartphone, 
  CheckCircle2, 
  Share, 
  PlusSquare, 
  Sparkles, 
  Zap, 
  ShieldCheck, 
  WifiOff, 
  ChevronRight,
  ExternalLink,
  Laptop
} from 'lucide-react'
import { Button } from "@/components/ui/button"
import { usePwa } from "@/src/components/pwa/pwa-provider"
import { toast } from "sonner"

interface PwaInstallCardProps {
  role?: 'BUYER' | 'SELLER' | 'BROKER' | 'ADMIN'
  compact?: boolean
}

export function PwaInstallCard({ role, compact = false }: PwaInstallCardProps) {
  const { 
    isInstallable, 
    isInstalled, 
    isStandalone, 
    isIOS, 
    isAndroid, 
    platform, 
    promptInstall,
    showIosInstructions,
    setShowIosInstructions
  } = usePwa()

  const [installing, setInstalling] = useState(false)
  const [showManualGuide, setShowManualGuide] = useState(false)

  const handleInstallClick = async () => {
    setInstalling(true)
    try {
      const result = await promptInstall()
      if (result) {
        toast.success("Install prompt initiated")
      }
    } catch (err) {
      console.error(err)
      toast.error("Could not trigger installation prompt")
    } finally {
      setInstalling(false)
    }
  }

  const roleLabel = role 
    ? role === 'SELLER' ? 'Seller Workspace' 
    : role === 'BUYER' ? 'Buyer Workspace' 
    : role === 'BROKER' ? 'Broker Desk' 
    : 'Admin Console'
    : 'Enterprise Platform'

  return (
    <div className="w-full space-y-4">
      {/* Primary Card */}
      <div className="relative overflow-hidden rounded-2xl border border-slate-200 bg-linear-to-b from-white to-slate-50/60 p-5 sm:p-6 shadow-xs">
        {/* Subtle decorative background gradient */}
        <div className="absolute -top-12 -right-12 w-48 h-48 bg-emerald-500/10 rounded-full blur-2xl pointer-events-none" />

        {/* Top Header */}
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-center gap-3.5">
            <div className="relative w-12 h-12 rounded-xl bg-slate-900 flex items-center justify-center shadow-md shrink-0 border border-slate-800 text-white font-black text-base tracking-tighter">
              <span className="bg-linear-to-tr from-emerald-400 to-teal-200 bg-clip-text text-transparent">
                BB
              </span>
              <div className="absolute -bottom-1 -right-1 w-4 h-4 rounded-full bg-emerald-500 border-2 border-white flex items-center justify-center">
                <Sparkles className="w-2.5 h-2.5 text-white" />
              </div>
            </div>

            <div>
              <div className="flex items-center gap-2">
                <h3 className="font-bold text-slate-900 text-base leading-tight">
                  BrokerBridge App
                </h3>
                {isInstalled || isStandalone ? (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                    <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                    Installed
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-medium bg-slate-100 text-slate-600 border border-slate-200">
                    PWA v1.0
                  </span>
                )}
              </div>
              <p className="text-xs text-slate-500 mt-0.5">
                Optimized for {roleLabel} on Mobile & Desktop
              </p>
            </div>
          </div>

          <div className="hidden sm:flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-100/80 text-[11px] font-medium text-slate-600">
            {platform === 'ios' ? (
              <>
                <Smartphone className="w-3.5 h-3.5 text-slate-500" />
                iOS Device
              </>
            ) : platform === 'android' ? (
              <>
                <Smartphone className="w-3.5 h-3.5 text-emerald-600" />
                Android Device
              </>
            ) : (
              <>
                <Laptop className="w-3.5 h-3.5 text-slate-500" />
                Desktop
              </>
            )}
          </div>
        </div>

        {/* Status & Action */}
        <div className="mt-5 pt-4 border-t border-slate-100">
          {isInstalled || isStandalone ? (
            <div className="p-4 rounded-xl bg-emerald-50/80 border border-emerald-200 flex items-start gap-3">
              <div className="w-8 h-8 rounded-lg bg-emerald-100 text-emerald-700 flex items-center justify-center shrink-0 mt-0.5">
                <CheckCircle2 className="w-4 h-4" />
              </div>
              <div className="space-y-1">
                <p className="text-sm font-semibold text-emerald-950">
                  Application Is Installed & Active
                </p>
                <p className="text-xs text-emerald-800 leading-relaxed">
                  BrokerBridge is running as a standalone progressive web application. You can launch it directly from your device home screen or desktop application drawer with offline resilience and hardware-accelerated responsiveness.
                </p>
              </div>
            </div>
          ) : (
            <div className="space-y-3">
              <p className="text-xs text-slate-600 leading-relaxed">
                Install BrokerBridge directly on your phone or computer. Enjoy a fast, full-screen native experience with zero storage overhead and instant offline capability.
              </p>

              <div className="flex flex-col sm:flex-row gap-2.5">
                <Button
                  onClick={handleInstallClick}
                  disabled={installing}
                  size="lg"
                  className="w-full sm:w-auto flex-1 bg-[#059669] hover:bg-[#047857] text-white font-semibold py-2.5 px-5 rounded-xl shadow-xs transition-all active:scale-[0.99] flex items-center justify-center gap-2"
                >
                  <Download className="w-4 h-4" />
                  {isIOS ? 'Show iOS Install Instructions' : 'Install App on This Device'}
                </Button>

                {!isIOS && !isInstallable && (
                  <Button
                    variant="outline"
                    size="lg"
                    onClick={() => setShowManualGuide(!showManualGuide)}
                    className="w-full sm:w-auto text-slate-700 border-slate-200 rounded-xl"
                  >
                    Installation Help
                  </Button>
                )}
              </div>
            </div>
          )}
        </div>

        {/* iOS Step-by-Step Guide Accordion / Banner */}
        {(isIOS || showIosInstructions) && !isInstalled && (
          <div className="mt-4 p-4 rounded-xl bg-slate-900 text-white shadow-md animate-in fade-in slide-in-from-top-2 duration-300">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2">
                <Smartphone className="w-4 h-4 text-emerald-400" />
                <span className="text-sm font-bold tracking-tight">
                  How to Install on iPhone / iPad (Safari)
                </span>
              </div>
              <button
                type="button"
                onClick={() => setShowIosInstructions(false)}
                className="text-xs text-slate-400 hover:text-white transition-colors"
              >
                Close
              </button>
            </div>

            <ol className="mt-3 space-y-2.5 text-xs text-slate-300">
              <li className="flex items-start gap-2.5">
                <span className="w-5 h-5 rounded-full bg-slate-800 text-emerald-400 font-bold flex items-center justify-center shrink-0 text-[11px]">
                  1
                </span>
                <span>
                  Tap the <strong className="text-white">Share</strong> button{' '}
                  <Share className="w-3.5 h-3.5 inline mx-1 text-sky-400" /> at the bottom of Safari toolbar.
                </span>
              </li>
              <li className="flex items-start gap-2.5">
                <span className="w-5 h-5 rounded-full bg-slate-800 text-emerald-400 font-bold flex items-center justify-center shrink-0 text-[11px]">
                  2
                </span>
                <span>
                  Scroll down the share sheet and tap{' '}
                  <strong className="text-white">"Add to Home Screen"</strong>{' '}
                  <PlusSquare className="w-3.5 h-3.5 inline mx-1 text-emerald-400" />.
                </span>
              </li>
              <li className="flex items-start gap-2.5">
                <span className="w-5 h-5 rounded-full bg-slate-800 text-emerald-400 font-bold flex items-center justify-center shrink-0 text-[11px]">
                  3
                </span>
                <span>
                  Tap <strong className="text-white">"Add"</strong> in the top-right corner. The BrokerBridge app icon will appear on your phone home screen!
                </span>
              </li>
            </ol>
          </div>
        )}

        {/* Manual guide for desktop/android when prompt is not pre-triggered */}
        {showManualGuide && !isIOS && !isInstalled && (
          <div className="mt-4 p-4 rounded-xl bg-slate-50 border border-slate-200 text-slate-700 text-xs space-y-2 animate-in fade-in duration-200">
            <p className="font-semibold text-slate-900 flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-emerald-600" />
              Direct Browser Installation
            </p>
            <p>
              If the automatic install pop-up doesn't display immediately:
            </p>
            <ul className="list-disc pl-4 space-y-1 text-slate-600">
              <li>
                <strong>Google Chrome (Android / Desktop):</strong> Tap the <strong>three dots (⋮)</strong> in the top-right corner and select <strong>"Install BrokerBridge"</strong> or <strong>"Add to Home screen"</strong>.
              </li>
              <li>
                <strong>Microsoft Edge:</strong> Click the app installation icon in the right side of the address bar, or go to Menu (⋯) &rarr; Apps &rarr; <strong>"Install BrokerBridge"</strong>.
              </li>
              <li>
                <strong>Samsung Internet:</strong> Tap the menu icon (&equiv;) at the bottom and tap <strong>"+ Add page to"</strong> &rarr; <strong>"Home screen"</strong>.
              </li>
            </ul>
          </div>
        )}

        {/* Value Proposition Features */}
        {!compact && (
          <div className="mt-5 pt-4 border-t border-slate-100 grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div className="flex items-start gap-2.5 p-2.5 rounded-lg bg-slate-50/70 border border-slate-100">
              <Zap className="w-4 h-4 text-emerald-600 shrink-0 mt-0.5" />
              <div>
                <span className="font-semibold text-slate-900 block">Instant 1-Tap Launch</span>
                <span className="text-slate-500">Opens directly like a native app without typing URLs.</span>
              </div>
            </div>

            <div className="flex items-start gap-2.5 p-2.5 rounded-lg bg-slate-50/70 border border-slate-100">
              <WifiOff className="w-4 h-4 text-sky-600 shrink-0 mt-0.5" />
              <div>
                <span className="font-semibold text-slate-900 block">Offline Resilience</span>
                <span className="text-slate-500">Smart cached shell ensures seamless trade operations.</span>
              </div>
            </div>

            <div className="flex items-start gap-2.5 p-2.5 rounded-lg bg-slate-50/70 border border-slate-100">
              <ShieldCheck className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
              <div>
                <span className="font-semibold text-slate-900 block">Zero App Store Updates</span>
                <span className="text-slate-500">Always runs the latest enterprise version automatically.</span>
              </div>
            </div>

            <div className="flex items-start gap-2.5 p-2.5 rounded-lg bg-slate-50/70 border border-slate-100">
              <Smartphone className="w-4 h-4 text-purple-600 shrink-0 mt-0.5" />
              <div>
                <span className="font-semibold text-slate-900 block">Maximized Workspace</span>
                <span className="text-slate-500">Full-screen display with zero browser address bar clutter.</span>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
