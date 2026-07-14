#!/bin/zsh
# Deploys the Kyra edge function to the Crossed Out Supabase project.
# Prereq: `supabase login` with the account that owns wqumwxoiqsiwizlftojq.
# Reads OPENAI_API_KEY from supabase/.env.local (git-ignored).
set -e
cd "$(dirname "$0")/.."
source supabase/.env.local
supabase secrets set OPENAI_API_KEY="$OPENAI_API_KEY" --project-ref wqumwxoiqsiwizlftojq
supabase functions deploy kyra --project-ref wqumwxoiqsiwizlftojq --no-verify-jwt --use-api
echo "Kyra deployed: https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/kyra"
