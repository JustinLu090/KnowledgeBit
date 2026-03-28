-- ============================================================
-- 非同步挑戰模式 (Async Challenge Mode)
-- challenge_sessions 表記錄挑戰發起者與接受者的成績比拼
-- ============================================================

CREATE TABLE IF NOT EXISTS public.challenge_sessions (
  id                        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- 發起者資訊
  challenger_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  challenger_display_name   TEXT,
  challenger_avatar_url     TEXT,
  challenger_level          INT         NOT NULL DEFAULT 1,

  -- 使用的單字集（可為空，若單字集已刪除）
  word_set_id               UUID        REFERENCES public.word_sets(id) ON DELETE SET NULL,
  word_set_title            TEXT        NOT NULL,

  -- 發起者分數
  challenger_score          INT         NOT NULL DEFAULT 0,
  challenger_total          INT         NOT NULL DEFAULT 0,
  challenger_time_spent     FLOAT,                           -- 秒數
  challenger_completed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- 接受者資訊（回應後填入）
  respondent_id             UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  respondent_display_name   TEXT,
  respondent_score          INT,
  respondent_total          INT,
  respondent_time_spent     FLOAT,
  respondent_completed_at   TIMESTAMPTZ,

  -- 狀態：pending | completed | expired
  status                    TEXT        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending', 'completed', 'expired')),

  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at                TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days')
);

-- ============================================================
-- 索引
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_challenge_challenger   ON public.challenge_sessions (challenger_id);
CREATE INDEX IF NOT EXISTS idx_challenge_respondent   ON public.challenge_sessions (respondent_id);
CREATE INDEX IF NOT EXISTS idx_challenge_word_set     ON public.challenge_sessions (word_set_id);
CREATE INDEX IF NOT EXISTS idx_challenge_status       ON public.challenge_sessions (status);
CREATE INDEX IF NOT EXISTS idx_challenge_created      ON public.challenge_sessions (created_at DESC);

-- ============================================================
-- Row Level Security
-- ============================================================
ALTER TABLE public.challenge_sessions ENABLE ROW LEVEL SECURITY;

-- 登入使用者可以讀取自己發起或接受的挑戰
CREATE POLICY "challenge_read_own" ON public.challenge_sessions
  FOR SELECT
  USING (
    auth.uid() = challenger_id
    OR auth.uid() = respondent_id
  );

-- 任何登入使用者可以讀取 pending 且未過期的挑戰（透過分享連結打開）
CREATE POLICY "challenge_read_pending" ON public.challenge_sessions
  FOR SELECT
  USING (
    status = 'pending'
    AND expires_at > now()
  );

-- 只有發起者可以建立挑戰
CREATE POLICY "challenge_insert_own" ON public.challenge_sessions
  FOR INSERT
  WITH CHECK (auth.uid() = challenger_id);

-- 接受者可以更新 respondent 欄位（比拼回應）
-- 發起者也可以更新（例如 expire 自己的挑戰）
CREATE POLICY "challenge_update_participant" ON public.challenge_sessions
  FOR UPDATE
  USING (
    auth.uid() = challenger_id
    OR auth.uid() = respondent_id
    OR (status = 'pending' AND expires_at > now())
  );

-- ============================================================
-- 讓接受挑戰者可以讀取挑戰所對應單字集的卡片
-- （即使他不是該 word_set 的擁有者或共編者）
-- ============================================================
CREATE POLICY "cards_read_for_active_challenge" ON public.cards
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.challenge_sessions cs
      WHERE cs.word_set_id = cards.word_set_id
        AND cs.status = 'pending'
        AND cs.expires_at > now()
    )
  );
