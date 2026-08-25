import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatIndianCurrency(amount: number): string {
  if (isNaN(amount) || amount === null || amount === undefined) return "₹0"
  
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(amount)
}

export function formatNumber(count: number): string {
  if (isNaN(count) || count === null || count === undefined) return "0"
  return new Intl.NumberFormat('en-IN').format(count)
}
