-- Battle energy (KE) per user per namespace (e.g. room_id or word_set_id)
CREATE TABLE IF NOT EXISTS public.battle_energy (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  namespace TEXT NOT NULL,
  available_ke INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, namespace)
);

CREATE INDEX IF NOT EXISTS idx_battle_energy_user ON public.battle_energy (user_id);

ALTER TABLE public.battle_energy ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "battle_energy_own" ON public.battle_energy;
CREATE POLICY "battle_energy_own" ON public.battle_energy FOR ALL USING (auth.uid() = user_id);

-- RPC: increment KE (p_delta can be sent as text from client, cast to int)
CREATE OR REPLACE FUNCTION public.ke_increment(
  p_user_id UUID,
  p_namespace TEXT,
  p_delta TEXT DEFAULT '0'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_delta INT := GREATEST(0, (p_delta::int));
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'User mismatch';
  END IF;
  IF v_delta <= 0 THEN
    RETURN;
  END IF;
  INSERT INTO public.battle_energy (user_id, namespace, available_ke, updated_at)
  VALUES (p_user_id, p_namespace, v_delta, now())
  ON CONFLICT (user_id, namespace) DO UPDATE SET
    available_ke = public.battle_energy.available_ke + v_delta,
    updated_at = now();
END;
$$;

-- RPC: spend KE (p_amount as text from client). Fails if insufficient.
CREATE OR REPLACE FUNCTION public.ke_spend(
  p_user_id UUID,
  p_namespace TEXT,
  p_amount TEXT DEFAULT '0'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_amount INT := GREATEST(0, (p_amount::int));
  v_current INT;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'User mismatch';
  END IF;
  IF v_amount <= 0 THEN
    RETURN;
  END IF;
  SELECT available_ke INTO v_current FROM public.battle_energy WHERE user_id = p_user_id AND namespace = p_namespace;
  v_current := COALESCE(v_current, 0);
  IF v_current < v_amount THEN
    RAISE EXCEPTION 'Insufficient KE: have %, need %', v_current, v_amount;
  END IF;
  UPDATE public.battle_energy SET available_ke = available_ke - v_amount, updated_at = now()
  WHERE user_id = p_user_id AND namespace = p_namespace;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient KE';
  END IF;
END;
$$;
