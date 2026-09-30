'use client'

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { LogOut, Loader2 } from "lucide-react"
import { createClient } from "@/lib/supabase/client"
import { signOutAction } from "@/src/server/actions/auth-actions"

interface SignOutButtonProps {
  className?: string
  variant?: "ghost" | "outline" | "default" | "destructive" | "secondary" | "link"
  size?: "default" | "sm" | "lg" | "icon"
  children?: React.ReactNode
}

export function SignOutButton({
  className = "text-slate-500 hover:text-slate-900 text-xs font-medium",
  variant = "ghost",
  size = "sm",
  children
}: SignOutButtonProps) {
  const [loading, setLoading] = useState(false)

  const handleSignOut = async () => {
    try {
      setLoading(true)
      const supabase = createClient()
      await supabase.auth.signOut()
      await signOutAction().catch(() => {})
      window.location.href = "/login"
    } catch (err) {
      console.error("Sign out error:", err)
      window.location.href = "/login"
    }
  }

  return (
    <Button
      type="button"
      variant={variant}
      size={size}
      onClick={handleSignOut}
      disabled={loading}
      className={className}
    >
      {loading ? (
        <>
          <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
          Signing out...
        </>
      ) : (
        children || (
          <>
            <LogOut className="mr-1.5 h-3.5 w-3.5" />
            Sign out of session
          </>
        )
      )}
    </Button>
  )
}
