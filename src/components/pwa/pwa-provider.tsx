'use client'

import React, { createContext, useContext, useEffect, useState, useCallback } from 'react'
import { toast } from 'sonner'

interface BeforeInstallPromptEvent extends Event {
  readonly platforms: string[]
  readonly userChoice: Promise<{
    outcome: 'accepted' | 'dismissed'
    platform: string
  }>
  prompt(): Promise<void>
}

interface PwaContextValue {
  isSupported: boolean
  isInstallable: boolean
  isInstalled: boolean
  isStandalone: boolean
  isIOS: boolean
  isAndroid: boolean
  platform: 'ios' | 'android' | 'desktop'
  promptInstall: () => Promise<boolean>
  showIosInstructions: boolean
  setShowIosInstructions: (show: boolean) => void
  swRegistered: boolean
}

const PwaContext = createContext<PwaContextValue | undefined>(undefined)

export function PwaProvider({ children }: { children: React.ReactNode }) {
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null)
  const [isInstallable, setIsInstallable] = useState(false)
  const [isInstalled, setIsInstalled] = useState(false)
  const [isStandalone, setIsStandalone] = useState(false)
  const [isIOS, setIsIOS] = useState(false)
  const [isAndroid, setIsAndroid] = useState(false)
  const [platform, setPlatform] = useState<'ios' | 'android' | 'desktop'>('desktop')
  const [showIosInstructions, setShowIosInstructions] = useState(false)
  const [swRegistered, setSwRegistered] = useState(false)
  const [isSupported, setIsSupported] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined') return

    // 1. Detect environment & platform
    const userAgent = window.navigator.userAgent || ''
    const iosDevice = /iPhone|iPad|iPod/i.test(userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
    const androidDevice = /Android/i.test(userAgent)

    setIsIOS(iosDevice)
    setIsAndroid(androidDevice)
    setPlatform(iosDevice ? 'ios' : androidDevice ? 'android' : 'desktop')

    // 2. Check if running in standalone mode (already installed & launched)
    const isStandaloneMode = 
      window.matchMedia('(display-mode: standalone)').matches ||
      (window.navigator as unknown as { standalone?: boolean }).standalone === true ||
      document.referrer.includes('android-app://')

    setIsStandalone(isStandaloneMode)
    if (isStandaloneMode) {
      setIsInstalled(true)
    }

    // 3. Register Service Worker
    if ('serviceWorker' in navigator) {
      setIsSupported(true)
      window.addEventListener('load', () => {
        navigator.serviceWorker
          .register('/sw.js', { scope: '/' })
          .then((reg) => {
            setSwRegistered(true)
            console.log('[PWA] Service Worker registered with scope:', reg.scope)

            // Check for service worker updates
            reg.onupdatefound = () => {
              const installingWorker = reg.installing
              if (installingWorker) {
                installingWorker.onstatechange = () => {
                  if (installingWorker.state === 'installed' && navigator.serviceWorker.controller) {
                    console.log('[PWA] New content is available; please refresh.')
                  }
                }
              }
            }
          })
          .catch((err) => {
            console.warn('[PWA] Service Worker registration failed:', err)
          })
      })
    }

    // 4. Capture native beforeinstallprompt event (Chromium, Android, Edge)
    const handleBeforeInstallPrompt = (e: Event) => {
      e.preventDefault()
      const promptEvent = e as BeforeInstallPromptEvent
      setDeferredPrompt(promptEvent)
      setIsInstallable(true)
      console.log('[PWA] beforeinstallprompt captured and ready')
    }

    // 5. Detect app installed event
    const handleAppInstalled = () => {
      console.log('[PWA] App successfully installed')
      setIsInstalled(true)
      setIsInstallable(false)
      setDeferredPrompt(null)
      toast.success('BrokerBridge App installed successfully!')
    }

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    window.addEventListener('appinstalled', handleAppInstalled)

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
      window.removeEventListener('appinstalled', handleAppInstalled)
    }
  }, [])

  const promptInstall = useCallback(async (): Promise<boolean> => {
    // If on iOS, show the guided instructions since Apple doesn't allow programmatic prompt()
    if (isIOS) {
      setShowIosInstructions(true)
      return true
    }

    // If deferred prompt is captured (Chrome / Android / Edge / Desktop)
    if (deferredPrompt) {
      try {
        await deferredPrompt.prompt()
        const choiceResult = await deferredPrompt.userChoice
        if (choiceResult.outcome === 'accepted') {
          console.log('[PWA] User accepted the install prompt')
          setIsInstalled(true)
          setIsInstallable(false)
          setDeferredPrompt(null)
          return true
        } else {
          console.log('[PWA] User dismissed the install prompt')
          return false
        }
      } catch (err) {
        console.error('[PWA] Error calling prompt():', err)
        return false
      }
    }

    // If already installed
    if (isInstalled || isStandalone) {
      toast.info('BrokerBridge is already installed on your device.')
      return true
    }

    // Fallback: If prompt is not yet available, show instructions
    setShowIosInstructions(true)
    return false
  }, [deferredPrompt, isIOS, isInstalled, isStandalone])

  return (
    <PwaContext.Provider
      value={{
        isSupported,
        isInstallable,
        isInstalled,
        isStandalone,
        isIOS,
        isAndroid,
        platform,
        promptInstall,
        showIosInstructions,
        setShowIosInstructions,
        swRegistered,
      }}
    >
      {children}
    </PwaContext.Provider>
  )
}

export function usePwa() {
  const context = useContext(PwaContext)
  if (!context) {
    throw new Error('usePwa must be used within a PwaProvider')
  }
  return context
}
