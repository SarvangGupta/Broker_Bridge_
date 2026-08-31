import React from 'react'
import { LucideIcon, Inbox } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

export interface EmptyStateProps {
  title: string
  description: string
  actionLabel?: string
  onAction?: () => void
  icon?: LucideIcon | React.ElementType
  className?: string
  children?: React.ReactNode
  actionVariant?: 'default' | 'outline' | 'secondary' | 'ghost'
}

export function EmptyState({
  title,
  description,
  actionLabel,
  onAction,
  icon: Icon = Inbox,
  className,
  children,
  actionVariant = 'default',
}: EmptyStateProps) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center p-8 sm:p-12 text-center bg-gray-50/50 rounded-2xl border border-dashed border-slate-300/80 transition-all",
        className
      )}
    >
      <div className="w-12 h-12 sm:w-14 sm:h-14 rounded-2xl bg-white flex items-center justify-center mb-4 text-slate-400 shadow-2xs border border-slate-200/80">
        <Icon className="w-6 h-6 sm:w-7 sm:h-7 stroke-[1.75]" />
      </div>

      <h3 className="text-base sm:text-lg font-bold text-slate-900 mb-1 leading-tight">
        {title}
      </h3>

      <p className="text-xs sm:text-sm text-slate-500 max-w-md mx-auto mb-5 leading-relaxed">
        {description}
      </p>

      {actionLabel && onAction && (
        <Button
          onClick={onAction}
          variant={actionVariant}
          className={cn(
            "min-h-[48px] px-6 font-semibold rounded-xl text-sm transition-all duration-150 cursor-pointer shadow-xs",
            actionVariant === 'default' && "bg-[#059669] hover:bg-[#047857] text-white"
          )}
        >
          {actionLabel}
        </Button>
      )}

      {children && <div className="mt-4">{children}</div>}
    </div>
  )
}
