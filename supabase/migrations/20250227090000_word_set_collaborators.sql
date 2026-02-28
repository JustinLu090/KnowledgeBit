-- word_set_collaborators.sql
-- 單字集共編成員：哪些使用者可以共同編輯某個 word_set

create table if not exists public.word_set_collaborators (
  word_set_id uuid not null references public.word_sets (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'editor',
  created_at timestamptz not null default now(),
  primary key (word_set_id, user_id)
);

create index if not exists idx_word_set_collab_user
  on public.word_set_collaborators (user_id);

alter table public.word_set_collaborators enable row level security;

-- 允許：自己是該 word_set 的擁有者，或自己就是 collaborator，本人可以看到
drop policy if exists "word_set_collab_select" on public.word_set_collaborators;
create policy "word_set_collab_select"
  on public.word_set_collaborators
  for select
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.word_sets ws
      where ws.id = word_set_id
        and ws.user_id = auth.uid()
    )
  );

-- 只有單字集擁有者可以新增 / 修改 / 刪除共編成員
drop policy if exists "word_set_collab_modify_owner_only" on public.word_set_collaborators;
create policy "word_set_collab_modify_owner_only"
  on public.word_set_collaborators
  for all
  using (
    exists (
      select 1
      from public.word_sets ws
      where ws.id = word_set_id
        and ws.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.word_sets ws
      where ws.id = word_set_id
        and ws.user_id = auth.uid()
    )
  );

