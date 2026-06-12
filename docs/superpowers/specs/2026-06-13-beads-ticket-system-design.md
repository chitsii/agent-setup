# 設計: チケット制タスク管理(beads 導入)

日付: 2026-06-13
ステータス: 承認済み
スコープ: サブプロジェクト1/3(チケット制)。「書く型」(ドキュメント規約)と「腐らせない型」(indexion 乖離検出)は後続サブプロジェクト。

## 背景と目的

CLAUDE.md 内の Markdown TODO リストは構造がなく、肥大化し、セッションをまたぐと文脈を失う。開発中に見つけたバグ・改善案をその場でチケット登録し、セッション開始時に着手可能タスクを機械的に取得できる仕組みに置き換える。

ツールには beads(bd, gastownhall/beads, v1.0系)を採用する。選定理由:

- エージェント向け設計(`bd ready` による着手可能タスク検出、依存関係グラフ、ハッシュID によるマージ衝突回避)
- `bd setup claude` / `bd setup codex` による公式統合があり、本リポジトリの Claude/Codex 両対応方針と一致
- ★24.5k、活発に開発中

既知のリスク: 破壊的変更が速い(v1.0 で SQLite+JSONL から Dolt へ全面刷新)。新規導入で v1.0 系から始めることで移行系バグを回避する。

## 方針(案A: 公式ルート最大活用 + 運用規約だけ自前)

beads のインストール・初期化・エージェント統合はすべて公式機能(`brew install beads`, `bd init`, `bd setup claude/codex`)に任せる。スキルやラッパーは作らない。agent-setup が持つのは運用規約(配布物)と導入手順の文書のみ。beads が公式にメンテしている統合層に自前レイヤーを重ねない。

## 段階的導入

グローバル適用の前に、agent-setup リポジトリ完結で試験運用する。

- フェーズ1(今回): agent-setup 内で beads を運用。フック類はプロジェクトレベルに限定
- フェーズ2(後日): 実運用で `bd create`→`bd ready`→`bd close` のループが数セッション回り、不満点が解消されたら、規約をグローバル `~/.claude/CLAUDE.md`(実体 `/mnt/c/Users/tishi/.claude/CLAUDE.md`)へ昇格。昇格作業自体を beads チケットとして登録しておく

## 成果物

| 成果物 | 役割 | 配布物か |
|---|---|---|
| `prompts/beads-tickets.md` | 運用規約の本体。検証後にグローバル CLAUDE.md へ取り込む元ネタ。リポジトリ固有の記述は含めない | 配布物 |
| `agent-setup/CLAUDE.md` への一文 | 「本リポジトリでは `prompts/beads-tickets.md` の規約を試験運用中。タスク管理は bd」という参照のみ。規約本文は書かない | 開発用 |
| `.beads/` | チケットの実体(Dolt embedded)。git にコミットする | リポジトリ内 |
| プロジェクトレベルのフック設定 | `bd setup claude` / `bd setup codex` の成果物 | リポジトリ内 |
| README 追記 | 導入手順1セクション + プロンプト一覧への `beads-tickets.md` 追加 | リポジトリ内 |

注: 本リポジトリの CLAUDE.md はスキル等の開発用であり配布物ではない。配布する規約テキストは必ず `prompts/` に置く。

## 運用規約の骨子(`prompts/beads-tickets.md` の内容)

- セッション開始時: `.beads/` のあるリポジトリでは `bd ready` で着手可能タスクを確認(フックの文脈注入を補助とする)
- 開発中の登録: 作業中に見つけたバグ・改善案・スコープ外の作業は、その場で対応せず `bd create` で登録して本筋に戻る(スコープクリープ防止)
- Markdown TODO の禁止: `.beads/` のあるリポジトリでは CLAUDE.md / README に TODO リストを作らない・育てない
- 着手時は `bd update <id> --claim`、完了時は `bd close <id>`
- 依存関係は `bd dep add <child> <parent>` で表現する
- アップグレード時は `bd info --whats-new` を確認する
- 未導入リポジトリでは無理に使わない。タスク管理の必要が生じたら `bd init` を提案する

## 導入手順

1. `brew install beads`
2. agent-setup で `bd init`(`.beads/` 作成。リモート追加後は `bd dolt push/pull` で同期可能)
3. `bd setup claude` / `bd setup codex` を実行し、それぞれ `--check` で確認。実行前に書き換え対象ファイルを確認し、グローバル設定に書き込む挙動なら手動でプロジェクトレベルに限定する
4. 既存 TODO(未完了6件)を `bd create` で移行。依存関係があるものは `bd dep add`(例: 「README の実URL差し替え」は「GitHub 公開」にブロックされる)
5. CLAUDE.md の TODO セクションを削除し、試験運用宣言の一文に置き換え
6. 「運用規約のグローバル昇格」をチケット登録(受け入れ条件: 数セッションの実運用で不満点が解消されていること)

## 全体像(3サブプロジェクトの関係)

```
[1. チケット制 (beads)] ←─ 本設計のスコープ
        ↑ チケット登録
[3. 腐らせない型 (indexion)] ─ 乖離検出 → bd create でチケット化(将来)
        ↓ 監査対象
[2. 書く型 (ドキュメント規約)] ─ 種類・置き場所・frontmatter(将来)
```

beads がタスクの単一の受け皿となり、indexion の乖離検出結果も人間の思いつきもここに流れ込む。サブプロジェクト2・3 は本設計の完了後、beads チケットとして登録して順次消化する。indexion は採用前提(ユーザー決定)だが、設計はサブプロジェクト3 で行う。

## エラーハンドリング・リスク対応

- beads の破壊的変更: 自前レイヤーを持たないことで影響面を最小化
- `bd setup` の書き換え範囲が不明: 実行前後で対象ファイルの diff を確認・提示する
- 試験運用で beads が合わなかった場合: `.beads/` とフック設定を削除し、チケットを CLAUDE.md TODO に書き戻すだけで撤退できる(成果物がリポジトリ内に閉じているため)

## 実施記録(2026-06-13、beads v1.0.5)

実装は完了。設計時の前提(v1.0.4 時点の調査)と実挙動の差分:

- `bd init` が `bd setup claude` / `bd setup codex` 相当(フック・AGENTS.md・スキル・CLAUDE.md 管理ブロック)を**全自動でプロジェクト配下に導入し、初回コミットまで自動実行**する。導入手順の 3 は不要だった。グローバル設定は書き換えられないことを確認済み
- チケット実体(`.beads/embeddeddolt/`)は **gitignore されており git にコミットされない**。同期は git remote 上の `refs/dolt/data`(`bd dolt push/pull`)。リモート未設定の間の可視性確保として auto-export(`bd config set export.auto true`)を有効化し、`.beads/issues.jsonl` をコミット対象にした
- `bd init` が CLAUDE.md に挿入する管理ブロックの内容が本設計の運用規約と一部重複するため、`prompts/beads-tickets.md` は管理ブロックを補完する横断ルールのみに絞った
- 発見した問題は bd チケットとして起票: auto-export のコミットタイミング問題(agent-setup-bwg)、管理ブロックとハーネス規約の衝突(agent-setup-i8x)

### 追記(同日): ステルスモードへ移行

issues.jsonl のコミット churn(agent-setup-bwg)の根本解決と、公開予定リポジトリへのタスク露出回避のため、ユーザー判断で**ステルス運用**に切り替えた。`.beads/` を git 追跡から除外(`git rm -r --cached` + `.git/info/exclude`)。auto-export はローカルビューア用に有効のまま。これに伴い bwg はクローズ(コミット手順の規約化は不要になった)。エージェント統合ファイル(CLAUDE.md 管理ブロック、.claude/settings.json、.codex/、AGENTS.md)は開発設定としてコミット対象のまま。

### 追記(同日): 人間向けUIとして beads-ui を導入

[mantoni/beads-ui](https://github.com/mantoni/beads-ui) v0.12.0 を `npm install -g beads-ui` で導入。`bdui start --open` で localhost:3000 にカンバン/インライン編集/ライブ更新の Web UI(Dolt 直結、エクスポート不要)。これに伴い auto-export(issues.jsonl)は無効化した。TUI 派の代替は bv([Dicklesworthstone/beads_viewer](https://github.com/Dicklesworthstone/beads_viewer)、要・手動 `bd export`)。選定根拠は beads 公式 COMMUNITY_TOOLS.md の Dolt 対応リスト。

## 検証(実機検証してから完了とする)

1. `bd create` → `bd ready` → `bd close` の一連が動く
2. 新しい Claude セッションで SessionStart フックが beads の文脈を注入する
3. `bd setup codex --check` が通り、Codex 側からも bd が呼べる
4. TODO 移行後、依存関係込みで `bd ready` が正しい着手可能タスクだけを返す(ブロックされたタスクが出ないこと)
