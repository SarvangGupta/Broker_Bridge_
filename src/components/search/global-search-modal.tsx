'use client';

import React, { useState, useEffect } from 'react';
import { X, Search } from 'lucide-react';
import { GlobalSearchWorkspace } from '@/src/components/search/global-search-workspace';
import { useLanguage } from '@/src/lib/i18n/language-context';

export function GlobalSearchModal() {
  const [isOpen, setIsOpen] = useState(false);
  const { t } = useLanguage();

  // Listen for Ctrl+K or Cmd+K
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setIsOpen((prev) => !prev);
      } else if (e.key === 'Escape' && isOpen) {
        setIsOpen(false);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center p-3 sm:p-6 md:p-10 bg-slate-900/60 backdrop-blur-xs animate-in fade-in"
      onClick={() => setIsOpen(false)}
    >
      <div
        className="w-full max-w-3xl bg-white rounded-2xl shadow-2xl border border-slate-200 overflow-hidden flex flex-col max-h-[90vh] animate-in zoom-in-95 mt-4 sm:mt-10"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Modal Top Bar */}
        <div className="px-4 py-3 border-b border-slate-100 flex items-center justify-between bg-slate-50/80">
          <div className="flex items-center gap-2 text-slate-700 text-xs font-bold">
            <Search className="w-4 h-4 text-[#0D9488]" />
            <span>{t('navGlobalSearch')}</span>
            <kbd className="hidden sm:inline-block px-1.5 py-0.5 rounded text-[10px] font-mono font-semibold bg-white border border-slate-200 text-slate-400">
              ESC
            </kbd>
          </div>
          <button
            type="button"
            onClick={() => setIsOpen(false)}
            className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-200/60 transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="flex-1 overflow-y-auto p-3 sm:p-5">
          <GlobalSearchWorkspace isModalView onNavigate={() => setIsOpen(false)} />
        </div>
      </div>
    </div>
  );
}
