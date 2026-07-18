#!/bin/zsh
# Deploys the add_church edge function (resolve a YouTube channel and upsert a church).
# Requires YOUTUBE_API_KEY and PIPELINE_SECRET in supabase/.env.local.
set -e
cd "$(dirname "$0")/.."
source supabase/.env.local
supabase secrets set YOUTUBE_API_KEY="$YOUTUBE_API_KEY" PIPELINE_SECRET="$PIPELINE_SECRET" --project-ref wqumwxoiqsiwizlftojq
supabase functions deploy add_church --project-ref wqumwxoiqsiwizlftojq --no-verify-jwt --use-api
echo "add_church deployed."
