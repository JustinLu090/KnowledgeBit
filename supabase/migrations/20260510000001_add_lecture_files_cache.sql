-- Cache OpenAI file_id per (user_id, storage_path) so repeated lecture
-- generations (e.g., task=summary then task=quiz, or user retries) reuse
-- the same uploaded PDF instead of re-uploading and re-billing storage.

create table if not exists public.lecture_files (
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  openai_file_id text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  primary key (user_id, storage_path)
);

create index if not exists lecture_files_expires_idx
  on public.lecture_files (expires_at);

alter table public.lecture_files enable row level security;

drop policy if exists lecture_files_owner_all on public.lecture_files;
create policy lecture_files_owner_all
on public.lecture_files
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
