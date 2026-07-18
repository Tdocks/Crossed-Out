-- 0016_devotionals.sql — G19 devotional system + feedback loop
-- Adds: (1) a built-in devotional catalog, (2) user "independent study"
-- devotionals, (3) a helpful/not-helpful feedback signal on BOTH, plus a
-- feedback upsert RPC and a deterministic "today's devotional" picker.
-- Foundation for personalized devotional suggestions (the preference loop
-- is a follow-up slice). See GAP_ANALYSIS_AND_ROADMAP.md section 7 (G19).

create extension if not exists pgcrypto;

-- 1) Built-in devotional catalog (admin-authored; readable by all signed-in users)
create table if not exists public.devotionals (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  verse_ref     text not null,                 -- display, e.g. "John 15:5"
  book          text,
  chapter       int,
  verse         int,
  verse_end     int,
  body          text not null,                 -- the devotional reflection
  prompt        text,                          -- optional reflection question
  style         text not null default 'reflective',  -- reflective|study|encouragement|practical|prayer
  focus_slug    text,                          -- optional tie to focus_areas taxonomy
  tags          text[] not null default '{}',
  is_published  boolean not null default true,
  published_at  timestamptz not null default now(),
  created_at    timestamptz not null default now()
);
alter table public.devotionals enable row level security;
-- Any authenticated user may read published devotionals; no user writes.
create policy "read published devotionals" on public.devotionals
  for select using (is_published);
create index if not exists devotionals_focus_idx on public.devotionals (focus_slug) where is_published;
create index if not exists devotionals_style_idx on public.devotionals (style) where is_published;

-- 2) User "independent study" devotionals (own rows only)
create table if not exists public.user_devotionals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text,
  verse_ref   text not null,                   -- what they studied (freeform or picked)
  book        text,
  chapter     int,
  verse       int,
  verse_end   int,
  notes       text not null,
  studied_on  date not null default current_date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.user_devotionals enable row level security;
create policy "own user_devotionals" on public.user_devotionals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists user_devotionals_user_idx
  on public.user_devotionals (user_id, created_at desc);

-- 3) Helpful/not-helpful feedback on either a built-in or an independent devotional
create table if not exists public.devotional_feedback (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade,
  source             text not null check (source in ('builtin','independent')),
  devotional_id      uuid references public.devotionals(id) on delete cascade,
  user_devotional_id uuid references public.user_devotionals(id) on delete cascade,
  helpful            boolean not null,
  reason             text,
  created_at         timestamptz not null default now(),
  constraint devotional_feedback_target_ck check (
    (source = 'builtin'     and devotional_id is not null and user_devotional_id is null) or
    (source = 'independent' and user_devotional_id is not null and devotional_id is null)
  )
);
alter table public.devotional_feedback enable row level security;
create policy "own devotional_feedback" on public.devotional_feedback
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- one feedback row per user per item (upserted via submit_devotional_feedback)
create unique index if not exists devotional_feedback_builtin_uq
  on public.devotional_feedback (user_id, devotional_id) where devotional_id is not null;
create unique index if not exists devotional_feedback_independent_uq
  on public.devotional_feedback (user_id, user_devotional_id) where user_devotional_id is not null;

-- Upsert the current user's feedback for one devotional (built-in or independent).
create or replace function public.submit_devotional_feedback(
  p_source text,
  p_devotional_id uuid,
  p_user_devotional_id uuid,
  p_helpful boolean,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if p_source = 'builtin' then
    insert into public.devotional_feedback (user_id, source, devotional_id, helpful, reason)
    values (v_uid, 'builtin', p_devotional_id, p_helpful, p_reason)
    on conflict (user_id, devotional_id) where devotional_id is not null
    do update set helpful = excluded.helpful, reason = excluded.reason, created_at = now();
  elsif p_source = 'independent' then
    insert into public.devotional_feedback (user_id, source, user_devotional_id, helpful, reason)
    values (v_uid, 'independent', p_user_devotional_id, p_helpful, p_reason)
    on conflict (user_id, user_devotional_id) where user_devotional_id is not null
    do update set helpful = excluded.helpful, reason = excluded.reason, created_at = now();
  else
    raise exception 'invalid source: %', p_source;
  end if;
end;
$$;
grant execute on function public.submit_devotional_feedback(text, uuid, uuid, boolean, text) to authenticated;

-- One built-in devotional for "today": deterministic per calendar day so it
-- stays stable through the day. (Focus/preference-aware selection lands with
-- the preference-loop slice.)
create or replace function public.today_devotional()
returns setof public.devotionals
language sql
stable
security definer
set search_path = public
as $$
  select d.* from public.devotionals d
  where d.is_published
  order by md5(d.id::text || current_date::text)
  limit 1;
$$;
grant execute on function public.today_devotional() to authenticated;

-- Seed a few starter built-in devotionals (public-domain BSB verses) so the
-- built-in surface renders real content. Replace/expand with the authored
-- catalog later. Idempotent: guarded on title.
insert into public.devotionals (title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
select * from (values
  ('Abide, and bear fruit',
   'John 15:5', 'John', 15, 5, null,
   'Jesus calls Himself the vine and us the branches. Fruit is not something we manufacture by striving harder — it grows out of staying connected to Him. Before you plan or produce today, simply remain: bring Him your morning, your work, your worry. Apart from Him we can do nothing; joined to Him, our small ordinary life bears fruit that lasts.',
   'Where are you tempted to strive on your own strength today, and what would it look like to abide instead?',
   'reflective', 'rest_peace', array['abiding','fruit','dependence']),
  ('Anxious about nothing',
   'Philippians 4:6', 'Philippians', 4, 6, 7,
   'Paul does not say ''feel nothing.'' He says take the thing that presses on you and turn it, item by item, into a request laid before God — with thanksgiving mixed in. The promise is not that the problem vanishes, but that a peace beyond understanding stands guard over your heart and mind, like a sentry at a gate. Name the worry. Hand it over. Let the guard take his post.',
   'What is the one worry you can hand to God right now, in a single honest sentence?',
   'encouragement', 'anxiety', array['peace','prayer','worry']),
  ('Trust, and He makes the path straight',
   'Proverbs 3:5', 'Proverbs', 3, 5, 6,
   'Leaning on your own understanding feels responsible — it is how we stay in control. But Scripture invites a deeper trust: to acknowledge God in the actual decisions of the day, not just in theory. Straight paths are promised not to those who figure it all out, but to those who keep turning back to Him. You do not have to see the whole road to take the next faithful step.',
   'In what decision are you leaning on your own understanding, and how could you acknowledge God in it today?',
   'practical', 'purpose', array['trust','guidance','decisions'])
) as v(title, verse_ref, book, chapter, verse, verse_end, body, prompt, style, focus_slug, tags)
where not exists (select 1 from public.devotionals d where d.title = v.title);
