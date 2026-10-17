"use client"

import { useState, Suspense } from "react"
import { signInAction } from "@/src/server/actions/auth-actions"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import Link from "next/link"
import { useRouter, useSearchParams } from "next/navigation"
import { Eye, EyeOff, Loader2 } from "lucide-react"

import { toast } from "sonner"

function LoginForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const urlError = searchParams.get("error")
  const isRegistered = searchParams.get("registered") === "true"
  
  const [error, setError] = useState<string | null>(urlError === "invalid_role" ? "Your account role is invalid or missing. Please contact support." : urlError)
  const [isLoading, setIsLoading] = useState(false)
  const [showPassword, setShowPassword] = useState(false)

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setIsLoading(true)
    setError(null)
    
    const formData = new FormData(e.currentTarget)
    const result = await signInAction(formData)
    
    if (result?.error) {
      setError(result.error)
      toast.error(result.error)
      setIsLoading(false)
    } else if (result?.success) {
      toast.success(result.success)
      
      if (result.redirectUrl) {
        window.location.href = result.redirectUrl
      } else {
        window.location.href = "/"
      }
    }
  }

  return (
    <div className="w-full max-w-[440px] bg-white rounded-[20px] shadow-[0_8px_30px_rgb(0,0,0,0.04)] border border-slate-100 p-8 sm:p-10 mx-auto">
      <div className="mb-8 text-center sm:text-left">
        <h2 className="text-2xl sm:text-3xl font-semibold tracking-tight text-slate-900">Welcome back</h2>
        <p className="text-sm text-slate-500 mt-2">Sign in to continue to BrokerBridge.</p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-5">
        {isRegistered && !error && (
          <div className="bg-emerald-50 text-emerald-800 text-sm p-4 rounded-xl border border-emerald-200 font-medium">
            Account created successfully! Please sign in with your email and password.
          </div>
        )}

        {error && (
          <div className="bg-red-50 text-red-600 text-sm p-4 rounded-xl border border-red-100 font-medium">
            {error}
          </div>
        )}
        
        <div className="space-y-2">
          <Label htmlFor="email" className="text-slate-700 font-medium text-sm">Email address</Label>
          <Input 
            id="email" 
            name="email" 
            type="email" 
            placeholder="name@company.com" 
            required 
            className="h-14 rounded-xl bg-slate-50 border-slate-200 focus:bg-white text-base px-4 transition-colors" 
          />
        </div>
        
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="password" className="text-slate-700 font-medium text-sm">Password</Label>
          </div>
          <div className="relative">
            <Input 
              id="password" 
              name="password" 
              type={showPassword ? "text" : "password"} 
              required 
              className="h-14 rounded-xl bg-slate-50 border-slate-200 focus:bg-white text-base px-4 pr-12 transition-colors"
            />
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="absolute right-1 top-1.5 h-11 w-11 hover:bg-slate-100 rounded-lg text-slate-400 hover:text-slate-600"
              onClick={() => setShowPassword((prev) => !prev)}
            >
              {showPassword ? (
                <EyeOff className="h-5 w-5" />
              ) : (
                <Eye className="h-5 w-5" />
              )}
              <span className="sr-only">
                {showPassword ? "Hide password" : "Show password"}
              </span>
            </Button>
          </div>
        </div>

        <Button 
          type="submit" 
          className="w-full h-14 rounded-xl text-base font-semibold mt-4 bg-slate-900 hover:bg-slate-800 text-white shadow-sm transition-all active:scale-[0.98]" 
          disabled={isLoading}
        >
          {isLoading ? (
            <>
              <Loader2 className="mr-2 h-5 w-5 animate-spin" />
              Signing in...
            </>
          ) : (
            "Sign in to account"
          )}
        </Button>

        <div className="text-center mt-8 text-sm text-slate-500 font-medium">
          Don't have an account?{" "}
          <Link href="/register" className="text-slate-900 hover:text-blue-600 transition-colors">
            Create an account
          </Link>
        </div>
      </form>
    </div>
  )
}

export default function LoginPage() {
  return (
    <div className="flex min-h-screen bg-white">
      {/* Left side: Branding (Hidden on mobile, ~55% width on desktop) */}
      <div className="hidden md:flex md:w-[55%] flex-col justify-between bg-[#F7F8FA] p-12 lg:p-20 xl:p-24 relative overflow-hidden">
        
        {/* Subtle SVG Connection Graphic Background */}
        <div className="absolute inset-0 z-0 pointer-events-none flex items-center justify-center opacity-60">
          <svg className="w-full h-full max-w-3xl text-slate-300" viewBox="0 0 600 400" fill="none" xmlns="http://www.w3.org/2000/svg">
            {/* Connection Lines */}
            <path d="M100 150 C 250 150 250 200 300 200" stroke="currentColor" strokeWidth="1.5" strokeDasharray="6 6" />
            <path d="M100 250 C 250 250 250 200 300 200" stroke="currentColor" strokeWidth="1.5" strokeDasharray="6 6" />
            <path d="M300 200 C 350 200 350 150 500 150" stroke="currentColor" strokeWidth="1.5" strokeDasharray="6 6" />
            <path d="M300 200 C 350 200 350 250 500 250" stroke="currentColor" strokeWidth="1.5" strokeDasharray="6 6" />
            
            {/* Buyer Nodes */}
            <g className="text-slate-400">
              <circle cx="100" cy="150" r="6" fill="#F7F8FA" stroke="currentColor" strokeWidth="2" />
              <circle cx="100" cy="250" r="6" fill="#F7F8FA" stroke="currentColor" strokeWidth="2" />
              <text x="80" y="154" fill="currentColor" fontSize="12" fontFamily="sans-serif" fontWeight="500" textAnchor="end">Buyer A</text>
              <text x="80" y="254" fill="currentColor" fontSize="12" fontFamily="sans-serif" fontWeight="500" textAnchor="end">Buyer B</text>
            </g>

            {/* Seller Nodes */}
            <g className="text-slate-400">
              <circle cx="500" cy="150" r="6" fill="#F7F8FA" stroke="currentColor" strokeWidth="2" />
              <circle cx="500" cy="250" r="6" fill="#F7F8FA" stroke="currentColor" strokeWidth="2" />
              <text x="520" y="154" fill="currentColor" fontSize="12" fontFamily="sans-serif" fontWeight="500" textAnchor="start">Seller X</text>
              <text x="520" y="254" fill="currentColor" fontSize="12" fontFamily="sans-serif" fontWeight="500" textAnchor="start">Seller Y</text>
            </g>

            {/* Center BrokerBridge Node */}
            <circle cx="300" cy="200" r="16" fill="white" stroke="#0f172a" strokeWidth="3" />
            <circle cx="300" cy="200" r="5" fill="#0f172a" />
          </svg>
        </div>

        <div className="relative z-10">
          <div className="flex items-center gap-3 mb-24">
            <div className="w-10 h-10 rounded-xl bg-slate-900 flex items-center justify-center shadow-md">
              <span className="text-white font-bold text-xl leading-none tracking-tighter">BB</span>
            </div>
            <span className="text-2xl font-bold tracking-tight text-slate-900">BrokerBridge</span>
          </div>
          <h1 className="text-4xl lg:text-5xl font-semibold tracking-tight text-slate-900 leading-[1.1] max-w-lg">
            The bridge between buyers and sellers.
          </h1>
          <p className="text-lg text-slate-600 mt-6 max-w-md font-medium leading-relaxed">
            Enterprise-grade matching, seamless negotiation, and dispute resolution—all in one secure marketplace.
          </p>
        </div>

        <div className="relative z-10 mt-auto text-sm text-slate-500 font-medium">
          © {new Date().getFullYear()} BrokerBridge Enterprise. All rights reserved.
        </div>
      </div>

      {/* Right side: Auth Form (~45% width on desktop, 100% on mobile) */}
      <div className="w-full md:w-[45%] flex items-center justify-center p-4 sm:p-8 md:p-12 bg-white relative">
        <Suspense fallback={
          <div className="w-full max-w-[440px] h-[500px] animate-pulse bg-slate-50 rounded-[20px] border border-slate-100" />
        }>
          <LoginForm />
        </Suspense>
      </div>
    </div>
  )
}
