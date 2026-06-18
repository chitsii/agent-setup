# agent-setup 作業ルール

Claude Code / Codex 共用のスキルとプロンプト集を配布するための素材リポジトリ。全体像は README.md を読むこと。

- 個人データ・認証情報は絶対にコミットしない。アーカイブは `~/.local/share/<skill>/`、認証は `~/.config/<skill>/` に逃がす
- `skills/` を追加・改名したら `./install.sh` を再実行し、README.md のスキル一覧表も更新する
- スキルを新規作成・編集するときは superpowers:writing-skills の手順（実機検証してから書く）に従う

## タスク管理

タスクは beads（`bd`）で管理する。Markdown の TODO リストはもう作らない。運用規約は [prompts/beads-tickets.md](prompts/beads-tickets.md) を参照（本リポジトリで試験運用中。検証後にグローバル CLAUDE.md / AGENTS.md へ昇格予定）。セッション開始時は `bd ready`。

## ドキュメント規約

ドキュメントの種類・frontmatter・鮮度管理は [prompts/doc-conventions.md](prompts/doc-conventions.md) を試験運用中（検証後にグローバル昇格予定）。監査は doc-audit スキルで行い、結果は bd に起票する。


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:6cd5cc61 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->
