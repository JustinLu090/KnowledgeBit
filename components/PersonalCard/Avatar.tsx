import React from 'react'
import Image from 'next/image'

interface AvatarProps {
  avatarUrl?: string
  name: string
  size?: 'sm' | 'md' | 'lg'
}

const sizeMap = {
  sm: 'w-10 h-10',
  md: 'w-12 h-12 md:w-14 md:h-14',
  lg: 'w-16 h-16'
}

export default function Avatar({ avatarUrl, name, size = 'md' }: AvatarProps) {
  const sizeClass = sizeMap[size]
  const initials = name.charAt(0).toUpperCase()

  return (
    <div
      className={`${sizeClass} rounded-full bg-gradient-to-br from-blue-400 to-blue-600 flex items-center justify-center text-white font-semibold text-sm md:text-base shadow-sm overflow-hidden flex-shrink-0`}
    >
      {avatarUrl ? (
        <Image
          src={avatarUrl}
          alt={name}
          width={size === 'sm' ? 40 : size === 'md' ? 56 : 64}
          height={size === 'sm' ? 40 : size === 'md' ? 56 : 64}
          className="w-full h-full object-cover"
        />
      ) : (
        <span>{initials}</span>
      )}
    </div>
  )
}
