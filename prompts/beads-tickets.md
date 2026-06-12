---
type: runbook
owner: chitsii
last_reviewed: 2026-06-13
review_cycle_days: 180
watches:
  - .claude/settings.json
  - .codex/hooks.json
---

# beads チケット制タスク管理(CLAUDE.md 断片)

グローバル CLAUDE.md に貼って使う。リポジトリ個別の詳細ルール(コマンドリファレンスやセッション完了プロトコル)は `bd init` が各リポジトリの CLAUDE.md / AGENTS.md に管理ブロックとして自動挿入するので、この断片はそれを補完する横断ルールだけを持つ。

---

## タスク管理(beads)

`.beads/` のあるリポジトリでは、タスク管理に beads(`bd`)を使うこと。詳細は CLAUDE.md 内の beads 管理ブロックと `bd prime` を参照。

### 横断ルール

- **セッション開始時**: `bd ready` で着手可能タスクを確認する(SessionStart フックの文脈注入があればそれを優先し、明示実行は補助とする)
- **開発中の登録**: 作業中に見つけたバグ・改善案・スコープ外の作業は、その場で対応せず `bd create "タイトル" --type=<type> -p <0-3>` で登録して本筋に戻る(スコープクリープ防止)
- **タイプを必ず付ける**: bug(不具合)/ feature(新機能・改善)/ task(一般作業)/ chore(雑務)/ spike(調査)/ decision(方針決定)を `--type` で区別する。一覧は `bd types`。デフォルトの task に頼らない
- **Markdown TODO の禁止**: CLAUDE.md や README に TODO リストを作らない・育てない。タスクはすべて bd へ
- **依存関係**: 順序依存があるタスクは `bd dep add <依存する側> <先に終わるべき側>` で表現する(`bd ready` が正しく機能するために重要)
- **アップグレード時**: `bd info --whats-new` を確認する(破壊的変更が速いツールのため)

### 未導入リポジトリでの振る舞い

`.beads/` が無いリポジトリでは無理に使わない。セッションをまたぐタスクリストが必要になったら `bd init` の実行をユーザーに提案する。なお `bd init` はフック導入・CLAUDE.md / AGENTS.md への追記・初回 git コミットまで自動で行うので、実行前にその旨をユーザーに伝えること。
