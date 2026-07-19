-- 0036_plus_subscriptions.sql
-- Crossed Out Plus entitlement mirror (StoreKit 2 client sync now;
-- App Store Server Notifications v2 can write the same table later).

create table if not exists public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  product_id text not null,
  status text not null check (status in ('active', 'expired', 'grace', 'revoked')),
  expires_at timestamptz,
  original_transaction_id text,
  environment text,
  updated_at timestamptz not null default now()
);

alter table public.subscriptions enable row level security;

drop policy if exists "own subscription read" on public.subscriptions;
create policy "own subscription read" on public.subscriptions
  for select using (auth.uid() = user_id);

revoke all on table public.subscriptions from anon;
grant select on table public.subscriptions to authenticated;

-- Client-verified StoreKit sync. Never lets a user set another user's row.
create or replace function public.upsert_own_subscription(
  p_product_id text,
  p_status text,
  p_expires_at timestamptz,
  p_original_transaction_id text default null,
  p_environment text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;
  if p_status not in ('active', 'expired', 'grace', 'revoked') then
    raise exception 'invalid status';
  end if;

  insert into public.subscriptions (
    user_id, product_id, status, expires_at,
    original_transaction_id, environment, updated_at
  ) values (
    uid, p_product_id, p_status, p_expires_at,
    p_original_transaction_id, p_environment, now()
  )
  on conflict (user_id) do update set
    product_id = excluded.product_id,
    status = excluded.status,
    expires_at = excluded.expires_at,
    original_transaction_id = coalesce(
      excluded.original_transaction_id,
      subscriptions.original_transaction_id
    ),
    environment = coalesce(excluded.environment, subscriptions.environment),
    updated_at = now();
end;
$$;

revoke all on function public.upsert_own_subscription(text, text, timestamptz, text, text) from public;
grant execute on function public.upsert_own_subscription(text, text, timestamptz, text, text) to authenticated;

-- True when the caller has an active (or grace) Plus entitlement.
create or replace function public.is_plus()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.subscriptions s
    where s.user_id = auth.uid()
      and s.status in ('active', 'grace')
      and (s.expires_at is null or s.expires_at > now())
  );
$$;

revoke all on function public.is_plus() from public;
grant execute on function public.is_plus() to authenticated;

-- Daily Kyra limit for the caller. Plus gets the elevated cap.
create or replace function public.kyra_daily_limit_for_user()
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  free_limit int := coalesce(nullif(current_setting('app.kyra_free_limit', true), '')::int, 30);
  plus_limit int := coalesce(nullif(current_setting('app.kyra_plus_limit', true), '')::int, 200);
begin
  if public.is_plus() then
    return plus_limit;
  end if;
  return free_limit;
end;
$$;

revoke all on function public.kyra_daily_limit_for_user() from public;
grant execute on function public.kyra_daily_limit_for_user() to authenticated;
