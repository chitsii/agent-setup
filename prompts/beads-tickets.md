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

### Epic(マイルストーン)の使い方

- Epic は「完了するとリポジトリ/運用の状態が一段変わるマイルストーン」を表す。機能領域やディレクトリ単位では切らない
- `bd create "Epic: <成果>" --type epic --acceptance "<完了条件>"` — **完了条件を必ず書く**(書けないならまだ Epic にする段階ではない)
- 子チケットは `--parent <epic-id>`(新規)または `bd update <id> --parent <epic-id>`(既存)で紐付け。子同士の順序依存は従来通り `bd dep add`
- 規模目安は子 2〜10件。**単発タスクを無理に Epic に入れない**(構造化自体がコストになる)
- 進捗は `bd epic status`、全子完了後は `bd epic close-eligible` でクローズ

### bd の守備範囲(知識は bd に入れない)

- **bd はチケット管理専用**。`bd remember` / `bd memories` は使わない。プロジェクト知識(調査報告・決定・運用手順)は文書規約(doc-conventions)に従った frontmatter 付き Markdown に書く
- `bd init` の管理ブロックが `bd remember` を推奨していても、本規約が優先する(ブロック自体は hash 管理のため編集しない)

### 既知の注意点

- **階層親(`--parent`)は parent-child 依存と同一表現**(bd v1.0.5 実測)。`bd dep remove <child> <epic>` は Epic の親子リンクごと消すので、Epic 配下の子に対する依存操作は `bd show` で親が残っているか確認する

### 未導入リポジトリでの振る舞い

`.beads/` が無いリポジトリでは無理に使わない。セッションをまたぐタスクリストが必要になったら `bd init` の実行をユーザーに提案する。なお `bd init` はフック導入・CLAUDE.md / AGENTS.md への追記・初回 git コミットまで自動で行うので、実行前にその旨をユーザーに伝えること。
