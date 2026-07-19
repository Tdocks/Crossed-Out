-- 0037_explore.sql
-- Explore content-discovery surface. One table, explore_items, populated
-- server-side on a schedule by the explore_* edge functions (YouTube sermons,
-- devotional RSS, later: Ticketmaster events, Apple Music, TMDB). The app
-- reads it read-only and deep-links users OUT to the source app. We host,
-- stream, and reproduce nothing — only metadata, thumbnails, and links.

create extension if not exists pgcrypto;

do $$ begin
  create type public.explore_vertical as enum
    ('music','sermons','devotionals','movies','events');
exception when duplicate_object then null;
end $$;

create table if not exists public.explore_items (
  id             uuid primary key default gen_random_uuid(),
  vertical       public.explore_vertical not null,
  source         text not null,          -- 'youtube','desiring_god','ligonier','ticketmaster','apple_music','tmdb'
  source_item_id text not null,          -- stable id from the source (videoId, guid, event id, catalog id)
  title          text not null,
  subtitle       text,                   -- artist / church / author / venue / where-to-watch
  excerpt        text,                   -- devotionals: capped excerpt; null elsewhere
  thumbnail_url  text,
  open_url       text not null,          -- canonical https universal link out
  app_url        text,                   -- optional app-scheme deep link (vnd.youtube://, music://…)
  attribution    text,                   -- required credit line where a source mandates it (TMDB, Bandsintown)
  published_at   timestamptz,            -- source publish / air / event date, for ordering
  rank           int not null default 0, -- curation weight; higher floats to top within a vertical
  is_active      boolean not null default true,
  metadata       jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (source, source_item_id)        -- idempotent upsert arbiter
);

create index if not exists explore_items_vertical_idx
  on public.explore_items (vertical, is_active, rank desc, published_at desc nulls last);

alter table public.explore_items enable row level security;

-- Read-only to any signed-in user (a shared discovery surface, like churches
-- and give_projects). Writes happen ONLY through the service-role edge
-- functions, which bypass RLS — never from the client.
drop policy if exists "read active explore items" on public.explore_items;
create policy "read active explore items" on public.explore_items
  for select using (is_active);

revoke all on table public.explore_items from anon;
grant select on table public.explore_items to authenticated;

-- Keep updated_at fresh on every upsert-update.
create or replace function public.touch_explore_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists explore_items_touch on public.explore_items;
create trigger explore_items_touch before update on public.explore_items
  for each row execute function public.touch_explore_updated_at();

comment on table public.explore_items is
  'Explore discovery surface. Populated server-side by explore_* edge functions; app reads read-only and deep-links out. No third-party media is hosted or reproduced here.';
