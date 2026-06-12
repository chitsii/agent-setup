#!/usr/bin/env bash
# Sync own X (Twitter) bookmarks into a local JSONL archive, deduplicated by tweet id.
# Usage: sync.sh [MAX]   (MAX = number of bookmarks to fetch, default 100)
set -euo pipefail

# Archive lives outside the repo (this skill is distributed material; no personal data inside).
DATA_FILE="${X_BOOKMARKS_FILE:-${XDG_DATA_HOME:-$HOME/.local/share}/x-bookmarks/bookmarks.jsonl}"
AUTH_ENV="${X_BOOKMARKS_AUTH_ENV:-$HOME/.config/x-bookmarks/auth.env}"
MAX="${1:-100}"

# Cookie auto-extraction fails on WSL2 (browser lives on Windows side),
# so credentials are loaded from an env file when present.
if [ -f "$AUTH_ENV" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$AUTH_ENV"
  set +a
fi

if ! command -v twitter >/dev/null 2>&1; then
  echo "error: twitter-cli not found. Install with: uv tool install twitter-cli" >&2
  exit 1
fi

mkdir -p "$(dirname "$DATA_FILE")"
touch "$DATA_FILE"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

if ! twitter bookmarks -n "$MAX" --json > "$tmpdir/fetch.json" \
   || ! jq -e 'if type == "array" then true else .ok end' "$tmpdir/fetch.json" >/dev/null; then
  echo "error: bookmark fetch failed. Run 'twitter status' to check authentication." >&2
  echo "hint: set TWITTER_AUTH_TOKEN / TWITTER_CT0 in $AUTH_ENV (see SKILL.md)." >&2
  exit 1
fi

before="$(wc -l < "$DATA_FILE")"

# Output is either a bare tweet array or an {ok, data: [...]} envelope.
# Merge: existing lines first, new fetch last, keep the newest copy per id.
{ cat "$DATA_FILE"; jq -c 'if type == "array" then .[] else .data[] end' "$tmpdir/fetch.json"; } \
  | jq -s -c 'group_by(.id) | map(.[-1]) | sort_by(.createdAtISO // .createdAt) | .[]' \
  > "$tmpdir/merged.jsonl"

mv "$tmpdir/merged.jsonl" "$DATA_FILE"
after="$(wc -l < "$DATA_FILE")"
echo "synced: $((after - before)) new, $after total -> $DATA_FILE"
