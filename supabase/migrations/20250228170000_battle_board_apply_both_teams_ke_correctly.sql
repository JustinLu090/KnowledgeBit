-- 修正地圖只顯示己方格子的問題：對方格子的 KE 應為「對方加固」而非「對己方攻擊」
-- 正確邏輯：己方格子 = +己方 KE（加固）- 對方 KE（被攻擊）- decay；對方格子 = +對方 KE（加固）- 己方 KE（被攻擊）- decay

-- 1. compute_one_battle_step：對方格子要加上 v_enemy_ke（對方加固），只扣 v_my_ke（己方攻擊）
CREATE OR REPLACE FUNCTION public.compute_one_battle_step(
  p_room_id UUID,
  p_creator_id UUID,
  p_invited_ids UUID[],
  p_prev_cells JSONB,
  p_prev_hour TIMESTAMPTZ,
  p_bucket_seconds INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next_hour TIMESTAMPTZ;
  v_prev_hour_end TIMESTAMPTZ;
  v_my_alloc JSONB;
  v_others_alloc JSONB;
  v_new_cells JSONB := '[]'::jsonb;
  v_idx INT;
  v_prev JSONB;
  v_owner TEXT;
  v_hp INT;
  v_hp_max INT;
  v_decay INT;
  v_my_ke INT;
  v_enemy_ke INT;
  v_net INT;
  v_other_rec RECORD;
  v_is_mine BOOLEAN;
  v_cells JSONB;
  v_is_start_cell BOOLEAN;
BEGIN
  v_cells := p_prev_cells;
  v_next_hour := p_prev_hour + make_interval(secs => p_bucket_seconds);
  v_prev_hour_end := p_prev_hour + (p_bucket_seconds || ' seconds')::interval;

  FOR v_idx IN 0..15 LOOP
    v_prev := v_cells->v_idx;
    v_owner := v_prev->>'owner';
    IF v_owner = 'player' THEN
      v_cells := jsonb_set(v_cells, ARRAY[v_idx::text, 'owner'], to_jsonb(
        CASE WHEN auth.uid() = p_creator_id THEN 'creator'::text ELSE 'invited'::text END
      ));
    ELSIF v_owner = 'enemy' THEN
      v_cells := jsonb_set(v_cells, ARRAY[v_idx::text, 'owner'], to_jsonb(
        CASE WHEN auth.uid() = p_creator_id THEN 'invited'::text ELSE 'creator'::text END
      ));
    END IF;
  END LOOP;

  SELECT allocations INTO v_my_alloc
  FROM public.battle_allocations
  WHERE room_id = p_room_id AND user_id = auth.uid()
    AND hour_bucket >= p_prev_hour AND hour_bucket < v_prev_hour_end
  ORDER BY hour_bucket DESC LIMIT 1;
  v_my_alloc := COALESCE(v_my_alloc, '{}'::jsonb);

  v_others_alloc := '{}'::jsonb;
  FOR v_other_rec IN
    SELECT DISTINCT ON (user_id) user_id, allocations
    FROM public.battle_allocations
    WHERE room_id = p_room_id AND user_id != auth.uid()
      AND hour_bucket >= p_prev_hour AND hour_bucket < v_prev_hour_end
    ORDER BY user_id, hour_bucket DESC
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

  FOR v_idx IN 0..15 LOOP
    v_prev := v_cells->v_idx;
    v_owner := v_prev->>'owner';
    v_hp_max := (v_prev->>'hp_max')::int;
    v_decay := (v_prev->>'decay_per_hour')::int;
    v_is_start_cell := (v_idx = 0 OR v_idx = 15) AND v_owner IN ('creator', 'invited');

    IF v_is_start_cell THEN
      v_new_cells := v_new_cells || jsonb_build_object(
        'id', v_idx,
        'owner', v_owner,
        'hp_now', 100,
        'hp_max', 100,
        'decay_per_hour', 0,
        'enemy_pressure', 0
      );
      CONTINUE;
    END IF;

    v_hp := (v_prev->>'hp_now')::int;
    v_my_ke := COALESCE((v_my_alloc->>(v_idx::text))::int, 0);
    v_enemy_ke := COALESCE((v_others_alloc->>(v_idx::text))::int, 0);

    v_is_mine := (v_owner = 'creator' AND auth.uid() = p_creator_id)
      OR (v_owner = 'invited' AND auth.uid() = ANY(p_invited_ids));

    IF v_owner = 'neutral' AND v_my_ke > 0 AND v_enemy_ke > 0 THEN
      v_net := v_my_ke - v_enemy_ke;
      IF v_net > 0 THEN
        v_owner := CASE WHEN auth.uid() = p_creator_id THEN 'creator' ELSE 'invited' END;
        v_hp := LEAST(v_hp_max, v_net);
      ELSIF v_net < 0 THEN
        v_owner := CASE WHEN auth.uid() = p_creator_id THEN 'invited' ELSE 'creator' END;
        v_hp := LEAST(v_hp_max, -v_net);
      ELSE
        v_owner := 'neutral';
        v_hp := 0;
      END IF;
    ELSE
      -- 己方格子：+己方 KE（加固）- 對方 KE（被攻擊）- decay
      -- 對方格子：+對方 KE（加固）- 己方 KE（被攻擊）- decay
      IF v_is_mine THEN
        v_hp := v_hp + v_my_ke - v_enemy_ke;
      ELSE
        v_hp := v_hp + v_enemy_ke - v_my_ke;
      END IF;
      v_hp := v_hp - v_decay;
      v_hp := GREATEST(0, v_hp);
      IF v_hp = 0 AND v_enemy_ke = 0 AND v_my_ke = 0 AND v_is_mine THEN
        v_hp := 1;
      END IF;
      IF v_hp = 0 THEN
        v_owner := 'neutral';
      END IF;
      IF NOT v_is_mine AND v_my_ke > 0 THEN
        IF v_my_ke > v_hp THEN
          v_owner := CASE WHEN auth.uid() = p_creator_id THEN 'creator' ELSE 'invited' END;
          v_hp := LEAST(v_hp_max, v_my_ke - v_hp);
        ELSE
          v_hp := v_hp - v_my_ke;
          v_hp := GREATEST(0, v_hp);
          IF v_hp = 0 THEN
            v_owner := 'neutral';
          END IF;
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

  INSERT INTO public.battle_board_state (room_id, hour_bucket, cells)
  VALUES (p_room_id, v_next_hour, v_new_cells)
  ON CONFLICT (room_id, hour_bucket) DO UPDATE
    SET cells = EXCLUDED.cells,
        created_at = now();

  RETURN v_new_cells;
END;
$$;

-- 2. get_battle_board_state 主迴圈：同上，己方格子 +my_ke -enemy_ke -decay，對方格子 +enemy_ke -my_ke -decay
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
  v_creator_id UUID;
  v_invited_ids UUID[];
  v_hour TIMESTAMPTZ;
  v_prev_hour TIMESTAMPTZ;
  v_prev_hour_end TIMESTAMPTZ;
  v_cursor_end TIMESTAMPTZ;
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
  v_net INT;
  v_other_rec RECORD;
  v_prev JSONB;
  v_bucket_seconds INT;
  v_is_mine BOOLEAN;
  v_output_owner TEXT;
  v_output_cells JSONB := '[]'::jsonb;
  v_cursor_hour TIMESTAMPTZ;
  v_step INT;
  v_max_steps INT := 500;
  v_is_start_cell BOOLEAN;
BEGIN
  SELECT creator_id, invited_member_ids INTO v_creator_id, v_invited_ids
  FROM public.battle_rooms WHERE id = p_room_id LIMIT 1;
  v_creator_id := COALESCE(v_creator_id, auth.uid());
  v_invited_ids := COALESCE(v_invited_ids, '{}');

  v_bucket_seconds := GREATEST(60, COALESCE(p_bucket_seconds, 3600));
  v_hour := to_timestamp(floor(extract(epoch from (p_hour_bucket::timestamptz)) / v_bucket_seconds) * v_bucket_seconds);
  v_prev_hour := v_hour - make_interval(secs => v_bucket_seconds);
  v_prev_hour_end := v_prev_hour + (v_bucket_seconds || ' seconds')::interval;

  SELECT b.cells INTO v_prev_cells
  FROM public.battle_board_state b
  WHERE b.room_id = p_room_id
    AND b.hour_bucket >= v_prev_hour AND b.hour_bucket < v_prev_hour_end
  ORDER BY b.hour_bucket DESC LIMIT 1;

  IF v_prev_cells IS NULL OR jsonb_array_length(v_prev_cells) = 0 THEN
    v_cursor_hour := v_prev_hour;
    v_step := 0;
    v_prev_cells := NULL;
    WHILE v_step < v_max_steps LOOP
      v_cursor_end := v_cursor_hour + (v_bucket_seconds || ' seconds')::interval;
      SELECT b.cells INTO v_prev_cells
      FROM public.battle_board_state b
      WHERE b.room_id = p_room_id
        AND b.hour_bucket >= v_cursor_hour AND b.hour_bucket < v_cursor_end
      ORDER BY b.hour_bucket DESC LIMIT 1;
      IF v_prev_cells IS NOT NULL AND jsonb_array_length(v_prev_cells) > 0 THEN
        EXIT;
      END IF;
      v_prev_cells := NULL;
      v_cursor_hour := v_cursor_hour - make_interval(secs => v_bucket_seconds);
      v_step := v_step + 1;
    END LOOP;

    IF v_prev_cells IS NULL OR jsonb_array_length(v_prev_cells) = 0 THEN
      v_prev_cells := public.battle_initial_board(p_room_id);
      v_cursor_hour := v_prev_hour - make_interval(secs => v_bucket_seconds * v_max_steps);
    ELSE
      v_cursor_hour := v_cursor_hour + make_interval(secs => v_bucket_seconds);
    END IF;

    WHILE v_cursor_hour < v_prev_hour LOOP
      v_prev_cells := public.compute_one_battle_step(
        p_room_id, v_creator_id, v_invited_ids,
        v_prev_cells, v_cursor_hour, v_bucket_seconds
      );
      v_cursor_hour := v_cursor_hour + make_interval(secs => v_bucket_seconds);
    END LOOP;
  END IF;

  FOR v_idx IN 0..15 LOOP
    v_prev := v_prev_cells->v_idx;
    v_owner := v_prev->>'owner';
    IF v_owner = 'player' THEN
      v_prev_cells := jsonb_set(v_prev_cells, ARRAY[v_idx::text, 'owner'], to_jsonb(
        CASE WHEN auth.uid() = v_creator_id THEN 'creator'::text ELSE 'invited'::text END
      ));
    ELSIF v_owner = 'enemy' THEN
      v_prev_cells := jsonb_set(v_prev_cells, ARRAY[v_idx::text, 'owner'], to_jsonb(
        CASE WHEN auth.uid() = v_creator_id THEN 'invited'::text ELSE 'creator'::text END
      ));
    END IF;
  END LOOP;

  SELECT allocations INTO v_my_alloc
  FROM public.battle_allocations
  WHERE room_id = p_room_id AND user_id = auth.uid()
    AND hour_bucket >= v_prev_hour AND hour_bucket < v_prev_hour_end
  ORDER BY hour_bucket DESC LIMIT 1;
  v_my_alloc := COALESCE(v_my_alloc, '{}'::jsonb);

  v_others_alloc := '{}'::jsonb;
  FOR v_other_rec IN
    SELECT DISTINCT ON (user_id) user_id, allocations
    FROM public.battle_allocations
    WHERE room_id = p_room_id AND user_id != auth.uid()
      AND hour_bucket >= v_prev_hour AND hour_bucket < v_prev_hour_end
    ORDER BY user_id, hour_bucket DESC
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

  FOR v_idx IN 0..15 LOOP
    v_prev := v_prev_cells->v_idx;
    v_owner := v_prev->>'owner';
    v_hp_max := (v_prev->>'hp_max')::int;
    v_decay := (v_prev->>'decay_per_hour')::int;
    v_is_start_cell := (v_idx = 0 OR v_idx = 15) AND v_owner IN ('creator', 'invited');

    IF v_is_start_cell THEN
      v_new_cells := v_new_cells || jsonb_build_object(
        'id', v_idx,
        'owner', v_owner,
        'hp_now', 100,
        'hp_max', 100,
        'decay_per_hour', 0,
        'enemy_pressure', 0
      );
      CONTINUE;
    END IF;

    v_hp := (v_prev->>'hp_now')::int;
    v_my_ke := COALESCE((v_my_alloc->>(v_idx::text))::int, 0);
    v_enemy_ke := COALESCE((v_others_alloc->>(v_idx::text))::int, 0);

    v_is_mine := (v_owner = 'creator' AND auth.uid() = v_creator_id)
      OR (v_owner = 'invited' AND auth.uid() = ANY(v_invited_ids));

    IF v_owner = 'neutral' AND v_my_ke > 0 AND v_enemy_ke > 0 THEN
      v_net := v_my_ke - v_enemy_ke;
      IF v_net > 0 THEN
        v_owner := CASE WHEN auth.uid() = v_creator_id THEN 'creator' ELSE 'invited' END;
        v_hp := LEAST(v_hp_max, v_net);
      ELSIF v_net < 0 THEN
        v_owner := CASE WHEN auth.uid() = v_creator_id THEN 'invited' ELSE 'creator' END;
        v_hp := LEAST(v_hp_max, -v_net);
      ELSE
        v_owner := 'neutral';
        v_hp := 0;
      END IF;
    ELSE
      -- 己方格子：+己方 KE（加固）- 對方 KE（被攻擊）- decay
      -- 對方格子：+對方 KE（加固）- 己方 KE（被攻擊）- decay
      IF v_is_mine THEN
        v_hp := v_hp + v_my_ke - v_enemy_ke;
      ELSE
        v_hp := v_hp + v_enemy_ke - v_my_ke;
      END IF;
      v_hp := v_hp - v_decay;
      v_hp := GREATEST(0, v_hp);
      IF v_hp = 0 AND v_enemy_ke = 0 AND v_my_ke = 0 AND v_is_mine THEN
        v_hp := 1;
      END IF;
      IF v_hp = 0 THEN
        v_owner := 'neutral';
      END IF;
      IF NOT v_is_mine AND v_my_ke > 0 THEN
        IF v_my_ke > v_hp THEN
          v_owner := CASE WHEN auth.uid() = v_creator_id THEN 'creator' ELSE 'invited' END;
          v_hp := LEAST(v_hp_max, v_my_ke - v_hp);
        ELSE
          v_hp := v_hp - v_my_ke;
          v_hp := GREATEST(0, v_hp);
          IF v_hp = 0 THEN
            v_owner := 'neutral';
          END IF;
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

  INSERT INTO public.battle_board_state (room_id, hour_bucket, cells)
  VALUES (p_room_id, v_hour, v_new_cells)
  ON CONFLICT (room_id, hour_bucket) DO UPDATE
    SET cells = EXCLUDED.cells,
        created_at = now();

  FOR v_idx IN 0..15 LOOP
    v_owner := (v_new_cells->v_idx)->>'owner';
    v_output_owner := CASE v_owner
      WHEN 'creator' THEN CASE WHEN auth.uid() = v_creator_id THEN 'player' ELSE 'enemy' END
      WHEN 'invited' THEN CASE WHEN auth.uid() = v_creator_id THEN 'enemy' ELSE 'player' END
      ELSE 'neutral'
    END;
    v_output_cells := v_output_cells || jsonb_set(
      v_new_cells->v_idx,
      '{owner}',
      to_jsonb(v_output_owner)
    );
  END LOOP;

  cells := v_output_cells;
  RETURN NEXT;
  RETURN;
END;
$$;
