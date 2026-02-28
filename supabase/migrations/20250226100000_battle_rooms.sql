-- Battle rooms: one row per room, created when host starts a battle
CREATE TABLE IF NOT EXISTS public.battle_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  word_set_id UUID NOT NULL,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  start_date TIMESTAMPTZ NOT NULL,
  duration_days INT NOT NULL DEFAULT 7,
  invited_member_ids UUID[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_battle_rooms_creator ON public.battle_rooms (creator_id);
CREATE INDEX IF NOT EXISTS idx_battle_rooms_word_set ON public.battle_rooms (word_set_id);

ALTER TABLE public.battle_rooms ENABLE ROW LEVEL SECURITY;

-- Creators can do everything on their rooms; invited members can SELECT
DROP POLICY IF EXISTS "battle_rooms_creator_all" ON public.battle_rooms;
CREATE POLICY "battle_rooms_creator_all" ON public.battle_rooms
  FOR ALL USING (auth.uid() = creator_id);

DROP POLICY IF EXISTS "battle_rooms_invited_select" ON public.battle_rooms;
CREATE POLICY "battle_rooms_invited_select" ON public.battle_rooms
  FOR SELECT USING (auth.uid() = ANY(invited_member_ids));

-- RPC: create a room and return room_id. Params from client may be strings; p_duration_days/p_invited_ids parsed in body.
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
BEGIN
  IF auth.uid() IS DISTINCT FROM p_creator_id THEN
    RAISE EXCEPTION 'Only creator can create a room';
  END IF;
  v_ids := COALESCE(
    (SELECT array_agg(elem::uuid) FROM jsonb_array_elements_text((COALESCE(p_invited_ids, '[]')::jsonb)) AS elem),
    '{}'
  );
  INSERT INTO public.battle_rooms (word_set_id, creator_id, start_date, duration_days, invited_member_ids)
  VALUES (p_word_set_id, p_creator_id, p_start_date, (COALESCE(p_duration_days, '7')::int), v_ids)
  RETURNING id INTO v_room_id;
  RETURN v_room_id;
END;
$$;
