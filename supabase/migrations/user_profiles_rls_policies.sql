-- user_profiles 表 RLS 政策
-- 確保登入使用者可讀寫自己的資料（含 upsert 的 INSERT / UPDATE）
-- 在 Supabase Dashboard > SQL Editor 執行

-- 啟用 RLS（若尚未啟用）
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- 若政策已存在則刪除（可依實際政策名稱調整）
DROP POLICY IF EXISTS "Users can read own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;

-- 讀取：使用者可讀自己的 profile
CREATE POLICY "Users can read own profile"
ON user_profiles FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 插入：使用者可建立自己的 profile（登入後首次建立）
CREATE POLICY "Users can insert own profile"
ON user_profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- 更新：使用者可更新自己的 profile（EditProfile 儲存時）
CREATE POLICY "Users can update own profile"
ON user_profiles FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
