-- Notes, bookmarks, saved churches, daily completions, give intents
create table if not exists public.user_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  book text not null,
  chapter int not null,
  verse int not null,
  note text not null,
  created_at timestamptz not null default now()
);
alter table public.user_notes enable row level security;
create policy "own notes" on public.user_notes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.user_bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  book text not null,
  chapter int not null,
  verse int,
  created_at timestamptz not null default now(),
  unique (user_id, book, chapter, verse)
);
alter table public.user_bookmarks enable row level security;
create policy "own bookmarks" on public.user_bookmarks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.saved_churches (
  user_id uuid not null references auth.users(id) on delete cascade,
  church_id uuid not null references public.churches(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, church_id)
);
alter table public.saved_churches enable row level security;
create policy "own saved churches" on public.saved_churches
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.daily_completions (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  kind text not null check (kind in ('scripture','prayer','reflection','community','encouragement','devotional')),
  created_at timestamptz not null default now(),
  primary key (user_id, day, kind)
);
alter table public.daily_completions enable row level security;
create policy "own completions" on public.daily_completions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.give_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  project_id uuid references public.give_projects(id) on delete cascade,
  amount numeric(12,2) not null,
  created_at timestamptz not null default now()
);
alter table public.give_intents enable row level security;
create policy "own give intents" on public.give_intents
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Give link-out
alter table public.give_projects add column if not exists donate_url text;
