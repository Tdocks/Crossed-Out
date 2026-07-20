-- Give tab rebuild: honest external-giving hub (pre-launch blocker fix).
--
-- The old Give tab showed fabricated fundraising campaigns ("$4,820 of
-- $10,000 raised") with a client-side Google-search fallback whenever a
-- project had no real donate_url -- i.e. every "Give Now" tap either hit a
-- fake progress bar or silently left the app to a search page. Give is now
-- a curated hub of REAL external giving destinations: Crossed Out never
-- touches the money, it only link-outs to an organization's own donation
-- page. This migration adds the columns the new card needs (a one-line
-- description and a category tag) plus is_active/sort_order so destinations
-- without a verified real donate_url can be hidden rather than shown with
-- an invented link. raised/goal are kept (NOT NULL) for backward
-- compatibility but are no longer rendered anywhere in the client.
-- ============================================================================

alter table public.give_projects
    add column if not exists description text,
    add column if not exists category text,
    add column if not exists is_active boolean not null default true,
    add column if not exists sort_order integer not null default 0;

comment on column public.give_projects.description is
    'One-line honest description shown on the Give hub card. No fundraising totals or fabricated numbers.';
comment on column public.give_projects.category is
    'Short tag shown on the card, e.g. "Local Church". Not a fundraising category/goal.';
comment on column public.give_projects.is_active is
    'Client only shows rows where is_active = true and donate_url is set to a real URL. Never fall back to a search engine for missing links.';
comment on column public.give_projects.sort_order is
    'Lower sorts first; used to feature the anchor destination (Emmanuel Church) at launch.';
