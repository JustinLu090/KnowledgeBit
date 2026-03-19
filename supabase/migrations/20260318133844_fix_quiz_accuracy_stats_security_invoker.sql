begin;

-- Recreate as SECURITY INVOKER to avoid SECURITY DEFINER bypassing RLS
drop view if exists public.quiz_accuracy_stats;

create view public.quiz_accuracy_stats
with (security_invoker = true) as
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