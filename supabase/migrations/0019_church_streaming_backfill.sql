-- 0019_church_streaming_backfill.sql
-- The 0018 seed used insert-where-name-not-exists, so churches that already
-- existed (Elevation, Bethel, Saddleback, Hillsong, etc.) kept null streaming
-- fields and "Watch Live" did nothing. Backfill them here (idempotent).

update public.churches set platform='youtube',
  youtube_channel_id='UCIQqvZbHSwX0yKNVK1MyYjQ',
  watch_url='https://www.youtube.com/@elevationchurch/live'
  where name='Elevation Church';

update public.churches set platform='youtube',
  watch_url='https://www.youtube.com/@bethel/live'
  where name='Bethel Church' and youtube_channel_id is null;

update public.churches set platform='youtube',
  watch_url='https://www.youtube.com/@saddlebackchurch/live'
  where name='Saddleback Church' and youtube_channel_id is null;

update public.churches set platform='youtube',
  watch_url='https://www.youtube.com/@hillsong/live'
  where name='Hillsong Church' and youtube_channel_id is null;

update public.churches set platform='youtube',
  watch_url='https://www.youtube.com/@bishopjakesofficial/live'
  where name = 'The Potter''s House' and youtube_channel_id is null;

-- Generic / demo churches with no known stream: link out to a YouTube search
-- for their live service (the app also does this as a runtime fallback).
update public.churches set platform='web',
  watch_url='https://www.youtube.com/results?search_query='||replace(name,' ','+')||'+live'
  where watch_url is null;
