'use client';

import React, { useState, useEffect, useRef } from 'react';
import { Mic, MicOff, Loader2, AlertCircle } from 'lucide-react';
import { useLanguage } from '@/src/lib/i18n/language-context';

export interface VoiceSearchButtonProps {
  onTranscript: (text: string) => void;
  isSearching?: boolean;
  disabled?: boolean;
  className?: string;
}

type VoiceState = 'idle' | 'listening' | 'processing' | 'error' | 'unsupported';

export function VoiceSearchButton({
  onTranscript,
  isSearching = false,
  disabled = false,
  className = '',
}: VoiceSearchButtonProps) {
  const { t, language } = useLanguage();
  const [voiceState, setVoiceState] = useState<VoiceState>('idle');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const recognitionRef = useRef<any>(null);

  // Check browser support on mount
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const SpeechRecognition =
        (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;

      if (!SpeechRecognition) {
        setVoiceState('unsupported');
      }
    }
  }, []);

  const stopListening = () => {
    if (recognitionRef.current) {
      try {
        recognitionRef.current.stop();
      } catch (_e) {
        // Ignore stop error
      }
      recognitionRef.current = null;
    }
    setVoiceState('idle');
  };

  const startListening = () => {
    if (typeof window === 'undefined') return;

    const SpeechRecognition =
      (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;

    if (!SpeechRecognition) {
      setVoiceState('unsupported');
      setErrorMessage(t('searchVoiceUnsupported'));
      return;
    }

    try {
      // Clean up any existing recognition
      if (recognitionRef.current) {
        try {
          recognitionRef.current.abort();
        } catch (_e) {}
      }

      const recognition = new SpeechRecognition();
      recognitionRef.current = recognition;

      recognition.continuous = false;
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;
      // Set language according to current active language
      recognition.lang = language === 'hi' ? 'hi-IN' : 'en-IN';

      recognition.onstart = () => {
        setVoiceState('listening');
        setErrorMessage(null);
      };

      recognition.onresult = (event: any) => {
        const transcript = Array.from(event.results)
          .map((result: any) => result[0]?.transcript || '')
          .join('');

        if (event.results[0]?.isFinal) {
          setVoiceState('processing');
          if (transcript.trim()) {
            onTranscript(transcript.trim());
          }
          setTimeout(() => {
            setVoiceState('idle');
          }, 300);
        }
      };

      recognition.onerror = (event: any) => {
        console.warn('Speech recognition error:', event.error);
        setVoiceState('error');

        if (event.error === 'not-allowed' || event.error === 'service-not-allowed') {
          setErrorMessage(t('searchVoicePermissionDenied'));
        } else if (event.error === 'no-speech') {
          setErrorMessage(t('searchVoiceNoSpeech'));
        } else {
          setErrorMessage(t('searchVoiceError'));
        }

        // Auto-reset error state after 4 seconds
        setTimeout(() => {
          setVoiceState('idle');
          setErrorMessage(null);
        }, 4000);
      };

      recognition.onend = () => {
        if (voiceState === 'listening') {
          setVoiceState('idle');
        }
      };

      recognition.start();
    } catch (err: any) {
      console.error('Failed to start speech recognition:', err);
      setVoiceState('error');
      setErrorMessage(t('searchVoiceError'));
      setTimeout(() => {
        setVoiceState('idle');
        setErrorMessage(null);
      }, 4000);
    }
  };

  const handleClick = () => {
    if (disabled || isSearching) return;

    if (voiceState === 'listening') {
      stopListening();
    } else {
      startListening();
    }
  };

  const getTooltip = () => {
    if (voiceState === 'unsupported') return t('searchVoiceUnsupported');
    if (voiceState === 'listening') return t('searchVoiceListening');
    if (voiceState === 'processing') return t('searchVoiceProcessing');
    if (voiceState === 'error') return errorMessage || t('searchVoiceError');
    return t('searchVoiceTooltip');
  };

  return (
    <div className="relative inline-flex items-center">
      <button
        type="button"
        onClick={handleClick}
        disabled={disabled || voiceState === 'unsupported' || isSearching}
        title={getTooltip()}
        aria-label={getTooltip()}
        className={`relative flex items-center justify-center w-8 h-8 rounded-lg transition-all focus:outline-none min-h-[32px] min-w-[32px] ${
          voiceState === 'listening'
            ? 'bg-rose-50 text-rose-600 border border-rose-300 ring-2 ring-rose-200 animate-pulse'
            : voiceState === 'processing'
            ? 'bg-teal-50 text-teal-600 border border-teal-200'
            : voiceState === 'unsupported'
            ? 'text-slate-300 cursor-not-allowed opacity-50'
            : voiceState === 'error'
            ? 'bg-amber-50 text-amber-600 border border-amber-200'
            : 'text-slate-400 hover:text-teal-700 hover:bg-teal-50 border border-transparent'
        } ${className}`}
      >
        {voiceState === 'listening' ? (
          <span className="relative flex items-center justify-center">
            <span className="absolute w-4 h-4 rounded-full bg-rose-400 opacity-75 animate-ping" />
            <Mic className="w-4 h-4 text-rose-600 relative z-10" />
          </span>
        ) : voiceState === 'processing' ? (
          <Loader2 className="w-4 h-4 text-teal-600 animate-spin" />
        ) : voiceState === 'error' ? (
          <AlertCircle className="w-4 h-4 text-amber-600" />
        ) : voiceState === 'unsupported' ? (
          <MicOff className="w-4 h-4 text-slate-300" />
        ) : (
          <Mic className="w-4 h-4" />
        )}
      </button>

      {/* Floating Listening Banner / Error Toast */}
      {voiceState === 'listening' && (
        <div className="absolute right-0 top-full mt-2 z-50 whitespace-nowrap px-3 py-1.5 rounded-lg bg-slate-900 text-white text-[11px] font-medium shadow-lg flex items-center gap-2 border border-slate-700 animate-in fade-in slide-in-from-top-1">
          <span className="w-2 h-2 rounded-full bg-rose-500 animate-pulse" />
          <span>{t('searchVoiceListeningPrompt')}</span>
        </div>
      )}

      {voiceState === 'error' && errorMessage && (
        <div className="absolute right-0 top-full mt-2 z-50 max-w-xs whitespace-normal px-3 py-2 rounded-lg bg-amber-50 text-amber-900 text-[11px] font-medium shadow-md border border-amber-200 animate-in fade-in">
          <div className="flex items-start gap-1.5">
            <AlertCircle className="w-3.5 h-3.5 text-amber-600 shrink-0 mt-0.5" />
            <span>{errorMessage}</span>
          </div>
        </div>
      )}
    </div>
  );
}
