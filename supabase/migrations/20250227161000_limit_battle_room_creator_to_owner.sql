-- 僅允許單字集「創辦人」（word_sets.user_id）建立對戰房間
CREATE OR REPLACE FUNCTION public.create_battle_room(
  p_word_set_id UUID,
  p_creator_id UUID,
  p_start_date TIMESTAMPTZ,
  p_duration_days TEXT DEFAULT '7',
  p_invited_ids TEXT DEFAULT '[]'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_room_id UUID;
  v_ids UUID[];
  v_owner_id UUID;
BEGIN
  -- 1) 驗證 caller 與參數中的 creator_id 一致
  IF auth.uid() IS DISTINCT FROM p_creator_id THEN
    RAISE EXCEPTION 'Only creator can create a room';
  END IF;

  -- 2) 確認 creator 為該單字集的擁有者
  SELECT user_id INTO v_owner_id FROM public.word_sets WHERE id = p_word_set_id;
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'word_set not found';
  END IF;
  IF v_owner_id IS DISTINCT FROM p_creator_id THEN
    RAISE EXCEPTION 'only word set owner can create battle room';
  END IF;

  -- 3) 解析受邀成員 ID 陣列
  v_ids := COALESCE(
    (SELECT array_agg(elem::uuid) FROM jsonb_array_elements_text((COALESCE(p_invited_ids, '[]')::jsonb)) AS elem),
    '{}'
  );

  -- 4) 建立房間
  INSERT INTO public.battle_rooms (word_set_id, creator_id, start_date, duration_days, invited_member_ids)
  VALUES (p_word_set_id, p_creator_id, p_start_date, (COALESCE(p_duration_days, '7')::int), v_ids)
  RETURNING id INTO v_room_id;

  RETURN v_room_id;
END;
$$;

