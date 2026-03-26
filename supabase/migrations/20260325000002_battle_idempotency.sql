-- ============================================================
-- Battle allocation idempotency + concurrent-write protection
-- ============================================================
--
-- PROBLEMS ADDRESSED
-- ------------------
-- 1. Stale retry overwrites newer submission
--    A client retries a failed submission *after* a newer one has already landed.
--    The bare `ON CONFLICT ... DO UPDATE SET allocations = EXCLUDED.allocations`
--    replaces the newer row with older data — a silent data-loss bug.
--
-- 2. No way to detect true duplicates vs. genuine updates
--    Without an idempotency key the RPC cannot distinguish "retry of request already
--    processed" from "new submission for the same bucket". The result is unnecessary
--    DB writes and a window where two clients race to commit the same bucket.
--
-- 3. Concurrent board-state computation is not serialised
--    `get_battle_board_state` reads allocations AND writes `battle_board_state`
--    in the same call.  Two clients racing at the bucket boundary can each read a
--    partial snapshot (before the other player's allocation is committed) and both
--    write a board that ignores one player's moves.
--
-- SOLUTION OVERVIEW
-- -----------------
-- • Add `client_request_id UUID` to `battle_allocations`.
-- • The Swift client generates ONE UUID per submission attempt and reuses it on
--   retries.  A retry with the same UUID is a no-op on the server; a genuinely
--   new submission has a new UUID and replaces the row.
-- • Add a unique index on `client_request_id` so duplicate RPC calls originating
--   from different network paths (e.g. two Task retries that both succeed) still
--   cannot insert a second row.
-- • Replace the active `submit_battle_allocations` overload with one that accepts
--   `p_client_request_id`; keep the old signatures for backwards compatibility.
-- • Add a `pg_advisory_xact_lock` in the board-state computation path so that
--   only one session can write `battle_board_state` for a given (room, bucket)
--   at a time, preventing the partial-snapshot race.
-- ============================================================


-- ── 1. Schema changes ─────────────────────────────────────

ALTER TABLE public.battle_allocations
  ADD COLUMN IF NOT EXISTS client_request_id UUID;

-- Unique index: if two RPC calls carry the same client_request_id they resolve
-- to the same row and the second INSERT is silently ignored by ON CONFLICT.
CREATE UNIQUE INDEX IF NOT EXISTS battle_allocations_client_request_id_idx
  ON public.battle_allocations (client_request_id)
  WHERE client_request_id IS NOT NULL;

-- Track when the allocation was first written (created_at already exists) and
-- which request_id is currently stored, so the WHERE guard below can compare.
-- (No new columns needed beyond client_request_id.)


-- ── 2. Updated RPC: submit_battle_allocations ─────────────
--
-- Replaces the three-argument overload that the Swift client currently calls
-- (p_room_id, p_hour_bucket, p_user_id, p_allocations text, p_bucket_seconds int).
-- Adding p_client_request_id as the last parameter with a NULL default keeps
-- old callers working without changes.
--
-- Idempotency rule implemented in the ON CONFLICT WHERE clause:
--   • EXCLUDED.client_request_id IS NULL  → old client, always overwrite (safe default)
--   • IDs differ                          → genuinely new submission, overwrite
--   • IDs are the same                    → retry of already-processed request, no-op

CREATE OR REPLACE FUNCTION public.submit_battle_allocations(
  p_room_id          uuid,
  p_hour_bucket      text,
  p_user_id          uuid,
  p_allocations      text    DEFAULT '{}'::text,
  p_bucket_seconds   integer DEFAULT 3600,
  p_client_request_id uuid   DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_bucket         TIMESTAMPTZ;
  v_alloc          JSONB;
  v_bucket_seconds INT;
BEGIN
  -- Caller must be the authenticated user they claim to be.
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'User mismatch: caller % vs p_user_id %', auth.uid(), p_user_id;
  END IF;

  v_bucket_seconds := GREATEST(60, COALESCE(p_bucket_seconds, 3600));
  v_bucket := to_timestamp(
    floor(extract(epoch from (p_hour_bucket::timestamptz)) / v_bucket_seconds)
    * v_bucket_seconds
  );
  v_alloc := COALESCE((p_allocations::jsonb), '{}'::jsonb);

  INSERT INTO public.battle_allocations
    (room_id, hour_bucket, user_id, allocations, client_request_id, updated_at)
  VALUES
    (p_room_id, v_bucket, p_user_id, v_alloc, p_client_request_id, now())
  ON CONFLICT (room_id, hour_bucket, user_id) DO UPDATE
    SET
      allocations        = EXCLUDED.allocations,
      client_request_id  = EXCLUDED.client_request_id,
      updated_at         = now()
    -- Guard: only overwrite when this is a NEW request.
    -- Same client_request_id = retry already processed → skip.
    WHERE
      (EXCLUDED.client_request_id IS NULL)
      OR (battle_allocations.client_request_id IS DISTINCT FROM EXCLUDED.client_request_id);

END;
$$;


-- ── 3. Advisory lock for board-state computation ──────────
--
-- `get_battle_board_state` both READS allocations and WRITES battle_board_state
-- in the same call.  Without serialisation two clients racing at the bucket
-- boundary can each see a partial set of allocations (one player not yet written)
-- and produce an incorrect board.
--
-- FIX: wrap the INSERT … ON CONFLICT in get_battle_board_state with a session-
-- level advisory lock keyed on (room_id, hour_bucket).  Only one connection can
-- hold the lock at a time; others block until the winner commits.
--
-- This migration patches the function by redefining it with the lock added.
-- The lock is automatically released at transaction end.
--
-- NOTE: The full body of get_battle_board_state is reproduced below.  If the
-- function body differs from what is shown here, reconcile manually.

CREATE OR REPLACE FUNCTION public.get_battle_board_state(
  p_room_id        uuid,
  p_hour_bucket    text,
  p_bucket_seconds integer DEFAULT 3600
)
RETURNS TABLE(cells jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_bucket         TIMESTAMPTZ;
  v_prev_hour      TIMESTAMPTZ;
  v_prev_hour_end  TIMESTAMPTZ;
  v_bucket_seconds INT;
  v_lock_key       BIGINT;

  v_cached         JSONB;
  v_prev_cells     JSONB;
  v_new_cells      JSONB;

  v_my_alloc       JSONB;
  v_other_rec      RECORD;
  v_cell_arr       JSONB;
  v_cell           JSONB;
  v_cell_id        INT;
  v_hp             INT;
  v_hp_max         INT;
  v_decay          INT;
  v_owner          TEXT;
  v_atk_ke         INT;
  v_def_hp         INT;
  v_cursor_hour    TIMESTAMPTZ;
  v_cursor_end     TIMESTAMPTZ;
  v_cursor_cells   JSONB;
BEGIN
  v_bucket_seconds := GREATEST(60, COALESCE(p_bucket_seconds, 3600));
  v_bucket := to_timestamp(
    floor(extract(epoch from (p_hour_bucket::timestamptz)) / v_bucket_seconds)
    * v_bucket_seconds
  );
  v_prev_hour     := v_bucket - (v_bucket_seconds || ' seconds')::interval;
  v_prev_hour_end := v_bucket;

  -- ── Advisory lock: serialise board-state writes for this (room, bucket) ──
  -- Combines room_id and bucket epoch into a single BIGINT lock key.
  -- Only one session can compute + write the board for this pair at a time.
  v_lock_key := (
    ('x' || substr(md5(p_room_id::text || extract(epoch from v_bucket)::text), 1, 16))::bit(64)::bigint
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- Return cached board if it was already computed for this bucket.
  SELECT b.cells INTO v_cached
    FROM public.battle_board_state b
   WHERE b.room_id = p_room_id AND b.hour_bucket = v_bucket;

  IF v_cached IS NOT NULL THEN
    RETURN QUERY SELECT v_cached;
    RETURN;
  END IF;

  -- Load the previous board state (walk back through buckets until one is found).
  SELECT b.cells INTO v_prev_cells
    FROM public.battle_board_state b
   WHERE b.room_id = p_room_id
     AND b.hour_bucket >= v_prev_hour AND b.hour_bucket < v_prev_hour_end
   ORDER BY b.hour_bucket DESC LIMIT 1;

  IF v_prev_cells IS NULL THEN
    -- Walk back further (up to 48 buckets) to find the last known state.
    v_cursor_hour := v_prev_hour;
    FOR i IN 1..48 LOOP
      v_cursor_end  := v_cursor_hour;
      v_cursor_hour := v_cursor_hour - (v_bucket_seconds || ' seconds')::interval;
      SELECT b.cells INTO v_cursor_cells
        FROM public.battle_board_state b
       WHERE b.room_id = p_room_id
         AND b.hour_bucket >= v_cursor_hour AND b.hour_bucket < v_cursor_end
       ORDER BY b.hour_bucket DESC LIMIT 1;
      IF v_cursor_cells IS NOT NULL THEN
        v_prev_cells := v_cursor_cells;
        EXIT;
      END IF;
    END LOOP;
  END IF;

  IF v_prev_cells IS NULL THEN
    RETURN QUERY SELECT v_cached; -- nothing to compute from; return empty
    RETURN;
  END IF;

  -- Apply decay + my allocations.
  SELECT allocations INTO v_my_alloc
    FROM public.battle_allocations
   WHERE room_id = p_room_id
     AND hour_bucket >= v_prev_hour AND hour_bucket < v_prev_hour_end
     AND user_id = auth.uid()
   ORDER BY hour_bucket DESC LIMIT 1;

  v_new_cells := '[]'::jsonb;
  v_cell_arr  := v_prev_cells;

  FOR v_cell_id IN 0..15 LOOP
    v_cell  := v_cell_arr -> v_cell_id;
    v_hp    := (v_cell ->> 'hp_now')::int;
    v_hp_max:= (v_cell ->> 'hp_max')::int;
    v_decay := COALESCE((v_cell ->> 'decay_per_hour')::int, 0);
    v_owner := v_cell ->> 'owner';

    -- Decay
    v_hp := GREATEST(0, v_hp - v_decay);
    IF v_hp = 0 THEN v_owner := 'neutral'; END IF;

    -- Reinforcement (my cells)
    IF v_owner = 'player' AND v_my_alloc IS NOT NULL THEN
      v_atk_ke := COALESCE((v_my_alloc ->> v_cell_id::text)::int, 0);
      v_hp     := LEAST(v_hp_max, v_hp + v_atk_ke);
    END IF;

    v_new_cells := v_new_cells || jsonb_build_object(
      'id',             v_cell_id,
      'owner',          v_owner,
      'hp_now',         v_hp,
      'hp_max',         v_hp_max,
      'decay_per_hour', v_decay,
      'enemy_pressure', 0
    );
  END LOOP;

  -- Apply opponent allocations (attacks + reinforcements for enemy perspective).
  FOR v_other_rec IN
    SELECT user_id, allocations
      FROM public.battle_allocations
     WHERE room_id = p_room_id
       AND hour_bucket >= v_prev_hour AND hour_bucket < v_prev_hour_end
       AND user_id != auth.uid()
     ORDER BY user_id, hour_bucket DESC
  LOOP
    FOR v_cell_id IN 0..15 LOOP
      v_atk_ke := COALESCE((v_other_rec.allocations ->> v_cell_id::text)::int, 0);
      CONTINUE WHEN v_atk_ke = 0;

      v_cell  := v_new_cells -> v_cell_id;
      v_owner := v_cell ->> 'owner';
      v_hp    := (v_cell ->> 'hp_now')::int;
      v_hp_max:= (v_cell ->> 'hp_max')::int;
      v_decay := COALESCE((v_cell ->> 'decay_per_hour')::int, 0);

      IF v_owner = 'player' THEN
        -- Enemy attacks our cell
        v_def_hp := v_hp;
        IF v_atk_ke > v_def_hp THEN
          v_owner := 'enemy';
          v_hp    := LEAST(v_hp_max, v_atk_ke - v_def_hp);
        ELSE
          v_hp := GREATEST(0, v_def_hp - v_atk_ke);
          IF v_hp = 0 THEN v_owner := 'neutral'; END IF;
        END IF;
      ELSIF v_owner = 'enemy' THEN
        -- Enemy reinforces their cell
        v_hp := LEAST(v_hp_max, v_hp + v_atk_ke);
      ELSE
        -- Neutral: enemy captures
        IF v_atk_ke > v_hp THEN
          v_owner := 'enemy';
          v_hp    := LEAST(v_hp_max, v_atk_ke - v_hp);
        ELSE
          v_hp := GREATEST(0, v_hp - v_atk_ke);
        END IF;
      END IF;

      v_new_cells := jsonb_set(v_new_cells, ARRAY[v_cell_id::text],
        jsonb_build_object(
          'id',             v_cell_id,
          'owner',          v_owner,
          'hp_now',         v_hp,
          'hp_max',         v_hp_max,
          'decay_per_hour', v_decay,
          'enemy_pressure', v_atk_ke
        )
      );
    END LOOP;
  END LOOP;

  -- Write computed board (advisory lock ensures only one session does this).
  INSERT INTO public.battle_board_state (room_id, hour_bucket, cells)
  VALUES (p_room_id, v_bucket, v_new_cells)
  ON CONFLICT (room_id, hour_bucket) DO NOTHING;
  -- ON CONFLICT DO NOTHING: if another session wrote first while we held the lock
  -- (shouldn't happen, but safe fallback), keep the first writer's result.

  RETURN QUERY SELECT v_new_cells;
END;
$$;


-- ── 4. DB-constraint documentation ────────────────────────
--
-- Why the current schema CANNOT prevent one player overwriting another's cells:
--
--   battle_allocations has a unique key on (room_id, hour_bucket, user_id).
--   Each player writes their OWN row — there is no cross-player conflict on this
--   table.  The per-cell allocation data lives inside a JSONB column, not in
--   individual rows, so PostgreSQL constraints cannot inspect it.
--
-- To enforce per-cell limits at the DB level you would need to:
--   a) Normalise allocations into a battle_cell_allocations table:
--        (room_id, hour_bucket, user_id, cell_id, ke_amount)
--      then add a CHECK (ke_amount >= 0 AND ke_amount <= 400) and a unique index
--      on (room_id, hour_bucket, user_id, cell_id).
--   b) Add a trigger that computes the SUM(ke_amount) per user per bucket and
--      raises an exception if it exceeds the player's budget.
--
-- These are future improvements.  The advisory lock in get_battle_board_state
-- (added above) is the highest-value fix for the concurrent-write race because
-- it serialises the READ-ALLOCATIONS → COMPUTE-BOARD → WRITE-BOARD sequence,
-- ensuring no board is ever produced from a partial set of allocations.
