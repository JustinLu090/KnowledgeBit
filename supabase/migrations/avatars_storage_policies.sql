-- Avatars Storage RLS 政策
-- 在 Supabase Dashboard > SQL Editor 執行此檔案
-- 解決 403 "new row violates row-level security policy" 上傳錯誤

-- 先刪除舊政策（若已存在），再建立新的
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Avatars are publicly readable" ON storage.objects;

-- 1. 允許登入使用者上傳頭貼到自己專屬路徑 {user_id}/avatar.jpg
-- 使用 auth.jwt()->>'sub' 與 path 前綴檢查，較穩定
CREATE POLICY "Users can upload own avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' AND
  name LIKE (auth.jwt()->>'sub') || '/%'
);

-- 2. 允許使用者更新自己的頭貼（upsert 會觸發 UPDATE）
CREATE POLICY "Users can update own avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars' AND
  name LIKE (auth.jwt()->>'sub') || '/%'
)
WITH CHECK (
  bucket_id = 'avatars' AND
  name LIKE (auth.jwt()->>'sub') || '/%'
);

-- 3. 允許所有人讀取 avatars（bucket 為 public 時配合使用）
CREATE POLICY "Avatars are publicly readable"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');
