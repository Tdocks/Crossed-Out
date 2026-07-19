-- 0031: Cross the Bridge — the full outreach package, recipient responses,
-- and the shared-journey content model (MASTER_PLAN §11).
--
-- Flow: sender composes a package in the app → gets a link with a random
-- unguessable token → recipient opens portal/bridge.html?bridge=<token>
-- (no install, no account) → reads the letter + real Scripture (context
-- joined live from bible_verses, never hand-typed) → responds through
-- anon-callable, token-keyed SECURITY DEFINER RPCs → the sender sees
-- responses in the app ("Your Bridges").
--
-- Privacy / security:
--   * Tokens are 16 random bytes hex (2^128) — retrieval is by exact token
--     only; nothing is enumerable, and unknown tokens return {found:false}.
--   * get_bridge exposes ONLY package content + the sender's first name —
--     never user ids, emails, or anything else.
--   * The recipient is NEVER captured into any marketing path: no email
--     collection, no signup requirement, no tracking fields. Responses
--     store only what they type.
--   * bridge_shares stays sender-own-rows (0007 policy). bridge_responses
--     are readable ONLY by the bridge's sender; inserts happen ONLY via
--     the validated respond_bridge RPC (response-count capped).

-- ============================================================
-- 1. Extend bridge_shares into the full package
-- ============================================================
alter table public.bridge_shares
  add column if not exists token text not null default encode(gen_random_bytes(16), 'hex'),
  add column if not exists sender_name text not null default '',
  add column if not exists message text not null default '',
  add column if not exists meaning text not null default '',
  add column if not exists invitation text,
  add column if not exists response_option text not null default 'any'
    check (response_option in ('any','reply','prayer','journey')),
  add column if not exists verse_book text,
  add column if not exists verse_chapter int,
  add column if not exists verse_start int,
  add column if not exists verse_end int,
  add column if not exists status text not null default 'sent'
    check (status in ('sent','opened','responded','declined')),
  add column if not exists opened_at timestamptz;

create unique index if not exists bridge_shares_token_uq
  on public.bridge_shares (token);

-- ============================================================
-- 2. Recipient responses
-- ============================================================
create table if not exists public.bridge_responses (
  id         uuid primary key default gen_random_uuid(),
  bridge_id  uuid not null references public.bridge_shares(id) on delete cascade,
  kind       text not null check (kind in
               ('reply','prayer_request','decline','journey_started','journey_day')),
  message    text check (char_length(message) <= 2000),
  day        int check (day between 1 and 31),
  created_at timestamptz not null default now()
);

create index if not exists bridge_responses_bridge_idx
  on public.bridge_responses (bridge_id, created_at desc);

alter table public.bridge_responses enable row level security;

drop policy if exists "sender reads bridge responses" on public.bridge_responses;
create policy "sender reads bridge responses" on public.bridge_responses
  for select to authenticated
  using (exists (
    select 1 from public.bridge_shares b
    where b.id = bridge_responses.bridge_id and b.user_id = auth.uid()
  ));

revoke all on table public.bridge_responses from anon;
grant select on table public.bridge_responses to authenticated;
-- (no client inserts — respond_bridge only)

-- ============================================================
-- 3. Journeys content model (+ Seven Days of Hope)
-- ============================================================
create table if not exists public.journeys (
  id         uuid primary key default gen_random_uuid(),
  slug       text unique not null,
  title      text not null,
  subtitle   text,
  created_at timestamptz not null default now()
);

create table if not exists public.journey_days (
  journey_id  uuid not null references public.journeys(id) on delete cascade,
  day         int not null check (day between 1 and 31),
  title       text not null,
  -- Verse text is JOINED LIVE from bible_verses (BSB) by get_journey —
  -- never hand-typed, keeping the no-hallucinated-Scripture promise.
  book        text not null,
  chapter     int not null,
  verse_start int not null,
  verse_end   int,
  body        text not null,
  primary key (journey_id, day)
);

alter table public.journeys enable row level security;
alter table public.journey_days enable row level security;

drop policy if exists "read journeys" on public.journeys;
create policy "read journeys" on public.journeys
  for select to authenticated using (true);
drop policy if exists "read journey_days" on public.journey_days;
create policy "read journey_days" on public.journey_days
  for select to authenticated using (true);

revoke all on table public.journeys from anon;
revoke all on table public.journey_days from anon;
grant select on table public.journeys to authenticated;
grant select on table public.journey_days to authenticated;

-- ============================================================
-- 4. Anon-callable RPCs (SECURITY DEFINER, token-keyed)
-- ============================================================

-- The recipient's read: full package + surrounding chapter (BSB) for
-- "see it in context". First open flips status sent→opened.
create or replace function public.get_bridge(p_token text)
returns json
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v public.bridge_shares%rowtype;
  v_context json;
begin
  if p_token is null or char_length(p_token) < 16 then
    return json_build_object('found', false);
  end if;

  select * into v from public.bridge_shares where token = p_token;
  if v.id is null then
    return json_build_object('found', false);
  end if;

  if v.status = 'sent' then
    update public.bridge_shares
       set status = 'opened', opened_at = now()
     where id = v.id;
  end if;

  if v.verse_book is not null and v.verse_chapter is not null then
    select json_agg(json_build_object('verse', bv.verse, 'text', bv.text)
                    order by bv.verse)
      into v_context
      from public.bible_verses bv
     where bv.translation = 'BSB'
       and bv.book = v.verse_book
       and bv.chapter = v.verse_chapter;
  end if;

  return json_build_object(
    'found', true,
    'sender_name', v.sender_name,
    'to_name', v.to_name,
    'why_text', v.why_text,
    'message', v.message,
    'verse_ref', v.verse_ref,
    'verse_text', v.verse_text,
    'verse_book', v.verse_book,
    'verse_chapter', v.verse_chapter,
    'verse_start', v.verse_start,
    'verse_end', v.verse_end,
    'meaning', v.meaning,
    'invitation', v.invitation,
    'response_option', v.response_option,
    'context', coalesce(v_context, '[]'::json)
  );
end;
$$;

revoke all on function public.get_bridge(text) from public;
grant execute on function public.get_bridge(text) to anon, authenticated;

-- The recipient's write path. Validated + capped; stores only what they
-- typed. Never creates an account, never captures contact info.
create or replace function public.respond_bridge(
  p_token text,
  p_kind text,
  p_message text default null,
  p_day int default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_count int;
begin
  if p_kind not in ('reply','prayer_request','decline','journey_started','journey_day') then
    raise exception 'invalid kind';
  end if;

  select id into v_id from public.bridge_shares where token = p_token;
  if v_id is null then
    raise exception 'not found';
  end if;

  select count(*) into v_count from public.bridge_responses where bridge_id = v_id;
  if v_count >= 100 then
    raise exception 'too many responses';
  end if;

  insert into public.bridge_responses (bridge_id, kind, message, day)
  values (v_id, p_kind,
          nullif(trim(left(coalesce(p_message, ''), 2000)), ''),
          case when p_kind in ('journey_day') then p_day else null end);

  if p_kind in ('reply','prayer_request') then
    update public.bridge_shares set status = 'responded' where id = v_id;
  elsif p_kind = 'decline' then
    update public.bridge_shares set status = 'declined'
     where id = v_id and status <> 'responded';
  end if;
end;
$$;

revoke all on function public.respond_bridge(text, text, text, int) from public;
grant execute on function public.respond_bridge(text, text, text, int) to anon, authenticated;

-- Journey content for the web page, verse text joined live from BSB.
create or replace function public.get_journey(p_slug text)
returns json
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select json_build_object(
      'found', true,
      'title', j.title,
      'subtitle', j.subtitle,
      'days', (
        select json_agg(json_build_object(
          'day', d.day,
          'title', d.title,
          'ref', d.book || ' ' || d.chapter || ':' || d.verse_start ||
                 case when d.verse_end is not null and d.verse_end > d.verse_start
                      then '-' || d.verse_end else '' end,
          'text', (
            select string_agg(bv.text, ' ' order by bv.verse)
            from public.bible_verses bv
            where bv.translation = 'BSB'
              and bv.book = d.book
              and bv.chapter = d.chapter
              and bv.verse between d.verse_start and coalesce(d.verse_end, d.verse_start)
          ),
          'body', d.body
        ) order by d.day)
        from public.journey_days d
        where d.journey_id = j.id
      )
    )
    from public.journeys j
    where j.slug = p_slug),
    json_build_object('found', false)
  );
$$;

revoke all on function public.get_journey(text) from public;
grant execute on function public.get_journey(text) to anon, authenticated;

-- ============================================================
-- 5. Seed: Seven Days of Hope (idempotent)
-- ============================================================
insert into public.journeys (slug, title, subtitle)
select 'seven-days-of-hope', 'Seven Days of Hope',
       'Seven short, honest readings for a hard season. No pressure, no signup — just a few minutes a day.'
where not exists (select 1 from public.journeys where slug = 'seven-days-of-hope');

with j as (select id from public.journeys where slug = 'seven-days-of-hope')
insert into public.journey_days (journey_id, day, title, book, chapter, verse_start, verse_end, body)
select j.id, v.day, v.title, v.book, v.chapter, v.verse_start, v.verse_end, v.body
from j, (values
  (1, 'You are seen', 'Psalms', 34, 18, null,
   'Whatever brought you here — a hard week, a kind friend, plain curiosity — start with this: the oldest prayers in the Bible say God stays closest to people who are hurting. Not the polished. Not the certain. The brokenhearted. You don''t have to believe everything today, or anything yet. Just consider the possibility that you are not invisible, and that what''s heavy on you right now is seen. That''s the whole first day.'),
  (2, 'Rest for the weary', 'Matthew', 11, 28, 30,
   'This is one of the only places Jesus describes His own heart: gentle and humble. His invitation isn''t "clean yourself up" — it''s "come, you who are worn out." If religion has ever felt like one more weight to carry, notice that His offer is the opposite: rest. Today, just sit with the idea that faith might be less like a demand and more like setting something heavy down.'),
  (3, 'A peace that guards', 'Philippians', 4, 6, 7,
   'This was written from a prison cell, not a comfortable life. The invitation is practical: take what you''re anxious about — item by item — and say it out loud to God, even if you''re not sure anyone is listening yet. People who try this often describe the same thing: not answers at first, but a strange steadiness, like something standing guard. Try it once today with one worry. Just one honest sentence.'),
  (4, 'Do not fear', 'Isaiah', 41, 10, null,
   'Count the promises in this one verse: I am with you. I am your God. I will strengthen you. I will help you. I will uphold you. Fear usually shrinks when it stops being faced alone — that''s true with people, and these words claim it''s true with God. Whatever you''re dreading this week, try walking into it as if you might not be walking in by yourself.'),
  (5, 'Loved first', 'Romans', 5, 8, null,
   'Here''s the part of the Christian story that surprises people most: it doesn''t say God loves you because you got better. It says love came first — at your worst, before any improvement, before any belief. Whatever you assume God thinks of you, test it against this sentence. If it doesn''t match, one of them is wrong — and it may not be this one.'),
  (6, 'New every morning', 'Lamentations', 3, 22, 23,
   'These lines sit in the middle of the saddest book in the Bible, written in the ruins of a burned city. That''s what makes them trustworthy: this isn''t optimism from someone who never suffered. Mercies "new every morning" means you only ever need enough for today — not the month, not the year. Tomorrow''s portion arrives tomorrow. For today, today''s is enough.'),
  (7, 'Come and see', 'John', 1, 38, 39,
   'When two curious people started following Jesus at a distance, He turned and asked what they were looking for. Their answer was hesitant — so was His reply: "Come, and you will see." No lecture. No conditions. An open door. That''s where this week ends: not with a demand to decide anything, but with an invitation to keep looking — a church near you, a service online, or the friend who sent you this. They''d love to hear from you. No pressure. Come and see.')
) as v(day, title, book, chapter, verse_start, verse_end, body)
on conflict (journey_id, day) do nothing;
