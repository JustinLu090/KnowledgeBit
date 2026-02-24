-- KnowledgeBit: 邀請碼與連結加好友
-- 1. user_profiles 新增 invite_code（6 位英數字、UNIQUE、Index）
-- 2. 新使用者註冊時自動生成 invite_code 的 Trigger
-- 3. 依 invite_code 查詢公開資料的 RPC（供 RLS 與客戶端呼叫）
-- 4. RLS 建議（依 invite_code 僅暴露部分欄位透過 RPC）

-- 若你的表名是 profiles 請改為 profiles，這裡依現有程式使用 user_profiles
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS invite_code TEXT;

-- 唯一索引（6 位英數字，需與下方 generate_invite_code 一致）
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_profiles_invite_code
  ON public.user_profiles (invite_code)
  WHERE invite_code IS NOT NULL;

-- 產生 6 位英數字邀請碼（避免 0/O、1/I 混淆可改字元集）
CREATE OR REPLACE FUNCTION public.generate_invite_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$;

-- 新列插入時自動填寫 invite_code（若為 NULL）
CREATE OR REPLACE FUNCTION public.set_invite_code_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_code TEXT;
  attempts INT := 0;
BEGIN
  IF NEW.invite_code IS NULL OR trim(NEW.invite_code) = '' THEN
    LOOP
      new_code := public.generate_invite_code();
      IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE invite_code = new_code) THEN
        NEW.invite_code := new_code;
        EXIT;
      END IF;
      attempts := attempts + 1;
      IF attempts > 50 THEN
        RAISE EXCEPTION 'Could not generate unique invite_code';
      END IF;
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_invite_code_on_insert ON public.user_profiles;
CREATE TRIGGER trg_set_invite_code_on_insert
  BEFORE INSERT ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_invite_code_on_insert();

-- 依 invite_code 查詢「可對外公開」的資料（僅 user_id, display_name, avatar_url, level）
-- 供 App 在點擊邀請連結時取得對方資訊並發送好友請求；RLS 不直接開放整表，改由此 RPC 限制欄位
CREATE OR REPLACE FUNCTION public.get_profile_by_invite_code(code TEXT)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  level INT
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT p.user_id, p.display_name, p.avatar_url, COALESCE(p.level, 0)
  FROM public.user_profiles p
  WHERE p.invite_code = code
  LIMIT 1;
$$;

-- 開放已登入使用者呼叫此 RPC（知道 invite_code 即可查到此一筆公開資料）
-- 若希望匿名也可呼叫，改為：GRANT EXECUTE ON FUNCTION public.get_profile_by_invite_code(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.get_profile_by_invite_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_profile_by_invite_code(TEXT) TO service_role;

COMMENT ON COLUMN public.user_profiles.invite_code IS '6 位英數字邀請碼，用於分享連結 / QR Code 加好友';
COMMENT ON FUNCTION public.get_profile_by_invite_code(TEXT) IS '依 invite_code 回傳該使用者的公開欄位（user_id, display_name, avatar_url, level），供邀請連結 / Deep Link 使用';

-- 為既有列產生 invite_code（執行一次）
DO $$
DECLARE
  r RECORD;
  new_code TEXT;
  attempts INT;
BEGIN
  FOR r IN SELECT user_id FROM public.user_profiles WHERE invite_code IS NULL OR trim(coalesce(invite_code, '')) = ''
  LOOP
    attempts := 0;
    LOOP
      new_code := public.generate_invite_code();
      IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE invite_code = new_code) THEN
        UPDATE public.user_profiles SET invite_code = new_code WHERE user_id = r.user_id;
        EXIT;
      END IF;
      attempts := attempts + 1;
      IF attempts > 50 THEN
        RAISE EXCEPTION 'Could not generate unique invite_code for user %', r.user_id;
      END IF;
    END LOOP;
  END LOOP;
END $$;
