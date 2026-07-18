# Church live-stream pipeline — setup

Makes "Watch Live" reliable: the app embeds the church's *actual current live
video* (resolved server-side), and a scheduled job keeps every church's real
live status fresh. Near-zero YouTube API quota (scrape the /live canonical link
= 0 units; confirm with 1 batched `videos.list` = 1 unit per 50 churches).

## 1. YouTube Data API key (browser)
console.cloud.google.com → new/any project → APIs & Services → Library →
enable **YouTube Data API v3** → Credentials → Create credentials → API key.
Restrict the key to *YouTube Data API v3* only (server-side, so no referrer/IP
restriction). Default quota: 10,000 units/day.

## 2. Local secrets (Terminal + editor)
```
cd ~/Projects/Crossed*/
open -e supabase/.env.local
```
Add two lines (keep PIPELINE_SECRET stable once chosen):
```
YOUTUBE_API_KEY=AIza...your-key...
PIPELINE_SECRET=<paste output of: openssl rand -hex 24>
```
(Do NOT add SUPABASE_SERVICE_ROLE_KEY — hosted edge functions get it injected
automatically, and the CLI rejects SUPABASE_-prefixed secret names.)

## 3. Apply migrations (Supabase SQL Editor)
```
pbcopy < supabase/migrations/0019_church_streaming_backfill.sql   # paste → Run (if not already)
pbcopy < supabase/migrations/0020_church_live_pipeline.sql        # paste → Run
```

## 4. Deploy the two edge functions (Terminal)
```
./supabase/deploy_refresh_church_streams.sh
./supabase/deploy_add_church.sh
```

## 5. First refresh + schedule
Fire once to populate live status (replace $PIPELINE_SECRET or export it first):
```
curl -s -X POST "https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/refresh_church_streams" \
  -H "Authorization: Bearer sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL" \
  -H "x-pipeline-secret: $PIPELINE_SECRET" -H "Content-Type: application/json" -d '{}'
```
Expect JSON like `{"checked":N,"live":x,"offline":y,"quota_units_spent":<=1}`.
Then schedule it every 5 min — SQL Editor (replace `<PIPELINE_SECRET>`):
```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;
select cron.schedule('refresh-church-streams', '*/5 * * * *', $$
  select net.http_post(
    url := 'https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/refresh_church_streams',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL',
      'x-pipeline-secret','<PIPELINE_SECRET>'),
    body := '{}'::jsonb, timeout_milliseconds := 60000);
$$);
```

## 6. Add churches (any time, Terminal)
```
curl -s -X POST "https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/add_church" \
  -H "Authorization: Bearer sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL" \
  -H "x-pipeline-secret: $PIPELINE_SECRET" -H "Content-Type: application/json" \
  -d '{"input":"@hillsong","city":"Sydney","denomination":"Pentecostal"}'
```
`input` accepts a handle (`@name`), a channel URL, or a `UC...` channel id. It
upserts on channel id. NOTE: the seeded churches Bethel/Saddleback/Hillsong were
backfilled with a watch_url but no channel id — add_church on them resolves the
real channel and inserts a fresh row, so delete the old null-channel duplicate
after (or just leave them as link-outs). Life.Church, Elevation, and
Transformation already have channel ids and are picked up by the refresh job.

## 7. Rebuild the app (Xcode)
Just Cmd+R (Swift edits only — no new Swift files, no xcodegen).

## Smoke test
- Refresh curl returns quota_units_spent ≤ 1, no confirm_error; `last_checked_at`
  updates on the youtube churches.
- During a real broadcast a church gets is_live=true + an 11-char live_video_id +
  viewers; "Watch Live" plays the embed (no error 152).
- Not live → "Not live right now" alert with an "Open on YouTube" link-out.
- Cron: after ~10 min, `select * from cron.job_run_details order by start_time desc limit 3;`
  shows succeeded runs; Google Cloud quota shows a few units/day.
