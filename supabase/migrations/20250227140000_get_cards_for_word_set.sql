-- 共編單字集：讓擁有者與共編者都能讀取該單字集內「所有」卡片（含他人新增的）
-- 透過 RPC 繞過 cards 的 RLS（僅能 SELECT 自己的列），依權限回傳該單字集全部卡片

CREATE OR REPLACE FUNCTION public.get_cards_for_word_set(p_word_set_id UUID)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  word_set_id UUID,
  title TEXT,
  content TEXT,
  is_mastered BOOLEAN,
  srs_level INT,
  due_at TIMESTAMPTZ,
  last_reviewed_at TIMESTAMPTZ,
  correct_streak INT,
  created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT c.id, c.user_id, c.word_set_id, c.title, c.content, c.is_mastered,
         c.srs_level, c.due_at, c.last_reviewed_at, c.correct_streak, c.created_at
  FROM public.cards c
  WHERE c.word_set_id = p_word_set_id
    AND (
      EXISTS (SELECT 1 FROM public.word_sets ws WHERE ws.id = c.word_set_id AND ws.user_id = auth.uid())
      OR EXISTS (
        SELECT 1 FROM public.word_set_collaborators col
        WHERE col.word_set_id = c.word_set_id AND col.user_id = auth.uid()
      )
    );
$$;

GRANT EXECUTE ON FUNCTION public.get_cards_for_word_set(uuid) TO authenticated;
