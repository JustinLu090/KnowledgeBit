# KnowledgeBit - 用碎片時間掌握知識

> **結合「被動輸入」（主畫面小工具）與「主動回憶」（每日測驗、SRS 複習、選擇題挑戰）的 iOS 學習 App。**

KnowledgeBit 是為現代「碎片化時間」設計的單字卡學習工具。有別於需要主動打開的傳統 App，KnowledgeBit 透過 **WidgetKit** 將知識推送到主畫面；並以 **App Groups** 在主 App 與小工具間同步資料，形成完整學習迴圈：**小工具瀏覽 → App 測驗／複習 → 連續天數與經驗值獎勵**。登入後更可同步至 **Supabase**、與好友共編單字集、發起**戰略對戰**，並以 **AI（Gemini）** 一鍵產生單字卡與選擇題。

---

## 功能總覽

### 一、首頁與學習入口

| 功能 | 說明 |
|------|------|
| **連續天數（Streak）** | 追蹤連續學習天數；同一天多次練習只算一天，斷日即重置。首頁以週曆條顯示過去 7 天的學習強度（GitHub 風格灰/淺藍～深藍）。 |
| **等級與經驗值（EXP）** | 完成每日測驗、完成任務、高正確率等可獲得 EXP，累積後升級；等級與 EXP 同步至 Supabase，並透過 App Group 供小工具顯示。 |
| **每日任務** | 每日可選多項任務（如：學習 5 分鐘、完成 1/2 本單字集複習、單字複習答對率 ≥90%、選擇題全對等），完成即得 EXP，進度以進度條與完成數顯示。 |
| **今日到期複習** | 依 SRS 排程顯示「今日到期」的卡片數量，一點即可進入 SRS 複習流程。 |
| **開始每日測驗** | 一鍵進入「全部卡片」或優先「到期卡片」的翻卡測驗；測驗結果會更新 SRS、StudyLog、每日任務與 EXP。 |
| **打卡 / 學習熱力圖** | 從首頁選單可進入「打卡」，查看 LeetCode 風格的學習熱力圖（依日期對齊、可切換年度），檢視過往每日學習強度。 |

### 二、單字集與卡片

| 功能 | 說明 |
|------|------|
| **單字集管理** | 建立多個單字集（如「英文」「CS – File System」），每張卡片可歸屬一個單字集，方便分主題學習。 |
| **單字集共編** | 單字集擁有者可邀請好友成為「共編者」；共編者可編輯卡片、參與該單字集的測驗與對戰，但僅擁有者可管理共編名單與發起對戰。 |
| **單字集同步** | 登入後，擁有與共編的單字集會與 Supabase 同步；在「單字集」分頁會自動拉取並合併遠端可見單字集。 |
| **卡片 CRUD** | 新增、編輯、刪除卡片；內容支援 **Markdown**；可從單字集詳情左滑刪除。 |
| **AI 產生單字卡** | 在新增單字時可輸入主題，呼叫 Supabase Edge Function，使用 **Google Gemini** 一次產生多張單字卡（word / definition / example），並可排除單字集內已有單字，避免重複。 |
| **設為 Widget 單字集** | 在單字集詳情可將該單字集設為「主畫面小工具」的來源，小工具會從此單字集隨機抽卡顯示。 |

### 三、測驗與複習

| 類型 | 說明 |
|------|------|
| **翻卡測驗（Quiz）** | 以 3D 翻卡動畫進行「看題 → 翻面看答案 → 記得/不記得」；可測「全部卡片」或「指定單字集」。結果會寫入 StudyLog、更新 SRS 與每日任務。 |
| **SRS 複習（Review）** | 依每張卡片的 `dueAt` 與 `srsLevel` 排程，只複習「今日到期」的卡片；答對升級間隔（10 分鐘 → 1 天 → 3 天 → 7 天…），答錯重置並 10 分鐘後再複習。 |
| **選擇題測驗（Choice Quiz）** | 由 AI 根據單字集內容產生「挖空句 + 四選一」題目；逐題作答後顯示結果，並可更新「選擇題全對」等每日任務。 |

### 四、對戰（Battle）

| 功能 | 說明 |
|------|------|
| **對戰房間** | 擁有者可針對某單字集建立對戰房間，設定天數（例如 7 天）；前 3/4 為「準備期」、最後 1/4 為「對戰期」。僅對戰期可進入戰略地圖戰鬥。 |
| **準備期 · 戰前測驗** | 準備期內，雙方需完成「戰前測驗」累積 **KE（動能）**；KE 用於對戰期在地圖上佔格與攻擊。 |
| **對戰期 · 戰略地圖** | 地圖為格子制，藍隊（房主）與紅隊（受邀者）輪流消耗 KE 佔領或攻擊格子；依規則結算 HP、佔領與勝負。 |
| **對戰地圖小工具** | 主畫面可加入「對戰地圖」小工具，顯示當前房間的戰略地圖快照，點擊可透過 Deep Link（`knowledgebit://battle?wordSetId=...`）開啟 App 並導向該單字集／對戰。 |
| **戰鬥能量（KE）** | 以單字集為 namespace 儲存於 App Group；戰前測驗答對可增加 KE，戰鬥時消耗 KE。 |

### 五、社群與個人

| 功能 | 說明 |
|------|------|
| **登入** | 支援 **Google 登入**（Supabase Auth）；登入後 profile（頭像、名稱）、等級、EXP 會同步至 Supabase 與 App Group。 |
| **個人頁** | 顯示頭像、名稱、設定入口；可編輯顯示名稱與頭像。 |
| **社群 · 邀請連結與 QR Code** | 每人有專屬邀請碼與邀請連結（網頁 + App scheme）；他人透過連結或掃 QR Code 可發送好友請求。 |
| **社群 · 好友** | 可搜尋使用者（依邀請碼）、發送/接受/拒絕好友請求；好友列表可解除好友。 |
| **單字集邀請** | 擁有者從單字集詳情邀請共編者；被邀請者會在「社群」頁看到待處理的單字集邀請，可接受或拒絕。接受後該單字集會出現在「單字集」列表。 |
| **成就 / 學習統計** | 「成就」分頁內為學習統計：本週每日 EXP 長條圖（Swift Charts）、單字複習平均正確率（圓形進度）；數據來自 DailyStats 與 StudyLog。 |

### 六、主畫面小工具（Widget）

| 小工具 | 說明 |
|--------|------|
| **單字卡小工具** | 從「當前設定的單字集」隨機選最多 5 張卡，在主畫面輪播；可左右箭頭切換（iOS 17+ 互動）；每 15 分鐘自動換一批。 |
| **對戰地圖小工具** | 顯示當前進行中對戰房間的戰略地圖快照；點擊以 Deep Link 開啟 App 並導向該對戰單字集。 |

---

## 技術架構

### 技術棧

| 項目 | 技術 |
|------|------|
| 語言 | Swift 5.9 |
| UI | SwiftUI |
| 本地持久化 | SwiftData（Core Data schema） |
| 小工具 | WidgetKit（含 App Intents 互動） |
| 後端 / 同步 | Supabase（Auth、PostgreSQL、Edge Functions） |
| 登入 | Google Sign-In + Supabase Auth |
| AI 產生 | Supabase Edge Function + Google Gemini API |
| 圖表 | Swift Charts（成就頁） |
| 版本控制 | Git / GitHub |

### 技術要點

1. **App Group 資料共用**  
   SwiftData 的 `ModelContainer` 使用 `groupContainer: .identifier("group.com.team.knowledgebit")`，讓主 App 與 Widget Extension 共用同一 SQLite；小工具可讀取單字集、卡片、到期數、等級、EXP、對戰快照等。

2. **互動小工具（iOS 17+）**  
   單字卡小工具使用 `AppIntentConfiguration` 與 `AppIntentTimelineProvider`，透過 `NextCardIntent` / `PreviousCardIntent` 實作左右切換；當前卡片索引與選中的 5 張卡 ID 存於 App Group UserDefaults。

3. **SRS 間隔**  
   等級 0：10 分鐘；1：1 天；2：3 天；3：7 天；4：14 天；5：30 天；之後每級 +30 天。複習結果透過 `SRSService` 寫回 `Card.srsLevel`、`dueAt`、`correctStreak`，並更新 App Group 的今日到期數供小工具顯示。

4. **經驗值與每日任務**  
   EXP 由 `ExperienceStore` 管理，存於 App Group UserDefaults 並同步至 Supabase；每日任務定義與進度由 `DailyQuestService` 管理（UserDefaults），完成時呼叫 `ExperienceStore.addExp` 並更新 DailyStats。

5. **對戰與 KE**  
   對戰房間、回合、地圖狀態等存於 Supabase；KE 以單字集 ID 為 key 存於 App Group UserDefaults（`BattleEnergyStore`），戰前測驗與戰鬥時讀寫。

6. **Deep Link**  
   - 對戰：`knowledgebit://battle?wordSetId=<UUID>`  
   - 邀請：`knowledgebit://join/<invite_code>` 或網頁 `https://<InviteConstants.baseURL>/join/<code>`

---

## 使用方式摘要

### 單字集與卡片

- **新增單字集**：首頁「+」→「新增單字集」，輸入標題與選填等級。  
- **新增單字**：首頁「+」→「新增單字」，或進入單字集後右上「+」；可填主題並用 AI 一次產生多張卡。  
- **設為 Widget 單字集**：單字集詳情右上「設為 Widget 單字集」。

### 測驗與複習

- **每日測驗（全部或到期）**：首頁「開始每日測驗」。  
- **單字集測驗**：進入單字集 →「開始測驗」（翻卡）或「選擇題測驗」（需先產生題目）。  
- **今日到期複習**：首頁「今日到期複習」進入 SRS 複習。

### 對戰

- **建立對戰**：單字集擁有者在單字集詳情建立對戰房間並邀請對方。  
- **準備期**：雙方在「戰前測驗」累積 KE。  
- **對戰期**：進入「對戰房間」→「進入戰鬥」，在地圖上消耗 KE 佔格/攻擊。

### 社群

- **加好友**：社群頁輸入對方邀請碼搜尋並發送請求；或分享自己的邀請連結/QR Code。  
- **單字集共編**：單字集詳情（擁有者）→ 邀請共編 → 對方在社群頁接受邀請。

### 小工具

- **單字卡**：主畫面新增小工具 → 選 KnowledgeBit 單字卡小工具；在 App 內設定要顯示的單字集。  
- **對戰地圖**：進行中對戰時，可加入對戰地圖小工具，點擊開啟 App 至該對戰。

---

## 專案結構（主要檔案）

```
KnowledgeBit/
├── KnowledgeBit/                    # 主 App
│   ├── KnowledgeBitApp.swift        # 入口、ModelContainer、Deep Link、環境物件
│   ├── MainTabView.swift            # 分頁：首頁 / 單字集 / 社群 / 成就 / 個人
│   ├── HomeView.swift               # 首頁（Streak、EXP、每日任務、測驗、到期複習）
│   ├── HomeSharedComponents.swift   # 首頁標題、每日測驗按鈕、打卡入口
│   ├── StreakCardView.swift         # 連續天數卡片與週曆
│   ├── ExpCardView.swift            # 等級與經驗值卡片
│   ├── DailyQuestsView.swift        # 每日任務區塊
│   ├── DueCardsCardView.swift       # 今日到期複習卡片（可選顯示）
│   ├── LibraryView.swift            # 單字集列表（含 Supabase 同步）
│   ├── WordSetListView.swift        # 單字集列表內容
│   ├── WordSetDetailView.swift      # 單字集詳情（卡片、測驗、選擇題、共編、對戰）
│   ├── WordSet+IconFields.swift     # 單字集圖示等擴充
│   ├── AddCardView.swift            # 新增/編輯單字（含 AI 產生）
│   ├── AddWordSetView.swift         # 新增單字集
│   ├── CardDetailView.swift         # 單字詳情與編輯/刪除
│   ├── CardRowView.swift            # 單字列表列
│   ├── Card.swift                   # Card、StudyLog 模型
│   ├── WordSet.swift                # WordSet 模型
│   ├── QuizView.swift               # 翻卡測驗
│   ├── QuizResultView.swift         # 測驗結果全螢幕
│   ├── ChoiceQuizView.swift         # 選擇題測驗 UI
│   ├── ReviewSessionView.swift      # SRS 複習流程
│   ├── SRSService.swift             # SRS 排程與到期查詢
│   ├── BattleRoomView.swift        # 對戰房間（準備期/對戰期）
│   ├── StrategicBattleView.swift   # 戰略地圖戰鬥
│   ├── StrategicBattleViewModel.swift
│   ├── BattlePrepQuizView.swift     # 戰前測驗（累積 KE）
│   ├── BattleEnergyStore.swift     # KE 儲存（App Group）
│   ├── CommunityView.swift         # 社群（邀請、好友、單字集邀請）
│   ├── CommunityViewModel.swift
│   ├── InviteService.swift          # 邀請碼、分享連結、RPC
│   ├── WordSetInvitationService.swift # 單字集邀請 API
│   ├── PendingInviteStore.swift    # 待處理邀請（Deep Link）
│   ├── PendingBattleOpenStore.swift # 待開啟對戰（Deep Link）
│   ├── AchievementsView.swift      # 成就 Tab 容器
│   ├── StatisticsView.swift        # 學習統計（本週 EXP、正確率）
│   ├── ProfileView.swift           # 個人頁
│   ├── EditProfileView.swift       # 編輯頭像與名稱
│   ├── SettingsView.swift          # 設定
│   ├── LoginView.swift             # 登入（Google）
│   ├── AuthService.swift           # Supabase Auth 與 profile 同步
│   ├── ExperienceStore.swift       # 等級/EXP 與雲端同步
│   ├── TaskService.swift           # 任務完成時加 EXP
│   ├── DailyQuest.swift            # 每日任務模型與 DailyQuestService
│   ├── StudyHeatmapView.swift      # 學習熱力圖（打卡頁）
│   ├── CheckInView.swift           # 打卡頁（內嵌熱力圖）
│   ├── FlipCardView.swift          # 3D 翻卡元件
│   ├── WeeklyCalendarView.swift   # 週曆條元件
│   ├── AppGroup.swift              # App Group ID 與 UserDefaults Keys
│   ├── WidgetReloader.swift        # 觸發小工具重載
│   └── ...（其他輔助與 UI）
├── KnowledgeWidget/                 # Widget Extension
│   ├── KnowledgeWidget.swift       # 單字卡小工具、對戰地圖小工具、Timeline、App Intents
│   └── KnowledgeWidgetControl.swift
├── supabase/
│   ├── migrations/                 # 資料表、RPC、RLS
│   └── functions/
│       ├── generate-card/         # 依主題用 Gemini 產生多張單字卡
│       └── join-preview/           # 邀請連結預覽等
└── components/                      # 網頁邀請頁等（若使用）
```

---

## 安全與敏感設定

- **Supabase**  
  請將 `SupabaseConfig.example.txt` 複製為 `SupabaseConfig.swift`，並在 [Supabase Dashboard](https://supabase.com/dashboard) → Project Settings → API 填入 **Project URL** 與 **anon public key**。`SupabaseConfig.swift` 已列入 `.gitignore`，請勿提交。  
  若曾誤將 `SupabaseConfig.swift` 提交，請在 Dashboard 的 API 設定中**重新產生 anon key**，並更新本機設定，以降低外洩風險。

- **Edge Functions（Gemini）**  
  AI 產生單字卡與選擇題所使用的 API Key，請僅在 Supabase 的 Edge Function **Secrets** 中設定 `GEMINI_API_KEY`，勿寫入程式碼。設定方式請參考專案內 AI 相關說明文件（若有 `AI_SETUP.md` 則以該檔為準）。

---

## 環境需求

- **iOS**：17.0 以上  
- **Xcode**：15.0 以上  
- **Capabilities**：主 App 與 Widget Extension 皆須啟用 **App Groups**（例如 `group.com.team.knowledgebit`），並在 Signing & Capabilities 中正確設定。

---

## 授權與貢獻

本專案為學習與個人使用導向；若需二次開發或貢獻，請依專案倉庫說明進行。
