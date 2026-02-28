-- 讓 get_word_set_collaborators 也回傳擁有者，這樣標題列可以顯示擁有者頭像
CREATE OR REPLACE FUNCTION public.get_word_set_collaborators(p_word_set_id UUID)
RETURNS TABLE (word_set_id UUID, user_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.word_sets w
    WHERE w.id = p_word_set_id
      AND (w.user_id = auth.uid() OR EXISTS (
        SELECT 1 FROM public.word_set_collaborators c
        WHERE c.word_set_id = w.id AND c.user_id = auth.uid()
      ))
  ) THEN
    RETURN;  -- 無權限則回傳空
  END IF;

  -- 擁有者 + 共編成員（含擁有者時 UNION 會去重）
  RETURN QUERY
  SELECT w.id, w.user_id
  FROM public.word_sets w
  WHERE w.id = p_word_set_id
  UNION
  SELECT c.word_set_id, c.user_id
  FROM public.word_set_collaborators c
  WHERE c.word_set_id = p_word_set_id;
END;
$$;
