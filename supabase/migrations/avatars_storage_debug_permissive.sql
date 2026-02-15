-- 除錯用：極寬鬆政策（無路徑檢查）
-- 若此政策能通過，表示問題出在 path 條件；若仍 403，表示請求可能未帶 JWT（anon）
-- 執行後請測試上傳，成功後務必改回正式政策 avatars_storage_policies.sql

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Avatars are publicly readable" ON storage.objects;

-- 僅檢查 bucket，不檢查 path（除錯用）
CREATE POLICY "Users can upload own avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Users can update own avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars')
WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Avatars are publicly readable"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');
