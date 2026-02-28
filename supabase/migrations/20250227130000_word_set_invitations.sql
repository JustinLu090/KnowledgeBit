-- 單字集邀請：擁有者發送邀請，被邀請者確認後才加入共編
CREATE TABLE IF NOT EXISTS public.word_set_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  word_set_id UUID NOT NULL REFERENCES public.word_sets(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invitee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (word_set_id, invitee_id)
);

CREATE INDEX IF NOT EXISTS idx_word_set_invitations_invitee ON public.word_set_invitations (invitee_id);
CREATE INDEX IF NOT EXISTS idx_word_set_invitations_word_set ON public.word_set_invitations (word_set_id);

ALTER TABLE public.word_set_invitations ENABLE ROW LEVEL SECURITY;

-- 擁有者可以插入邀請（限自己的單字集）；被邀請者可以讀取自己的、可更新狀態
DROP POLICY IF EXISTS "word_set_invitations_insert_owner" ON public.word_set_invitations;
CREATE POLICY "word_set_invitations_insert_owner" ON public.word_set_invitations
  FOR INSERT WITH CHECK (
    auth.uid() = inviter_id
    AND EXISTS (SELECT 1 FROM public.word_sets ws WHERE ws.id = word_set_id AND ws.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "word_set_invitations_select_invitee" ON public.word_set_invitations;
CREATE POLICY "word_set_invitations_select_invitee" ON public.word_set_invitations
  FOR SELECT USING (auth.uid() = invitee_id OR auth.uid() = inviter_id);

DROP POLICY IF EXISTS "word_set_invitations_update_invitee" ON public.word_set_invitations;
CREATE POLICY "word_set_invitations_update_invitee" ON public.word_set_invitations
  FOR UPDATE USING (auth.uid() = invitee_id);

-- 發送邀請（僅單字集擁有者）
CREATE OR REPLACE FUNCTION public.create_word_set_invitation(
  p_word_set_id UUID,
  p_invitee_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_id UUID;
  v_invitation_id UUID;
BEGIN
  SELECT user_id INTO v_owner_id FROM public.word_sets WHERE id = p_word_set_id;
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'word_set not found';
  END IF;
  IF auth.uid() IS DISTINCT FROM v_owner_id THEN
    RAISE EXCEPTION 'only owner can invite';
  END IF;
  IF EXISTS (SELECT 1 FROM public.word_set_collaborators WHERE word_set_id = p_word_set_id AND user_id = p_invitee_id) THEN
    RAISE EXCEPTION 'user is already a collaborator';
  END IF;

  INSERT INTO public.word_set_invitations (word_set_id, inviter_id, invitee_id, status)
  VALUES (p_word_set_id, auth.uid(), p_invitee_id, 'pending')
  ON CONFLICT (word_set_id, invitee_id) DO UPDATE SET updated_at = now()
  RETURNING id INTO v_invitation_id;
  RETURN v_invitation_id;
END;
$$;

-- 取得「我收到的」待處理單字集邀請（含單字集名稱與邀請者名稱）
CREATE OR REPLACE FUNCTION public.get_my_pending_word_set_invitations()
RETURNS TABLE (
  id UUID,
  word_set_id UUID,
  word_set_title TEXT,
  inviter_id UUID,
  inviter_display_name TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    i.id,
    i.word_set_id,
    ws.title AS word_set_title,
    i.inviter_id,
    COALESCE(p.display_name, '使用者') AS inviter_display_name,
    i.created_at
  FROM public.word_set_invitations i
  JOIN public.word_sets ws ON ws.id = i.word_set_id
  LEFT JOIN public.user_profiles p ON p.user_id = i.inviter_id
  WHERE i.invitee_id = auth.uid()
    AND i.status = 'pending';
$$;

-- 接受或拒絕邀請（僅被邀請者）；p_accept 可傳 'true'/'false' 字串
CREATE OR REPLACE FUNCTION public.respond_word_set_invitation(
  p_invitation_id UUID,
  p_accept TEXT DEFAULT 'true'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invitee_id UUID;
  v_word_set_id UUID;
  v_accept BOOLEAN;
BEGIN
  v_accept := lower(trim(p_accept)) = 'true';

  SELECT invitee_id, word_set_id INTO v_invitee_id, v_word_set_id
  FROM public.word_set_invitations
  WHERE id = p_invitation_id AND status = 'pending';

  IF v_invitee_id IS NULL THEN
    RAISE EXCEPTION 'invitation not found or already responded';
  END IF;
  IF auth.uid() IS DISTINCT FROM v_invitee_id THEN
    RAISE EXCEPTION 'only invitee can respond';
  END IF;

  IF v_accept THEN
    INSERT INTO public.word_set_collaborators (word_set_id, user_id)
    VALUES (v_word_set_id, v_invitee_id)
    ON CONFLICT (word_set_id, user_id) DO NOTHING;
  END IF;

  UPDATE public.word_set_invitations
  SET status = CASE WHEN v_accept THEN 'accepted' ELSE 'declined' END,
      updated_at = now()
  WHERE id = p_invitation_id;
END;
$$;

-- 查詢某單字集目前「待確認」的邀請（擁有者用）
CREATE OR REPLACE FUNCTION public.get_word_set_pending_invitations(p_word_set_id UUID)
RETURNS TABLE (invitation_id UUID, invitee_id UUID, invitee_display_name TEXT, created_at TIMESTAMPTZ)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT i.id AS invitation_id, i.invitee_id, COALESCE(p.display_name, '使用者') AS invitee_display_name, i.created_at
  FROM public.word_set_invitations i
  LEFT JOIN public.user_profiles p ON p.user_id = i.invitee_id
  WHERE i.word_set_id = p_word_set_id
    AND i.status = 'pending'
    AND EXISTS (SELECT 1 FROM public.word_sets ws WHERE ws.id = i.word_set_id AND ws.user_id = auth.uid());
$$;

GRANT EXECUTE ON FUNCTION public.create_word_set_invitation(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_pending_word_set_invitations() TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_word_set_invitation(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_word_set_pending_invitations(uuid) TO authenticated;
