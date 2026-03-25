-- Add weekly_exp column to user_profiles for friend leaderboard feature.
-- Achievements are stored client-side in UserDefaults; no server table needed.

alter table public.user_profiles
  add column if not exists weekly_exp int not null default 0;
