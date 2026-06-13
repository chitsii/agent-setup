---
type: decision
---

# 0001: bd はチケット専用、知識は frontmatter 付き Markdown に貯める

日付: 2026-06-13
ステータス: accepted
対応チケット: agent-setup-i8x

## 文脈

`bd init` が CLAUDE.md に挿入する管理ブロックは「タスク追跡に TodoWrite/TaskCreate を使うな」「永続知識は `bd remember` を使い MEMORY.md を使うな」と指示する。一方、本リポジトリには doc-conventions(frontmatter 付き Markdown の文書規約)があり、Claude Code ハーネス自体もタスク・メモリ機能を持つ。役割の重複と矛盾を解消する必要がある。

## 決定

1. **bd はチケット管理専用**。`bd remember` / `bd memories` は使わない
2. **プロジェクト知識は doc-conventions に従った frontmatter 付き Markdown に貯める**(調査は `report`、決定は `decision`、運用手順は `runbook`)。知識の検索性・鮮度管理・レビュー可能性を文書規約側に一本化する
3. `.beads/` のあるリポジトリではタスク追跡に bd を使い、ハーネスの TodoWrite/TaskCreate はセッション内の使い捨てチェックリスト以外に使わない(管理ブロックの方針を踏襲)
4. CLAUDE.md の管理ブロック自体は編集しない(bd が hash 管理しており更新で戻るため)。本決定が管理ブロックの記述と矛盾する箇所(bd remember の推奨)は、**リポジトリ規約(prompts/beads-tickets.md)側の明文が優先**する

## 結果

- 知識が bd(検索性が低く、チケットのライフサイクルに紐づく)と Markdown に分散しない
- doc-audit の鮮度管理・doc-render の PDF 化が知識文書にそのまま適用できる
- 管理ブロックとの矛盾は「規約優先」の一文で運用上解消(ブロックの書き換えはしない)

## 却下した代替案

- **bd remember に寄せる**: bd の破壊的変更リスクに知識まで巻き込まれる。文書規約(鮮度・型)と二重管理になる
- **管理ブロックを直接編集**: hash 管理のため bd のアップデートで巻き戻り、差分が騒がしくなる
