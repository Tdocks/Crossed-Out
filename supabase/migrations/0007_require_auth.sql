-- Require a real account: the app no longer creates anonymous Supabase
-- sessions (client-side anonymous sign-in has been removed entirely, and a
-- real account — Sign in with Apple or email/password — is now mandatory
-- before any app screen is reachable).
--
-- This migration is defense-in-depth at the database layer: even if
-- anonymous sign-in were ever re-enabled in the dashboard by mistake, the
-- database itself should still refuse anon-role / unauthenticated access to
-- every table and RPC that touches user-owned or user-authored content.
--
-- Note: Supabase's `auth.signInAnonymously()` issues a session whose JWT
-- role is `authenticated` (not `anon`) — so `auth.role() = 'authenticated'`
-- policies alone never actually distinguished a real user from an
-- anonymous one. Removing anonymous sign-in client-side fixes that gap
-- going forward; the grant/policy tightening below is the belt-and-braces
-- backstop.

-- ============================================================
-- 1. RPCs — revoke the anon execute grants added in 0004_interactions.sql.
--    Community reaction RPCs must only be callable by real authenticated
--    users.
-- ============================================================
revoke execute on function public.pray_for(uuid) from anon;
revoke execute on function public.encourage_post(uuid) from anon;
grant execute on function public.pray_for(uuid) to authenticated;
grant execute on function public.encourage_post(uuid) to authenticated;

-- ============================================================
-- 2. Table grants — revoke default anon table privileges on every table
--    that stores user-owned or user-authored content. Purely public
--    reference content (passages, churches, live_services, give_projects,
--    bible_verses) is intentionally left alone: it is not tied to any
--    individual user and its "read *" policies below already use `using
--    (true)`.
-- ============================================================
revoke all on table public.profiles from anon;
revoke all on table public.check_ins from anon;
revoke all on table public.streaks from anon;
revoke all on table public.working_items from anon;
revoke all on table public.prayer_requests from anon;
revoke all on table public.community_posts from anon;
revoke all on table public.bridge_shares from anon;
revoke all on table public.user_highlights from anon;
revoke all on table public.user_notes from anon;
revoke all on table public.user_bookmarks from anon;
revoke all on table public.saved_churches from anon;
revoke all on table public.daily_completions from anon;
revoke all on table public.give_intents from anon;
revoke all on table public.content_reports from anon;
revoke all on table public.user_blocks from anon;

-- ============================================================
-- 3. RLS policies — rebuild every "own row" policy scoped explicitly to the
--    `authenticated` role (`to authenticated`) instead of relying solely on
--    `auth.uid()` evaluating to NULL for anon requests. This makes the
--    restriction explicit at the policy layer, not just an accidental
--    consequence of NULL comparisons.
-- ============================================================
drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "own check_ins" on public.check_ins;
create policy "own check_ins" on public.check_ins
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own streaks" on public.streaks;
create policy "own streaks" on public.streaks
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own working_items" on public.working_items;
create policy "own working_items" on public.working_items
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own bridge_shares" on public.bridge_shares;
create policy "own bridge_shares" on public.bridge_shares
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own highlights" on public.user_highlights;
create policy "own highlights" on public.user_highlights
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own notes" on public.user_notes;
create policy "own notes" on public.user_notes
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own bookmarks" on public.user_bookmarks;
create policy "own bookmarks" on public.user_bookmarks
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own saved churches" on public.saved_churches;
create policy "own saved churches" on public.saved_churches
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own completions" on public.daily_completions;
create policy "own completions" on public.daily_completions
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own give intents" on public.give_intents;
create policy "own give intents" on public.give_intents
  for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own blocks" on public.user_blocks;
create policy "own blocks" on public.user_blocks
  for all to authenticated using (auth.uid() = blocker_id) with check (auth.uid() = blocker_id);

drop policy if exists "insert own reports" on public.content_reports;
create policy "insert own reports" on public.content_reports
  for insert to authenticated with check (auth.uid() = reporter_id);

drop policy if exists "read own reports" on public.content_reports;
create policy "read own reports" on public.content_reports
  for select to authenticated using (auth.uid() = reporter_id);

-- ============================================================
-- 4. Community read/insert policies — pin explicitly to `authenticated`.
--    The original `auth.role() = 'authenticated'` check alone does not
--    exclude anon-role requests once combined with a `to` clause, and an
--    explicit `to authenticated` is enforced at the grant layer as well as
--    the policy layer.
-- ============================================================
drop policy if exists "read prayers" on public.prayer_requests;
create policy "read prayers" on public.prayer_requests
  for select to authenticated using (true);

drop policy if exists "insert prayers" on public.prayer_requests;
create policy "insert prayers" on public.prayer_requests
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "read posts" on public.community_posts;
create policy "read posts" on public.community_posts
  for select to authenticated using (true);

drop policy if exists "insert posts" on public.community_posts;
create policy "insert posts" on public.community_posts
  for insert to authenticated with check (auth.uid() = user_id);
