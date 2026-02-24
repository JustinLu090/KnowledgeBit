import React from 'react'
import './glassmorphism.css'

interface ProfileButtonProps {
  onClick?: () => void
}

export default function ProfileButton({ onClick }: ProfileButtonProps) {
  return (
    <button
      onClick={onClick}
      className="glass-circle-button flex-shrink-0 w-10 h-10 md:w-12 md:h-12 group"
      aria-label="個人檔案"
    >
      <svg
        className="w-5 h-5 md:w-6 md:h-6 text-white transition-colors"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth={2}
          d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
        />
      </svg>
    </button>
  )
}
