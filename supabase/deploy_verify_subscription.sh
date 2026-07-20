#!/bin/zsh
# Deploys the verify_subscription edge function to the Crossed Out Supabase project.
# Prereq: `supabase login` with the account that owns wqumwxoiqsiwizlftojq.
# No extra secrets needed — SUPABASE_URL / SUPABASE_ANON_KEY /
# SUPABASE_SERVICE_ROLE_KEY are auto-injected by the edge runtime.
set -e
cd "$(dirname "$0")/.."
supabase functions deploy verify_subscription --project-ref wqumwxoiqsiwizlftojq --no-verify-jwt --use-api
echo "verify_subscription deployed: https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/verify_subscription"
