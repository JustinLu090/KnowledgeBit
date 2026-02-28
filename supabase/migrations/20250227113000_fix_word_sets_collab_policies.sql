-- 修正 word_sets 與 word_set_collaborators 之間的 RLS 遞迴問題
-- 目前情況：兩邊的 policy 互相用 EXISTS 查對方，導致 infinite recursion (42P17)

-- 方案：
-- 1. 保留 word_sets 這邊「擁有者 + 共編者可 SELECT」的邏輯（需要查 word_set_collaborators）
-- 2. 簡化 word_set_collaborators 的 SELECT policy，只依 user_id 判斷，
--    不再回頭查 word_sets，避免形成遞迴。

-- 調整 word_set_collaborators 的 SELECT policy：只要是該列的 user_id 就能看到
ALTER TABLE public.word_set_collaborators ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "word_set_collab_select" ON public.word_set_collaborators;

CREATE POLICY "word_set_collab_select"
  ON public.word_set_collaborators
  FOR SELECT
  USING (auth.uid() = user_id);

-- 保留「只有單字集擁有者可以新增 / 修改 / 刪除共編成員」的邏輯
DROP POLICY IF EXISTS "word_set_collab_modify_owner_only" ON public.word_set_collaborators;

CREATE POLICY "word_set_collab_modify_owner_only"
  ON public.word_set_collaborators
  FOR ALL
  USING (
    EXISTS (
      SELECT 1
      FROM public.word_sets ws
      WHERE ws.id = word_set_id
        AND ws.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.word_sets ws
      WHERE ws.id = word_set_id
        AND ws.user_id = auth.uid()
    )
  );

