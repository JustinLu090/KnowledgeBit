'use client'

import React, { useState, useEffect, useRef } from 'react'
import Avatar from './Avatar'
import UserMeta from './UserMeta'
import ExpBar from './ExpBar'
import ProfileButton from './ProfileButton'

export interface PersonalCardProps {
  name: string
  title: string
  level: number
  exp: number
  expToNext: number
  avatarUrl?: string
  onProfileClick?: () => void
}

export default function PersonalCard({
  name,
  title,
  level,
  exp,
  expToNext,
  avatarUrl,
  onProfileClick
}: PersonalCardProps) {
  const [expGained, setExpGained] = useState<number | undefined>(undefined)
  const prevExpRef = useRef(exp)

  // 偵測 EXP 變化並觸發動畫
  useEffect(() => {
    if (exp > prevExpRef.current) {
      const gained = exp - prevExpRef.current
      setExpGained(gained)
    }
    prevExpRef.current = exp
  }, [exp])

  return (
    <div className="relative bg-white rounded-2xl shadow-sm border border-gray-100 p-4 md:p-5">
      <div className="flex items-start gap-3 md:gap-4">
        {/* 左側：頭像 */}
        <Avatar avatarUrl={avatarUrl} name={name} size="md" />

        {/* 中間：使用者資訊 */}
        <UserMeta name={name} level={level} title={title} />

        {/* 右側：個人檔案按鈕 */}
        <ProfileButton onClick={onProfileClick} />
      </div>

      {/* 下方：EXP 進度條 */}
      <ExpBar
        exp={exp}
        expToNext={expToNext}
        level={level}
        expGained={expGained}
      />
    </div>
  )
}
