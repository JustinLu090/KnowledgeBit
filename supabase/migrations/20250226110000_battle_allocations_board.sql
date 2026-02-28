-- Per-user, per-hour allocations: cell_id (as text) -> KE amount
CREATE TABLE IF NOT EXISTS public.battle_allocations (
  room_id UUID NOT NULL REFERENCES public.battle_rooms(id) ON DELETE CASCADE,
  hour_bucket TIMESTAMPTZ NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  allocations JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, hour_bucket, user_id)
);

CREATE INDEX IF NOT EXISTS idx_battle_allocations_room_hour ON public.battle_allocations (room_id, hour_bucket);

ALTER TABLE public.battle_allocations ENABLE ROW LEVEL SECURITY;

-- Users can only insert/update their own row for a given room/hour
DROP POLICY IF EXISTS "battle_allocations_insert_own" ON public.battle_allocations;
CREATE POLICY "battle_allocations_insert_own" ON public.battle_allocations FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "battle_allocations_update_own" ON public.battle_allocations;
CREATE POLICY "battle_allocations_update_own" ON public.battle_allocations FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "battle_allocations_select_room" ON public.battle_allocations;
CREATE POLICY "battle_allocations_select_room" ON public.battle_allocations FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.battle_rooms r WHERE r.id = room_id AND (r.creator_id = auth.uid() OR auth.uid() = ANY(r.invited_member_ids)))
);

-- Cached board state per room per hour (computed from allocations)
CREATE TABLE IF NOT EXISTS public.battle_board_state (
  room_id UUID NOT NULL REFERENCES public.battle_rooms(id) ON DELETE CASCADE,
  hour_bucket TIMESTAMPTZ NOT NULL,
  cells JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, hour_bucket)
);

CREATE INDEX IF NOT EXISTS idx_battle_board_state_room ON public.battle_board_state (room_id);

ALTER TABLE public.battle_board_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "battle_board_state_select_room" ON public.battle_board_state;
CREATE POLICY "battle_board_state_select_room" ON public.battle_board_state FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.battle_rooms r WHERE r.id = room_id AND (r.creator_id = auth.uid() OR auth.uid() = ANY(r.invited_member_ids)))
);
-- Only RPC (SECURITY DEFINER) can insert/update
DROP POLICY IF EXISTS "battle_board_state_insert_service" ON public.battle_board_state;
CREATE POLICY "battle_board_state_insert_service" ON public.battle_board_state FOR INSERT WITH CHECK (false);
DROP POLICY IF EXISTS "battle_board_state_all_service" ON public.battle_board_state;
CREATE POLICY "battle_board_state_all_service" ON public.battle_board_state FOR ALL USING (false);

-- Allow service role / definer to manage board_state (policy above blocks normal users; RPC runs as definer)
-- So we need no INSERT policy for users; the RPC will run as SECURITY DEFINER and bypass RLS for insert.

-- Revoke the insert policy so only definer can insert (actually we want the RPC to insert)
-- RPC with SECURITY DEFINER bypasses RLS, so we're good. Normal users only SELECT.

-- RPC: submit this user's allocations for a room/hour (upsert). p_hour_bucket: ISO8601 string. p_allocations: JSON object string from client.
CREATE OR REPLACE FUNCTION public.submit_battle_allocations(
  p_room_id UUID,
  p_hour_bucket TEXT,
  p_user_id UUID,
  p_allocations TEXT DEFAULT '{}'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hour TIMESTAMPTZ;
  v_alloc JSONB;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'User mismatch';
  END IF;
  v_hour := date_trunc('hour', (p_hour_bucket::timestamptz));
  v_alloc := COALESCE((p_allocations::jsonb), '{}'::jsonb);
  INSERT INTO public.battle_allocations (room_id, hour_bucket, user_id, allocations, updated_at)
  VALUES (p_room_id, v_hour, p_user_id, v_alloc, now())
  ON CONFLICT (room_id, hour_bucket, user_id) DO UPDATE SET
    allocations = EXCLUDED.allocations,
    updated_at = now();
END;
$$;

-- Helper: build initial board (16 cells) - one corner player, some enemy, rest neutral
CREATE OR REPLACE FUNCTION public.battle_initial_board(p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cells JSONB := '[]'::jsonb;
  i INT;
  owner_val TEXT;
  hp_now_val INT;
  hp_max_val INT := 400;
  decay_val INT := 10;
BEGIN
  FOR i IN 0..15 LOOP
    IF i IN (0, 3, 12, 15) THEN
      IF i = 0 THEN
        owner_val := 'player';
        hp_now_val := 240;
      ELSE
        owner_val := 'neutral';
        hp_now_val := 120;
      END IF;
    ELSIF i % 7 = 0 THEN
      owner_val := 'enemy';
      hp_now_val := 220;
    ELSE
      owner_val := 'neutral';
      hp_now_val := 120;
    END IF;
    cells := cells || jsonb_build_object(
      'id', i,
      'owner', owner_val,
      'hp_now', hp_now_val,
      'hp_max', hp_max_val,
      'decay_per_hour', decay_val,
      'enemy_pressure', 0
    );
  END LOOP;
  RETURN cells;
END;
$$;

-- Get previous hour bucket
-- Settle: compute new board from previous board + all allocations for hour_bucket (perspective of p_viewer_id)
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

  -- 1) Return cached if exists
  SELECT b.cells INTO v_cached FROM public.battle_board_state b WHERE b.room_id = p_room_id AND b.hour_bucket = v_hour;
  IF v_cached IS NOT NULL AND jsonb_array_length(v_cached) > 0 THEN
    cells := v_cached;
    RETURN NEXT;
    RETURN;
  END IF;

  -- 2) Previous hour board (or initial)
  v_prev_hour := v_hour - interval '1 hour';
  SELECT b.cells INTO v_prev_cells FROM public.battle_board_state b WHERE b.room_id = p_room_id AND b.hour_bucket = v_prev_hour;
  IF v_prev_cells IS NULL OR jsonb_array_length(v_prev_cells) = 0 THEN
    v_prev_cells := public.battle_initial_board(p_room_id);
  END IF;

  -- 3) My allocations and others' (as enemy pressure per cell)
  SELECT allocations INTO v_my_alloc FROM public.battle_allocations WHERE room_id = p_room_id AND hour_bucket = v_hour AND user_id = auth.uid();
  v_my_alloc := COALESCE(v_my_alloc, '{}'::jsonb);

  v_others_alloc := '{}'::jsonb;
  FOR v_other_rec IN SELECT user_id, allocations FROM public.battle_allocations WHERE room_id = p_room_id AND hour_bucket = v_hour AND user_id != auth.uid()
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
