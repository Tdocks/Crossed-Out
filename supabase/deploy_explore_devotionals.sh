#!/bin/zsh
# Deploys the explore_devotionals edge function (Explore → Devotionals ingestion).
# Requires PIPELINE_SECRET in supabase/.env.local. Public RSS — no API key needed.
# NOTE: SUPABASE_SERVICE_ROLE_KEY is auto-injected into hosted edge functions;
# the CLI rejects secrets with the SUPABASE_ prefix, so do NOT set it manually.
set -e
cd "$(dirname "$0")/.."
source supabase/.env.local
supabase secrets set PIPELINE_SECRET="$PIPELINE_SECRET" --project-ref wqumwxoiqsiwizlftojq
supabase functions deploy explore_devotionals --project-ref wqumwxoiqsiwizlftojq --no-verify-jwt --use-api
echo "explore_devotionals deployed."
