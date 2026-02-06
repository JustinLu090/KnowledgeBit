# KnowledgeBit 記憶體問題分析與修改建議

本文件整理可能導致 App 因記憶體過高被系統終止的原因，以及已實施與建議的修改。

---

## 1. 只增不減的變數、陣列或快取 (Cache)

### 1.1 @Query 載入無上限筆數

**問題**：多處使用 `@Query` 且**沒有 predicate 或 fetchLimit**，會依資料庫內容載入**全部** `StudyLog` / `Card`，時間一久筆數只會增加，記憶體只升不降。

| 檔案 | 查詢 | 風險 |
|------|------|------|
| `StreakCardView.swift` | `@Query(sort: \StudyLog.date, order: .reverse) var logs` | 載入全部學習記錄 |
| `StatsView.swift` | 同上 | 同上 |
| `StudyHeatmapView.swift` | 同上 | 同上，且 heatmap 會對每一天呼叫 `countForDate`，複雜度 O(天數 × logs) |
| `QuizView.swift` | `@Query ... var logs`、`@Query ... var allCards` | 全部 StudyLog + 全部 Card |
| `WordSetListView.swift` | `@Query ... var wordSets` | 全部 WordSet（通常量較小） |

**建議修改**（擇一或並用）：

- **方案 A**：對「只關心近期資料」的畫面改用 **FetchDescriptor + predicate + fetchLimit**，在 `.task { }` 裡手動 fetch 後存到 `@State`，例如只取最近 400 天的 StudyLog、或最多 5000 筆：
  ```swift
  // 範例：在 .task 中限制範圍
  let cutoff = Calendar.current.date(byAdding: .day, value: -400, to: Date())!
  var descriptor = FetchDescriptor<StudyLog>(
    predicate: #Predicate<StudyLog> { $0.date >= cutoff },
    sortBy: [SortDescriptor(\.date, order: .reverse)]
  )
  descriptor.fetchLimit = 5000
  let recent = try modelContext.fetch(descriptor)
  ```
- **方案 B**：若維持 `@Query`，可研究 SwiftData 是否支援以**綁定變數**傳入 predicate（例如 `cutoffDate`），讓查詢只取「最近 N 天」，避免載入整張表。

**已實施**：尚未改動 @Query，避免影響現有行為；建議在確認 predicate 與綁定變數後再套用方案 A/B。

---

### 1.2 ExperienceStore / DailyQuestService

- 使用 `UserDefaults` 存少量數值（等級、EXP、任務進度），**沒有無上限陣列或快取**，目前可視為安全。
- 若未來在記憶體中維護「歷史紀錄」或「事件佇列」，請加上筆數上限或定期清理。

---

## 2. 閉包 (Closure) 強引用導致無法釋放

### 2.1 StudyHeatmapView — `DispatchQueue.main.asyncAfter` 與 `scrollToLatest`

**問題**：`scrollToLatest(proxy:)` 內用 `DispatchQueue.main.asyncAfter`，閉包裡使用 `monthBlocks.last`，會**隱性捕獲 self（View）**，延遲執行時仍持有該視圖，若使用者快速切換年份會排隊多個延遲 block，增加記憶體與生命週期。

**已實施**：

- 改為 `scrollToLatest(proxy:lastMonthId:)`，由呼叫端傳入 `monthBlocks.last?.id`（`String`）。
- 延遲閉包內只使用 `proxy` 與 `lastMonthId`（值類型／參數），**不再存取 `monthBlocks` 或 self**，降低強引用與重複建立視圖的風險。

### 2.2 QuizResultView — `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)`

**問題**：閉包內更新 `showContent`（@State）。若使用者在 0.3 秒內離開畫面，View 可能已被 dismiss，延遲 block 仍會執行並更新 state，雖不一定直接造成 leak，但可能觸發多餘的更新或未預期行為。

**建議**（可選）：

- 使用 `Task { try? await Task.sleep(nanoseconds: 300_000_000); ... }`，並在 `.onDisappear` 裡 `task.cancel()`，讓離開畫面時取消延遲動畫。
- 或維持現狀，但避免在閉包內再捕獲其他強引用（例如不要捕獲整個 View 或大量資料）。

---

### 2.3 其他閉包

- `NotificationManager`、`UNUserNotificationCenter` 的 completion handler 為系統 API，未發現明顯強引用循環。
- `QuizView` 傳給 `QuizResultView` 的 `onFinish` / `onRetry` 主要捕獲 `questService`、`taskService`、`experienceStore`、`dismiss` 等，為環境物件或 SwiftUI 提供，未發現 View 之間的循環引用。

---

## 3. 大量 UI 渲染與重複建立視圖 (Views)

### 3.1 HeatmapDay / MonthBlock 使用 UUID() 作為 id

**問題**：`HeatmapDay`、`MonthBlock` 的 `id = UUID()` 在**每次 computed property 重新計算**時都會變，SwiftUI 的 `ForEach` 會認為整份列表都是新項目，導致**大量 cell 被銷毀並重新建立**，增加記憶體與 CPU 負擔。

**已實施**：

- **HeatmapDay**：改為 `var id: TimeInterval { date.timeIntervalSince1970 }`（以日期為穩定 id）。
- **MonthBlock**：改為 `var id: String { "\(year)-\(monthIndex)" }`（以年＋月為穩定 id）。

這樣同一日／同一月會保持相同 id，減少不必要的 view 重建。

### 3.2 DayStudySummary 使用 UUID() 作為 id

**問題**：`WeeklyCalendarView` 的資料來源 `weeklySummaries` 每次計算都會產生新的 `DayStudySummary`，且每個都帶新的 `UUID()`，導致 7 天的 strip 被當成全新列表而重繪。

**已實施**：

- **DayStudySummary**：改為 `var id: TimeInterval { date.timeIntervalSince1970 }`，以日期為穩定 id。

### 3.3 StudyHeatmapView — heatmapData 重算成本

**問題**：`heatmapData` 對選取範圍內**每一天**呼叫 `countForDate(currentDate)`，若 `countForDate` 每次都 filter 整個 `logs`，會變成 O(天數 × logs)，CPU 與暫時記憶體都會偏高。

**已實施**：

- 新增 `logsByDate: [Date: Int]`，在一個 computed 中**一次**遍歷 `logs` 依日期彙總。
- `countForDate` 改為對 `logsByDate` 做 O(1) 查表。
- 整體由 O(天數 × logs) 降為 O(logs) + O(天數)。

---

## 4. 已實施修改摘要

| 項目 | 檔案 | 修改內容 |
|------|------|----------|
| 穩定 id | `StudyHeatmapView.swift` | `HeatmapDay.id` → `date.timeIntervalSince1970`；`MonthBlock.id` → `"\(year)-\(monthIndex)"` |
| 閉包不捕獲 self | `StudyHeatmapView.swift` | `scrollToLatest(proxy:lastMonthId:)`，延遲閉包只使用 `proxy` 與 `lastMonthId` |
| 穩定 id | `WeeklyCalendarView.swift` | `DayStudySummary.id` → `date.timeIntervalSince1970` |
| Heatmap 彙總 | `StudyHeatmapView.swift` | 新增 `logsByDate`，`countForDate` 改為 O(1) 查表，避免 O(天數×logs) |

---

## 5. 建議後續優先處理

1. **限制 StudyLog 查詢範圍**：在 StreakCardView、StatsView、StudyHeatmapView（及必要時 QuizView）改用手動 FetchDescriptor + 最近 N 天 predicate + fetchLimit，或等效的 @Query 寫法，避免載入無上限筆數。
2. **Heatmap 資料結構與重算**：對 `logs` 做一次「依日期彙總」，並視情況用 @State 快取 heatmap 資料，降低 body 重算次數與複雜度。
3. **QuizResultView 延遲動畫**：可改為 `Task` + `onDisappear` 取消，避免延遲 block 在畫面已消失後仍執行。

完成上述項目後，預期可明顯降低長時間使用後的記憶體成長與被系統終止的機率。
