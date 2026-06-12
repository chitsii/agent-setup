#!/usr/bin/env bash
# Delegate implementation work or a self-review to Codex (file-based).
# Completion detection = process exit: run this via the agent harness's
# background execution and get notified when it finishes. No polling.
# herdr is optional visualization only (a viewer pane tailing the log).
#
# Usage:
#   delegate.sh task <name> <instructions-file> [project-dir]
#   delegate.sh review [project-dir]
#
# Prints the state dir. Artifacts inside it:
#   codex.log        full codex output
#   exit_code        codex exit status
#   instructions.md  copy of the instructions (task mode)
set -euo pipefail

MODE="${1:?usage: delegate.sh task <name> <instructions.md> [dir] | review [dir]}"
STATE_ROOT="${CODEX_DELEGATE_STATE:-$HOME/.local/state/codex-delegate}"

command -v codex >/dev/null 2>&1 || { echo "error: codex CLI not found" >&2; exit 1; }

# Viewer pane is best-effort: skipped outside herdr or when disabled.
open_viewer() { # $1=label $2=logfile
  [ "${HERDR_ENV:-0}" = "1" ] || return 0
  [ "${CODEX_DELEGATE_NO_PANE:-0}" = "1" ] && return 0
  herdr agent start "codex-view-$1" --no-focus --cwd "$PWD" -- \
    tail -n +1 -F "$2" >/dev/null 2>&1 || true
}

case "$MODE" in
  task)
    NAME="${2:?task name}"
    INSTR="${3:?instructions file}"
    DIR="${4:-$PWD}"
    [ -f "$INSTR" ] || { echo "error: instructions file not found: $INSTR" >&2; exit 1; }
    # Read instructions before any cd: INSTR may be relative to the launch dir, not DIR.
    PROMPT="$(cat "$INSTR")"
    STATE_DIR="$STATE_ROOT/$(date +%Y%m%d-%H%M%S)-$NAME"
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
    DIR="${2:-$PWD}"
    # Check cleanliness BEFORE creating state artifacts: if CODEX_DELEGATE_STATE
    # points inside the repo, creating them first would make a clean tree look dirty.
    CLEAN=0
    [ -z "$(git -C "$DIR" status --porcelain)" ] && CLEAN=1
    STATE_DIR="$STATE_ROOT/$(date +%Y%m%d-%H%M%S)-review"
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
    rc=0
    # `--uncommitted` selects staged+unstaged+untracked as the review TARGET.
    # Do NOT pipe a diff to `codex review -`: that treats it as instructions,
    # not as the target, and lets diff text influence the review.
    (cd "$DIR" && codex review --uncommitted) >"$LOG" 2>&1 || rc=$?
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    exit 2
    ;;
esac

echo "$rc" > "$STATE_DIR/exit_code"
echo "$STATE_DIR"
exit "$rc"
