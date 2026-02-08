-- SUPABASE_USER_PROFILES.sql
-- 創建 user_profiles 表，用於儲存用戶個人資料
-- 注意：頭貼圖片建議使用 Supabase Storage，此表僅儲存 metadata

-- 創建 user_profiles 表
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '使用者',
  avatar_url TEXT,  -- Supabase Storage 的圖片 URL 或 Google 頭貼 URL
  level INTEGER NOT NULL DEFAULT 1,  -- 用戶等級
  current_exp INTEGER NOT NULL DEFAULT 0,  -- 當前經驗值
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 建立索引以加速查詢
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);

-- 啟用 Row Level Security (RLS)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- RLS 政策：用戶只能查看和修改自己的資料
CREATE POLICY "Users can view own profile"
  ON user_profiles
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
  ON user_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own profile"
  ON user_profiles
  FOR DELETE
  USING (auth.uid() = user_id);

-- 自動更新 updated_at 的觸發器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 可選：為現有用戶自動創建 profile（如果需要的話）
-- CREATE OR REPLACE FUNCTION create_profile_for_new_user()
-- RETURNS TRIGGER AS $$
-- BEGIN
--   INSERT INTO user_profiles (user_id, display_name)
--   VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email));
--   RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql SECURITY DEFINER;

-- CREATE TRIGGER on_auth_user_created
--   AFTER INSERT ON auth.users
--   FOR EACH ROW
--   EXECUTE FUNCTION create_profile_for_new_user();
