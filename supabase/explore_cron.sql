-- explore_cron.sql
-- Daily pg_cron schedules that refresh each Explore vertical by POSTing to its
-- edge function (same pg_net pattern as refresh-church-streams). Staggered by
-- 10 min so they don't all fire at once. Times are UTC (08:00Z ≈ overnight ET).
--
-- Apply (injects the pipeline secret at runtime; never written to disk):
--   set -a; source scripts/.env.run; set +a
--   sed "s/__SECRET__/$PIPELINE_SECRET/g" supabase/explore_cron.sql | psql "$DATABASE_URL"
--
-- cron.schedule() upserts by job name, so re-applying just updates the schedule.

select cron.schedule('explore-sermons-daily', '0 8 * * *', $cron$
  select net.http_post(
    url := 'https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/explore_sermons',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL',
      'x-pipeline-secret','__SECRET__'),
    body := '{}'::jsonb, timeout_milliseconds := 60000);
$cron$);

select cron.schedule('explore-devotionals-daily', '10 8 * * *', $cron$
  select net.http_post(
    url := 'https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/explore_devotionals',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL',
      'x-pipeline-secret','__SECRET__'),
    body := '{}'::jsonb, timeout_milliseconds := 60000);
$cron$);

select cron.schedule('explore-events-daily', '20 8 * * *', $cron$
  select net.http_post(
    url := 'https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/explore_events',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL',
      'x-pipeline-secret','__SECRET__'),
    body := '{}'::jsonb, timeout_milliseconds := 60000);
$cron$);

select cron.schedule('explore-music-daily', '30 8 * * *', $cron$
  select net.http_post(
    url := 'https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/explore_music',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'Authorization','Bearer sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL',
      'x-pipeline-secret','__SECRET__'),
    body := '{}'::jsonb, timeout_milliseconds := 60000);
$cron$);
