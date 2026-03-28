-- ============================================================
-- 新增 target_score 欄位到 challenge_sessions 表
-- target_score：挑戰目標分數（接受者須超越的分數門檻，初始等於 challenger_score）
-- ============================================================

ALTER TABLE public.challenge_sessions
  ADD COLUMN IF NOT EXISTS target_score INT;

-- 為已存在的紀錄補填預設值（等於發起者成績）
UPDATE public.challenge_sessions
  SET target_score = challenger_score
  WHERE target_score IS NULL;
