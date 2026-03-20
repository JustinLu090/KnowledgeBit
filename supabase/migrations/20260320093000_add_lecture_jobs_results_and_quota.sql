-- Async lecture processing scaffolding + per-user daily quota.

create table if not exists public.lecture_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  status text not null default 'pending' check (status in ('pending', 'processing', 'done', 'failed')),
  language text,
  difficulty text,
  max_flashcards integer,
  max_multiple_choice integer,
  max_fill_in_blank integer,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);

create table if not exists public.lecture_results (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references public.lecture_jobs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  summary text not null,
  result_json jsonb not null,
  model text not null default 'gemini-1.5-flash',
  created_at timestamptz not null default now()
);

create table if not exists public.user_ai_daily_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default current_date,
  lecture_requests integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, usage_date)
);

alter table public.lecture_jobs enable row level security;
alter table public.lecture_results enable row level security;
alter table public.user_ai_daily_usage enable row level security;

drop policy if exists lecture_jobs_owner_all on public.lecture_jobs;
create policy lecture_jobs_owner_all
on public.lecture_jobs
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists lecture_results_owner_all on public.lecture_results;
create policy lecture_results_owner_all
on public.lecture_results
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists user_ai_daily_usage_owner_select on public.user_ai_daily_usage;
create policy user_ai_daily_usage_owner_select
on public.user_ai_daily_usage
for select
to authenticated
using (auth.uid() = user_id);

create or replace function public.consume_lecture_quota(p_daily_limit integer default 20)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_count integer;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  insert into public.user_ai_daily_usage (user_id, usage_date, lecture_requests, updated_at)
  values (v_user_id, current_date, 0, now())
  on conflict (user_id, usage_date) do nothing;

  update public.user_ai_daily_usage
  set lecture_requests = lecture_requests + 1,
      updated_at = now()
  where user_id = v_user_id
    and usage_date = current_date
    and lecture_requests < greatest(1, p_daily_limit)
  returning lecture_requests into v_count;

  return v_count is not null;
end;
$$;

revoke all on function public.consume_lecture_quota(integer) from public;
grant execute on function public.consume_lecture_quota(integer) to authenticated;

create or replace function public.touch_lecture_jobs_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tr_touch_lecture_jobs_updated_at on public.lecture_jobs;
create trigger tr_touch_lecture_jobs_updated_at
before update on public.lecture_jobs
for each row
execute function public.touch_lecture_jobs_updated_at();
