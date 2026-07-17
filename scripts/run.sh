#!/usr/bin/env bash
# One-command runner for the Crossed Out data pipeline.
# Usage:
#   ./scripts/run.sh tag            # embed + AI-tag the whole Bible (full run)
#   ./scripts/run.sh tag --limit 200   # small test run
#   ./scripts/run.sh review         # review/promote pending AI tags
#   ./scripts/run.sh review --limit 200
set -euo pipefail
cd "$(dirname "$0")/.."

# 1) venv
if [ ! -d .venv ]; then
  echo "Creating .venv ..."; python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -c "import openai, psycopg" 2>/dev/null || pip install openai "psycopg[binary]"

# 2) OpenAI key from the git-ignored supabase/.env.local
export OPENAI_API_KEY="$(grep -E '^OPENAI_API_KEY=' supabase/.env.local | cut -d= -f2-)"

# 3) DATABASE_URL (+ optional TAG_MODEL / REVIEW_MODEL) from a git-ignored file you create once
if [ -f scripts/.env.run ]; then
  set -a; # shellcheck disable=SC1091
  source scripts/.env.run; set +a
fi

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: DATABASE_URL is not set. Run:  cp scripts/.env.run.example scripts/.env.run  and put your DB password in it."; exit 1
fi
if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "ERROR: OPENAI_API_KEY not found in supabase/.env.local"; exit 1
fi

cmd="${1:-tag}"; shift || true
case "$cmd" in
  tag)    exec python scripts/tag_bible.py "$@" ;;
  review) exec python scripts/review_tags.py "$@" ;;
  *) echo "Usage: ./scripts/run.sh [tag|review] [args]"; exit 1 ;;
esac
