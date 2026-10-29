'use client'

import React from 'react'

export interface WhatsAppShareButtonProps {
  url: string
  text: string
  className?: string
}

/**
 * Task 3: WhatsApp Share Integration Button
 * Standard wa.me/?text=[encoded_text_and_url] deep link with #25D366 brand styling
 * Enforces >= 48px touch targets for mobile accessibility on Tier-2 networks.
 */
export function WhatsAppShareButton({
  url,
  text,
  className = '',
}: WhatsAppShareButtonProps) {
  // Construct standard WhatsApp deep link
  const messageBody = url ? `${text.trim()}\n\n🔗 Verified Record: ${url.trim()}` : text.trim()
  const shareHref = `https://wa.me/?text=${encodeURIComponent(messageBody)}`

  return (
    <a
      href={shareHref}
      target="_blank"
      rel="noopener noreferrer"
      aria-label="Share verified credential on WhatsApp"
      className={`min-h-[48px] px-5 py-3 bg-[#25D366] hover:bg-[#20ba59] active:bg-[#1da850] text-white font-semibold text-sm sm:text-base rounded-xl inline-flex items-center justify-center gap-2.5 shadow-sm hover:shadow-md transition-all touch-manipulation select-none w-full sm:w-auto ${className}`}
    >
      {/* Official WhatsApp Glyph */}
      <svg
        className="w-5 h-5 fill-current shrink-0"
        viewBox="0 0 24 24"
        xmlns="http://www.w3.org/2000/svg"
        aria-hidden="true"
      >
        <path d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91C2.13 13.66 2.59 15.36 3.45 16.86L2.05 22L7.3 20.63C8.75 21.41 10.38 21.83 12.04 21.83C17.5 21.83 21.95 17.38 21.95 11.92C21.95 9.27 20.92 6.78 19.05 4.91C17.18 3.03 14.69 2 12.04 2ZM12.05 20.15C10.57 20.15 9.12 19.76 7.85 19.01L7.55 18.83L4.43 19.65L5.26 16.61L5.06 16.29C4.24 14.99 3.81 13.47 3.81 11.91C3.81 7.37 7.5 3.69 12.05 3.69C14.25 3.69 16.31 4.55 17.87 6.11C19.42 7.67 20.28 9.73 20.28 11.92C20.28 16.46 16.59 20.15 12.05 20.15ZM16.57 14.39C16.32 14.27 15.1 13.67 14.88 13.58C14.65 13.5 14.49 13.46 14.32 13.71C14.16 13.96 13.68 14.52 13.53 14.68C13.39 14.85 13.24 14.87 12.99 14.75C12.75 14.62 11.96 14.36 11.02 13.52C10.28 12.87 9.79 12.06 9.64 11.81C9.5 11.56 9.63 11.43 9.75 11.31C9.86 11.2 10 11.03 10.12 10.89C10.25 10.74 10.29 10.64 10.37 10.47C10.45 10.31 10.41 10.16 10.35 10.04C10.29 9.92 9.8 8.71 9.59 8.21C9.39 7.73 9.19 7.79 9.04 7.78C8.9 7.78 8.73 7.78 8.57 7.78C8.4 7.78 8.14 7.84 7.91 8.09C7.68 8.34 7.03 8.95 7.03 10.18C7.03 11.42 7.93 12.61 8.06 12.77C8.18 12.94 9.83 15.48 12.35 16.57C12.95 16.83 13.42 16.98 13.78 17.1C14.38 17.29 14.93 17.26 15.36 17.2C15.85 17.12 16.86 16.58 17.07 15.99C17.27 15.39 17.27 14.89 17.21 14.78C17.15 14.68 17 14.62 16.75 14.49L16.57 14.39Z" />
      </svg>
      <span>Share via WhatsApp</span>
    </a>
  )
}

export default WhatsAppShareButton

