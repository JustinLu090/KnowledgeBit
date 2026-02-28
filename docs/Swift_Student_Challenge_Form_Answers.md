# Swift Student Challenge — 表單回答（中英對照）

根據 KnowledgeBit 專案整理的提交表單回答，可直接複製到表單或依需要微調。

---

## 功能總覽 / Feature Overview（供撰寫與截圖參考）

- **多種 Widget**：主畫面「知識小工具」（可互動翻卡、多尺寸與鎖定畫面）、「對戰地圖」Widget（即時顯示戰略格與紅藍佔領）。
- **測驗方式**：單字卡測驗（翻卡、主動回憶）、選擇題測驗（多選一），以及對戰中的題目測驗。
- **單字卡來源**：可手動新增／編輯卡片，也可用 AI 依描述或主題一次產生多張單字卡。
- **對戰功能**：邀請單字集共編成員、選擇題測驗對戰、戰略地圖即時佔領與回合摘要，並可從 Widget 一鍵進入對戰。

---

## 1. Name of your app playground / 你的 App Playground 名稱

**English:**  
KnowledgeBit

**中文：**  
KnowledgeBit（或：知識碎片）

---

## 2. Which software should we use to run your app playground? / 我們應該使用哪種軟體來執行你的 App Playground？

**English:**  
Xcode (run in Simulator)

**中文：**  
Xcode（在模擬器中執行）

---

## 3. What problem is your app playground trying to solve and what inspired you to solve it?  
## 你的 App Playground 嘗試解決什麼問題？以及是什麼啟發你解決這個問題？  
**（200 words or less / 200 字以內）**

### English (within 200 words)

Many learners struggle to study consistently because they only think about learning when they open an app—by then, free time is often over. KnowledgeBit brings learning into fragmented moments: on the home screen with multiple widgets, without having to open the app.

I was inspired by two ideas. First, “passive input”—we glance at our phones dozens of times a day; what if some of those glances showed a flashcard? Second, “active recall”—real retention comes from testing yourself. I built a **knowledge widget** (home and lock screen) plus in-app **flashcard** and **multiple-choice** quizzes. Cards can be added **manually** or **with AI** (describe a topic and generate a set). A **battle** mode lets you invite collaborators and compete on a strategic grid; a **battle map widget** keeps the match visible from the home screen.

The core loop is **Widget Browse → App Quiz (flashcard or choice) → Streak**; battle adds social, gamified practice. App Groups keep the app and all widgets in sync. The goal is to make learning fit into life—and into study groups—instead of relying on long, solitary sessions.

---

### 中文（200 字以內）

很多人無法持續學習，是因為只有「打開 app」時才會想到要念書，而真的打開時零碎時間往往已經沒了。KnowledgeBit 把學習放進這些零碎時刻：用**多種小工具**在主畫面（與鎖定畫面）就能看到內容，不必先打開 app。

靈感來自兩點：一是「被動輸入」——每天會看手機很多次，若其中幾次是單字或知識卡就能自然複習；二是「主動回憶」——真正記住要靠測驗。所以除了主畫面的**知識小工具**，在 app 裡有**單字卡測驗**（翻卡回憶）和**選擇題測驗**；單字卡可以**手動新增**，也能用 **AI 依描述或主題一次產生多張**。**對戰功能**則讓單字集共編成員一起在戰略地圖上答題佔領、即時對戰，並有**對戰地圖小工具**從主畫面一鍵查看。

核心循環是**小工具瀏覽 → App 測驗（單字卡或選擇題）→ 連續天數**，對戰則加上社交與遊戲化。透過 App Groups 讓 app 與所有小工具共用同一批卡片與學習資料，目標是讓學習塞進生活與共學，而不是只靠長時間獨自念書。

---

## 4. Who would benefit from your app playground and how?  
## 誰會從你的 App Playground 受益？如何受益？  
**（200 words or less / 200 字以內）**

### English (within 200 words)

Students and busy learners who find it hard to block out long study sessions benefit most. They see cards on the **knowledge widget** (home or lock screen), then open the app for a quick **flashcard** or **multiple-choice** quiz. No need to remember to open the app—the widget reminds them. Cards can be added **manually** or **with AI** (describe a topic and generate a set), so building a deck is fast.

Language learners benefit from spaced repetition and short, frequent practice; the streak and weekly calendar give clear feedback. The **battle** mode helps study groups and collaborators: invite members of a shared word set, answer questions, and compete on a strategic grid. The **battle map widget** keeps the match visible from the home screen. Different quiz types (flip-card recall vs. multiple choice) suit different goals and moods.

Teachers or study groups can use word sets to organize cards by topic or level and run battles for review. In short, anyone who wants to learn in small, consistent steps—alone or with others—and likes flexibility in how they add content and how they quiz can benefit.

---

### 中文（200 字以內）

最適合的是「很難排出長時間、但有很多零碎時間」的學生與上班族。他們可以在主畫面的**知識小工具**（或鎖定畫面）看到卡片，有幾分鐘再打開 app 做**單字卡測驗**或**選擇題測驗**，不必刻意記得打開 app，小工具就是提醒。單字卡可**手動新增**，也可**用 AI 描述主題一次產生多張**，建卡很快。

對語言學習者特別有幫助：單字需要間隔複習與少量多次，連續天數與每週日曆提供進度與動力。**對戰功能**則適合讀書會與共編成員：邀請同一單字集的夥伴，一起答題、在戰略地圖上即時對戰，**對戰地圖小工具**讓戰況在主畫面就能看到。單字卡測驗與選擇題測驗可依目標與情境切換。

老師或讀書會可用單字集依主題或程度整理卡片，並用對戰做複習。總結：任何想用「小步、持續」取代「久久一次、一次很久」的人，以及喜歡手動／AI 建卡、多種測驗與對戰的人，都能從中受益。

---

## 5. How did accessibility factor into your design process?  
## 無障礙設計在你的設計過程中扮演什麼角色？  
**（200 words or less / 200 字以內）**

### English (within 200 words)

Accessibility was considered from the start. I use system fonts and support Dynamic Type so text scales with the user’s preferred size. Important actions use clear labels and hierarchy so the interface is scannable.

I added haptic feedback for key actions (e.g. flipping a card, completing a quiz, updating the streak) so that success and state changes are communicated by touch as well as visually. This helps in noisy or low-visibility environments and supports users who rely more on tactile feedback.

Interactive elements are sized for comfortable tap targets, and the widget and app both avoid relying on color alone to convey meaning—icons and text reinforce the same information. For the quiz, the flip animation is optional in spirit: the main content is readable without depending on the animation. I kept contrast and spacing consistent so that the layout stays readable at different text sizes and in different lighting conditions.

---

### 中文（200 字以內）

從一開始就把無障礙納入考量。使用系統字型並支援 Dynamic Type，文字會依使用者設定的字級縮放；重要操作有清楚的標籤與層級，方便掃讀。

在關鍵操作（例如翻卡、完成測驗、更新連續天數）加入觸覺回饋，讓成功或狀態改變不只用畫面、也用觸覺傳達，在吵雜或光線不佳時仍有回饋，也方便更依賴觸覺的使用者。

按鈕與可點區域有足夠的點擊範圍；小工具與 app 都不單靠顏色傳達資訊，會用圖示與文字重複同一訊息。測驗的翻卡動畫不是必須依賴才能理解內容，主要資訊在靜態時也可閱讀。對比與間距盡量一致，在不同字級與光線下仍能閱讀。

---

## 6. Did you use open source software, other than Swift?  
## 你是否使用了 Swift 以外的開源軟體？

**English:**  
Yes. The project uses the Supabase Swift client for backend and optional cloud sync, and Google Sign-In for authentication in the full app. The App Playground submission may be a standalone version using only Swift, SwiftUI, SwiftData, and WidgetKit (all Apple frameworks). If your submitted ZIP includes no third-party dependencies, answer **No**.

**中文：**  
是。專案中使用了 Supabase Swift 客戶端（後端與選用雲端同步）以及 Google Sign-In（完整版 app 登入）。若你提交的 App Playground 是僅使用 Swift、SwiftUI、SwiftData、WidgetKit（皆為 Apple 框架）的獨立版本且 ZIP 內無第三方套件，請選 **No**。

**表單選項：**  
- 若提交的 .swiftpm 內含 Supabase / Google 等第三方套件 → 選 **Yes**，並在表單要求處說明：Supabase Swift SDK, Google Sign-In for iOS。  
- 若提交的 .swiftpm 僅用 Apple 內建框架 → 選 **No**。

---

## 7. Did you use any content that you don't have ownership rights to?  
## 你是否使用了任何你沒有所有權的內容？

**English:**  
No. All code is original. Any assets (icons, images) used in the playground are either created by me or from system symbols (SF Symbols) and Apple’s frameworks. No third-party artwork, music, or copyrighted content is used without permission.

**中文：**  
否。程式碼皆為原創。Playground 中使用的素材（圖示、圖片）為自行製作或使用系統符號（SF Symbols）與 Apple 框架提供之資源，未使用未經授權的第三方圖像、音樂或受版權保護之內容。

**表單選項：**  
**No** / 否

---

## 提交前檢查清單

- [ ] **Playground & Assets**：ZIP 內含 .swiftpm 與所需素材，且 ≤ 25 MB。  
- [ ] **Screenshots**：3 張 .png 或 .jpg，各 ≤ 5 MB，建議包含：知識小工具（或對戰地圖小工具）、單字卡／選擇題測驗畫面、對戰或連續天數等體驗。  
- [ ] **Software**：下拉選 Xcode（Simulator）。  
- [ ] **字數**：第 3、4、5 題英文回答皆 ≤ 200 words。  
- [ ] **開源 / 版權**：依實際提交內容選擇 Yes/No 並必要時簡短說明。

---

*本文件依 KnowledgeBit 專案內容撰寫，實際提交時請依你的 Playground 範圍（是否含後端、登入等）調整第 6 題與文字細節。*
