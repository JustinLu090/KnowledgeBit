-- Prevent duplicate card titles within the same word set.
-- Keep UUID `id` as the primary key; enforce uniqueness on normalized title per word_set_id.

do $$
declare
  duplicate_record record;
begin
  -- If the index already exists, skip the duplicate precheck and creation.
  if to_regclass('public.cards_word_set_normalized_title_unique_idx') is not null then
    return;
  end if;

  select
    word_set_id,
    lower(regexp_replace(btrim(title), '\s+', ' ', 'g')) as normalized_title,
    count(*) as duplicate_count
  into duplicate_record
  from public.cards
  where word_set_id is not null
  group by word_set_id, lower(regexp_replace(btrim(title), '\s+', ' ', 'g'))
  having count(*) > 1
  limit 1;

  if duplicate_record is not null then
    raise exception using
      message = format(
        'Cannot enforce unique card titles yet. Found duplicate titles in word_set_id=%s (normalized title="%s", count=%s). Please clean duplicates first, then rerun the migration.',
        duplicate_record.word_set_id,
        duplicate_record.normalized_title,
        duplicate_record.duplicate_count
      );
  end if;
end $$;

create unique index if not exists cards_word_set_normalized_title_unique_idx
on public.cards (
  word_set_id,
  lower(regexp_replace(btrim(title), '\s+', ' ', 'g'))
)
where word_set_id is not null;
