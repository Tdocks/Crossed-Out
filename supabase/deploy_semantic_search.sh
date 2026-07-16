#!/usr/bin/env bash
# Deploys the semantic_search edge function to the Crossed Out Supabase project.
# Prereq: `supabase login` with the account that owns wqumwxoiqsiwizlftojq.
# Reads OPENAI_API_KEY from supabase/.env.local (git-ignored).
set -e
cd "$(dirname "$0")/.."
source supabase/.env.local
supabase secrets set OPENAI_API_KEY="$OPENAI_API_KEY" --project-ref wqumwxoiqsiwizlftojq
supabase functions deploy semantic_search --project-ref wqumwxoiqsiwizlftojq --no-verify-jwt --use-api
echo "semantic_search deployed: https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/semantic_search"
