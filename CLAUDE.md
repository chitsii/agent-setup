# agent-setup 作業ルール

Claude Code / Codex 共用のスキルとプロンプト集を配布するための素材リポジトリ。全体像は README.md を読むこと。

- 個人データ・認証情報は絶対にコミットしない。アーカイブは `~/.local/share/<skill>/`、認証は `~/.config/<skill>/` に逃がす
- `skills/` を追加・改名したら `./install.sh` を再実行し、README.md のスキル一覧表も更新する
- スキルを新規作成・編集するときは superpowers:writing-skills の手順（実機検証してから書く）に従う

## TODO

- [x] codex-delegate スキルの実装（ファイルベース設計: 完了検知=プロセス終了通知、回収=ログRead、herdrは閲覧ペインのみ）
- [ ] codex-delegate の herdr 閲覧ペインの使い勝手改善（完了後にペインが残る。自動クローズや完了表示を検討）
- [ ] herdr の `pane read` / `wait output` が無人ペインで空を返す問題の調査（別セッションで実施予定。判明済み: 人が見ているペインなら動く。要確認: ソース実装上の意図か不具合か。リポジトリ: https://github.com/ogulcancelik/herdr ）
- [ ] Codex が `~/.codex/skills/` の symlink スキルを実際に認識するか実機検証
- [x] グローバル `~/.claude/CLAUDE.md` の Codex Review ルールを codex-delegate スキル方式に差し替え（2026-06-13。実体は `/mnt/c/Users/tishi/.claude/CLAUDE.md`、WSL2/Windows共有）
- [ ] prompts/fable-codex-collab.md（役割分担）をグローバル CLAUDE.md にも取り込むか検討
- [ ] GitHub 公開（リモート追加、README の `<this-repo>` を実URLへ差し替え）
- [ ] macOS での install.sh 動作検証（`pwd -P` 化済みだが未検証）

完了した項目は消すか `[x]` にして、肥大化したら整理する。


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
