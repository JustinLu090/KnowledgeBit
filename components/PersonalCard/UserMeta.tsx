import React from 'react'
import './glassmorphism.css'

interface UserMetaProps {
  name: string
  level: number
  title: string
}

export default function UserMeta({ name, level, title }: UserMetaProps) {
  return (
    <div className="flex-1 min-w-0">
      <div className="flex items-center gap-3 flex-wrap">
        <h3 className="glass-text-bold text-lg md:text-xl truncate">
          {name}
        </h3>
        <span className="glass-base inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold text-white flex-shrink-0">
          Lv.{level}
        </span>
      </div>
      <p className="glass-text text-sm md:text-base mt-1.5 truncate">
        {title}
      </p>
    </div>
  )
}
