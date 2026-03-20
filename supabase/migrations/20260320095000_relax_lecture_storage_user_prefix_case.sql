-- Make lecture storage RLS robust to UUID letter case in object prefix.

drop policy if exists lectures_select_own on storage.objects;
create policy lectures_select_own
on storage.objects
for select
to authenticated
using (
  bucket_id = 'lectures'
  and lower(split_part(name, '/', 1)) = auth.uid()::text
);

drop policy if exists lectures_insert_own on storage.objects;
create policy lectures_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'lectures'
  and lower(split_part(name, '/', 1)) = auth.uid()::text
);

drop policy if exists lectures_update_own on storage.objects;
create policy lectures_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'lectures'
  and lower(split_part(name, '/', 1)) = auth.uid()::text
)
with check (
  bucket_id = 'lectures'
  and lower(split_part(name, '/', 1)) = auth.uid()::text
);

drop policy if exists lectures_delete_own on storage.objects;
create policy lectures_delete_own
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'lectures'
  and lower(split_part(name, '/', 1)) = auth.uid()::text
);
