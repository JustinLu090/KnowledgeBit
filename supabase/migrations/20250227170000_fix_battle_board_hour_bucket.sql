-- Fix: 整點統整時應使用「上一小時」的 allocations 來計算新盤面
-- 客戶端在整點送出的是 previousHourBucket（剛結束的那小時），
-- 因此 get_battle_board_state 請求某小時 H 的盤面時，應套用 hour_bucket = H-1 的分配結果。

CREATE OR REPLACE FUNCTION public.get_battle_board_state(
  p_room_id UUID,
  p_hour_bucket TEXT
)
RETURNS TABLE(cells JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hour TIMESTAMPTZ;
  v_prev_hour TIMESTAMPTZ;
  v_cached JSONB;
  v_prev_cells JSONB;
  v_allocations JSONB;
  v_my_alloc JSONB;
  v_others_alloc JSONB;
  v_cell JSONB;
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
BEGIN
  v_hour := (p_hour_bucket::timestamptz);
  v_hour := date_trunc('hour', v_hour);
  v_prev_hour := v_hour - interval '1 hour';

  -- 1) Return cached if exists
  SELECT b.cells INTO v_cached FROM public.battle_board_state b WHERE b.room_id = p_room_id AND b.hour_bucket = v_hour;
  IF v_cached IS NOT NULL AND jsonb_array_length(v_cached) > 0 THEN
    cells := v_cached;
    RETURN NEXT;
    RETURN;
  END IF;

  -- 2) Previous hour board (or initial)
  SELECT b.cells INTO v_prev_cells FROM public.battle_board_state b WHERE b.room_id = p_room_id AND b.hour_bucket = v_prev_hour;
  IF v_prev_cells IS NULL OR jsonb_array_length(v_prev_cells) = 0 THEN
    v_prev_cells := public.battle_initial_board(p_room_id);
  END IF;

  -- 3) 使用「上一小時」的 allocations（客戶端整點送出的是 previousHourBucket）
  SELECT allocations INTO v_my_alloc FROM public.battle_allocations WHERE room_id = p_room_id AND hour_bucket = v_prev_hour AND user_id = auth.uid();
  v_my_alloc := COALESCE(v_my_alloc, '{}'::jsonb);

  v_others_alloc := '{}'::jsonb;
  FOR v_other_rec IN SELECT user_id, allocations FROM public.battle_allocations WHERE room_id = p_room_id AND hour_bucket = v_prev_hour AND user_id != auth.uid()
  LOOP
    FOR v_idx IN 0..15 LOOP
      v_others_alloc := jsonb_set(v_others_alloc, ARRAY[v_idx::text], to_jsonb((COALESCE((v_others_alloc->>v_idx::text)::int, 0) + COALESCE((v_other_rec.allocations->>v_idx::text)::int, 0))::text::int));
    END LOOP;
  END LOOP;

  -- 4) Apply reinforce (my KE to my cells) then decay + enemy pressure then attacks (simplified: one pass per cell)
  FOR v_idx IN 0..15 LOOP
    v_prev := v_prev_cells->v_idx;
    v_owner := v_prev->>'owner';
    v_hp := (v_prev->>'hp_now')::int;
    v_hp_max := (v_prev->>'hp_max')::int;
    v_decay := (v_prev->>'decay_per_hour')::int;
    v_my_ke := (v_my_alloc->>(v_idx::text))::int;
    v_my_ke := COALESCE(v_my_ke, 0);
    v_enemy_ke := (v_others_alloc->>(v_idx::text))::int;
    v_enemy_ke := COALESCE(v_enemy_ke, 0);

    IF v_owner = 'player' THEN
      v_hp := LEAST(v_hp_max, v_hp + v_my_ke);
    END IF;
    v_hp := v_hp - v_enemy_ke - v_decay;
    v_hp := GREATEST(0, v_hp);
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
        IF v_hp = 0 THEN v_owner := 'neutral'; END IF;
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

  INSERT INTO public.battle_board_state (room_id, hour_bucket, cells) VALUES (p_room_id, v_hour, v_new_cells);

  cells := v_new_cells;
  RETURN NEXT;
  RETURN;
END;
$$;
