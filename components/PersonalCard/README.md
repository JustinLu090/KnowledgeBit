# PersonalCard 元件說明

## 安裝需求

此元件使用 **Tailwind CSS**，請確保你的專案已設定 Tailwind。

### 如果尚未安裝 Tailwind：

```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

在 `tailwind.config.js` 中設定：

```js
module.exports = {
  content: [
    './components/**/*.{js,ts,jsx,tsx}',
    './app/**/*.{js,ts,jsx,tsx}',
    // ... 其他路徑
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

## 檔案結構

```
components/PersonalCard/
├── index.tsx          # 主元件（匯出 PersonalCard）
├── Avatar.tsx         # 頭像子元件
├── UserMeta.tsx       # 使用者資訊子元件
├── ExpBar.tsx         # EXP 進度條子元件
├── ProfileButton.tsx  # 個人檔案按鈕子元件
├── example-usage.tsx  # 使用範例
└── README.md          # 本檔案
```

## Props 說明

| 屬性 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `name` | `string` | ✅ | 使用者名稱 |
| `title` | `string` | ✅ | 稱號（例如：語言學徒） |
| `level` | `number` | ✅ | 等級 |
| `exp` | `number` | ✅ | 當前 EXP |
| `expToNext` | `number` | ✅ | 升級所需 EXP |
| `avatarUrl` | `string` | ❌ | 頭像圖片 URL（可選，無則顯示首字母） |
| `onProfileClick` | `() => void` | ❌ | 點擊個人檔案按鈕的回調函數 |

## 使用方式

### 基本使用

```tsx
import PersonalCard from '@/components/PersonalCard'

<PersonalCard
  name="陳庭宇"
  title="語言學徒"
  level={1}
  exp={20}
  expToNext={100}
/>
```

### 完整使用（含頭像與回調）

```tsx
import PersonalCard from '@/components/PersonalCard'
import { useRouter } from 'next/navigation'

function LobbyPage() {
  const router = useRouter()
  
  return (
    <PersonalCard
      name="陳庭宇"
      title="語言學徒"
      level={1}
      exp={20}
      expToNext={100}
      avatarUrl="/avatars/user1.jpg"
      onProfileClick={() => router.push('/profile')}
    />
  )
}
```

### 動態更新 EXP（觸發動畫）

```tsx
const [userExp, setUserExp] = useState(20)

// 戰鬥結算後
const handleBattleComplete = (expGained: number) => {
  setUserExp(prev => prev + expGained)
  // PersonalCard 會自動偵測 exp 變化並顯示動畫
}

<PersonalCard
  name="陳庭宇"
  title="語言學徒"
  level={1}
  exp={userExp}  // 當這個值改變時，會觸發 +EXP 動畫
  expToNext={100}
/>
```

## 功能特色

### ✅ EXP 顯示
- 進度條右側顯示「EXP 當前/升級門檻 (百分比)」
- 例如：`EXP 20/100 (20%)`

### ✅ 動畫效果
- EXP 增加時自動顯示 `+EXP` 浮動標籤
- 進度條有 smooth transition（300ms）
- 數值變化有平滑動畫（500ms ease-out）

### ✅ 新手友善
- Lv.1 且 EXP 為 0 時顯示提示文字
- 提示：「完成第一場對戰即可獲得 EXP」

### ✅ 響應式設計
- 手機優先（Mobile First）
- 文字自動換行，不溢出
- 頭像大小：手機 48px，平板 56px

### ✅ 可維護性
- 拆分成 4 個可重用子元件
- 完整的 TypeScript 型別定義
- 所有資料由 props 傳入

## 樣式自訂

如果需要調整樣式，可以：

1. **修改 Tailwind classes**：直接編輯各子元件的 className
2. **使用 CSS Variables**：在 `tailwind.config.js` 中定義自訂顏色
3. **覆蓋樣式**：使用 `className` prop（需要修改元件以支援）

## 注意事項

1. **Next.js Image 優化**：
   - 如果使用 Next.js：使用 `components/PersonalCard/Avatar.tsx`（已包含 `next/image`）
   - 如果不使用 Next.js：請使用 `components/PersonalCard/Avatar.vanilla.tsx`（使用標準 `<img>` 標籤）
   - 或在 `Avatar.tsx` 中將 `import Image from 'next/image'` 改為使用 `<img>`

2. **動畫效能**：EXP 動畫使用 `requestAnimationFrame`，效能良好

3. **無障礙**：按鈕有 `aria-label`，符合無障礙標準

4. **CSS 動畫**：
   - `ExpBar.tsx` 使用 `style jsx`（Next.js 內建支援）
   - 如果不使用 Next.js，可以：
     - 將 `exp-gain-animation.css` 引入到全局 CSS
     - 或在 Tailwind config 中定義動畫（參考 `tailwind.config.example.js`）

## 疑難排解

### EXP 動畫沒有出現？
- 確保 `exp` prop 是從 state 更新，而非直接計算
- 檢查 `expToNext` 是否大於 0

### 頭像不顯示？
- 檢查 `avatarUrl` 路徑是否正確
- 若使用 Next.js，確保圖片在 `public` 資料夾中

### 樣式跑版？
- 確認 Tailwind CSS 已正確載入
- 檢查是否有其他 CSS 覆蓋了樣式
