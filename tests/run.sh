#!/usr/bin/env bash
# Repository smoke tests that avoid external services and personal data.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_file_equals() {
  local expected="$1" actual="$2"
  if ! cmp -s "$expected" "$actual"; then
    printf 'expected:\n' >&2
    sed -n '1,120p' "$expected" >&2
    printf 'actual:\n' >&2
    sed -n '1,120p' "$actual" >&2
    fail "file mismatch: $actual"
  fi
}

cd "$ROOT"

bash -n install.sh \
  skills/codex-delegate/scripts/delegate.sh \
  skills/x-bookmarks/scripts/sync.sh \
  tests/run.sh
pass "shell syntax"

python3 -m py_compile \
  skills/doc-audit/scripts/check.py \
  skills/doc-render/scripts/render.py
pass "python syntax"

HOME="$TMPDIR/home" ./install.sh --dry-run > "$TMPDIR/install.out"
grep -q 'link: .*/\.claude/skills/codex-delegate -> .*/skills/codex-delegate' "$TMPDIR/install.out" \
  || fail "install dry-run did not include claude codex-delegate link"
grep -q 'link: .*/\.codex/skills/doc-audit -> .*/skills/doc-audit' "$TMPDIR/install.out" \
  || fail "install dry-run did not include codex doc-audit link"
pass "install dry-run"

mkdir -p "$TMPDIR/audit"
cat > "$TMPDIR/audit/stale.md" <<'EOF'
---
type: readme
owner: docs
last_reviewed: 2000-01-01
---
# Stale
EOF

skills/doc-audit/scripts/check.py "$TMPDIR/audit" > "$TMPDIR/audit.json"
python3 - "$TMPDIR/audit.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    findings = json.load(f)

if not any(
    item.get("file") == "stale.md" and item.get("status") == "stale"
    for item in findings
):
    raise SystemExit(f"missing stale finding: {findings!r}")
PY
pass "doc-audit fixture"

if python3 skills/doc-render/scripts/render.py > "$TMPDIR/render.out" 2> "$TMPDIR/render.err"; then
  fail "doc-render without args should fail with usage"
fi
grep -q 'usage: render.py <input.md> \[output.pdf\]' "$TMPDIR/render.err" \
  || fail "doc-render usage output changed"
pass "doc-render usage"

mkdir -p "$TMPDIR/bin" "$TMPDIR/repo"
cat > "$TMPDIR/bin/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${CODEX_STUB_LOG:?}"
EOF
chmod +x "$TMPDIR/bin/codex"

cat > "$TMPDIR/bin/herdr" <<'EOF'
#!/usr/bin/env bash
[ -z "${HERDR_STUB_LOG:-}" ] || printf '%s\n' "$*" >> "$HERDR_STUB_LOG"
case "${1:-}:${2:-}" in
  agent:start)
    printf '{"id":"cli:agent:start","result":{"agent":{"pane_id":"%s"}}}\n' "${HERDR_STUB_PANE_ID:-pane-test}"
    ;;
  pane:close)
    [ -z "${HERDR_CLOSE_LOG:-}" ] || printf '%s\n' "${3:-}" >> "$HERDR_CLOSE_LOG"
    ;;
esac
EOF
chmod +x "$TMPDIR/bin/herdr"

default_review_tmp="$TMPDIR/review-tmp"
env \
  CODEX_STUB_LOG="$TMPDIR/default-review.args" \
  TMPDIR="$default_review_tmp" \
  PATH="$TMPDIR/bin:$PATH" \
  bash skills/codex-delegate/scripts/delegate.sh review --base main "$TMPDIR/repo" > "$TMPDIR/default-review.state"
default_review_state="$(cat "$TMPDIR/default-review.state")"
case "$default_review_state" in
  "$default_review_tmp"/codex-delegate-review-*/????????-??????-review) ;;
  *) fail "delegate review default state was not under TMPDIR: $default_review_state" ;;
esac
cat > "$TMPDIR/default-review.expected" <<'EOF'
review
--base
main
EOF
assert_file_equals "$TMPDIR/default-review.expected" "$TMPDIR/default-review.args"

CODEX_STUB_LOG="$TMPDIR/base.args" \
CODEX_DELEGATE_STATE="$TMPDIR/state-base" \
PATH="$TMPDIR/bin:$PATH" \
  bash skills/codex-delegate/scripts/delegate.sh review --base main "$TMPDIR/repo" > "$TMPDIR/base.state"
case "$(cat "$TMPDIR/base.state")" in
  "$TMPDIR/state-base"/????????-??????-review) ;;
  *) fail "delegate review ignored CODEX_DELEGATE_STATE override" ;;
esac
cat > "$TMPDIR/base.expected" <<'EOF'
review
--base
main
EOF
assert_file_equals "$TMPDIR/base.expected" "$TMPDIR/base.args"

CODEX_STUB_LOG="$TMPDIR/commit.args" \
CODEX_DELEGATE_STATE="$TMPDIR/state-commit" \
PATH="$TMPDIR/bin:$PATH" \
  bash skills/codex-delegate/scripts/delegate.sh review --commit abc123 "$TMPDIR/repo" > "$TMPDIR/commit.state"
cat > "$TMPDIR/commit.expected" <<'EOF'
review
--commit
abc123
EOF
assert_file_equals "$TMPDIR/commit.expected" "$TMPDIR/commit.args"

CODEX_STUB_LOG="$TMPDIR/herdr-review.args" \
CODEX_DELEGATE_STATE="$TMPDIR/state-herdr" \
HERDR_ENV=1 \
HERDR_STUB_LOG="$TMPDIR/herdr-review.herdr" \
HERDR_CLOSE_LOG="$TMPDIR/herdr-review.closed" \
HERDR_STUB_PANE_ID="pane-review-123" \
PATH="$TMPDIR/bin:$PATH" \
  bash skills/codex-delegate/scripts/delegate.sh review --base main "$TMPDIR/repo" > "$TMPDIR/herdr-review.state"
case "$(cat "$TMPDIR/herdr-review.state")" in
  "$TMPDIR/state-herdr"/????????-??????-review) ;;
  *) fail "delegate review leaked herdr output into state dir output" ;;
esac
grep -q '^agent start codex-view-review ' "$TMPDIR/herdr-review.herdr" \
  || fail "delegate review did not open herdr viewer"
grep -q '^pane close pane-review-123$' "$TMPDIR/herdr-review.herdr" \
  || fail "delegate review did not close herdr viewer"
grep -q '^pane-review-123$' "$TMPDIR/herdr-review.closed" \
  || fail "delegate review closed the wrong herdr pane"

if CODEX_STUB_LOG="$TMPDIR/conflict.args" \
  CODEX_DELEGATE_STATE="$TMPDIR/state-conflict" \
  PATH="$TMPDIR/bin:$PATH" \
  bash skills/codex-delegate/scripts/delegate.sh review --base main --commit abc123 "$TMPDIR/repo" \
  > "$TMPDIR/conflict.out" 2> "$TMPDIR/conflict.err"; then
  fail "delegate review accepted conflicting targets"
fi
grep -q 'choose only one review target' "$TMPDIR/conflict.err" \
  || fail "delegate review conflict error changed"
pass "codex-delegate review targets"
