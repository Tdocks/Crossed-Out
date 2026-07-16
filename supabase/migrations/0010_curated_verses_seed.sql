-- 0010_curated_verses_seed.sql
-- Curated, pastorally-sound verse seed data for the personalization engine.
--
-- Book-name convention: book strings match EXACTLY the spelling used by the
-- `BibleBooks.all` canonical list in CrossedOut/Features/Bible/BibleReaderView.swift,
-- which is the same string SupabaseService.fetchChapter(...) passes via
-- .eq("book", value: book) against public.bible_verses. Examples: "Psalms" (plural,
-- not "Psalm"), "1 Peter" / "2 Corinthians" / "1 John" (numeral + space, not "I Peter"
-- or "1Peter"), "Revelation" (singular, not "Revelations"), "Song of Solomon".
-- These spellings also match the `passages.book` values already seeded in 0002_seed.sql.
--
-- curated_verses / curated_verse_tags schema is defined in 0009 (not redefined here).
--
-- Idempotent-friendly: each verse insert is guarded by a NOT EXISTS check on
-- (book, chapter, verse_start, verse_end), and each tag insert uses
-- ON CONFLICT (curated_verse_id, focus_slug) DO NOTHING, so re-running this file
-- after a successful run is a no-op rather than creating duplicates.

-- Philippians 4:6-7  ->  anxiety, learning_to_pray, rest_peace
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Philippians', 4, 6, 7,
    'Paul''s remedy for anxiety: prayer with thanksgiving in exchange for God''s peace that guards the heart and mind.',
    'For when you''re carrying {focus} and need to trade it for God''s peace through honest prayer.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Philippians' and cv.chapter = 4
      and cv.verse_start = 6 and cv.verse_end = 7
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anxiety', 'anxious', 'comfort', 'beginner', 25 from v
union all
select id, 'learning_to_pray', 'anxious', 'instruction', 'beginner', 18 from v
union all
select id, 'rest_peace', 'peaceful', 'comfort', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 6:34  ->  anxiety
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 6, 34, 0,
    'Jesus teaches His followers to release tomorrow''s worries and trust God one day at a time.',
    'For when {focus} keeps pulling your mind into a future only God can see.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 6
      and cv.verse_start = 34 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anxiety', 'anxious', 'comfort', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 Peter 5:7  ->  anxiety
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 Peter', 5, 7, 0,
    'An invitation to hand every worry to a God who genuinely cares for you.',
    'For when you''re carrying {focus} and need permission to let God carry it instead.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 Peter' and cv.chapter = 5
      and cv.verse_start = 7 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anxiety', 'anxious', 'comfort', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 94:19  ->  anxiety
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 94, 19, 0,
    'God''s consolation meets the psalmist in the middle of anxious, cluttered thoughts.',
    'For when {focus} multiplies in your mind and you need God''s quiet reassurance.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 94
      and cv.verse_start = 19 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anxiety', 'anxious', 'comfort', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- John 14:27  ->  anxiety, rest_peace
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'John', 14, 27, 0,
    'Jesus offers a peace that is different from the world''s, one that steadies a troubled heart.',
    'For when {focus} leaves you unsettled and you need a peace the world can''t give.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'John' and cv.chapter = 14
      and cv.verse_start = 27 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anxiety', 'anxious', 'comfort', 'beginner', 15 from v
union all
select id, 'rest_peace', 'peaceful', 'comfort', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Isaiah 41:10  ->  anxiety, loneliness, confidence
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Isaiah', 41, 10, 0,
    'God''s personal promise to strengthen and uphold those who fear or feel alone.',
    'For when {focus} makes you feel unsteady and you need to hear that God is with you.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Isaiah' and cv.chapter = 41
      and cv.verse_start = 10 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anxiety', 'anxious', 'comfort', 'beginner', 18 from v
union all
select id, 'loneliness', 'lonely', 'comfort', 'beginner', 20 from v
union all
select id, 'confidence', 'anxious', 'comfort', 'beginner', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Jeremiah 29:11  ->  purpose
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Jeremiah', 29, 11, 0,
    'God''s declared intention to give His people a future and a hope, even in a hard season.',
    'For when {focus} feels uncertain and you need to trust God''s plans are good.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Jeremiah' and cv.chapter = 29
      and cv.verse_start = 11 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'purpose', 'hopeful', 'comfort', 'beginner', 25 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Romans 8:28  ->  purpose
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Romans', 8, 28, 0,
    'God works all things, even hard things, together for good for those who love Him.',
    'For when {focus} feels chaotic and you need to trust God is weaving something good.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Romans' and cv.chapter = 8
      and cv.verse_start = 28 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'purpose', 'hopeful', 'comfort', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Ephesians 2:10  ->  purpose
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Ephesians', 2, 10, 0,
    'You are God''s handiwork, created for good works He prepared in advance.',
    'For when {focus} feels vague and you need to remember you were made on purpose, for a purpose.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Ephesians' and cv.chapter = 2
      and cv.verse_start = 10 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'purpose', 'motivated', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 19:21  ->  purpose
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 19, 21, 0,
    'Human plans are many, but it is the Lord''s purpose that ultimately prevails.',
    'For when {focus} has you making plans that need to be held loosely under God''s.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 19
      and cv.verse_start = 21 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'purpose', 'confused', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 138:8  ->  purpose
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 138, 8, 0,
    'Confidence that the Lord will fulfill His purpose for a life fully surrendered to Him.',
    'For when {focus} feels unfinished and you need assurance God isn''t done with you.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 138
      and cv.verse_start = 8 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'purpose', 'hopeful', 'comfort', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Philippians 1:6  ->  purpose
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Philippians', 1, 6, 0,
    'God who began a good work in you is faithful to complete it.',
    'For when {focus} makes you doubt your progress and you need to trust God isn''t finished.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Philippians' and cv.chapter = 1
      and cv.verse_start = 6 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'purpose', 'hopeful', 'comfort', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Esther 4:14  ->  purpose
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Esther', 4, 14, 0,
    'Mordecai''s challenge to Esther that she may have been positioned by God for this exact moment.',
    'For when {focus} makes you wonder if you''re in the right place at the right time.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Esther' and cv.chapter = 4
      and cv.verse_start = 14 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'purpose', 'motivated', 'challenge', 'mature', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 Corinthians 13:4-7  ->  relationships, marriage
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 Corinthians', 13, 4, 7,
    'Paul''s description of love in action: patient, kind, and enduring.',
    'For when {focus} needs the kind of love that keeps no record of wrongs.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 Corinthians' and cv.chapter = 13
      and cv.verse_start = 4 and cv.verse_end = 7
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'relationships', 'grateful', 'instruction', 'growing', 25 from v
union all
select id, 'marriage', 'grateful', 'instruction', 'growing', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Colossians 3:13  ->  relationships, forgiveness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Colossians', 3, 13, 0,
    'A call to bear with one another and forgive as generously as the Lord forgave you.',
    'For when {focus} calls for a forgiveness that mirrors the grace you''ve received.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Colossians' and cv.chapter = 3
      and cv.verse_start = 13 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'relationships', 'discouraged', 'instruction', 'growing', 18 from v
union all
select id, 'forgiveness', 'discouraged', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 27:17  ->  relationships
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 27, 17, 0,
    'Iron sharpens iron, a picture of how good relationships shape our character.',
    'For when {focus} would benefit from people who sharpen rather than dull you.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 27
      and cv.verse_start = 17 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'relationships', 'grateful', 'instruction', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Romans 12:10  ->  relationships
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Romans', 12, 10, 0,
    'A call to genuine affection and mutual honor within the family of believers.',
    'For when {focus} needs a posture of honoring others above yourself.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Romans' and cv.chapter = 12
      and cv.verse_start = 10 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'relationships', 'grateful', 'instruction', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Ephesians 4:32  ->  relationships, forgiveness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Ephesians', 4, 32, 0,
    'Kindness, compassion, and forgiveness modeled on how God forgave us in Christ.',
    'For when {focus} asks you to extend the same grace God has extended to you.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Ephesians' and cv.chapter = 4
      and cv.verse_start = 32 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'relationships', 'discouraged', 'instruction', 'beginner', 18 from v
union all
select id, 'forgiveness', 'discouraged', 'instruction', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- John 13:34-35  ->  relationships
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'John', 13, 34, 35,
    'Jesus'' new command to love one another as He has loved us.',
    'For when {focus} calls for a love that reflects Christ''s own love for you.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'John' and cv.chapter = 13
      and cv.verse_start = 34 and cv.verse_end = 35
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'relationships', 'grateful', 'instruction', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 3:9-10  ->  financial_wisdom
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 3, 9, 10,
    'Honoring God with the first and best of what you have, trusting Him with provision.',
    'For when {focus} tempts you to hold tightly instead of holding open hands.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 3
      and cv.verse_start = 9 and cv.verse_end = 10
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'financial_wisdom', 'motivated', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 6:33  ->  financial_wisdom
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 6, 33, 0,
    'Seek God''s kingdom first, and daily needs fall into their proper place.',
    'For when {focus} competes for first place and needs to be put back in order.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 6
      and cv.verse_start = 33 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'financial_wisdom', 'anxious', 'instruction', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Hebrews 13:5  ->  financial_wisdom, loneliness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Hebrews', 13, 5, 0,
    'A call to contentment rooted in God''s unbreakable promise to never leave or forsake you.',
    'For when {focus} tempts you to chase security in the wrong places.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Hebrews' and cv.chapter = 13
      and cv.verse_start = 5 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'financial_wisdom', 'anxious', 'comfort', 'beginner', 20 from v
union all
select id, 'loneliness', 'lonely', 'comfort', 'beginner', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Philippians 4:19  ->  financial_wisdom
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Philippians', 4, 19, 0,
    'God''s promise to meet every need according to His riches in glory.',
    'For when {focus} has you unsure how needs will be met and you need to trust God''s supply.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Philippians' and cv.chapter = 4
      and cv.verse_start = 19 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'financial_wisdom', 'anxious', 'comfort', 'beginner', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 22:7  ->  financial_wisdom
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 22, 7, 0,
    'A sober warning about the bondage that comes with debt.',
    'For when {focus} involves decisions about debt and financial freedom.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 22
      and cv.verse_start = 7 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'financial_wisdom', 'confused', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Luke 6:38  ->  financial_wisdom
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Luke', 6, 38, 0,
    'A generous, giving posture is met with God''s generous measure in return.',
    'For when {focus} raises the question of holding on versus giving generously.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Luke' and cv.chapter = 6
      and cv.verse_start = 38 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'financial_wisdom', 'grateful', 'instruction', 'growing', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 6:14-15  ->  forgiveness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 6, 14, 15,
    'Jesus ties our willingness to forgive others to receiving the Father''s forgiveness.',
    'For when {focus} feels hard to let go of and you need Jesus'' own words as motivation.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 6
      and cv.verse_start = 14 and cv.verse_end = 15
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'forgiveness', 'discouraged', 'challenge', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 John 1:9  ->  forgiveness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 John', 1, 9, 0,
    'God''s faithful promise to forgive and cleanse when we confess honestly.',
    'For when {focus} weighs on your conscience and you need the assurance of confession.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 John' and cv.chapter = 1
      and cv.verse_start = 9 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'forgiveness', 'hopeful', 'comfort', 'beginner', 25 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Luke 6:37  ->  forgiveness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Luke', 6, 37, 0,
    'Jesus links our judgment and forgiveness of others to what we receive ourselves.',
    'For when {focus} tempts you toward judgment instead of mercy.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Luke' and cv.chapter = 6
      and cv.verse_start = 37 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'forgiveness', 'discouraged', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 103:12  ->  forgiveness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 103, 12, 0,
    'A picture of how completely God removes our sin from us, as far as east from west.',
    'For when {focus} makes you doubt whether you''re really forgiven.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 103
      and cv.verse_start = 12 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'forgiveness', 'grateful', 'comfort', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 34:18  ->  grief, depression_hope
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 34, 18, 0,
    'The Lord draws especially near to those who are brokenhearted and crushed in spirit.',
    'For when {focus} leaves you brokenhearted and needing to know God is close.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 34
      and cv.verse_start = 18 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'grief', 'grieving', 'comfort', 'beginner', 25 from v
union all
select id, 'depression_hope', 'grieving', 'comfort', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 5:4  ->  grief
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 5, 4, 0,
    'A blessing pronounced over those who mourn: comfort is promised, not denied.',
    'For when {focus} brings tears and you need the promise that comfort is coming.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 5
      and cv.verse_start = 4 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'grief', 'grieving', 'comfort', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Revelation 21:4  ->  grief, depression_hope
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Revelation', 21, 4, 0,
    'A future vision where God wipes away every tear and death is no more.',
    'For when {focus} makes you long for the day when sorrow will finally end.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Revelation' and cv.chapter = 21
      and cv.verse_start = 4 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'grief', 'grieving', 'comfort', 'growing', 20 from v
union all
select id, 'depression_hope', 'grieving', 'comfort', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- John 11:25-26  ->  grief
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'John', 11, 25, 26,
    'Jesus reveals Himself as the resurrection and the life to a grieving Martha.',
    'For when {focus} confronts you with mortality and you need resurrection hope.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'John' and cv.chapter = 11
      and cv.verse_start = 25 and cv.verse_end = 26
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'grief', 'grieving', 'comfort', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 2 Corinthians 1:3-4  ->  grief
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '2 Corinthians', 1, 3, 4,
    'God comforts us in affliction so that we, in turn, can comfort others.',
    'For when {focus} feels isolating and you need the God of all comfort.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '2 Corinthians' and cv.chapter = 1
      and cv.verse_start = 3 and cv.verse_end = 4
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'grief', 'grieving', 'comfort', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 147:3  ->  grief
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 147, 3, 0,
    'The Lord heals the brokenhearted and binds up their wounds.',
    'For when {focus} has left wounds only God can truly heal.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 147
      and cv.verse_start = 3 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'grief', 'grieving', 'comfort', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 30:5  ->  grief
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 30, 5, 0,
    'Weeping may last through the night, but joy comes with the morning.',
    'For when {focus} feels like a long night and you need hope that morning is coming.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 30
      and cv.verse_start = 5 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'grief', 'grieving', 'comfort', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Hebrews 12:11  ->  discipline
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Hebrews', 12, 11, 0,
    'Discipline is painful in the moment but produces a harvest of righteousness later.',
    'For when {focus} feels painful now but is producing something good later.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Hebrews' and cv.chapter = 12
      and cv.verse_start = 11 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'discipline', 'discouraged', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 3:11-12  ->  discipline
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 3, 11, 12,
    'The Lord disciplines those He loves, as a father disciplines a child he delights in.',
    'For when {focus} feels like correction and you need to see it as love.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 3
      and cv.verse_start = 11 and cv.verse_end = 12
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'discipline', 'discouraged', 'instruction', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 2 Timothy 1:7  ->  discipline, confidence
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '2 Timothy', 1, 7, 0,
    'God has given a spirit not of fear, but of power, love, and self-discipline.',
    'For when {focus} tests your resolve and you need the Spirit''s power, not fear.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '2 Timothy' and cv.chapter = 1
      and cv.verse_start = 7 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'discipline', 'anxious', 'instruction', 'growing', 20 from v
union all
select id, 'confidence', 'anxious', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 12:1  ->  discipline
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 12, 1, 0,
    'Whoever loves discipline loves knowledge; correction is a gift, not an insult.',
    'For when {focus} requires you to welcome correction instead of resisting it.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 12
      and cv.verse_start = 1 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'discipline', 'confused', 'instruction', 'mature', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Galatians 6:9  ->  discipline, motivation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Galatians', 6, 9, 0,
    'A call to keep doing good without growing weary, because a harvest is coming.',
    'For when {focus} tempts you to quit right before the breakthrough.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Galatians' and cv.chapter = 6
      and cv.verse_start = 9 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'discipline', 'discouraged', 'instruction', 'growing', 18 from v
union all
select id, 'motivation', 'discouraged', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 Corinthians 9:24-27  ->  discipline
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 Corinthians', 9, 24, 27,
    'Paul compares the Christian life to an athlete''s disciplined training for a prize.',
    'For when {focus} calls for the kind of focused training a race requires.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 Corinthians' and cv.chapter = 9
      and cv.verse_start = 24 and cv.verse_end = 27
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'discipline', 'motivated', 'challenge', 'mature', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 25:28  ->  discipline
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 25, 28, 0,
    'A person without self-control is compared to a city with broken-down walls.',
    'For when {focus} leaves you feeling exposed and in need of God-given self-control.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 25
      and cv.verse_start = 28 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'discipline', 'overwhelmed', 'instruction', 'growing', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Deuteronomy 31:6  ->  loneliness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Deuteronomy', 31, 6, 0,
    'Moses'' charge to be strong and courageous because God goes with you and will never leave you.',
    'For when {focus} makes you feel abandoned and you need the promise God won''t leave.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Deuteronomy' and cv.chapter = 31
      and cv.verse_start = 6 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'loneliness', 'lonely', 'comfort', 'beginner', 25 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 68:6  ->  loneliness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 68, 6, 0,
    'God sets the lonely in families and leads the isolated into community.',
    'For when {focus} has you feeling isolated and needing to be placed among people.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 68
      and cv.verse_start = 6 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'loneliness', 'lonely', 'comfort', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 28:20  ->  loneliness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 28, 20, 0,
    'Jesus'' final promise to His followers: I am with you always, to the very end.',
    'For when {focus} makes the world feel empty and you need Jesus'' constant presence.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 28
      and cv.verse_start = 20 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'loneliness', 'lonely', 'comfort', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 25:16-18  ->  loneliness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 25, 16, 18,
    'An honest prayer asking God to turn toward someone who feels lonely and afflicted.',
    'For when {focus} leaves you feeling unseen and you need God to turn toward you.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 25
      and cv.verse_start = 16 and cv.verse_end = 18
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'loneliness', 'lonely', 'comfort', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 27:10  ->  loneliness
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 27, 10, 0,
    'Even if closest family relationships fail, the Lord promises to receive you.',
    'For when {focus} touches your closest relationships and you need God''s unfailing welcome.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 27
      and cv.verse_start = 10 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'loneliness', 'lonely', 'comfort', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Genesis 2:24  ->  marriage
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Genesis', 2, 24, 0,
    'God''s original design for marriage: leaving, cleaving, and becoming one flesh.',
    'For when {focus} needs to be grounded in God''s original design for covenant union.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Genesis' and cv.chapter = 2
      and cv.verse_start = 24 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'marriage', 'grateful', 'instruction', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Ephesians 5:25  ->  marriage
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Ephesians', 5, 25, 0,
    'Husbands are called to love their wives with the same sacrificial love Christ showed the church.',
    'For when {focus} calls for a sacrificial, Christlike kind of love.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Ephesians' and cv.chapter = 5
      and cv.verse_start = 25 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'marriage', 'grateful', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Ecclesiastes 4:9-12  ->  marriage
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Ecclesiastes', 4, 9, 12,
    'Two are better than one, a picture of the strength found in a shared life.',
    'For when {focus} reminds you a shared life is stronger than one lived alone.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Ecclesiastes' and cv.chapter = 4
      and cv.verse_start = 9 and cv.verse_end = 12
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'marriage', 'grateful', 'instruction', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 31:10-12  ->  marriage
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 31, 10, 12,
    'A tribute to a spouse of noble character, trustworthy and good all her days.',
    'For when {focus} calls you to notice and honor character over convenience.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 31
      and cv.verse_start = 10 and cv.verse_end = 12
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'marriage', 'grateful', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Mark 10:9  ->  marriage
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Mark', 10, 9, 0,
    'What God has joined together, let no one separate: the sanctity of the marriage bond.',
    'For when {focus} needs the reminder that this covenant was joined by God.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Mark' and cv.chapter = 10
      and cv.verse_start = 9 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'marriage', 'grateful', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 18:22  ->  marriage
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 18, 22, 0,
    'Finding a spouse is described as finding a good thing and receiving favor from the Lord.',
    'For when {focus} calls for gratitude for the gift of a spouse.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 18
      and cv.verse_start = 22 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'marriage', 'grateful', 'comfort', 'beginner', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 22:6  ->  parenting
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 22, 6, 0,
    'Train up a child in the way they should go, trusting the lasting shape it forms.',
    'For when {focus} feels like planting seeds you won''t see fully grown for years.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 22
      and cv.verse_start = 6 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'parenting', 'motivated', 'instruction', 'growing', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Ephesians 6:4  ->  parenting
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Ephesians', 6, 4, 0,
    'Fathers are called to raise children with instruction that reflects the Lord''s own correction, not provocation.',
    'For when {focus} requires correction that builds up instead of tearing down.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Ephesians' and cv.chapter = 6
      and cv.verse_start = 4 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'parenting', 'confused', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Deuteronomy 6:6-7  ->  parenting
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Deuteronomy', 6, 6, 7,
    'A call to weave God''s commands into the everyday rhythms of family life.',
    'For when {focus} looks like ordinary conversations that carry eternal weight.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Deuteronomy' and cv.chapter = 6
      and cv.verse_start = 6 and cv.verse_end = 7
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'parenting', 'motivated', 'instruction', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 127:3  ->  parenting
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 127, 3, 0,
    'Children are described as a heritage and reward from the Lord.',
    'For when {focus} needs the reminder that children are a gift, not a burden.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 127
      and cv.verse_start = 3 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'parenting', 'grateful', 'comfort', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 29:17  ->  parenting
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 29, 17, 0,
    'Disciplining a child is connected to the peace and delight they will one day bring.',
    'For when {focus} feels thankless now but promises peace later.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 29
      and cv.verse_start = 17 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'parenting', 'discouraged', 'instruction', 'mature', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 3 John 1:4  ->  parenting
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '3 John', 1, 4, 0,
    'No greater joy than hearing your children are walking faithfully in the truth.',
    'For when {focus} centers on hoping and praying for your children''s faith.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '3 John' and cv.chapter = 1
      and cv.verse_start = 4 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'parenting', 'grateful', 'comfort', 'beginner', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 78:4  ->  parenting
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 78, 4, 0,
    'A charge to tell the next generation about the Lord''s praiseworthy deeds.',
    'For when {focus} involves passing your faith on to the next generation.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 78
      and cv.verse_start = 4 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'parenting', 'hopeful', 'instruction', 'growing', 10 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 Corinthians 10:13  ->  temptation, addiction
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 Corinthians', 10, 13, 0,
    'God is faithful to limit temptation and always provide a way out.',
    'For when {focus} feels overwhelming and you need to know there''s always a way out.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 Corinthians' and cv.chapter = 10
      and cv.verse_start = 13 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'temptation', 'tempted', 'comfort', 'growing', 25 from v
union all
select id, 'addiction', 'tempted', 'comfort', 'growing', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- James 1:12  ->  temptation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'James', 1, 12, 0,
    'Blessed is the one who perseveres under trial and receives the promised crown of life.',
    'For when {focus} tests your endurance and you need eyes on what''s promised.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'James' and cv.chapter = 1
      and cv.verse_start = 12 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'temptation', 'tempted', 'challenge', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 26:41  ->  temptation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 26, 41, 0,
    'Jesus'' warning to watch and pray so as not to fall into temptation, since the flesh is weak.',
    'For when {focus} exposes how willing your spirit is but how weak your flesh can be.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 26
      and cv.verse_start = 41 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'temptation', 'tempted', 'instruction', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Hebrews 4:15-16  ->  temptation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Hebrews', 4, 15, 16,
    'Christ sympathizes with our weaknesses, having been tempted in every way, yet without sin.',
    'For when {focus} makes you feel judged and you need a High Priest who understands.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Hebrews' and cv.chapter = 4
      and cv.verse_start = 15 and cv.verse_end = 16
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'temptation', 'tempted', 'comfort', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Galatians 5:16  ->  temptation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Galatians', 5, 16, 0,
    'Walking by the Spirit is the antidote to gratifying the desires of the flesh.',
    'For when {focus} calls for a Spirit-led step instead of giving in.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Galatians' and cv.chapter = 5
      and cv.verse_start = 16 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'temptation', 'tempted', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- James 4:7  ->  temptation, addiction
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'James', 4, 7, 0,
    'Submit to God, resist the devil, and he will flee from you.',
    'For when {focus} calls for active resistance, not passive hoping.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'James' and cv.chapter = 4
      and cv.verse_start = 7 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'temptation', 'tempted', 'challenge', 'growing', 15 from v
union all
select id, 'addiction', 'tempted', 'challenge', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 119:11  ->  temptation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 119, 11, 0,
    'Hiding God''s word in your heart as a defense against sin.',
    'For when {focus} needs Scripture stored up ahead of the moment of struggle.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 119
      and cv.verse_start = 11 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'temptation', 'tempted', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Colossians 3:23  ->  career, motivation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Colossians', 3, 23, 0,
    'Whatever the work, do it with your whole heart, as if working for the Lord.',
    'For when {focus} needs a shift from working for people to working for the Lord.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Colossians' and cv.chapter = 3
      and cv.verse_start = 23 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'career', 'motivated', 'instruction', 'beginner', 22 from v
union all
select id, 'motivation', 'motivated', 'instruction', 'beginner', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 16:3  ->  career, motivation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 16, 3, 0,
    'Commit your plans to the Lord and trust Him to establish them.',
    'For when {focus} has you making plans that need to be surrendered to God.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 16
      and cv.verse_start = 3 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'career', 'anxious', 'instruction', 'growing', 20 from v
union all
select id, 'motivation', 'anxious', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 14:23  ->  career
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 14, 23, 0,
    'All hard work brings a profit, but idle talk leads only to poverty.',
    'For when {focus} calls for diligent effort rather than empty talk.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 14
      and cv.verse_start = 23 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'career', 'motivated', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Ecclesiastes 3:1  ->  career
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Ecclesiastes', 3, 1, 0,
    'There is a season and a time for every purpose under heaven.',
    'For when {focus} has you wondering if the timing is right.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Ecclesiastes' and cv.chapter = 3
      and cv.verse_start = 1 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'career', 'confused', 'instruction', 'growing', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Philippians 4:13  ->  career, confidence
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Philippians', 4, 13, 0,
    'Paul''s confidence that Christ supplies the strength for every circumstance.',
    'For when {focus} requires strength you don''t feel you have on your own.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Philippians' and cv.chapter = 4
      and cv.verse_start = 13 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'career', 'motivated', 'challenge', 'beginner', 18 from v
union all
select id, 'confidence', 'motivated', 'challenge', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 22:29  ->  career
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 22, 29, 0,
    'Skilled, diligent work has a way of opening doors and gaining notice.',
    'For when {focus} calls for diligence that quietly builds a reputation over time.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 22
      and cv.verse_start = 29 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'career', 'motivated', 'instruction', 'mature', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 12:24  ->  career
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 12, 24, 0,
    'Diligent hands lead to responsibility; laziness leads to labor without reward.',
    'For when {focus} needs a nudge toward diligence over drifting.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 12
      and cv.verse_start = 24 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'career', 'motivated', 'instruction', 'growing', 10 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Joshua 1:9  ->  confidence, leadership
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Joshua', 1, 9, 0,
    'God''s charge to be strong and courageous, backed by His constant presence.',
    'For when {focus} calls for courage and you need to remember God goes with you.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Joshua' and cv.chapter = 1
      and cv.verse_start = 9 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'confidence', 'anxious', 'challenge', 'beginner', 22 from v
union all
select id, 'leadership', 'anxious', 'challenge', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 27:1  ->  confidence
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 27, 1, 0,
    'The Lord as light and salvation removes the grounds for fear.',
    'For when {focus} raises fear and you need to ask, of whom shall I be afraid.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 27
      and cv.verse_start = 1 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'confidence', 'anxious', 'comfort', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 3:5-6  ->  confidence
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 3, 5, 6,
    'Trusting the Lord with all your heart rather than leaning on your own understanding.',
    'For when {focus} tempts you to lean on yourself instead of trusting God''s direction.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 3
      and cv.verse_start = 5 and cv.verse_end = 6
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'confidence', 'confused', 'instruction', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Romans 11:33-36  ->  understanding_god
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Romans', 11, 33, 36,
    'Paul''s doxology over the depth and unsearchable wisdom of God''s judgments and ways.',
    'For when {focus} reminds you God''s wisdom is far beyond full understanding.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Romans' and cv.chapter = 11
      and cv.verse_start = 33 and cv.verse_end = 36
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_god', 'confused', 'challenge', 'mature', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 145:8-9  ->  understanding_god
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 145, 8, 9,
    'The Lord is gracious, compassionate, slow to anger, and good to all He has made.',
    'For when {focus} needs a clearer picture of God''s compassionate character.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 145
      and cv.verse_start = 8 and cv.verse_end = 9
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_god', 'grateful', 'comfort', 'beginner', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 John 4:8  ->  understanding_god
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 John', 4, 8, 0,
    'A foundational statement of God''s nature: God is love.',
    'For when {focus} needs to be filtered through the simple truth that God is love.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 John' and cv.chapter = 4
      and cv.verse_start = 8 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_god', 'grateful', 'comfort', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Exodus 34:6-7  ->  understanding_god
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Exodus', 34, 6, 7,
    'God''s own self-description to Moses: compassionate, gracious, faithful, and just.',
    'For when {focus} calls for God''s own words about who He is.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Exodus' and cv.chapter = 34
      and cv.verse_start = 6 and cv.verse_end = 7
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_god', 'confused', 'instruction', 'mature', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Isaiah 55:8-9  ->  understanding_god
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Isaiah', 55, 8, 9,
    'God''s thoughts and ways are as high above ours as the heavens are above the earth.',
    'For when {focus} doesn''t make sense and you need to trust God sees more than you do.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Isaiah' and cv.chapter = 55
      and cv.verse_start = 8 and cv.verse_end = 9
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_god', 'confused', 'challenge', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Malachi 3:6  ->  understanding_god
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Malachi', 3, 6, 0,
    'The Lord''s unchanging nature is the ground of His people''s security.',
    'For when {focus} shifts and you need to remember God does not change.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Malachi' and cv.chapter = 3
      and cv.verse_start = 6 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_god', 'grateful', 'comfort', 'mature', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Luke 15:20  ->  returning_to_faith
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Luke', 15, 20, 0,
    'The father runs to meet his returning son while he is still far off, filled with compassion.',
    'For when {focus} makes you wonder how you''ll be received if you come back.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Luke' and cv.chapter = 15
      and cv.verse_start = 20 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'returning_to_faith', 'hopeful', 'comfort', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- James 4:8  ->  returning_to_faith
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'James', 4, 8, 0,
    'A simple invitation: come near to God, and He will come near to you.',
    'For when {focus} feels like a first step you''re not sure how to take.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'James' and cv.chapter = 4
      and cv.verse_start = 8 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'returning_to_faith', 'hopeful', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Joel 2:12-13  ->  returning_to_faith
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Joel', 2, 12, 13,
    'A call to return to the Lord with a whole heart, trusting His grace and compassion.',
    'For when {focus} calls for a heart-level turning, not just outward change.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Joel' and cv.chapter = 2
      and cv.verse_start = 12 and cv.verse_end = 13
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'returning_to_faith', 'discouraged', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 2 Chronicles 7:14  ->  returning_to_faith
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '2 Chronicles', 7, 14, 0,
    'God''s promise to hear, forgive, and heal a humble, praying, repentant people.',
    'For when {focus} begins with humility and honest prayer.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '2 Chronicles' and cv.chapter = 7
      and cv.verse_start = 14 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'returning_to_faith', 'hopeful', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 51:10-12  ->  returning_to_faith
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 51, 10, 12,
    'David''s prayer for a clean heart and the restoration of joy after failure.',
    'For when {focus} needs the honest prayer of a heart wanting to start fresh.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 51
      and cv.verse_start = 10 and cv.verse_end = 12
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'returning_to_faith', 'discouraged', 'comfort', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Hosea 6:1  ->  returning_to_faith
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Hosea', 6, 1, 0,
    'Even after being torn, God''s people are invited to return, trusting He will heal.',
    'For when {focus} follows a painful season and you need hope for healing.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Hosea' and cv.chapter = 6
      and cv.verse_start = 1 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'returning_to_faith', 'hopeful', 'instruction', 'growing', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 6:9-13  ->  learning_to_pray
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 6, 9, 13,
    'Jesus'' own model prayer, teaching His disciples how to approach the Father.',
    'For when {focus} feels unfamiliar and you need Jesus'' own pattern to follow.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 6
      and cv.verse_start = 9 and cv.verse_end = 13
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'learning_to_pray', 'confused', 'instruction', 'beginner', 25 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 Thessalonians 5:16-18  ->  learning_to_pray
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 Thessalonians', 5, 16, 18,
    'A rhythm of rejoicing, praying continually, and giving thanks in all circumstances.',
    'For when {focus} needs to become less of an event and more of a rhythm.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 Thessalonians' and cv.chapter = 5
      and cv.verse_start = 16 and cv.verse_end = 18
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'learning_to_pray', 'grateful', 'instruction', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- James 5:16  ->  learning_to_pray
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'James', 5, 16, 0,
    'The prayer of a righteous person is described as powerful and effective.',
    'For when {focus} needs the confidence that honest prayer truly accomplishes something.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'James' and cv.chapter = 5
      and cv.verse_start = 16 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'learning_to_pray', 'hopeful', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 7:7-8  ->  learning_to_pray
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 7, 7, 8,
    'Jesus'' invitation to ask, seek, and knock, trusting the Father''s responsiveness.',
    'For when {focus} needs the courage to keep asking and trust God hears.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 7
      and cv.verse_start = 7 and cv.verse_end = 8
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'learning_to_pray', 'hopeful', 'instruction', 'beginner', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Romans 8:26  ->  learning_to_pray
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Romans', 8, 26, 0,
    'When words fail, the Spirit intercedes for us with groans too deep for words.',
    'For when {focus} leaves you without words and you need the Spirit to intercede.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Romans' and cv.chapter = 8
      and cv.verse_start = 26 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'learning_to_pray', 'overwhelmed', 'comfort', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 42:11  ->  depression_hope
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 42, 11, 0,
    'The psalmist questions his own downcast soul and redirects it toward hope in God.',
    'For when {focus} has you asking why your soul feels so low.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 42
      and cv.verse_start = 11 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'depression_hope', 'discouraged', 'comfort', 'growing', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 40:1-3  ->  depression_hope
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 40, 1, 3,
    'God lifts the psalmist out of a pit of despair and sets his feet on solid ground.',
    'For when {focus} feels like a pit you can''t climb out of alone.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 40
      and cv.verse_start = 1 and cv.verse_end = 3
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'depression_hope', 'discouraged', 'comfort', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Isaiah 61:3  ->  depression_hope
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Isaiah', 61, 3, 0,
    'God offers beauty for ashes and a garment of praise instead of a spirit of despair.',
    'For when {focus} feels heavy and you need God''s promised exchange.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Isaiah' and cv.chapter = 61
      and cv.verse_start = 3 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'depression_hope', 'discouraged', 'comfort', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Lamentations 3:22-23  ->  depression_hope
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Lamentations', 3, 22, 23,
    'God''s mercies are new every single morning; His faithfulness never runs out.',
    'For when {focus} needs the reminder that today is a fresh mercy, not a repeat of yesterday.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Lamentations' and cv.chapter = 3
      and cv.verse_start = 22 and cv.verse_end = 23
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'depression_hope', 'discouraged', 'comfort', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Romans 15:13  ->  depression_hope
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Romans', 15, 13, 0,
    'A prayer that the God of hope would fill you with joy and peace as you trust Him.',
    'For when {focus} needs to be met with overflowing hope, not just relief.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Romans' and cv.chapter = 15
      and cv.verse_start = 13 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'depression_hope', 'discouraged', 'comfort', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Isaiah 40:31  ->  motivation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Isaiah', 40, 31, 0,
    'Those who hope in the Lord will renew their strength and soar like eagles.',
    'For when {focus} has you running on empty and needing renewed strength.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Isaiah' and cv.chapter = 40
      and cv.verse_start = 31 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'motivation', 'discouraged', 'comfort', 'growing', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Hebrews 12:1  ->  motivation
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Hebrews', 12, 1, 0,
    'A call to lay aside every hindrance and run the race set before us with endurance.',
    'For when {focus} calls for perseverance in the race you''re already running.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Hebrews' and cv.chapter = 12
      and cv.verse_start = 1 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'motivation', 'discouraged', 'challenge', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 Corinthians 6:12  ->  addiction
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 Corinthians', 6, 12, 0,
    'Not everything permissible is beneficial, a call to refuse being mastered by anything.',
    'For when {focus} raises the question of what, or who, is really in control.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 Corinthians' and cv.chapter = 6
      and cv.verse_start = 12 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'addiction', 'tempted', 'instruction', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Romans 6:12-14  ->  addiction
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Romans', 6, 12, 14,
    'A call to no longer let sin reign, since grace has broken its power over you.',
    'For when {focus} feels like a pattern with power over you that grace can break.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Romans' and cv.chapter = 6
      and cv.verse_start = 12 and cv.verse_end = 14
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'addiction', 'tempted', 'instruction', 'growing', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Galatians 5:1  ->  addiction
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Galatians', 5, 1, 0,
    'Christ set us free for freedom, a call not to be burdened again by slavery.',
    'For when {focus} feels like a yoke you were never meant to carry again.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Galatians' and cv.chapter = 5
      and cv.verse_start = 1 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'addiction', 'tempted', 'challenge', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 40:2  ->  addiction
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 40, 2, 0,
    'God lifts the psalmist out of the mud and mire and sets his feet on solid rock.',
    'For when {focus} feels like being stuck, and you need solid ground under your feet.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 40
      and cv.verse_start = 2 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'addiction', 'hopeful', 'comfort', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Ephesians 4:26-27  ->  anger
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Ephesians', 4, 26, 27,
    'Anger itself isn''t forbidden, but it must not become sin or a foothold for the enemy.',
    'For when {focus} needs boundaries before the sun goes down.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Ephesians' and cv.chapter = 4
      and cv.verse_start = 26 and cv.verse_end = 27
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anger', 'angry', 'instruction', 'growing', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- James 1:19-20  ->  anger
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'James', 1, 19, 20,
    'Be quick to listen, slow to speak, and slow to anger, since human anger doesn''t produce God''s righteousness.',
    'For when {focus} needs a slower fuse and a quicker ear.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'James' and cv.chapter = 1
      and cv.verse_start = 19 and cv.verse_end = 20
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anger', 'angry', 'instruction', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 15:1  ->  anger
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 15, 1, 0,
    'A gentle answer turns away wrath, while harsh words stir up conflict.',
    'For when {focus} can be defused with a gentler response than you feel like giving.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 15
      and cv.verse_start = 1 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anger', 'angry', 'instruction', 'beginner', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 29:11  ->  anger
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 29, 11, 0,
    'Fools vent their anger fully; the wise hold it back and bring calm instead.',
    'For when {focus} tempts you to let it all out instead of holding it back wisely.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 29
      and cv.verse_start = 11 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anger', 'angry', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Colossians 3:8  ->  anger
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Colossians', 3, 8, 0,
    'A call to rid yourself of anger, rage, and malice as part of putting off the old self.',
    'For when {focus} is something to actively set aside, not just manage.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Colossians' and cv.chapter = 3
      and cv.verse_start = 8 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anger', 'angry', 'challenge', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Ecclesiastes 7:9  ->  anger
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Ecclesiastes', 7, 9, 0,
    'Quick-tempered anger is described as resting in the lap of fools.',
    'For when {focus} tempts you to react quickly instead of responding wisely.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Ecclesiastes' and cv.chapter = 7
      and cv.verse_start = 9 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anger', 'angry', 'instruction', 'mature', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Mark 10:42-45  ->  leadership
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Mark', 10, 42, 45,
    'Jesus redefines greatness as serving others, following His own example.',
    'For when {focus} needs to be measured by service, not status.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Mark' and cv.chapter = 10
      and cv.verse_start = 42 and cv.verse_end = 45
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'leadership', 'motivated', 'challenge', 'growing', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 Timothy 3:1-2  ->  leadership
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 Timothy', 3, 1, 2,
    'A description of the noble, above-reproach character required of those who lead.',
    'For when {focus} calls for character that matches the responsibility.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 Timothy' and cv.chapter = 3
      and cv.verse_start = 1 and cv.verse_end = 2
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'leadership', 'motivated', 'instruction', 'mature', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Proverbs 11:14  ->  leadership
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Proverbs', 11, 14, 0,
    'Good leadership requires wise counsel; many advisers bring success.',
    'For when {focus} needs more wisdom than you can gather on your own.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Proverbs' and cv.chapter = 11
      and cv.verse_start = 14 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'leadership', 'confused', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 1 Peter 5:2-3  ->  leadership
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '1 Peter', 5, 2, 3,
    'Leaders are called to shepherd willingly, not for personal gain, but as an example.',
    'For when {focus} calls you to lead by example rather than by control.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '1 Peter' and cv.chapter = 5
      and cv.verse_start = 2 and cv.verse_end = 3
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'leadership', 'motivated', 'instruction', 'mature', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Luke 22:26  ->  leadership
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Luke', 22, 26, 0,
    'Jesus reframes greatness as becoming like the youngest and the one who serves.',
    'For when {focus} tempts you toward status instead of service.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Luke' and cv.chapter = 22
      and cv.verse_start = 26 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'leadership', 'motivated', 'challenge', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- John 3:16  ->  new_to_christianity
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'John', 3, 16, 0,
    'The heart of the gospel: God''s love for the world expressed through the gift of His Son.',
    'For when {focus} starts with the most foundational truth of all, God''s love for you.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'John' and cv.chapter = 3
      and cv.verse_start = 16 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'new_to_christianity', 'hopeful', 'comfort', 'beginner', 25 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Romans 10:9  ->  new_to_christianity
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Romans', 10, 9, 0,
    'The simple confession and belief that leads to salvation in Christ.',
    'For when {focus} raises the question of what it actually means to believe.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Romans' and cv.chapter = 10
      and cv.verse_start = 9 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'new_to_christianity', 'hopeful', 'instruction', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 2 Corinthians 5:17  ->  new_to_christianity
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '2 Corinthians', 5, 17, 0,
    'In Christ, a person becomes a new creation, the old has gone, the new has come.',
    'For when {focus} feels like the start of an entirely new chapter.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '2 Corinthians' and cv.chapter = 5
      and cv.verse_start = 17 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'new_to_christianity', 'hopeful', 'comfort', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Ephesians 2:8-9  ->  new_to_christianity
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Ephesians', 2, 8, 9,
    'Salvation is a gift received by grace through faith, not something earned.',
    'For when {focus} raises questions about grace versus earning your way.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Ephesians' and cv.chapter = 2
      and cv.verse_start = 8 and cv.verse_end = 9
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'new_to_christianity', 'hopeful', 'instruction', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Romans 3:23-24  ->  new_to_christianity
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Romans', 3, 23, 24,
    'All have fallen short, yet all are freely justified through Christ''s redemption.',
    'For when {focus} needs an honest starting point about grace for everyone.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Romans' and cv.chapter = 3
      and cv.verse_start = 23 and cv.verse_end = 24
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'new_to_christianity', 'hopeful', 'instruction', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- John 1:12  ->  new_to_christianity
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'John', 1, 12, 0,
    'Those who receive Christ are given the right to become children of God.',
    'For when {focus} centers on a new identity as God''s child.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'John' and cv.chapter = 1
      and cv.verse_start = 12 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'new_to_christianity', 'hopeful', 'comfort', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 2 Timothy 3:16-17  ->  understanding_the_bible
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '2 Timothy', 3, 16, 17,
    'All Scripture is God-breathed and useful for teaching, correction, and training.',
    'For when {focus} needs a foundation for why Scripture can be trusted.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '2 Timothy' and cv.chapter = 3
      and cv.verse_start = 16 and cv.verse_end = 17
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_the_bible', 'confused', 'instruction', 'growing', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 119:105  ->  understanding_the_bible
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 119, 105, 0,
    'God''s word pictured as a lamp for the feet and a light for the path ahead.',
    'For when {focus} needs a light for a decision or a dark stretch of the path.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 119
      and cv.verse_start = 105 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_the_bible', 'confused', 'comfort', 'beginner', 20 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Hebrews 4:12  ->  understanding_the_bible
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Hebrews', 4, 12, 0,
    'God''s word is described as living, active, and able to discern the heart.',
    'For when {focus} needs a word sharp enough to reach what''s really going on inside.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Hebrews' and cv.chapter = 4
      and cv.verse_start = 12 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_the_bible', 'confused', 'instruction', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Joshua 1:8  ->  understanding_the_bible
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Joshua', 1, 8, 0,
    'Meditating on and obeying God''s word is tied to a well-lived, fruitful life.',
    'For when {focus} calls for regular meditation, not just occasional reading.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Joshua' and cv.chapter = 1
      and cv.verse_start = 8 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_the_bible', 'motivated', 'instruction', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- 2 Peter 1:20-21  ->  understanding_the_bible
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select '2 Peter', 1, 20, 21,
    'Scripture''s prophecy came not from human will but from the Holy Spirit''s guidance.',
    'For when {focus} raises questions about where Scripture actually comes from.'
  where not exists (
    select 1 from curated_verses cv where cv.book = '2 Peter' and cv.chapter = 1
      and cv.verse_start = 20 and cv.verse_end = 21
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_the_bible', 'confused', 'instruction', 'mature', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 4:4  ->  understanding_the_bible
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 4, 4, 0,
    'Jesus affirms that life is sustained not by bread alone but by every word from God.',
    'For when {focus} reminds you Scripture is as essential as daily bread.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 4
      and cv.verse_start = 4 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'understanding_the_bible', 'hopeful', 'instruction', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Matthew 11:28-30  ->  rest_peace
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Matthew', 11, 28, 30,
    'Jesus'' invitation to the weary and burdened to find rest in Him.',
    'For when {focus} has you weary and needing to trade your burden for His.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Matthew' and cv.chapter = 11
      and cv.verse_start = 28 and cv.verse_end = 30
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'rest_peace', 'overwhelmed', 'comfort', 'beginner', 25 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 23:1-3  ->  rest_peace
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 23, 1, 3,
    'The Lord as shepherd who leads to green pastures and restores the soul.',
    'For when {focus} needs the quiet, restorative care of the Good Shepherd.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 23
      and cv.verse_start = 1 and cv.verse_end = 3
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'rest_peace', 'peaceful', 'comfort', 'beginner', 22 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Isaiah 26:3  ->  rest_peace
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Isaiah', 26, 3, 0,
    'Perfect peace is promised to the mind that stays fixed and trusting on God.',
    'For when {focus} needs a mind anchored in trust instead of spinning.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Isaiah' and cv.chapter = 26
      and cv.verse_start = 3 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'rest_peace', 'peaceful', 'comfort', 'growing', 18 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 4:8  ->  rest_peace
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 4, 8, 0,
    'A simple confidence that allows peaceful sleep because the Lord keeps you safe.',
    'For when {focus} disrupts your rest and you need safety to fall asleep in.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 4
      and cv.verse_start = 8 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'rest_peace', 'peaceful', 'comfort', 'beginner', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Luke 16:10  ->  financial_wisdom
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Luke', 16, 10, 0,
    'Faithfulness in small things, including money, reveals readiness for greater trust.',
    'For when {focus} tests your faithfulness in things that seem small.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Luke' and cv.chapter = 16
      and cv.verse_start = 10 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'financial_wisdom', 'motivated', 'instruction', 'growing', 12 from v
on conflict (curated_verse_id, focus_slug) do nothing;

-- Psalms 55:22  ->  anxiety
with v as (
  insert into curated_verses (book, chapter, verse_start, verse_end, theme_summary, why_template)
  select 'Psalms', 55, 22, 0,
    'Cast your burden on the Lord, and He will sustain you and keep you from being shaken.',
    'For when {focus} feels like too much weight to carry and needs to be cast onto God.'
  where not exists (
    select 1 from curated_verses cv where cv.book = 'Psalms' and cv.chapter = 55
      and cv.verse_start = 22 and cv.verse_end = 0
  )
  returning id
)
insert into curated_verse_tags (curated_verse_id, focus_slug, emotion, tone, maturity, weight)
select id, 'anxiety', 'overwhelmed', 'comfort', 'growing', 15 from v
on conflict (curated_verse_id, focus_slug) do nothing;
