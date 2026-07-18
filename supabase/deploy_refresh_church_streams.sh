#!/bin/zsh
# Deploys the refresh_church_streams edge function (church live-stream pipeline).
# Requires YOUTUBE_API_KEY and PIPELINE_SECRET in supabase/.env.local.
# NOTE: SUPABASE_SERVICE_ROLE_KEY is auto-injected into hosted edge functions;
# the CLI rejects secrets with the SUPABASE_ prefix, so do NOT set it manually.
set -e
cd "$(dirname "$0")/.."
source supabase/.env.local
supabase secrets set YOUTUBE_API_KEY="$YOUTUBE_API_KEY" PIPELINE_SECRET="$PIPELINE_SECRET" --project-ref wqumwxoiqsiwizlftojq
supabase functions deploy refresh_church_streams --project-ref wqumwxoiqsiwizlftojq --no-verify-jwt --use-api
echo "refresh_church_streams deployed."
