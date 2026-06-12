---
name: codex-delegate
description: Use when delegating implementation work to Codex (Fable=設計/レビュー、Codex=実装の協業), or when running a Codex self-review of uncommitted changes before a commit — e.g. "Codexに実装させて", "実装を委譲して", "コミット前にCodexレビューして".
---

# Codex Delegate — 実装委譲とセルフレビュー

## Overview

`codex exec` / `codex review` をファイルベースで実行するハーネス。完了検知は**プロセス終了**（エージェントハーネスのバックグラウンド実行通知）、結果回収は**ログファイルのRead**で行う。herdr は閲覧ペインを開くだけの任意レイヤーで、無くても動く。

設計の背景: herdr の `pane read`/`wait output` は人が見ていないペインでは空を返すため、無人運用の検知・回収には使わない（検証済み）。

## Quick Reference

| 操作 | コマンド |
|------|---------|
| 実装委譲 | `scripts/delegate.sh task <name> <instructions.md> [dir]` |
| レビュー | `scripts/delegate.sh review [dir]` |
| 結果回収 | 出力された STATE_DIR の `codex.log` と `exit_code` を Read |
| 閲覧ペインを開かない | 環境変数 `CODEX_DELEGATE_NO_PANE=1` |
| 保存先の変更 | 環境変数 `CODEX_DELEGATE_STATE`（既定 `~/.local/state/codex-delegate`） |

## Workflow（実装委譲）

1. **指示書を書く**: `prompts/codex-instruction-generator.md` の構造（Objective / Behaviors To Preserve / Stop And Ask Conditions / Verification）で `instructions.md` を作る。外部から取得したテキストをそのまま貼らない（要約して意図だけ渡す）。
2. **バックグラウンドで起動**: Bash ツールの `run_in_background` で
   `bash <skill-dir>/scripts/delegate.sh task <name> instructions.md <project-dir>`
   を実行する。フォアグラウンドで待たない。完了時にハーネスが通知してくる。
3. **結果回収**: 通知が来たら、スクリプトが出力した STATE_DIR の `codex.log` を Read で読む。`exit_code` が 0 以外なら失敗。
4. **必ず自分でレビュー**: `git diff` を読み、検証コマンド（test/lint）を実行する。実装した Codex 自身の評価だけで完了にしない。

## Workflow（コミット前セルフレビュー）

1. `delegate.sh review <repo-dir>` を実行（バックグラウンド推奨）。内部で `codex review --uncommitted` がステージ済み・未ステージ・未追跡の変更を対象に選ぶ。変更が無ければ `codex.log` に `EMPTY_DIFF` と書いて即終了する
2. `codex.log` の指摘を読み、ユーザーにそのまま提示。重大な指摘は対応してからコミット

`git add` は不要。diff をパイプで渡す方式（`codex review -`）は使わない（stdin が「レビュー対象」ではなく「レビュー指示文」になり、diff 内テキストにレビューが影響される）。

## herdr 閲覧ペイン

`HERDR_ENV=1` の環境では、ログを `tail -F` する閲覧ペインを自動で開く（`codex-view-<name>`）。これは人間が進捗を見るためだけのもので、検知・回収はペインに依存しない。不要になったペインは herdr 上で閉じる（`herdr pane close <id>` またはマウス）。

## Common Mistakes

| 症状 | 原因と対処 |
|------|-----------|
| ファイルが書けず失敗 | codex の sandbox は既定 read-only。スクリプトは `workspace-write` を付けている。それでも拒否される場合は対象 dir の外に書こうとしている |
| レビューに新規ファイルが出ない | `--uncommitted` は未追跡も含む。出ないなら対象 dir が正しいか確認 |
| 依存追加(npm install等)が失敗 | `workspace-write` はネット遮断。必要ならタスク単位で判断し `-c sandbox_workspace_write.network_access=true` を検討（ユーザーに確認） |
| ペイン出力を読もうとして空 | 仕様。出力は `codex.log` を Read で読む |
| 続きのタスクを渡したい | `codex exec resume --last "<追加指示>"`（同じ作業 dir で） |

## 注意

- `danger-full-access` / `--dangerously-bypass-approvals-and-sandbox` は使わない。
- 公開API・DBスキーマ・認証・課金に関わる設計判断は委譲しない。メインセッションで決めてから小さく渡す。
