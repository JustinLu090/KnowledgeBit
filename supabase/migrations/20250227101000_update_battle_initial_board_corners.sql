-- Ensure initial battle board has exactly:
-- - enemy controlling top-left corner (cell 0)
-- - player controlling bottom-right corner (cell 15)
-- - all other cells neutral
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
    IF i = 0 THEN
      -- Top-left: enemy start
      owner_val := 'enemy';
      hp_now_val := 220;
    ELSIF i = 15 THEN
      -- Bottom-right: player start
      owner_val := 'player';
      hp_now_val := 240;
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

