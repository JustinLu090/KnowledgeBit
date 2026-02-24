-- KnowledgeBit: word_sets 與 cards 表結構與 RLS
-- 供 App 在 SwiftData 寫入成功後同步至 Supabase（單向寫入）

-- word_sets：若表已存在則跳過建立，僅確保欄位與 RLS
CREATE TABLE IF NOT EXISTS public.word_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  level TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_word_sets_user_id ON public.word_sets (user_id);

-- cards
CREATE TABLE IF NOT EXISTS public.cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  word_set_id UUID REFERENCES public.word_sets(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  is_mastered BOOLEAN NOT NULL DEFAULT false,
  srs_level INT NOT NULL DEFAULT 0,
  due_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_reviewed_at TIMESTAMPTZ,
  correct_streak INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cards_user_id ON public.cards (user_id);
CREATE INDEX IF NOT EXISTS idx_cards_word_set_id ON public.cards (word_set_id);

-- RLS
ALTER TABLE public.word_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;

-- word_sets: 僅允許操作自己的列
DROP POLICY IF EXISTS "word_sets_select_own" ON public.word_sets;
CREATE POLICY "word_sets_select_own" ON public.word_sets FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "word_sets_insert_own" ON public.word_sets;
CREATE POLICY "word_sets_insert_own" ON public.word_sets FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "word_sets_update_own" ON public.word_sets;
CREATE POLICY "word_sets_update_own" ON public.word_sets FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "word_sets_delete_own" ON public.word_sets;
CREATE POLICY "word_sets_delete_own" ON public.word_sets FOR DELETE USING (auth.uid() = user_id);

-- cards: 僅允許操作自己的列
DROP POLICY IF EXISTS "cards_select_own" ON public.cards;
CREATE POLICY "cards_select_own" ON public.cards FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "cards_insert_own" ON public.cards;
CREATE POLICY "cards_insert_own" ON public.cards FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "cards_update_own" ON public.cards;
CREATE POLICY "cards_update_own" ON public.cards FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "cards_delete_own" ON public.cards;
CREATE POLICY "cards_delete_own" ON public.cards FOR DELETE USING (auth.uid() = user_id);
