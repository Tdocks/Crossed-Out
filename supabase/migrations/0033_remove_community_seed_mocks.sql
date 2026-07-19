-- Remove the demo community rows seeded in 0002_seed.sql (Jessica L. /
-- Mark D.). Those were stand-ins before live posting existed; the app no
-- longer falls back to MockData for Community, so leaving the seed rows
-- made the feed look "mocked" even when wired to Supabase.

delete from public.prayer_requests
where author_name = 'Jessica L.'
  and body = 'Please pray for my dad''s surgery on Friday. Thank you!';

delete from public.community_posts
where author_name = 'Mark D.'
  and kind = 'verse_share'
  and verse_ref = 'John 16:33';
