#!/bin/zsh
# Deploys the explore_music edge function (Explore → Music ingestion).
# Requires in supabase/.env.local:
#   APPLE_MUSIC_PRIVATE_KEY  (full .p8 PEM contents, quoted / multi-line ok)
#   APPLE_MUSIC_KEY_ID       (10-char MusicKit Key ID)
#   APPLE_MUSIC_TEAM_ID      (10-char Apple Developer Team ID)
#   PIPELINE_SECRET
# NOTE: SUPABASE_SERVICE_ROLE_KEY is auto-injected into hosted edge functions;
# the CLI rejects secrets with the SUPABASE_ prefix, so do NOT set it manually.
set -e
cd "$(dirname "$0")/.."
source supabase/.env.local
supabase secrets set \
  APPLE_MUSIC_PRIVATE_KEY="$APPLE_MUSIC_PRIVATE_KEY" \
  APPLE_MUSIC_KEY_ID="$APPLE_MUSIC_KEY_ID" \
  APPLE_MUSIC_TEAM_ID="$APPLE_MUSIC_TEAM_ID" \
  PIPELINE_SECRET="$PIPELINE_SECRET" \
  --project-ref wqumwxoiqsiwizlftojq
supabase functions deploy explore_music --project-ref wqumwxoiqsiwizlftojq --no-verify-jwt --use-api
echo "explore_music deployed."
