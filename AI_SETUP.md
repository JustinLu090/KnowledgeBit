# AI 卡片產生功能：API Key 與部署說明

「用 AI 產生卡片」會透過 **Supabase Edge Function** 呼叫 **Google Gemini API**，API Key 只存放在 Supabase 後端，**不會**寫在 App 裡，較安全。

## 一、取得 Google Gemini API Key

1. 前往 [Google AI Studio](https://aistudio.google.com/) 並用 Google 帳號登入。
2. 點左側 **Get API key**（或 [https://aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)）。
3. 選擇或建立一個專案後，點 **Create API key**。
4. **複製金鑰**，妥善保存（可隨時在 AI Studio 重新查看或停用）。

## 二、在 Supabase 設定 API Key（Secret）

1. 開啟 [Supabase Dashboard](https://supabase.com/dashboard)，選你的專案（與 `SupabaseConfig.swift` 同一個）。
2. 左側選 **Edge Functions**，在 **Secrets** 區塊點 **Add new secret**（或到 Project Settings → Edge Functions → Secrets）。
3. 新增一筆：
   - **Name**: `GEMINI_API_KEY`
   - **Value**: 貼上剛才複製的 Gemini API Key。
4. 儲存。

## 三、部署 Edge Function（generate-card）

專案裡已包含 Edge Function 原始碼：`supabase/functions/generate-card/index.ts`（使用 Gemini 2.5 Flash）。

### 方式 A：用 Supabase CLI（建議）

1. 安裝 [Supabase CLI](https://supabase.com/docs/guides/cli)（若尚未安裝）：
   ```bash
   brew install supabase/tap/supabase
   ```
2. 在專案根目錄登入並連結專案：
   ```bash
   cd /path/to/KnowledgeBit
   supabase login
   supabase link --project-ref <你的專案 ref>
   ```
   **專案 ref** 可在 Dashboard 的 **Project Settings → General** 裡看到（例如 URL `https://xxxxx.supabase.co` 的 `xxxxx` 就是 ref）。
3. 部署函數：
   ```bash
   supabase functions deploy generate-card
   ```
4. 若剛才沒在 Dashboard 設 Secret，可用 CLI 設定：
   ```bash
   supabase secrets set GEMINI_API_KEY=你的金鑰
   ```

### 方式 B：在 Dashboard 建立函數

1. Dashboard → **Edge Functions** → **Deploy a new function** → **Via Editor**。
2. 名稱填 `generate-card`。
3. 將 `supabase/functions/generate-card/index.ts` 的內容貼上並部署。
4. 在 **Secrets** 中新增 `GEMINI_API_KEY`（同上）。

## 四、確認可正常呼叫

- 在 App 的「新增卡片」畫面上方會出現 **AI 產生** 區塊。
- 輸入主題（例如「TCP 三次握手」）後點 **用 AI 產生卡片**。
- 若設定正確，標題與詳細筆記會自動帶入；若失敗，畫面上會顯示錯誤訊息（例如未設定 Key、網路錯誤等）。

## 五、常見問題

| 狀況 | 可能原因 | 處理方式 |
|------|----------|----------|
| **401 Unauthorized** | Edge Function 預設驗證 JWT，請求未帶有效 token 或被拒 | 見下方「遇到 401 怎麼除錯」 |
| **502 Bad Gateway** | Edge Function 執行時出錯（例如沒設 Key、Gemini 呼叫失敗） | 見下方「遇到 502 怎麼除錯」 |
| 顯示「GEMINI_API_KEY not configured」 | Edge Function 沒有讀到 Secret | 在 Dashboard → Edge Functions → Secrets 新增 `GEMINI_API_KEY`，或用 `supabase secrets set` 設定後不必重新 deploy |
| 網路錯誤 / 逾時 | 裝置網路或 Supabase 區域 | 檢查網路、或確認 Edge Function 部署的區域 |
| 未登入時無法使用 | 功能需透過 Supabase 呼叫，會帶入登入狀態 | 先完成登入再使用 AI 產生 |

### 遇到 401 怎麼除錯

1. **看 Xcode Console**：按「用 AI 產生卡片」後，在 Xcode 下方 Console 會印出 `[AddCardView] AI generate: isLoggedIn=...` 與 `[AIService] generateCard failed: ...`。確認 `isLoggedIn=true`（已登入）。
2. **關閉 JWT 驗證（先讓功能跑通）**：  
   - **若用 CLI 部署**：專案已含 `supabase/config.toml`，內有 `[functions.generate-card] verify_jwt = false`。重新執行 `supabase functions deploy generate-card` 後再試。  
   - **若用 Dashboard 部署**：到 Edge Functions → 點 **generate-card** → 在 function 設定裡找到 **Verify JWT** 或 **Enforce JWT**，關閉後重新部署。
3. 關閉後仍 401：確認 App 的 `SupabaseConfig.swift` 的 URL、anon key 與 Dashboard → Project Settings → API 完全一致。

### 遇到 502 怎麼除錯

502 表示請求已進入 Edge Function，但 function 執行時出錯。

1. **看 Xcode Console 的 Response body**：App 會嘗試印出 `[AIService] Response body: ...`，裡面可能是 Edge Function 回傳的 JSON（例如 `{"error":"GEMINI_API_KEY not configured"}` 或 Gemini 的錯誤訊息）。
2. **看 Supabase 的 function 日誌（最準）**：Dashboard → **Edge Functions** → 點 **generate-card** → 分頁選 **Logs** 或 **Invocations**，再按一次「用 AI 產生卡片」，看該次呼叫的 log 與錯誤內容。
3. **常見原因**：  
   - **GEMINI_API_KEY 未設定**：到 Edge Functions → **Secrets** 新增 `GEMINI_API_KEY`（值為你的 Gemini API key），儲存後不必重新 deploy function。  
   - **Gemini API 失敗**：key 無效、額度或限制；可對照 Logs 裡的錯誤訊息，或到 [Google AI Studio](https://aistudio.google.com/) 檢查 key 與用量。

## 六、費用說明

- **Supabase Edge Function**：依 Supabase 方案有免費額度。
- **Google Gemini API**：本功能使用 `gemini-2.5-flash`，有免費額度與付費方案，詳見 [Google AI 定價](https://ai.google.dev/pricing)。
