import React from 'react';
import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';

export interface SprintPlaceholderProps {
  title: string;
  sprintName: string;
  description: string;
  icon: React.ReactNode;
}

export function SprintPlaceholder({
  title,
  sprintName,
  description,
  icon,
}: SprintPlaceholderProps) {
  return (
    <div className="w-full max-w-full overflow-hidden min-h-[60vh] flex flex-col items-center justify-center p-4 sm:p-6 text-center select-none">
      <div className="max-w-md w-full bg-white border border-slate-200/80 rounded-2xl p-6 sm:p-8 flex flex-col items-center space-y-4 shadow-2xs">
        {/* Ocean Blue Icon Badge */}
        <div className="w-14 h-14 rounded-full bg-[#E0F2FE] text-[#0284C7] flex items-center justify-center border border-sky-200 shrink-0">
          {icon}
        </div>

        {/* Header Title & Sprint Tag */}
        <div className="space-y-1.5 min-w-0 w-full">
          <h2 className="text-xl sm:text-2xl font-bold text-slate-900 tracking-tight truncate">
            {title}
          </h2>
          <div className="inline-block text-xs font-bold text-[#0284C7] bg-[#E0F2FE] border border-sky-200 px-3 py-1 rounded-full">
            {sprintName}
          </div>
        </div>

        {/* Description Text */}
        <p className="text-xs sm:text-sm text-slate-500 leading-relaxed max-w-xs sm:max-w-sm">
          {description}
        </p>

        {/* Return to Dashboard Action */}
        <div className="pt-2 w-full sm:w-auto">
          <Link
            href="/buyer"
            className="inline-flex items-center justify-center gap-2 px-5 py-2.5 text-xs sm:text-sm font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-all min-h-[48px] w-full sm:w-auto"
          >
            <ArrowLeft className="w-4 h-4 text-slate-500" />
            <span>Return to Dashboard</span>
          </Link>
        </div>
      </div>
    </div>
  );
}
