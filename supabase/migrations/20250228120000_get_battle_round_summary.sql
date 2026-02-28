-- 取得指定小時（上一輪）的雙方投入統整，供 App 顯示「藍隊／紅隊在各格做了什麼」
-- 僅限該房間的創辦人或被邀請者呼叫

CREATE OR REPLACE FUNCTION public.get_battle_round_summary(
  p_room_id UUID,
  p_hour_bucket TEXT,
  p_bucket_seconds INT DEFAULT 3600
)
RETURNS TABLE(blue_allocations JSONB, red_allocations JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_creator_id UUID;
  v_invited_ids UUID[];
  v_hour TIMESTAMPTZ;
  v_blue JSONB := '{}'::jsonb;
  v_red JSONB := '{}'::jsonb;
  v_rec RECORD;
  v_idx INT;
  v_cell_key TEXT;
  v_ke INT;
  v_cur INT;
BEGIN
  -- 僅限房間內成員
  IF NOT EXISTS (
    SELECT 1 FROM public.battle_rooms r
    WHERE r.id = p_room_id AND (r.creator_id = auth.uid() OR auth.uid() = ANY(r.invited_member_ids))
  ) THEN
    RAISE EXCEPTION 'Not a member of this battle room';
  END IF;

  SELECT creator_id, invited_member_ids INTO v_creator_id, v_invited_ids
  FROM public.battle_rooms WHERE id = p_room_id LIMIT 1;
  v_creator_id := COALESCE(v_creator_id, auth.uid());
  v_invited_ids := COALESCE(v_invited_ids, '{}');

  v_hour := to_timestamp(
    floor(extract(epoch from (p_hour_bucket::timestamptz)) / GREATEST(60, COALESCE(p_bucket_seconds, 3600)))
    * GREATEST(60, COALESCE(p_bucket_seconds, 3600))
  );

  FOR v_rec IN
    SELECT user_id, allocations
    FROM public.battle_allocations
    WHERE room_id = p_room_id AND hour_bucket = v_hour
  LOOP
    IF v_rec.user_id = v_creator_id THEN
      -- 藍隊：合併到 v_blue（每個 cell 的 KE 相加）
      FOR v_idx IN 0..15 LOOP
        v_cell_key := v_idx::text;
        v_ke := COALESCE((v_rec.allocations->>v_cell_key)::int, 0);
        IF v_ke > 0 THEN
          v_cur := COALESCE((v_blue->>v_cell_key)::int, 0);
          v_blue := jsonb_set(v_blue, ARRAY[v_cell_key], to_jsonb((v_cur + v_ke)::text::int));
        END IF;
      END LOOP;
    ELSE
      -- 紅隊
      FOR v_idx IN 0..15 LOOP
        v_cell_key := v_idx::text;
        v_ke := COALESCE((v_rec.allocations->>v_cell_key)::int, 0);
        IF v_ke > 0 THEN
          v_cur := COALESCE((v_red->>v_cell_key)::int, 0);
          v_red := jsonb_set(v_red, ARRAY[v_cell_key], to_jsonb((v_cur + v_ke)::text::int));
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  RETURN QUERY SELECT v_blue, v_red;
END;
$$;
