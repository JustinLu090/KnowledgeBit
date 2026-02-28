-- 強制每次呼叫 get_battle_board_state 都重新依 allocations 計算該 bucket 的盤面，
-- 而不是直接回傳快取；計算完後再以 upsert 方式更新 battle_board_state。
-- 這樣即使同一 bucket 先在「尚未提交 KE」時被讀取，之後提交 KE 再讀取時也會得到最新結果。

CREATE OR REPLACE FUNCTION public.get_battle_board_state(
  p_room_id UUID,
  p_hour_bucket TEXT,
  p_bucket_seconds INT DEFAULT 3600
)
RETURNS TABLE(cells JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hour TIMESTAMPTZ;
  v_prev_hour TIMESTAMPTZ;
  v_prev_cells JSONB;
  v_my_alloc JSONB;
  v_others_alloc JSONB;
  v_new_cells JSONB := '[]'::jsonb;
  v_idx INT;
  v_owner TEXT;
  v_hp INT;
  v_hp_max INT;
  v_decay INT;
  v_my_ke INT;
  v_enemy_ke INT;
  v_other_rec RECORD;
  v_prev JSONB;
  v_bucket_seconds INT;
BEGIN
  v_bucket_seconds := GREATEST(60, COALESCE(p_bucket_seconds, 3600));
  v_hour := to_timestamp(floor(extract(epoch from (p_hour_bucket::timestamptz)) / v_bucket_seconds) * v_bucket_seconds);
  v_prev_hour := v_hour - make_interval(secs => v_bucket_seconds);

  -- 1) 取得前一個 bucket 的盤面（或初始盤面）
  SELECT b.cells INTO v_prev_cells
  FROM public.battle_board_state b
  WHERE b.room_id = p_room_id AND b.hour_bucket = v_prev_hour;

  IF v_prev_cells IS NULL OR jsonb_array_length(v_prev_cells) = 0 THEN
    v_prev_cells := public.battle_initial_board(p_room_id);
  END IF;

  -- 2) 讀取前一個 bucket 的 allocations（自己 + 其他玩家）
  SELECT allocations INTO v_my_alloc
  FROM public.battle_allocations
  WHERE room_id = p_room_id AND hour_bucket = v_prev_hour AND user_id = auth.uid();
  v_my_alloc := COALESCE(v_my_alloc, '{}'::jsonb);

  v_others_alloc := '{}'::jsonb;
  FOR v_other_rec IN
    SELECT user_id, allocations
    FROM public.battle_allocations
    WHERE room_id = p_room_id AND hour_bucket = v_prev_hour AND user_id != auth.uid()
  LOOP
    FOR v_idx IN 0..15 LOOP
      v_others_alloc := jsonb_set(
        v_others_alloc,
        ARRAY[v_idx::text],
        to_jsonb(
          (COALESCE((v_others_alloc->>v_idx::text)::int, 0)
           + COALESCE((v_other_rec.allocations->>v_idx::text)::int, 0))::text::int
        )
      );
    END LOOP;
  END LOOP;

  -- 3) 依企劃規則：先我方補血，再扣敵方 KE 與 Decay，再處理進攻。
  --    額外保護：純粹因為自然衰減（沒有任何 KE 交戰）時，不會直接失去已佔領格子，
  --    會保留至少 1 HP，必須有敵方 KE（或我的進攻 KE）介入才會真正歸零變回中立。
  FOR v_idx IN 0..15 LOOP
    v_prev := v_prev_cells->v_idx;
    v_owner := v_prev->>'owner';
    v_hp := (v_prev->>'hp_now')::int;
    v_hp_max := (v_prev->>'hp_max')::int;
    v_decay := (v_prev->>'decay_per_hour')::int;
    v_my_ke := COALESCE((v_my_alloc->>(v_idx::text))::int, 0);
    v_enemy_ke := COALESCE((v_others_alloc->>(v_idx::text))::int, 0);

    IF v_owner = 'player' THEN
      v_hp := LEAST(v_hp_max, v_hp + v_my_ke);
    END IF;

    v_hp := v_hp - v_enemy_ke - v_decay;
    v_hp := GREATEST(0, v_hp);

    -- 若沒有任何 KE 交戰（雙方都沒投入），且原本是我方格子，則至少保留 1 HP，避免純粹因自然衰減就直接失去領地
    IF v_hp = 0 AND v_enemy_ke = 0 AND v_my_ke = 0 AND v_owner = 'player' THEN
      v_hp := 1;
    END IF;

    IF v_hp = 0 THEN
      v_owner := 'neutral';
    END IF;

    IF v_owner != 'player' AND v_my_ke > 0 THEN
      IF v_my_ke > v_hp THEN
        v_owner := 'player';
        v_hp := LEAST(v_hp_max, v_my_ke - v_hp);
      ELSE
        v_hp := v_hp - v_my_ke;
        v_hp := GREATEST(0, v_hp);
        IF v_hp = 0 THEN
          v_owner := 'neutral';
        END IF;
      END IF;
    END IF;

    v_new_cells := v_new_cells || jsonb_build_object(
      'id', v_idx,
      'owner', v_owner,
      'hp_now', v_hp,
      'hp_max', v_hp_max,
      'decay_per_hour', v_decay,
      'enemy_pressure', 0
    );
  END LOOP;

  -- 4) 將新盤面寫回快取（若已有紀錄則更新）
  INSERT INTO public.battle_board_state (room_id, hour_bucket, cells)
  VALUES (p_room_id, v_hour, v_new_cells)
  ON CONFLICT (room_id, hour_bucket) DO UPDATE
    SET cells = EXCLUDED.cells,
        created_at = now();

  cells := v_new_cells;
  RETURN NEXT;
  RETURN;
END;
$$;

