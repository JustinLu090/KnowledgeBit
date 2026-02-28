-- 取得目前使用者在某單字集底下的「進行中」對戰房間（若有的話）
-- 僅當前使用者為 creator 或 invited_member 之一時才會回傳
CREATE OR REPLACE FUNCTION public.get_active_battle_room_for_user(
  p_word_set_id UUID
)
RETURNS TABLE (
  id UUID,
  word_set_id UUID,
  creator_id UUID,
  start_date TIMESTAMPTZ,
  duration_days INT,
  invited_member_ids UUID[]
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    br.id,
    br.word_set_id,
    br.creator_id,
    br.start_date,
    br.duration_days,
    br.invited_member_ids
  FROM public.battle_rooms br
  WHERE br.word_set_id = p_word_set_id
    AND (
      br.creator_id = auth.uid()
      OR auth.uid() = ANY(br.invited_member_ids)
    )
    -- 僅回傳「尚在期間內」的房間
    AND now() <= br.start_date + (br.duration_days || ' days')::interval
  ORDER BY br.start_date DESC
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_active_battle_room_for_user(UUID) TO authenticated;

