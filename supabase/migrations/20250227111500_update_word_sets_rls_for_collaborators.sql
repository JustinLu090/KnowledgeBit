-- 允許被加入為某單字集共編者的使用者，也能 SELECT 該 word_set
-- 調整 word_sets 的 RLS select 規則

ALTER TABLE public.word_sets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "word_sets_select_own" ON public.word_sets;

CREATE POLICY "word_sets_select_visible" ON public.word_sets
  FOR SELECT
  USING (
    -- 單字集擁有者本身
    auth.uid() = user_id
    OR
    -- 或者被加入為該單字集的共編成員
    EXISTS (
      SELECT 1
      FROM public.word_set_collaborators c
      WHERE c.word_set_id = word_sets.id
        AND c.user_id = auth.uid()
    )
  );

