-- 0018_church_streaming.sql — Attend build-out.
-- Real streaming fields on churches + a starter directory of churches that
-- stream. Playback approach (research/church_streaming_plan.md): YouTube via
-- the official iframe embed, direct HLS via AVPlayer, everything else link-out
-- to the church's watch page. Never extract raw HLS from YouTube (ToS).

alter table public.churches add column if not exists platform text;            -- 'youtube' | 'hls' | 'facebook' | 'web'
alter table public.churches add column if not exists youtube_channel_id text;  -- UC... channel id (for live embed)
alter table public.churches add column if not exists hls_url text;             -- direct .m3u8 (BoxCast/Resi/Subsplash/etc.)
alter table public.churches add column if not exists watch_url text;           -- fallback / link-out watch page
alter table public.churches add column if not exists thumbnail_url text;
alter table public.churches add column if not exists denomination text;

-- Starter directory (idempotent on name). Channel IDs are from the churches'
-- official YouTube channel URLs; where absent, the app links out to the
-- church's /live page. Expand/curate this list over time.
insert into public.churches
  (name, city, style, denomination, platform, youtube_channel_id, watch_url, is_live, viewers, accent, rating, distance_miles)
select v.name, v.city, v.style, v.denomination, v.platform,
       v.youtube_channel_id, v.watch_url, v.is_live, v.viewers::int,
       v.accent, v.rating::numeric, v.distance_miles::numeric
from (values
  ('Life.Church', 'Edmond, OK', 'Contemporary', 'Non-denominational', 'youtube', 'UCoDt562cJaageYU-LYKt4Pw', 'https://www.youtube.com/@life.church/live', true, 5200, 'blue', 4.8, null),
  ('Elevation Church', 'Charlotte, NC', 'Contemporary', 'Non-denominational', 'youtube', 'UCIQqvZbHSwX0yKNVK1MyYjQ', 'https://www.youtube.com/@elevationchurch/live', true, 8100, 'olive', 4.7, null),
  ('Transformation Church', 'Tulsa, OK', 'Contemporary', 'Non-denominational', 'youtube', 'UCETv6h2iCi2FpVAFPPmpytg', 'https://www.youtube.com/@transformchurch/live', false, null, 'gold', 4.8, null),
  ('The Potter''s House', 'Dallas, TX', 'Gospel', 'Non-denominational', 'youtube', null, 'https://www.youtube.com/@bishopjakesofficial/live', false, null, 'blue', 4.7, null),
  ('Bethel Church', 'Redding, CA', 'Worship', 'Charismatic', 'youtube', null, 'https://www.youtube.com/@bethel/live', false, null, 'olive', 4.5, null),
  ('Saddleback Church', 'Lake Forest, CA', 'Contemporary', 'Baptist', 'youtube', null, 'https://www.youtube.com/@saddlebackchurch/live', false, null, 'gold', 4.6, null)
) as v(name, city, style, denomination, platform, youtube_channel_id, watch_url, is_live, viewers, accent, rating, distance_miles)
where not exists (select 1 from public.churches c where c.name = v.name);

-- One service row per seeded church (idempotent on church + title).
insert into public.live_services (church_id, title, starts_in, service_time, is_live)
select c.id, v.title, v.starts_in, v.service_time, v.is_live
from (values
  ('Life.Church',            'Weekend Message', null,  null,      true),
  ('Elevation Church',       'Sunday Worship',  null,  null,      true),
  ('Transformation Church',  'Sunday Service',  '2h',  null,      false),
  ('The Potter''s House',    'Sunday Gathering', null, '9:00 AM', false),
  ('Bethel Church',          'Sunday Service',  null,  '10:00 AM', false),
  ('Saddleback Church',      'Weekend Service', null,  '11:00 AM', false)
) as v(church_name, title, starts_in, service_time, is_live)
join public.churches c on c.name = v.church_name
where not exists (
  select 1 from public.live_services ls where ls.church_id = c.id and ls.title = v.title
);
