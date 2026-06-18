#!/usr/bin/env bash
# Delegate implementation work or a self-review to Codex (file-based).
# Completion detection = process exit: run this via the agent harness's
# background execution and get notified when it finishes. No polling.
# herdr is optional visualization only (a viewer pane tailing the log).
#
# Usage:
#   delegate.sh task <name> <instructions-file> [project-dir]
#   delegate.sh review [--base <branch>|--commit <sha>] [project-dir]
#
# Prints the state dir. Artifacts inside it:
#   codex.log        full codex output
#   exit_code        codex exit status
#   instructions.md  copy of the instructions (task mode)
set -euo pipefail

MODE="${1:?usage: delegate.sh task <name> <instructions.md> [dir] | review [--base <branch>|--commit <sha>] [dir]}"
shift
TASK_STATE_ROOT="${CODEX_DELEGATE_STATE:-$HOME/.local/state/codex-delegate}"
if [ "${CODEX_DELEGATE_STATE+x}" ]; then
  REVIEW_STATE_ROOT="$CODEX_DELEGATE_STATE"
else
  REVIEW_STATE_ROOT="${CODEX_DELEGATE_REVIEW_STATE:-${TMPDIR:-/tmp}/codex-delegate-review-${USER:-user}}"
fi

command -v codex >/dev/null 2>&1 || { echo "error: codex CLI not found" >&2; exit 1; }

# Viewer pane is best-effort: skipped outside herdr or when disabled.
VIEWER_PANE_ID=""
open_viewer() { # $1=label $2=logfile
  [ "${HERDR_ENV:-0}" = "1" ] || return 0
  [ "${CODEX_DELEGATE_NO_PANE:-0}" = "1" ] && return 0
  local viewer_json
  viewer_json="$(
    herdr agent start "codex-view-$1" --no-focus --cwd "$PWD" -- \
      tail -n +1 -F "$2" 2>/dev/null
  )" || return 0
  VIEWER_PANE_ID="$(printf '%s\n' "$viewer_json" | sed -n 's/.*"pane_id":"\([^"]*\)".*/\1/p' | head -n 1)"
}

close_viewer() {
  [ -n "$VIEWER_PANE_ID" ] || return 0
  herdr pane close "$VIEWER_PANE_ID" >/dev/null 2>&1 || true
  VIEWER_PANE_ID=""
}

case "$MODE" in
  task)
    NAME="${1:?task name}"
    INSTR="${2:?instructions file}"
    DIR="${3:-$PWD}"
    [ -f "$INSTR" ] || { echo "error: instructions file not found: $INSTR" >&2; exit 1; }
    # Read instructions before any cd: INSTR may be relative to the launch dir, not DIR.
    PROMPT="$(cat "$INSTR")"
    STATE_DIR="$TASK_STATE_ROOT/$(date +%Y%m%d-%H%M%S)-$NAME"
    mkdir -p "$STATE_DIR"
    LOG="$STATE_DIR/codex.log"
    cp "$INSTR" "$STATE_DIR/instructions.md"
    touch "$LOG"
    open_viewer "$NAME" "$LOG"
    rc=0
    (cd "$DIR" && codex exec --skip-git-repo-check --sandbox workspace-write \
      "$PROMPT") >"$LOG" 2>&1 || rc=$?
    ;;
  review)
    DIR="$PWD"
    HAS_DIR=0
    REVIEW_ARGS=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --base)
          [ "${2:-}" ] || { echo "error: --base requires a branch" >&2; exit 2; }
          [ "${#REVIEW_ARGS[@]}" = 0 ] || { echo "error: choose only one review target" >&2; exit 2; }
          REVIEW_ARGS=(--base "$2")
          shift 2
          ;;
        --commit)
          [ "${2:-}" ] || { echo "error: --commit requires a sha" >&2; exit 2; }
          [ "${#REVIEW_ARGS[@]}" = 0 ] || { echo "error: choose only one review target" >&2; exit 2; }
          REVIEW_ARGS=(--commit "$2")
          shift 2
          ;;
        --)
          shift
          [ "$#" -le 1 ] || { echo "error: too many positional arguments" >&2; exit 2; }
          if [ "$#" -eq 1 ]; then
            [ "$HAS_DIR" = 0 ] || { echo "error: too many positional arguments" >&2; exit 2; }
            DIR="$1"
          fi
          break
          ;;
        -*)
          echo "unknown review option: $1" >&2
          exit 2
          ;;
        *)
          [ "$HAS_DIR" = 0 ] || { echo "error: too many positional arguments" >&2; exit 2; }
          DIR="$1"
          HAS_DIR=1
          shift
          ;;
      esac
    done
    if [ "${#REVIEW_ARGS[@]}" = 0 ]; then
      REVIEW_ARGS=(--uncommitted)
      # Check cleanliness BEFORE creating state artifacts: if CODEX_DELEGATE_STATE
      # points inside the repo, creating them first would make a clean tree look dirty.
      CLEAN=0
      [ -z "$(git -C "$DIR" status --porcelain)" ] && CLEAN=1
    else
      CLEAN=0
    fi
    STATE_DIR="$REVIEW_STATE_ROOT/$(date +%Y%m%d-%H%M%S)-review"
    mkdir -p "$STATE_DIR"
    LOG="$STATE_DIR/codex.log"
    if [ "$CLEAN" = 1 ]; then
      echo "EMPTY_DIFF" > "$LOG"
      echo "0" > "$STATE_DIR/exit_code"
      echo "$STATE_DIR"
      exit 0
    fi
    touch "$LOG"
    open_viewer review "$LOG"
    trap 'close_viewer' EXIT HUP INT TERM
    rc=0
    # Review flags select the TARGET. Do NOT pipe a diff to `codex review -`:
    # that treats it as instructions, not as the target, and lets diff text
    # influence the review.
    (cd "$DIR" && codex review "${REVIEW_ARGS[@]}") >"$LOG" 2>&1 || rc=$?
    close_viewer
    trap - EXIT HUP INT TERM
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    exit 2
    ;;
esac

echo "$rc" > "$STATE_DIR/exit_code"
echo "$STATE_DIR"
exit "$rc"
