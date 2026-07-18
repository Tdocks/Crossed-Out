#!/bin/zsh
# Add a church to Crossed Out by its YouTube handle, channel URL, or channel id.
# The add_church edge function resolves the channel (name, thumbnail, id),
# upserts the church, ensures it shows in Attend, and does an immediate live check.
#
# Usage:
#   ./scripts/add_church.sh "<@handle | youtube url | UC...id>" ["City"] ["Denomination"] ["Style"]
# Examples:
#   ./scripts/add_church.sh "@elevationchurch" "Charlotte, NC" "Non-denominational"
#   ./scripts/add_church.sh "https://www.youtube.com/@lifechurch"
#   ./scripts/add_church.sh "UCoDt562cJaageYU-LYKt4Pw" "Edmond, OK"

set -e
cd "$(dirname "$0")/.."

if [ -z "$1" ]; then
  echo 'Usage: ./scripts/add_church.sh "<@handle | youtube url | UC...id>" ["City"] ["Denomination"] ["Style"]'
  echo 'Example: ./scripts/add_church.sh "@elevationchurch" "Charlotte, NC" "Non-denominational"'
  exit 1
fi

source supabase/.env.local
if [ -z "$PIPELINE_SECRET" ]; then
  echo "PIPELINE_SECRET is not set in supabase/.env.local"; exit 1
fi

INPUT="$1"
BODY="{\"input\":\"$INPUT\""
[ -n "$2" ] && BODY="$BODY,\"city\":\"$2\""
[ -n "$3" ] && BODY="$BODY,\"denomination\":\"$3\""
[ -n "$4" ] && BODY="$BODY,\"style\":\"$4\""
BODY="$BODY}"

echo "Adding church: $INPUT ..."
RESP=$(curl -s -X POST "https://wqumwxoiqsiwizlftojq.supabase.co/functions/v1/add_church" \
  -H "Authorization: Bearer sb_publishable_W6kfGB2XfRAYvV_kfe_tWA_NiAdhZmL" \
  -H "x-pipeline-secret: $PIPELINE_SECRET" \
  -H "Content-Type: application/json" -d "$BODY")

# Pretty-print if possible; fall back to raw.
echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"
