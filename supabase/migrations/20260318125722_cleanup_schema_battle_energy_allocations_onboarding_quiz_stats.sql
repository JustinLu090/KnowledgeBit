-- KnowledgeBit schema cleanup (Option B)
-- Keep: battle_rooms, battle_board_state
-- Remove: battle_energy, battle_allocations (+ any dependent functions/policies/grants)
-- Add/ensure:
-- - user_profiles.has_seen_onboarding boolean default false
-- - study_logs.activity_type ('multiple_choice','flashcard') + total_cards
-- - view: public.quiz_accuracy_stats (multiple_choice only)
-- RLS: merge redundant policies on core tables (cards/word_sets/user_profiles/study_logs/word_set_*)

begin;

-- -----------------------------------------------------------------------------
-- 0) Remove legacy battle_energy / battle_allocations and dependent functions
-- -----------------------------------------------------------------------------

-- battle_energy dependent functions (overloads)
drop function if exists public.ke_increment(uuid, text, integer);
drop function if exists public.ke_increment(uuid, text, text);
drop function if exists public.ke_spend(uuid, text, integer);
drop function if exists public.ke_spend(uuid, text, text);

-- battle_allocations dependent functions (overloads) + step computation that reads allocations
drop function if exists public.submit_battle_allocations(uuid, text, uuid, jsonb);
drop function if exists public.submit_battle_allocations(uuid, text, uuid, text);
drop function if exists public.submit_battle_allocations(uuid, text, uuid, text, integer);
drop function if exists public.compute_one_battle_step(uuid, uuid, uuid[], jsonb, timestamp with time zone, integer);

-- Drop tables (CASCADE removes RLS policies, grants, indexes, FKs on these tables)
drop table if exists public.battle_energy cascade;
drop table if exists public.battle_allocations cascade;

-- -----------------------------------------------------------------------------
-- 1) Schema adjustments
-- -----------------------------------------------------------------------------

-- 1.1 user_profiles: onboarding flag
alter table public.user_profiles
  add column if not exists has_seen_onboarding boolean not null default false;

-- 1.2 study_logs: accuracy inputs + activity type
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

-- -----------------------------------------------------------------------------
-- 2) RLS policy cleanup (merge duplicates)
-- -----------------------------------------------------------------------------

-- -------------------------
-- 2.1 cards
-- -------------------------
drop policy if exists "Users can do everything on own cards" on public.cards;
drop policy if exists "cards_delete_own" on public.cards;
drop policy if exists "cards_insert_own" on public.cards;
drop policy if exists "cards_select_own" on public.cards;
drop policy if exists "cards_update_own" on public.cards;

alter table public.cards enable row level security;

-- SELECT: own cards OR cards in visible word set (owner/collab)
create policy cards_select_visible
on public.cards
as permissive
for select
to authenticated
using (
  auth.uid() = user_id
  or (
    word_set_id is not null
    and (
      exists (
        select 1 from public.word_sets ws
        where ws.id = cards.word_set_id
          and ws.user_id = auth.uid()
      )
      or exists (
        select 1 from public.word_set_collaborators c
        where c.word_set_id = cards.word_set_id
          and c.user_id = auth.uid()
      )
    )
  )
);

-- INSERT: must be own row; if word_set_id present, must be visible
create policy cards_insert_own
on public.cards
as permissive
for insert
to authenticated
with check (
  auth.uid() = user_id
  and (
    word_set_id is null
    or exists (
      select 1 from public.word_sets ws
      where ws.id = cards.word_set_id
        and ws.user_id = auth.uid()
    )
    or exists (
      select 1 from public.word_set_collaborators c
      where c.word_set_id = cards.word_set_id
        and c.user_id = auth.uid()
    )
  )
);

-- UPDATE/DELETE: only row owner
create policy cards_update_own
on public.cards
as permissive
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy cards_delete_own
on public.cards
as permissive
for delete
to authenticated
using (auth.uid() = user_id);

-- -------------------------
-- 2.2 word_sets
-- -------------------------
drop policy if exists "Users can do everything on own word_sets" on public.word_sets;
drop policy if exists "word_sets_delete_own" on public.word_sets;
drop policy if exists "word_sets_insert_own" on public.word_sets;
drop policy if exists "word_sets_select_visible" on public.word_sets;
drop policy if exists "word_sets_update_own" on public.word_sets;

alter table public.word_sets enable row level security;

create policy word_sets_select_visible
on public.word_sets
as permissive
for select
to authenticated
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.word_set_collaborators c
    where c.word_set_id = word_sets.id
      and c.user_id = auth.uid()
  )
);

create policy word_sets_insert_own
on public.word_sets
as permissive
for insert
to authenticated
with check (auth.uid() = user_id);

create policy word_sets_update_own
on public.word_sets
as permissive
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy word_sets_delete_own
on public.word_sets
as permissive
for delete
to authenticated
using (auth.uid() = user_id);

-- -------------------------
-- 2.3 word_set_collaborators
-- -------------------------
drop policy if exists "word_set_collab_modify_any_authenticated" on public.word_set_collaborators;
drop policy if exists "word_set_collab_select" on public.word_set_collaborators;

alter table public.word_set_collaborators enable row level security;

-- SELECT: owner of the set OR the collaborator themself
create policy word_set_collaborators_select_visible
on public.word_set_collaborators
as permissive
for select
to authenticated
using (
  auth.uid() = user_id
  or exists (
    select 1
    from public.word_sets ws
    where ws.id = word_set_collaborators.word_set_id
      and ws.user_id = auth.uid()
  )
);

-- ALL (insert/update/delete): only word_set owner manages collaborators
create policy word_set_collaborators_manage_owner
on public.word_set_collaborators
as permissive
for all
to authenticated
using (
  exists (
    select 1
    from public.word_sets ws
    where ws.id = word_set_collaborators.word_set_id
      and ws.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.word_sets ws
    where ws.id = word_set_collaborators.word_set_id
      and ws.user_id = auth.uid()
  )
);

-- -------------------------
-- 2.4 word_set_invitations
-- -------------------------
drop policy if exists "word_set_invitations_insert_owner" on public.word_set_invitations;
drop policy if exists "word_set_invitations_select_invitee" on public.word_set_invitations;
drop policy if exists "word_set_invitations_update_invitee" on public.word_set_invitations;

alter table public.word_set_invitations enable row level security;

create policy word_set_invitations_insert_owner
on public.word_set_invitations
as permissive
for insert
to authenticated
with check (
  auth.uid() = inviter_id
  and exists (
    select 1
    from public.word_sets ws
    where ws.id = word_set_invitations.word_set_id
      and ws.user_id = auth.uid()
  )
);

create policy word_set_invitations_select_participants
on public.word_set_invitations
as permissive
for select
to authenticated
using (auth.uid() = invitee_id or auth.uid() = inviter_id);

create policy word_set_invitations_update_invitee
on public.word_set_invitations
as permissive
for update
to authenticated
using (auth.uid() = invitee_id)
with check (auth.uid() = invitee_id);

-- -------------------------
-- 2.5 study_logs
-- -------------------------
drop policy if exists "Users can do everything on own study_logs" on public.study_logs;

alter table public.study_logs enable row level security;

create policy study_logs_owner_all
on public.study_logs
as permissive
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- -------------------------
-- 2.6 user_profiles
-- -------------------------
drop policy if exists "Authenticated users can view profiles for discovery" on public.user_profiles;
drop policy if exists "Users can delete own profile" on public.user_profiles;
drop policy if exists "Users can insert own profile" on public.user_profiles;
drop policy if exists "Users can read own profile" on public.user_profiles;
drop policy if exists "Users can update own profile" on public.user_profiles;
drop policy if exists "Users can view own profile" on public.user_profiles;

alter table public.user_profiles enable row level security;

-- SELECT: authenticated discovery
create policy user_profiles_select_authenticated
on public.user_profiles
as permissive
for select
to authenticated
using (true);

-- INSERT/UPDATE/DELETE: own row only
create policy user_profiles_insert_own
on public.user_profiles
as permissive
for insert
to authenticated
with check (auth.uid() = user_id);

create policy user_profiles_update_own
on public.user_profiles
as permissive
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy user_profiles_delete_own
on public.user_profiles
as permissive
for delete
to authenticated
using (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- 3) View: multiple choice quiz accuracy only
-- -----------------------------------------------------------------------------
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