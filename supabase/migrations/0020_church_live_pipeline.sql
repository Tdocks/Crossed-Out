-- 0020_church_live_pipeline.sql
-- Live-stream pipeline columns for churches. Idempotent.

alter table public.churches add column if not exists live_video_id   text;
alter table public.churches add column if not exists last_checked_at timestamptz;
alter table public.churches add column if not exists youtube_handle  text;

comment on column public.churches.live_video_id   is 'Current YouTube live videoId (null when not live). Written by refresh_church_streams.';
comment on column public.churches.last_checked_at is 'Last time refresh_church_streams checked this church.';
comment on column public.churches.youtube_handle  is 'YouTube handle, e.g. @lifechurch (informational; channel_id is canonical).';

-- One church row per YouTube channel; lets add_church upsert safely.
create unique index if not exists churches_youtube_channel_id_key
  on public.churches (youtube_channel_id)
  where youtube_channel_id is not null;

create index if not exists churches_platform_idx on public.churches (platform);
