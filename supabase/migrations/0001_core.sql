-- Crossed Out core schema
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '',
  need text not null default '',
  translation text not null default 'WEB',
  day_number int not null default 1,
  focus_areas text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  mood text not null,
  note text,
  created_at timestamptz not null default now(),
  unique (user_id, day)
);

create table if not exists public.streaks (
  user_id uuid primary key references auth.users(id) on delete cascade,
  current int not null default 0,
  longest int not null default 0,
  grace_used int not null default 0,
  grace_total int not null default 3,
  last_active date,
  updated_at timestamptz not null default now()
);

create table if not exists public.working_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  crossed boolean not null default false,
  position int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.passages (
  id uuid primary key default gen_random_uuid(),
  book text not null,
  chapter int not null,
  verse_start int not null,
  verse_end int,
  translation text not null default 'WEB',
  text text not null,
  topics text[] not null default '{}',
  tone text not null default 'comfort',
  maturity text not null default 'beginner'
);

create table if not exists public.prayer_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  author_name text not null,
  body text not null,
  prayed_count int not null default 0,
  is_answered boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  author_name text not null,
  kind text not null check (kind in ('prayer','verse_share','testimony')),
  body text not null,
  verse_ref text,
  verse_text text,
  heart_count int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.churches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text not null,
  rating numeric(2,1) not null default 4.5,
  style text not null default 'Contemporary',
  distance_miles numeric(4,1),
  is_live boolean not null default false,
  viewers int,
  accent text not null default 'blue'
);

create table if not exists public.live_services (
  id uuid primary key default gen_random_uuid(),
  church_id uuid references public.churches(id) on delete cascade,
  title text,
  starts_in text,
  service_time text,
  is_live boolean not null default false
);

create table if not exists public.give_projects (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  org text not null,
  raised numeric(12,2) not null default 0,
  goal numeric(12,2) not null,
  date_range text
);

create table if not exists public.bridge_shares (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  to_name text not null,
  why_text text not null,
  verse_ref text not null,
  verse_text text not null,
  created_at timestamptz not null default now()
);

-- RLS
alter table public.profiles enable row level security;
alter table public.check_ins enable row level security;
alter table public.streaks enable row level security;
alter table public.working_items enable row level security;
alter table public.passages enable row level security;
alter table public.prayer_requests enable row level security;
alter table public.community_posts enable row level security;
alter table public.churches enable row level security;
alter table public.live_services enable row level security;
alter table public.give_projects enable row level security;
alter table public.bridge_shares enable row level security;

-- Policies: user-owned rows
create policy "own profile" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "own check_ins" on public.check_ins
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own streaks" on public.streaks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own working_items" on public.working_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own bridge_shares" on public.bridge_shares
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Public readable content
create policy "read passages" on public.passages for select using (true);
create policy "read churches" on public.churches for select using (true);
create policy "read services" on public.live_services for select using (true);
create policy "read projects" on public.give_projects for select using (true);

-- Community: readable by authed users, insert own
create policy "read prayers" on public.prayer_requests
  for select using (auth.role() = 'authenticated');
create policy "insert prayers" on public.prayer_requests
  for insert with check (auth.uid() = user_id);
create policy "read posts" on public.community_posts
  for select using (auth.role() = 'authenticated');
create policy "insert posts" on public.community_posts
  for insert with check (auth.uid() = user_id);
