"use client"

import { useState } from "react"
import { signUpAction } from "@/src/server/actions/auth-actions"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Label } from "@/components/ui/label"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { Eye, EyeOff, Loader2, ArrowRight } from "lucide-react"

import { toast } from "sonner"

export default function RegisterPage() {
  const router = useRouter()
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  // Default to buyer (Invite-only broker model)
  const [role, setRole] = useState<"buyer" | "seller">("buyer")

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setIsLoading(true)
    setError(null)
    
    const formData = new FormData(e.currentTarget)
    // Map the human-readable selection to the backend enum string
    formData.set("role", role)
    
    const result = await signUpAction(formData)
    
    if (result?.error) {
      setError(result.error)
      toast.error(result.error)
      setIsLoading(false)
    } else if (result?.success) {
      toast.success(result.success)
      // Keep isLoading(true) to prevent button clicking again while navigating
      router.push("/login")
    }
  }

  return (
    <div className="flex min-h-screen bg-white">
      {/* Left side: Branding (Hidden on mobile, ~55% width on desktop) */}
      <div className="hidden md:flex md:w-[55%] flex-col justify-between bg-[#F7F8FA] p-12 lg:p-20 xl:p-24 relative overflow-hidden">
        
        {/* Minimal SVG Bridge Motif Background */}
        <div className="absolute inset-0 z-0 pointer-events-none flex items-center justify-center opacity-70">
          <svg className="w-full h-full max-w-2xl text-slate-300" viewBox="0 0 600 400" fill="none" xmlns="http://www.w3.org/2000/svg">
            {/* The Bridge Line */}
            <path d="M 150 200 L 450 200" stroke="currentColor" strokeWidth="1.5" strokeDasharray="4 4" />
            
            {/* Nodes */}
            <circle cx="150" cy="200" r="6" fill="#F7F8FA" stroke="currentColor" strokeWidth="2" />
            <circle cx="450" cy="200" r="6" fill="#F7F8FA" stroke="currentColor" strokeWidth="2" />
            
            {/* Center Node */}
            <circle cx="300" cy="200" r="14" fill="white" stroke="#0f172a" strokeWidth="3" />
            <circle cx="300" cy="200" r="4" fill="#0f172a" />

            {/* Labels */}
            <text x="150" y="176" fill="currentColor" fontSize="13" fontFamily="sans-serif" fontWeight="600" textAnchor="middle" letterSpacing="0.15em">BUYER</text>
            <text x="450" y="176" fill="currentColor" fontSize="13" fontFamily="sans-serif" fontWeight="600" textAnchor="middle" letterSpacing="0.15em">SELLER</text>
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
            Build better connections.
          </h1>
          <p className="text-lg text-slate-600 mt-6 max-w-md font-medium leading-relaxed">
            Join Broker Bridge to connect with the right businesses, buyers, and sellers.
          </p>
        </div>

        <div className="relative z-10 mt-auto text-sm text-slate-500 font-medium">
          © {new Date().getFullYear()} BrokerBridge Enterprise. All rights reserved.
        </div>
      </div>

      {/* Right side: Auth Form (~45% width on desktop, 100% on mobile) */}
      <div className="w-full md:w-[45%] flex items-center justify-center p-4 sm:p-8 md:p-12 bg-white relative">
        <div className="w-full max-w-[440px] bg-white rounded-[20px] shadow-[0_8px_30px_rgb(0,0,0,0.04)] border border-slate-100 p-8 sm:p-10 mx-auto">
          <div className="mb-8 text-center sm:text-left">
            <h2 className="text-2xl sm:text-3xl font-semibold tracking-tight text-slate-900">Create your account</h2>
            <p className="text-sm text-slate-500 mt-2">Join Broker Bridge and start connecting.</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            {error && (
              <div className="bg-red-50 text-red-600 text-sm p-4 rounded-xl border border-red-100 font-medium">
                {error}
              </div>
            )}

            {/* Segmented Control for Account Type (Buyer / Seller) */}
            <div className="space-y-2">
              <Label className="text-slate-700 font-medium text-sm">Account Type</Label>
              <div className="flex p-1 bg-slate-100 rounded-xl">
                <button
                  type="button"
                  onClick={(e) => {
                    e.preventDefault();
                    setRole("buyer");
                  }}
                  className={`relative z-10 flex-1 h-12 text-sm font-semibold rounded-lg transition-all cursor-pointer touch-manipulation ${
                    role === "buyer" 
                      ? "bg-white text-slate-900 shadow-sm border border-slate-200/50" 
                      : "text-slate-500 hover:text-slate-700"
                  }`}
                >
                  Buyer
                </button>
                <button
                  type="button"
                  onClick={(e) => {
                    e.preventDefault();
                    setRole("seller");
                  }}
                  className={`relative z-10 flex-1 h-12 text-sm font-semibold rounded-lg transition-all cursor-pointer touch-manipulation ${
                    role === "seller" 
                      ? "bg-white text-slate-900 shadow-sm border border-slate-200/50" 
                      : "text-slate-500 hover:text-slate-700"
                  }`}
                >
                  Seller
                </button>
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="name" className="text-slate-700 font-medium text-sm">Full Name</Label>
              <Input 
                id="name" 
                name="name" 
                placeholder="John Doe" 
                required 
                className="h-14 rounded-xl bg-slate-50 border-slate-200 focus:bg-white text-base px-4 transition-colors"
              />
            </div>

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
              <Label htmlFor="password" className="text-slate-700 font-medium text-sm">Password</Label>
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
              className="w-full h-14 rounded-xl text-base font-semibold mt-4 bg-slate-900 hover:bg-slate-800 text-white shadow-sm transition-all active:scale-[0.98] group" 
              disabled={isLoading}
            >
              {isLoading ? (
                <>
                  <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                  Creating account...
                </>
              ) : (
                <>
                  Create account
                  <ArrowRight className="ml-2 h-5 w-5 group-hover:translate-x-1 transition-transform" />
                </>
              )}
            </Button>

            <div className="text-center mt-8 text-sm text-slate-500 font-medium">
              Already have an account?{" "}
              <Link href="/login" className="text-slate-900 hover:text-blue-600 transition-colors">
                Sign in
              </Link>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}
