-- Thin text-in wrapper around public.match_verses (migration 0012) so the
-- semantic_search edge function can pass a pgvector literal string
-- ("[v1,v2,...]") without fighting supabase-js's client-side marshaling of
-- the `vector` type. Additive only — match_verses itself is untouched.

create or replace function public.match_verses_text(
  p_embedding text,
  p_translation text default 'BSB',
  p_limit int default 20
)
returns table (
  book text,
  chapter int,
  verse int,
  text text,
  similarity real
)
language sql
stable
security definer
set search_path = public
as $$
  select * from public.match_verses(p_embedding::vector, p_translation, p_limit)
$$;

revoke all on function public.match_verses_text(text, text, int) from public;
revoke all on function public.match_verses_text(text, text, int) from anon;
grant execute on function public.match_verses_text(text, text, int) to authenticated;
