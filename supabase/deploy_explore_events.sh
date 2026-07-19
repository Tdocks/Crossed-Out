#!/bin/zsh
# Deploys the explore_events edge function (Explore → Events ingestion).
# Requires TICKETMASTER_API_KEY and PIPELINE_SECRET in supabase/.env.local.
# NOTE: SUPABASE_SERVICE_ROLE_KEY is auto-injected into hosted edge functions;
# the CLI rejects secrets with the SUPABASE_ prefix, so do NOT set it manually.
set -e
cd "$(dirname "$0")/.."
source supabase/.env.local
supabase secrets set TICKETMASTER_API_KEY="$TICKETMASTER_API_KEY" PIPELINE_SECRET="$PIPELINE_SECRET" --project-ref wqumwxoiqsiwizlftojq
supabase functions deploy explore_events --project-ref wqumwxoiqsiwizlftojq --no-verify-jwt --use-api
echo "explore_events deployed."
