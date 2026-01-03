import React from 'react'

interface UserMetaProps {
  name: string
  level: number
  title: string
}

export default function UserMeta({ name, level, title }: UserMetaProps) {
  return (
    <div className="flex-1 min-w-0">
      <div className="flex items-center gap-2 flex-wrap">
        <h3 className="text-base md:text-lg font-semibold text-gray-900 truncate">
          {name}
        </h3>
        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 flex-shrink-0">
          Lv.{level}
        </span>
      </div>
      <p className="text-sm md:text-base text-gray-600 mt-0.5 truncate">
        {title}
      </p>
    </div>
  )
}
