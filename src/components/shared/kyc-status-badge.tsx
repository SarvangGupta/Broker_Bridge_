import React from 'react';
import { ShieldCheck, Clock, ShieldX, AlertTriangle } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface KycStatusBadgeProps {
  isVerified?: boolean | null;
  status?: string | null;
  showIcon?: boolean;
  className?: string;
  size?: 'sm' | 'md' | 'lg';
}

export function KycStatusBadge({
  isVerified = false,
  status = 'PENDING',
  showIcon = true,
  className,
  size = 'md',
}: KycStatusBadgeProps) {
  const normalizedStatus = String(status || '').toUpperCase();

  const isApproved =
    Boolean(isVerified) ||
    normalizedStatus === 'APPROVED' ||
    normalizedStatus === 'VERIFIED' ||
    normalizedStatus === 'TRUE';

  const isRejected =
    normalizedStatus === 'REJECTED' ||
    normalizedStatus === 'ACTION REQUIRED' ||
    normalizedStatus === 'FAILED';

  let config = {
    label: 'Pending Review',
    icon: Clock,
    bg: 'bg-amber-500/10 dark:bg-amber-500/20 text-amber-700 dark:text-amber-400 border-amber-500/30',
  };

  if (isApproved) {
    config = {
      label: 'Verified Enterprise',
      icon: ShieldCheck,
      bg: 'bg-emerald-500/10 dark:bg-emerald-500/20 text-emerald-700 dark:text-emerald-400 border-emerald-500/30',
    };
  } else if (isRejected) {
    config = {
      label: 'Verification Rejected',
      icon: ShieldX,
      bg: 'bg-rose-500/10 dark:bg-rose-500/20 text-rose-700 dark:text-rose-400 border-rose-500/30',
    };
  }

  const Icon = config.icon;

  const sizeClasses = {
    sm: 'px-2 py-0.5 text-xs gap-1',
    md: 'px-2.5 py-1 text-xs sm:text-sm gap-1.5',
    lg: 'px-3 py-1.5 text-sm sm:text-base gap-2 font-medium',
  }[size];

  const iconSizes = {
    sm: 'w-3 h-3',
    md: 'w-3.5 h-3.5 sm:w-4 sm:h-4',
    lg: 'w-4 h-4 sm:w-5 sm:h-5',
  }[size];

  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full border font-medium transition-colors shrink-0',
        config.bg,
        sizeClasses,
        className
      )}
    >
      {showIcon && <Icon className={cn('shrink-0', iconSizes)} />}
      <span>{config.label}</span>
    </span>
  );
}
