import React from 'react'

export function RoleBadge({ role, className = "" }: { role: string, className?: string }) {
  const normalizedRole = role.toLowerCase()
  
  if (normalizedRole.includes("buyer")) {
    return <span className={`px-2.5 py-1 rounded-md text-[11px] uppercase tracking-wider font-bold bg-[#EFF6FF] text-[#1D4ED8] border border-[#BFDBFE] ${className}`}>Buyer</span>
  }
  if (normalizedRole.includes("broker")) {
    return <span className={`px-2.5 py-1 rounded-md text-[11px] uppercase tracking-wider font-bold bg-[#F0FDFA] text-[#0F766E] border border-[#99F6E4] ${className}`}>Broker</span>
  }
  if (normalizedRole.includes("seller")) {
    return <span className={`px-2.5 py-1 rounded-md text-[11px] uppercase tracking-wider font-bold bg-[#ECFDF5] text-[#047857] border border-[#A7F3D0] ${className}`}>Seller</span>
  }
  
  // Default fallback
  return <span className={`px-2.5 py-1 rounded-md text-[11px] uppercase tracking-wider font-bold bg-slate-100 text-slate-700 border border-slate-200 ${className}`}>{role}</span>
}
