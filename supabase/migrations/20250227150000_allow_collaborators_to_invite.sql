-- 允許單字集「擁有者」或「共編者」發送邀請（原本僅允許擁有者）
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
  v_can_invite BOOLEAN;
BEGIN
  SELECT user_id INTO v_owner_id FROM public.word_sets WHERE id = p_word_set_id;
  IF v_owner_id IS NULL THEN
    RAISE EXCEPTION 'word_set not found';
  END IF;

  -- 擁有者或共編者都可以邀請
  v_can_invite := (auth.uid() = v_owner_id)
    OR EXISTS (
      SELECT 1 FROM public.word_set_collaborators
      WHERE word_set_id = p_word_set_id AND user_id = auth.uid()
    );
  IF NOT v_can_invite THEN
    RAISE EXCEPTION 'only owner or collaborator can invite';
  END IF;

  IF EXISTS (SELECT 1 FROM public.word_set_collaborators WHERE word_set_id = p_word_set_id AND user_id = p_invitee_id) THEN
    RAISE EXCEPTION 'user is already a collaborator';
  END IF;

  -- 若對方已經邀請過你（pending），你就不能再邀請對方，避免互相重複邀請
  IF EXISTS (
    SELECT 1 FROM public.word_set_invitations
    WHERE word_set_id = p_word_set_id
      AND inviter_id = p_invitee_id
      AND invitee_id = auth.uid()
      AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'cannot invite someone who has already invited you';
  END IF;

  INSERT INTO public.word_set_invitations (word_set_id, inviter_id, invitee_id, status)
  VALUES (p_word_set_id, auth.uid(), p_invitee_id, 'pending')
  ON CONFLICT (word_set_id, invitee_id) DO UPDATE SET updated_at = now()
  RETURNING id INTO v_invitation_id;
  RETURN v_invitation_id;
END;
$$;
