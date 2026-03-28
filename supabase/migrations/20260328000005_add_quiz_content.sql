-- ============================================================
-- 非同步挑戰：儲存 AI 生成的完整題目快照（JSONB）
-- 確保 A 與 B 看到完全相同的題目，不重新呼叫 AI
-- ============================================================

ALTER TABLE public.challenge_sessions
  ADD COLUMN IF NOT EXISTS quiz_content JSONB;
