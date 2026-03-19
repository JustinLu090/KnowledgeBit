begin;

alter table public.user_profiles
  add column if not exists has_seen_onboarding boolean not null default false;

alter table public.study_logs
  add column if not exists total_cards integer not null default 0;

alter table public.study_logs
  add column if not exists activity_type text not null default 'flashcard';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'study_logs_activity_type_check'
      and conrelid = 'public.study_logs'::regclass
  ) then
    alter table public.study_logs
      add constraint study_logs_activity_type_check
      check (activity_type in ('multiple_choice', 'flashcard'));
  end if;
end $$;

create index if not exists idx_study_logs_user_activity_date
  on public.study_logs (user_id, activity_type, date);

create or replace view public.quiz_accuracy_stats as
select
  sl.user_id,
  count(*) as quiz_sessions,
  sum(sl.cards_reviewed)::bigint as total_correct,
  sum(sl.total_cards)::bigint as total_questions,
  case
    when sum(sl.total_cards) > 0
      then round((sum(sl.cards_reviewed)::numeric / sum(sl.total_cards)::numeric) * 100, 2)
    else null
  end as accuracy_percent
from public.study_logs sl
where sl.activity_type = 'multiple_choice'
  and sl.total_cards > 0
group by sl.user_id;

commit;