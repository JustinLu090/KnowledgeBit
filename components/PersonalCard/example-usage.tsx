/**
 * PersonalCard 使用範例
 * 
 * 此檔案展示如何在 Lobby 頁面中使用 PersonalCard 元件
 */

'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import PersonalCard from './index'

export default function LobbyPage() {
  const router = useRouter()
  
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
    
    // 這裡可以加入其他邏輯，例如：
    // - 檢查是否升級
    // - 發送分析事件
    // - 更新後端資料
  }

  // 處理個人檔案按鈕點擊
  const handleProfileClick = () => {
    router.push('/profile')
    // 或開啟 modal
    // setShowProfileModal(true)
  }

  return (
    <div className="min-h-screen bg-gray-50 p-4 md:p-6">
      <div className="max-w-4xl mx-auto space-y-6">
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
        <div className="bg-white rounded-lg p-4 shadow-sm">
          <h2 className="text-lg font-semibold mb-4">測試 EXP 增加動畫</h2>
          <div className="flex gap-2">
            <button
              onClick={() => handleBattleComplete(15)}
              className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
            >
              +15 EXP
            </button>
            <button
              onClick={() => handleBattleComplete(30)}
              className="px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors"
            >
              +30 EXP
            </button>
            <button
              onClick={() => handleBattleComplete(50)}
              className="px-4 py-2 bg-purple-500 text-white rounded-lg hover:bg-purple-600 transition-colors"
            >
              +50 EXP
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * 實際整合範例（在真實的 Lobby 頁面中）
 * 
 * ```tsx
 * // app/lobby/page.tsx 或 pages/lobby.tsx
 * import PersonalCard from '@/components/PersonalCard'
 * import { useUser } from '@/hooks/useUser'
 * 
 * export default function Lobby() {
 *   const { user, updateExp } = useUser()
 *   const router = useRouter()
 * 
 *   // 從 API 取得使用者資料
 *   const { data: userData } = useSWR('/api/user', fetcher)
 * 
 *   return (
 *     <div className="lobby-container">
 *       <PersonalCard
 *         name={userData?.name || '使用者'}
 *         title={userData?.title || '新手'}
 *         level={userData?.level || 1}
 *         exp={userData?.exp || 0}
 *         expToNext={userData?.expToNext || 100}
 *         avatarUrl={userData?.avatarUrl}
 *         onProfileClick={() => router.push('/profile')}
 *       />
 *       {/* 其他 Lobby 內容 */}
 *     </div>
 *   )
 * }
 * ```
 */
