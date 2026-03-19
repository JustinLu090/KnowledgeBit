-- When a word set is deleted, delete its cards as well.
-- This ensures creator deletion fully removes the shared content for collaborators too.

alter table public.cards
drop constraint if exists cards_word_set_id_fkey;

alter table public.cards
add constraint cards_word_set_id_fkey
foreign key (word_set_id)
references public.word_sets(id)
on delete cascade;
