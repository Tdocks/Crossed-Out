-- 0025: "One small step" — deterministic practical actions for the Today loop.
--
-- The Today screen previously ended at understanding (verse + reason). This
-- adds the ACT step: a small, concrete, pastorally-written practice matched
-- to the user's focus areas and today's mood, picked DETERMINISTICALLY
-- (relevance tiers + a per-user-per-day stable shuffle). Zero AI, zero
-- marginal cost, offline-cacheable.
--
-- Also extends daily_completions.kind with 'action' so crossing the step
-- off lands in the existing streak/rhythm machinery (0005).

-- ============================================================
-- 1. Allow the new completion kind
-- ============================================================
alter table public.daily_completions
  drop constraint if exists daily_completions_kind_check;
alter table public.daily_completions
  add constraint daily_completions_kind_check
  check (kind in ('scripture','prayer','reflection','community',
                  'encouragement','devotional','action'));

-- ============================================================
-- 2. Reference table of practices
-- ============================================================
create table if not exists public.practice_actions (
  id uuid primary key default gen_random_uuid(),
  -- null = universal (fits any focus)
  focus_slug text references public.focus_areas(slug) on delete cascade,
  -- null = any mood; values match 0009's emotion taxonomy = the app's Mood
  emotion text check (emotion in (
    'peaceful','anxious','discouraged','motivated','angry','lonely',
    'confused','grateful','tempted','overwhelmed','hopeful','grieving'
  )),
  body text not null unique check (char_length(body) between 8 and 240),
  created_at timestamptz not null default now()
);

alter table public.practice_actions enable row level security;
drop policy if exists "read practice_actions" on public.practice_actions;
create policy "read practice_actions" on public.practice_actions
  for select to authenticated using (true);
revoke all on table public.practice_actions from anon;
grant select on table public.practice_actions to authenticated;

-- ============================================================
-- 3. Deterministic daily pick
-- ============================================================
-- Relevance first (focus match, then mood match), then a stable per-user
-- per-day shuffle inside the winning tier so the step rotates day to day
-- but never changes mid-day. Same-day stability comes from hashing
-- (action id + user + utc date) — no state table needed.
create or replace function public.today_practice_action(
  p_focus_slugs text[] default null,
  p_mood text default null
)
returns table (id uuid, body text, focus_slug text)
language sql
stable
security definer
set search_path = public
as $$
  select pa.id, pa.body, pa.focus_slug
  from public.practice_actions pa
  where auth.uid() is not null
  order by
    (pa.focus_slug is not null
      and p_focus_slugs is not null
      and array_length(p_focus_slugs, 1) is not null
      and pa.focus_slug = any(p_focus_slugs))::int desc,
    (pa.emotion is not null and p_mood is not null and pa.emotion = p_mood)::int desc,
    md5(pa.id::text || auth.uid()::text || ((now() at time zone 'utc')::date)::text)
  limit 1;
$$;

revoke all on function public.today_practice_action(text[], text) from public;
revoke all on function public.today_practice_action(text[], text) from anon;
grant execute on function public.today_practice_action(text[], text) to authenticated;

-- ============================================================
-- 4. Seed practices (idempotent via unique body + do nothing)
-- ============================================================

-- Universal (any focus). Mood-tagged rows win the tiebreak on matching days.
insert into public.practice_actions (focus_slug, emotion, body) values
  (null, null, 'Set a timer for three minutes, put your phone face down, and sit quietly with God. Just breathe and listen.'),
  (null, null, 'Text one person: "I thought of you today. How can I pray for you?"'),
  (null, null, 'Write today''s verse on a sticky note and put it where you''ll see it again tonight.'),
  (null, null, 'Before your next meal, pause and thank God for three specific things from today.'),
  (null, null, 'Read today''s verse out loud, slowly, twice — once for your head, once for your heart.'),
  (null, 'anxious', 'Name the one worry that''s loudest right now, say it to God out loud, and leave it with Him for the next hour.'),
  (null, 'grateful', 'Write down three specific gifts from this week and thank God for each one by name.'),
  (null, 'overwhelmed', 'Choose the single most important thing on your list. Ask God for strength for just that one — the rest can wait.'),
  (null, 'lonely', 'Reach out to one friend or family member today — even a two-line text counts.'),
  (null, 'discouraged', 'Write down one way God has carried you through before. Keep it where you can see it today.'),
  (null, 'grieving', 'Find a quiet spot and tell God one memory you''re thankful for. Tears are allowed.'),
  (null, 'angry', 'Before you respond to what stirred you up, wait one hour — and pray for that person first.')
on conflict (body) do nothing;

-- Focus-matched practices.
insert into public.practice_actions (focus_slug, emotion, body) values
  ('anxiety', 'anxious', 'Each time worry rises today, stop and pray one sentence: "Father, I hand this to You." Every single time.'),
  ('anxiety', null, 'Take a ten-minute walk without your phone and tell God honestly what''s making you anxious.'),
  ('purpose', null, 'Finish this sentence in writing: "The good work in front of me today is ___." Then do it as if for God.'),
  ('relationships', null, 'Send a short note of appreciation to someone you''ve been taking for granted.'),
  ('financial_wisdom', null, 'Write down every dollar you spend today. Tonight, thank God for what you have before you review the list.'),
  ('forgiveness', null, 'Pray one honest sentence for the person who hurt you — even just "God, help me want to forgive."'),
  ('grief', 'grieving', 'Say the name of who or what you lost out loud to God, and let Him hear exactly how you feel about it.'),
  ('discipline', null, 'Tonight, set out what tomorrow''s first faithful act needs — make it easier to begin than to skip.'),
  ('loneliness', 'lonely', 'Say yes to one invitation this week — or extend one yourself today.'),
  ('marriage', null, 'Do one small unasked act of service for your spouse today, and don''t point it out.'),
  ('parenting', null, 'Give each of your children sixty seconds of undivided attention today — eyes, ears, no phone.'),
  ('temptation', 'tempted', 'Tell one trusted person what you''re wrestling with. Temptation loses power in the light.'),
  ('career', null, 'Do today''s most tedious task with excellence, as work done for God rather than for a boss.'),
  ('confidence', null, 'Write down one thing God says is true about you, and read it before your next hard moment.'),
  ('understanding_god', null, 'Read one chapter of a Gospel today and note a single thing Jesus does that surprises you.'),
  ('returning_to_faith', null, 'Pray for one minute today. No pressure to get the words right — just come back.'),
  ('learning_to_pray', null, 'Try one honest sentence of prayer at morning, noon, and night today. Short is fine.'),
  ('depression_hope', 'discouraged', 'Step outside for ten minutes of daylight, and ask God for grace for the next hour — not the whole day.'),
  ('motivation', 'motivated', 'Do the very next small thing — five minutes, right now — and ask God to meet you in motion.'),
  ('addiction', 'tempted', 'Tell God the honest truth about today''s pull, and tell one safe person too.'),
  ('anger', 'angry', 'Write the angry message if you must — then delete it, and ask God what a peacemaker would do instead.'),
  ('leadership', null, 'Encourage one person you lead today — specifically, by name, for something real.'),
  ('new_to_christianity', null, 'Read John chapter 1 today. Mark one line you want to ask someone about.'),
  ('understanding_the_bible', null, 'Read today''s verse inside its full chapter to see what surrounds it.'),
  ('rest_peace', 'peaceful', 'Choose one hour tonight with no screens. Let it be quiet enough to hear yourself and God.'),
  ('rest_peace', 'overwhelmed', 'Cancel or postpone one nonessential thing today, and give that hour to rest without guilt.')
on conflict (body) do nothing;
