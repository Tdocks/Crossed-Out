#!/bin/zsh
# Deploys the devotional_suggest edge function (G19 Tier 3 AI suggestion).
# Prereq: `supabase login` with the account that owns wqumwxoiqsiwizlftojq.
# Reads OPENAI_API_KEY from supabase/.env.local (git-ignored).
set -e
cd "$(dirname "$0")/.."
source supabase/.env.local
supabase secrets set OPENAI_API_KEY="$OPENAI_API_KEY" --project-ref wqumwxoiqsiwizlftojq
supabase functions deploy devotional_suggest --project-ref wqumwxoiqsiwizlftojq --no-verify-jwt --use-api
echo "devotional_suggest deployed: https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/devotional_suggest"
