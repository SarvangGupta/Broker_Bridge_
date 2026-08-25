import { useState, useEffect } from "react"
import { differenceInMinutes, differenceInHours, differenceInDays } from "date-fns"

export interface SLAInfo {
  text: string
  isUrgent: boolean
  isOverdue: boolean
  diffHours: number
  diffDays: number
  diffMinutes: number
}

export function calculateSLA(date: Date | string | null | undefined): SLAInfo {
  if (!date) {
    return {
      text: "No Deadline",
      isUrgent: false,
      isOverdue: false,
      diffHours: 0,
      diffDays: 0,
      diffMinutes: 0,
    }
  }

  const target = new Date(date)
  if (isNaN(target.getTime())) {
    return {
      text: "Invalid Date",
      isUrgent: false,
      isOverdue: false,
      diffHours: 0,
      diffDays: 0,
      diffMinutes: 0,
    }
  }

  const now = new Date()
  const diffMs = target.getTime() - now.getTime()
  const isOverdue = diffMs < 0

  if (isOverdue) {
    const absDiffMs = Math.abs(diffMs)
    const mins = Math.floor(absDiffMs / (1000 * 60))
    const hours = Math.floor(absDiffMs / (1000 * 60 * 60))
    const days = Math.floor(absDiffMs / (1000 * 60 * 60 * 24))

    let text = "Overdue"
    if (days >= 1) {
      text = `Overdue by ${days} ${days === 1 ? "day" : "days"}`
    } else if (hours >= 1) {
      text = `Overdue by ${hours} ${hours === 1 ? "hour" : "hours"}`
    } else {
      text = `Overdue by ${Math.max(1, mins)} mins`
    }

    return {
      text,
      isUrgent: true,
      isOverdue: true,
      diffHours: -hours,
      diffDays: -days,
      diffMinutes: -mins,
    }
  }

  // Future countdown
  const mins = differenceInMinutes(target, now)
  const hours = differenceInHours(target, now)
  const days = differenceInDays(target, now)

  const isUrgent = hours < 24

  let text = ""
  if (days >= 1) {
    text = `Expires in ${days} ${days === 1 ? "day" : "days"}`
  } else if (hours >= 1) {
    text = `Expires in ${hours} ${hours === 1 ? "hour" : "hours"}`
  } else {
    text = `Expires in ${Math.max(1, mins)} mins`
  }

  return {
    text,
    isUrgent,
    isOverdue: false,
    diffHours: hours,
    diffDays: days,
    diffMinutes: mins,
  }
}

export function useSLA(date: Date | string | null | undefined): SLAInfo {
  const [sla, setSla] = useState<SLAInfo>(() => ({
    text: date ? "Calculating..." : "No Deadline",
    isUrgent: false,
    isOverdue: false,
    diffHours: 0,
    diffDays: 0,
    diffMinutes: 0,
  }))

  useEffect(() => {
    // Compute dynamic relative time after client mount to eliminate SSR hydration mismatches
    setSla(calculateSLA(date))

    // Update every 60 seconds for live countdown
    const interval = setInterval(() => {
      setSla(calculateSLA(date))
    }, 60000)

    return () => clearInterval(interval)
  }, [date])

  return sla
}
