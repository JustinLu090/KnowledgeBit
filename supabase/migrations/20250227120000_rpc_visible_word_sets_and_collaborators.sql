-- 用 RPC 取得「目前使用者可見的單字集」與「共編名單」，避開 RLS 遞迴
-- 單字集與卡片仍寫在 DB；共編者列表也在 DB；只是「讀取」改由 SECURITY DEFINER 函數代勞

-- 1) 回傳目前使用者能看到的 word_sets（擁有者 或 共編者）
CREATE OR REPLACE FUNCTION public.get_visible_word_sets()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  title TEXT,
  level TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT ws.id, ws.user_id, ws.title, ws.level, ws.created_at
  FROM public.word_sets ws
  WHERE ws.user_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.word_set_collaborators c
    WHERE c.word_set_id = ws.id
      AND c.user_id = auth.uid()
  );
$$;

-- 2) 回傳某單字集的共編成員（僅限：本人是擁有者或本人是共編者時可查）
CREATE OR REPLACE FUNCTION public.get_word_set_collaborators(p_word_set_id UUID)
RETURNS TABLE (word_set_id UUID, user_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.word_sets w
    WHERE w.id = p_word_set_id
      AND (w.user_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.word_set_collaborators c
        WHERE c.word_set_id = w.id AND c.user_id = auth.uid()
      ))
  ) THEN
    RETURN;  -- 無權限則回傳空
  END IF;

  RETURN QUERY
  SELECT c.word_set_id, c.user_id
  FROM public.word_set_collaborators c
  WHERE c.word_set_id = p_word_set_id;
END;
$$;

-- 3) 設定某單字集的共編名單（僅擁有者可呼叫）
-- p_collaborator_ids: JSON 陣列字串，例如 "[\"uuid1\", \"uuid2\"]"
CREATE OR REPLACE FUNCTION public.set_word_set_collaborators(
  p_word_set_id UUID,
  p_collaborator_ids TEXT DEFAULT '[]'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id UUID;
  v_ids UUID[];
  v_uid UUID;
BEGIN
  SELECT ws.user_id INTO v_owner_id
  FROM public.word_sets ws
  WHERE ws.id = p_word_set_id;

  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'word_set not found';
  END IF;

  IF auth.uid() IS DISTINCT FROM v_owner_id THEN
    RAISE EXCEPTION 'only owner can set collaborators';
  END IF;

  -- 解析 JSON 陣列為 UUID[]
  v_ids := ARRAY(
    SELECT (elem::text)::uuid
    FROM jsonb_array_elements_text(COALESCE(p_collaborator_ids::jsonb, '[]'::jsonb)) AS elem
  );

  DELETE FROM public.word_set_collaborators
  WHERE word_set_id = p_word_set_id;

  IF array_length(v_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  FOREACH v_uid IN ARRAY v_ids
  LOOP
    INSERT INTO public.word_set_collaborators (word_set_id, user_id)
    VALUES (p_word_set_id, v_uid)
    ON CONFLICT (word_set_id, user_id) DO NOTHING;
  END LOOP;
END;
$$;

-- 允許已登入使用者呼叫這三個 RPC
GRANT EXECUTE ON FUNCTION public.get_visible_word_sets() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_word_set_collaborators(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_word_set_collaborators(uuid, text) TO authenticated;
