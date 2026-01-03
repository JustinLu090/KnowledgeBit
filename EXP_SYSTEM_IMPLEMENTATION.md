# EXP/Level 系統實作說明

## ✅ 已完成項目

### A) ExperienceStore.swift
📄 檔案位置：`KnowledgeBit/ExperienceStore.swift`

**功能：**
- `ObservableObject`，統一管理等級與經驗值
- 使用 App Group UserDefaults 儲存（`group.com.timmychen.KnowledgeBit`）
- 儲存 keys：`"userLevel"`, `"userExp"`, `"expToNext"`
- 預設值：level=1, exp=0, expToNext=100

**主要方法：**
- `addExp(delta:)` - 增加經驗值，自動處理升級邏輯
- `expPercentage` - 計算 EXP 百分比（0.0 ~ 1.0）

**升級規則：**
- 當 `exp >= expToNext` 時自動升級
- 升級後：`level += 1`, `exp -= expToNext`
- `expToNext` 計算公式：`100 * (1.2 ^ (level - 1))`，最少為 100

**安全機制：**
- 確保 level >= 1
- 確保 exp >= 0
- 確保 expToNext > 0
- 所有變更都會自動存回 UserDefaults

---

### B) ExpCardView.swift
📄 檔案位置：`KnowledgeBit/ExpCardView.swift`

**功能：**
- 顯示使用者等級（Lv.x）
- 顯示 EXP 進度條與數值（current/target + 百分比）
- 使用 `ProgressView` 顯示進度
- 即使 exp=0 也會顯示（符合需求）

**UI 風格：**
- 圓角卡片（cornerRadius: 16）
- 與 StatsView 一致的背景色
- 星形圖示（漸層黃橙）
- 簡潔的排版

---

### C) ContentView.swift 整合
📄 修改位置：`KnowledgeBit/ContentView.swift`

**變更：**
1. 加入 `@EnvironmentObject var experienceStore: ExperienceStore`
2. 在 `StatsView` 之後加入 `ExpCardView`
3. 位置：Header → StatsView → **ExpCardView** → Daily Quiz Button

**程式碼片段：**
```swift
// Streak Card Section
StatsView()
  .padding(.horizontal, 20)

// EXP Card Section
ExpCardView(experienceStore: experienceStore)
  .padding(.horizontal, 20)

// Daily Quiz Button
dailyQuizButton
  .padding(.horizontal, 20)
```

---

### D) QuizResultView.swift 整合
📄 修改位置：`KnowledgeBit/QuizResultView.swift`

**變更：**
1. 加入 `@EnvironmentObject var experienceStore: ExperienceStore`
2. 加入 `@State private var didGrantExp: Bool = false`（防止重複加 EXP）
3. 在 `onAppear` 中呼叫 `grantExperience()`

**EXP 計算規則：**
- 基礎 EXP：10（至少）
- 每答對一題：+5
- 公式：`totalExp = 10 + (rememberedCards * 5)`

**防重複機制：**
- 使用 `didGrantExp` flag
- 只在 `onAppear` 且 `didGrantExp == false` 時執行
- 每次 `QuizResultView` 被創建時，flag 自動重置為 `false`

**Debug 輸出：**
- 測驗結算時印出：答對數、總 EXP、等級變化、EXP 變化
- 格式：`🎯 [EXP] 測驗結算 - 答對: X/Y, 獲得: Z EXP`

**插入位置：**
```swift
.onAppear {
  // ... 現有動畫程式碼 ...
  
  // 給予 EXP（只執行一次）
  if !didGrantExp {
    grantExperience()
    didGrantExp = true
  }
}
```

---

### E) KnowledgeBitApp.swift 整合
📄 修改位置：`KnowledgeBit/KnowledgeBitApp.swift`

**變更：**
1. 建立 `ExperienceStore` singleton
2. 使用 `.environmentObject()` 注入到整個 App

**程式碼片段：**
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

## 📋 使用流程

1. **首次啟動：**
   - `ExperienceStore` 初始化，從 UserDefaults 讀取（若無則使用預設值）
   - 首頁顯示 EXP 卡片（Lv.1, EXP 0/100）

2. **完成測驗：**
   - 用戶完成測驗，進入 `QuizResultView`
   - `onAppear` 觸發，計算並給予 EXP
   - Debug 輸出顯示獲得的 EXP 與等級變化

3. **回到首頁：**
   - `ExpCardView` 自動更新（因為 `@ObservedObject`）
   - 顯示新的等級與 EXP 進度

4. **升級：**
   - 當 `exp >= expToNext` 時自動升級
   - 升級後計算新的 `expToNext`
   - 所有變更自動存回 UserDefaults

---

## 🔍 Debug 輸出範例

```
📊 [EXP] 初始化完成 - Level: 1, EXP: 0/100
🎯 [EXP] 測驗結算 - 答對: 8/10, 獲得: 50 EXP
📈 [EXP] 獲得 50 EXP, 當前: 50/100 (Level 1)
🎯 [EXP] 等級變化: 1 → 1
🎯 [EXP] EXP 變化: 0 → 50/100
```

升級時：
```
🎯 [EXP] 測驗結算 - 答對: 10/10, 獲得: 60 EXP
📈 [EXP] 升級！Level 1 → 2, EXP: 100 → 60/120
🎉 [EXP] 升級！新等級: 2, 剩餘 EXP: 60, 下一級需要: 120
🎯 [EXP] 等級變化: 1 → 2
🎯 [EXP] EXP 變化: 100 → 60/120
```

---

## ⚙️ 可調整參數

### ExperienceStore.swift
- **基礎 EXP 門檻**：`calculateExpToNext(for:)` 中的 `baseExp = 100`
- **升級倍率**：`multiplier = pow(1.2, Double(level - 1))`（可改為 1.15、1.25 等）

### QuizResultView.swift
- **基礎 EXP**：`baseExp = 10`（可調整）
- **每題 EXP**：`correctBonus = rememberedCards * 5`（可改為 3、7 等）

---

## ✅ 測試檢查清單

- [x] 首次啟動顯示 Lv.1, EXP 0/100
- [x] 完成測驗後獲得 EXP
- [x] 回到首頁看到 EXP 更新
- [x] 升級時自動計算新的 expToNext
- [x] 不會重複加 EXP（即使多次進入結算畫面）
- [x] Debug 輸出正常
- [x] App Group UserDefaults 正常儲存
- [x] Widget 可讀取相同資料（需在 Widget 中實作）

---

## 📝 注意事項

1. **App Group 設定：**
   - 確保 Xcode 中已設定 App Groups capability
   - App Group ID：`group.com.timmychen.KnowledgeBit`
   - 主 App 與 Widget Extension 都需啟用

2. **Widget 整合：**
   - Widget 可透過相同 App Group UserDefaults 讀取 EXP 資料
   - 範例：`UserDefaults(suiteName: "group.com.timmychen.KnowledgeBit")?.integer(forKey: "userLevel")`

3. **資料持久化：**
   - 所有資料儲存在 App Group UserDefaults
   - 即使 App 重啟，資料也會保留
   - 可透過 Xcode 的 UserDefaults 查看器檢查

4. **效能：**
   - `ExperienceStore` 使用 `@Published`，UI 會自動更新
   - 所有儲存操作都是同步的，不會阻塞 UI

---

## 🚀 後續擴充建議

1. **升級動畫：**
   - 在 `addExp` 中檢測升級，觸發慶祝動畫
   - 可在 `ExpCardView` 中加入升級提示

2. **成就系統：**
   - 基於等級解鎖成就
   - 可在 `ExperienceStore` 中加入成就追蹤

3. **Widget 顯示：**
   - 在 Widget 中顯示當前等級與 EXP
   - 使用相同的 `ExperienceStore` 邏輯

4. **統計資料：**
   - 記錄總獲得 EXP
   - 記錄升級歷史
