-- Full-text Bible storage (BSB, WEB, KJV — all public domain)
create table if not exists public.bible_verses (
  id bigint generated always as identity primary key,
  translation text not null,
  book text not null,
  chapter int not null,
  verse int not null,
  text text not null,
  unique (translation, book, chapter, verse)
);
create index if not exists idx_bible_lookup on public.bible_verses (translation, book, chapter);
alter table public.bible_verses enable row level security;
create policy "read bible" on public.bible_verses for select using (true);

-- Data loaded via \copy from normalized TSV (getbible.net KJV/WEB + bereanbible.com BSB).

-- Rebuild tagged passages in BSB (default app translation)
update public.passages p
set text = sub.txt, translation = 'BSB'
from (
  select p2.id, string_agg(bv.text, ' ' order by bv.verse) as txt
  from public.passages p2
  join public.bible_verses bv
    on bv.translation = 'BSB'
   and bv.book = p2.book
   and bv.chapter = p2.chapter
   and bv.verse between p2.verse_start and coalesce(p2.verse_end, p2.verse_start)
  group by p2.id
) sub
where sub.id = p.id;
