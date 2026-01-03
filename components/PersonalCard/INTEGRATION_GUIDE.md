# PersonalCard 整合指南

## 快速開始

### 1. 複製元件檔案

將整個 `components/PersonalCard/` 資料夾複製到你的專案中。

### 2. 選擇適合的 Avatar 版本

**使用 Next.js：**
```tsx
// 使用預設的 Avatar.tsx（已包含 next/image）
import Avatar from './Avatar'
```

**不使用 Next.js：**
```tsx
// 使用 Avatar.vanilla.tsx
import Avatar from './Avatar.vanilla'
// 或直接修改 Avatar.tsx，將 next/image 改為 <img>
```

### 3. 設定 CSS 動畫

**選項 A：使用 Next.js（推薦）**
- 不需要額外設定，`ExpBar.tsx` 已使用 `style jsx`

**選項 B：使用全局 CSS**
```css
/* 在全局 CSS 檔案中（例如 globals.css）引入 */
@import './components/PersonalCard/exp-gain-animation.css';
```

**選項 C：使用 Tailwind 配置**
```js
// 在 tailwind.config.js 中（參考 tailwind.config.example.js）
module.exports = {
  theme: {
    extend: {
      keyframes: {
        'exp-gain-float': { /* ... */ }
      },
      animation: {
        'exp-gain': 'expGainFloat 2s ease-out forwards',
      },
    },
  },
}
```

### 4. 在 Lobby 頁面中使用

```tsx
// app/lobby/page.tsx 或 pages/lobby.tsx
import PersonalCard from '@/components/PersonalCard'

export default function LobbyPage() {
  return (
    <PersonalCard
      name="陳庭宇"
      title="語言學徒"
      level={1}
      exp={20}
      expToNext={100}
      onProfileClick={() => router.push('/profile')}
    />
  )
}
```

## 與狀態管理整合

### 使用 React Context

```tsx
// contexts/UserContext.tsx
import { createContext, useContext, useState } from 'react'

const UserContext = createContext(null)

export function UserProvider({ children }) {
  const [user, setUser] = useState({
    name: '陳庭宇',
    title: '語言學徒',
    level: 1,
    exp: 20,
    expToNext: 100,
  })

  const updateExp = (gained: number) => {
    setUser(prev => ({ ...prev, exp: prev.exp + gained }))
  }

  return (
    <UserContext.Provider value={{ user, updateExp }}>
      {children}
    </UserContext.Provider>
  )
}

// 在 Lobby 中使用
import { useContext } from 'react'
import { UserContext } from '@/contexts/UserContext'
import PersonalCard from '@/components/PersonalCard'

export default function LobbyPage() {
  const { user } = useContext(UserContext)
  
  return <PersonalCard {...user} />
}
```

### 使用 SWR / React Query

```tsx
import useSWR from 'swr'
import PersonalCard from '@/components/PersonalCard'

export default function LobbyPage() {
  const { data: user, mutate } = useSWR('/api/user', fetcher)
  
  const handleBattleComplete = async (expGained: number) => {
    await fetch('/api/user/exp', {
      method: 'POST',
      body: JSON.stringify({ expGained })
    })
    mutate() // 重新取得資料，觸發 EXP 動畫
  }

  if (!user) return <div>載入中...</div>

  return (
    <PersonalCard
      name={user.name}
      title={user.title}
      level={user.level}
      exp={user.exp}
      expToNext={user.expToNext}
    />
  )
}
```

## 與路由整合

### Next.js App Router

```tsx
// app/lobby/page.tsx
'use client'
import { useRouter } from 'next/navigation'
import PersonalCard from '@/components/PersonalCard'

export default function LobbyPage() {
  const router = useRouter()
  
  return (
    <PersonalCard
      {...userData}
      onProfileClick={() => router.push('/profile')}
    />
  )
}
```

### Next.js Pages Router

```tsx
// pages/lobby.tsx
import { useRouter } from 'next/router'
import PersonalCard from '@/components/PersonalCard'

export default function LobbyPage() {
  const router = useRouter()
  
  return (
    <PersonalCard
      {...userData}
      onProfileClick={() => router.push('/profile')}
    />
  )
}
```

### React Router

```tsx
import { useNavigate } from 'react-router-dom'
import PersonalCard from '@/components/PersonalCard'

export default function LobbyPage() {
  const navigate = useNavigate()
  
  return (
    <PersonalCard
      {...userData}
      onProfileClick={() => navigate('/profile')}
    />
  )
}
```

## 樣式自訂

### 修改顏色主題

在 `ExpBar.tsx` 中修改漸層顏色：
```tsx
// 從
className="bg-gradient-to-r from-blue-400 to-blue-600"
// 改為
className="bg-gradient-to-r from-purple-400 to-purple-600"
```

### 修改圓角大小

在 `index.tsx` 中修改：
```tsx
// 從
className="rounded-2xl"
// 改為
className="rounded-xl" // 或 rounded-3xl
```

### 修改間距

在各元件中調整 `gap`、`padding` 等 Tailwind classes。

## 測試 EXP 動畫

參考 `example-usage.tsx` 中的測試按鈕，或使用以下程式碼：

```tsx
const [exp, setExp] = useState(20)

<button onClick={() => setExp(prev => prev + 15)}>
  增加 15 EXP
</button>

<PersonalCard
  name="測試使用者"
  title="測試稱號"
  level={1}
  exp={exp}
  expToNext={100}
/>
```

## 疑難排解

### EXP 動畫沒有出現
- ✅ 確保 `exp` 是從 state 更新，不是直接計算
- ✅ 檢查 `expToNext` 是否 > 0
- ✅ 確認 CSS 動畫已正確載入

### 樣式跑版
- ✅ 確認 Tailwind CSS 已正確設定
- ✅ 檢查是否有其他 CSS 覆蓋樣式
- ✅ 確認 Tailwind 的 `content` 路徑包含元件資料夾

### 頭像不顯示
- ✅ 檢查 `avatarUrl` 路徑是否正確
- ✅ 若使用 Next.js，確保圖片在 `public` 資料夾
- ✅ 檢查 CORS 設定（如果是外部圖片）
