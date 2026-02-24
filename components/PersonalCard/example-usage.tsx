/**
 * PersonalCard 使用範例
 * 
 * 此檔案展示如何在 Lobby 頁面中使用 PersonalCard 元件
 */

'use client'

import React, { useState } from 'react'
import PersonalCard from './index'
import './glassmorphism.css'

export default function LobbyPage() {
  // 範例：使用者資料（實際應從 API 或狀態管理取得）
  const [userData, setUserData] = useState({
    name: '陳庭宇',
    title: '語言學徒',
    level: 1,
    exp: 20,
    expToNext: 100,
    avatarUrl: '/avatars/user1.jpg' // 可選
  })

  // 模擬戰鬥結算後增加 EXP
  const handleBattleComplete = (expGained: number) => {
    setUserData(prev => ({
      ...prev,
      exp: prev.exp + expGained
    }))
  }

  // 處理個人檔案按鈕點擊
  // 注意：如果使用 Next.js，可以在這裡使用 useRouter
  // import { useRouter } from 'next/navigation'
  // const router = useRouter()
  // 然後在 handleProfileClick 中使用 router.push('/profile')
  const handleProfileClick = () => {
    console.log('導航到個人檔案頁面')
    // 實際使用時，可以這樣寫：
    // if (router) router.push('/profile')
  }

  return (
    <div 
      className="min-h-screen p-6 md:p-8" 
      style={{
        background: `
          radial-gradient(circle at 20% 50%, rgba(138, 43, 226, 0.3) 0%, transparent 50%),
          radial-gradient(circle at 80% 80%, rgba(59, 130, 246, 0.3) 0%, transparent 50%),
          radial-gradient(circle at 40% 20%, rgba(255, 182, 193, 0.3) 0%, transparent 50%),
          linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 25%, #16213e 50%, #0f3460 75%, #0a0a0f 100%)
        `,
        backgroundAttachment: 'fixed',
        backgroundSize: 'cover'
      }}
    >
      <div className="max-w-4xl mx-auto space-y-8">
        {/* PersonalCard 元件 */}
        <PersonalCard
          name={userData.name}
          title={userData.title}
          level={userData.level}
          exp={userData.exp}
          expToNext={userData.expToNext}
          avatarUrl={userData.avatarUrl}
          onProfileClick={handleProfileClick}
        />

        {/* 範例：模擬戰鬥結算按鈕（僅供測試） */}
        <div className="glass-card p-6 md:p-8">
          <h2 className="glass-text-bold text-xl mb-6">測試 EXP 增加動畫</h2>
          <div className="flex gap-4 flex-wrap">
            <button
              onClick={() => handleBattleComplete(15)}
              className="glass-action-button blue"
            >
              +15 EXP
            </button>
            <button
              onClick={() => handleBattleComplete(30)}
              className="glass-action-button green"
            >
              +30 EXP
            </button>
            <button
              onClick={() => handleBattleComplete(50)}
              className="glass-action-button purple"
            >
              +50 EXP
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
