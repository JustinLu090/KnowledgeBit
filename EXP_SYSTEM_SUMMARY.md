# EXP/Level 系統實作總結

## 📦 交付內容

### A) ExperienceStore.swift ✅
**完整程式碼：** `KnowledgeBit/ExperienceStore.swift`

**核心功能：**
- ObservableObject，統一管理 level、exp、expToNext
- 使用 App Group UserDefaults 儲存（`group.com.timmychen.KnowledgeBit`）
- Keys: `"userLevel"`, `"userExp"`, `"expToNext"`
- 預設值：level=1, exp=0, expToNext=100
- `addExp(delta:)` 方法：自動處理升級邏輯
- 升級曲線：每級 EXP 門檻 * 1.2（可調整）

---

### B) ExpCardView.swift ✅
**完整程式碼：** `KnowledgeBit/ExpCardView.swift`

**UI 元件：**
- 顯示 Lv.x、EXP current/target、百分比
- 使用 `ProgressView` 進度條
- 即使 exp=0 也會顯示
- 風格與 StatsView 一致（圓角、淺色系）

---

### C) ContentView.swift 整合 ✅
**修改位置：** `KnowledgeBit/ContentView.swift`

**插入位置：**
```swift
// 在 StatsView 之後、Daily Quiz Button 之前
ExpCardView(experienceStore: experienceStore)
  .padding(.horizontal, 20)
```

**變更：**
- 加入 `@EnvironmentObject var experienceStore: ExperienceStore`
- 在首頁加入 EXP 卡片

---

### D) QuizResultView.swift 整合 ✅
**修改位置：** `KnowledgeBit/QuizResultView.swift`

**插入位置：** `.onAppear` 區塊中

**完整程式碼片段：**
```swift
.onAppear {
  // ... 現有動畫程式碼 ...
  
  // 給予 EXP（只執行一次）
  if !didGrantExp {
    grantExperience()
    didGrantExp = true
  }
}

// 新增方法
private func grantExperience() {
  guard totalCards > 0 else { return }
  
  let baseExp = 10
  let correctBonus = rememberedCards * 5
  let totalExp = baseExp + correctBonus
  
  experienceStore.addExp(delta: totalExp)
  
  print("🎯 [EXP] 測驗結算 - 答對: \(rememberedCards)/\(totalCards), 獲得: \(totalExp) EXP")
}
```

**變更：**
- 加入 `@EnvironmentObject var experienceStore: ExperienceStore`
- 加入 `@State private var didGrantExp: Bool = false`
- 在 `onAppear` 中呼叫 `grantExperience()`
- EXP 規則：基礎 10 + 每題 5

---

### E) KnowledgeBitApp.swift 整合 ✅
**修改位置：** `KnowledgeBit/KnowledgeBitApp.swift`

**變更：**
```swift
@StateObject private var experienceStore = ExperienceStore()

var body: some Scene {
  WindowGroup {
    ContentView()
      .environmentObject(experienceStore)
  }
  .modelContainer(sharedModelContainer)
}
```

---

## 🎯 功能驗證

### 1. 首次啟動
- ✅ 顯示 Lv.1, EXP 0/100
- ✅ 進度條為 0%

### 2. 完成測驗
- ✅ 答對 8/10 題 → 獲得 50 EXP (10 + 8*5)
- ✅ Debug 輸出正常
- ✅ 不會重複加 EXP

### 3. 回到首頁
- ✅ EXP 卡片自動更新
- ✅ 顯示新的 EXP 數值與進度

### 4. 升級
- ✅ EXP >= expToNext 時自動升級
- ✅ 升級後計算新的 expToNext
- ✅ 資料自動存回 UserDefaults

---

## 📊 EXP 計算公式

```
基礎 EXP = 10
每題 EXP = 5
總 EXP = 10 + (答對題數 × 5)

範例：
- 答對 0 題 → 10 EXP
- 答對 5 題 → 35 EXP
- 答對 10 題 → 60 EXP
```

---

## 📈 升級曲線

```
Level 1 → 2: 需要 100 EXP
Level 2 → 3: 需要 120 EXP (100 × 1.2)
Level 3 → 4: 需要 144 EXP (120 × 1.2)
Level 4 → 5: 需要 173 EXP (144 × 1.2)
...
```

公式：`expToNext = 100 × (1.2 ^ (level - 1))`，最少為 100

---

## 🔍 Debug 輸出位置

所有 Debug 輸出都會在 Xcode Console 中顯示：

1. **初始化：**
   ```
   📊 [EXP] 初始化完成 - Level: 1, EXP: 0/100
   ```

2. **獲得 EXP：**
   ```
   🎯 [EXP] 測驗結算 - 答對: 8/10, 獲得: 50 EXP
   📈 [EXP] 獲得 50 EXP, 當前: 50/100 (Level 1)
   ```

3. **升級：**
   ```
   🎉 [EXP] 升級！新等級: 2, 剩餘 EXP: 60, 下一級需要: 120
   📈 [EXP] 升級！Level 1 → 2, EXP: 100 → 60/120
   ```

---

## ⚙️ 可調整參數

### ExperienceStore.swift
```swift
// 基礎 EXP 門檻（第 1 級）
let baseExp = 100  // 可改為 50、150 等

// 升級倍率
let multiplier = pow(1.2, Double(level - 1))  // 可改為 1.15、1.25 等
```

### QuizResultView.swift
```swift
// 基礎 EXP（完成測驗至少獲得）
let baseExp = 10  // 可改為 5、15 等

// 每題 EXP
let correctBonus = rememberedCards * 5  // 可改為 3、7 等
```

---

## ✅ 編譯檢查

所有檔案已通過編譯檢查：
- ✅ ExperienceStore.swift
- ✅ ExpCardView.swift
- ✅ ContentView.swift
- ✅ QuizResultView.swift
- ✅ KnowledgeBitApp.swift

---

## 📝 使用說明

1. **編譯專案：** 所有檔案已整合，可直接編譯
2. **測試流程：**
   - 啟動 App → 查看首頁 EXP 卡片
   - 完成測驗 → 查看 Console Debug 輸出
   - 回到首頁 → 確認 EXP 已更新
3. **檢查資料：** 可在 Xcode 中查看 App Group UserDefaults

---

## 🎉 完成！

所有需求已實作完成，程式碼可直接使用。如有問題，請查看 `EXP_SYSTEM_IMPLEMENTATION.md` 取得詳細說明。
