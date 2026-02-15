# 頭貼 Storage 設定說明

編輯個人資料時，若使用者選擇自訂頭貼，App 會上傳至 Supabase Storage。需先建立 bucket。

## 1. 建立 avatars bucket

1. 前往 **Supabase Dashboard > Storage**
2. 點擊 **New bucket**
3. 設定：
   - Name: `avatars`
   - Public bucket: **勾選**（頭貼需可被他人讀取，如好友列表）
4. 儲存

## 2. RLS 政策（必要）

若出現 `403: new row violates row-level security policy`，表示需新增 Storage RLS 政策。

**在 Supabase Dashboard > SQL Editor 執行：**

```sql
-- 先刪除舊政策，再建立新的（使用 auth.jwt()->>'sub' 較穩定）
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Avatars are publicly readable" ON storage.objects;

CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars' AND name LIKE (auth.jwt()->>'sub') || '/%');

CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND name LIKE (auth.jwt()->>'sub') || '/%')
WITH CHECK (bucket_id = 'avatars' AND name LIKE (auth.jwt()->>'sub') || '/%');

CREATE POLICY "Avatars are publicly readable"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');
```

完整 SQL 檔案：`supabase/migrations/avatars_storage_policies.sql`

## 3. user_profiles 表 RLS（若資料庫不更新）

若頭貼或名稱已上傳但 **Supabase 資料庫的 user_profiles 沒有更新**，可能是 RLS 阻擋。請執行 `supabase/migrations/user_profiles_rls_policies.sql`。

## 4. 若未設定

若未建立 avatars bucket，頭貼上傳會失敗，但 **名稱仍會同步** 至 Supabase。App 會印出警告日誌，不影響其他功能。
