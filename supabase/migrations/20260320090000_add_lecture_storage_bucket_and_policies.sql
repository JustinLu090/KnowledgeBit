-- Storage bucket + RLS policies for lecture PDF uploads.
-- Users can only access files under their own folder: <auth.uid()>/...

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'lectures',
  'lectures',
  false,
  52428800, -- 50 MiB
  array['application/pdf']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists lectures_select_own on storage.objects;
create policy lectures_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'lectures'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists lectures_insert_own on storage.objects;
create policy lectures_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'lectures'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists lectures_update_own on storage.objects;
create policy lectures_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'lectures'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'lectures'
  and split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists lectures_delete_own on storage.objects;
create policy lectures_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'lectures'
  and split_part(name, '/', 1) = auth.uid()::text
);
