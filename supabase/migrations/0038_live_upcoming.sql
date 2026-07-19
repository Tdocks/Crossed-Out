-- 0038_live_upcoming.sql
-- Surface SCHEDULED ("upcoming") YouTube streams, not just currently-live ones.
--
-- Before: refresh_church_streams only ever wrote is_live, and only for streams
-- that were actively broadcasting. A church with a scheduled-but-not-yet-live
-- service (the common case) showed a blank, indicator-less row — no "LIVE",
-- no "starts in 5 min". These columns let the pipeline record the next
-- broadcast's scheduled start + video id so the app can show a live countdown
-- and open the upcoming stream.

alter table public.live_services add column if not exists scheduled_start_at timestamptz;
alter table public.live_services add column if not exists upcoming_video_id  text;

comment on column public.live_services.scheduled_start_at is
  'Scheduled start of the next upcoming YouTube broadcast (null when live or none). Written by refresh_church_streams.';
comment on column public.live_services.upcoming_video_id is
  'videoId of the next upcoming broadcast, so the app can open its watch/notify page.';
