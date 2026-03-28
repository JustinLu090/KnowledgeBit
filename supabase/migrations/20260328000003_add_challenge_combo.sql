-- ============================================================
-- 挑戰模式：新增選擇題連答數欄位
-- challenger_combo：發起者最高連答數
-- respondent_combo：接受者最高連答數
-- ============================================================

ALTER TABLE public.challenge_sessions
  ADD COLUMN IF NOT EXISTS challenger_combo INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS respondent_combo INT;
