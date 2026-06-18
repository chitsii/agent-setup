---
type: runbook
owner: chitsii
last_reviewed: 2026-06-14
review_cycle_days: 180
watches:
  - skills/doc-audit/**
---

# ドキュメント規約(CLAUDE.md / AGENTS.md 断片)

グローバル CLAUDE.md / AGENTS.md、または各リポジトリの CLAUDE.md / AGENTS.md に貼って使う。検出の実行系は doc-audit スキル(agent-setup リポジトリ)が担う。

## 原則: 腐る対象を減らす

網羅的な説明やコードの要約は書かない(エージェントが都度コードから生成できる)。書くのは**コードから復元できないもの** — 意図、却下した代替案、決定の経緯、運用手順。

## 文書の種類(frontmatter の `type:` で宣言)

| type | 性質 | 既定の置き場所 | 鮮度管理 |
|---|---|---|---|
| `spec` | 記録 | `docs/specs/YYYY-MM-DD-<topic>.md` | 不要 |
| `plan` | 記録 | `docs/plans/YYYY-MM-DD-<topic>.md` | 不要 |
| `decision` | 記録 | `docs/decisions/NNNN-<topic>.md`(MADR v4 準拠) | 不要 |
| `handoff` | 記録 | 使用するハンドオフツールの既定に従う | 不要 |
| `report` | 記録 | `docs/reports/YYYY-MM-DD-<topic>.md`(調査報告・検証記録) | 不要 |
| `runbook` | 生きた文書 | `docs/runbooks/<topic>.md` | **必須** |
| `readme` | 生きた文書 | リポジトリ直下・各ディレクトリ | **必須**(直下 README.md のみ frontmatter 省略可) |

- 置き場所は迷わないための既定。リポジトリや既存ツール(superpowers の `docs/superpowers/specs/` 等)に確立済みの場所があればそちらを優先してよい。**判定は type のみで行われ、場所は問わない**
- CLAUDE.md / AGENTS.md 断片・運用規約のような配布断片は `runbook` 扱い
- **記録は不変**: 間違いや実態との乖離は本文を書き換えず「追記(実施記録・訂正)」で正す

## 生きた文書の frontmatter

```yaml
---
type: runbook
owner: <名前。既定は git config user.name>
last_reviewed: 2026-06-13
review_cycle_days: 90   # 省略時の既定: runbook 90日 / readme 180日
watches:                # この文書が依存するコードパス(glob、任意)
  - install.sh
  - scripts/**
---
```

- `owner`: レビュー責任の明示(名前を出すことが文化定着に効く)
- `watches`: 文書が前提にしているコード。ここが last_reviewed より後に変わったら見直しの合図
- レビューして実態と合っていれば `last_reviewed` を今日に更新するだけでよい

## 監査

鮮度切れ・乖離の検出は doc-audit スキル(`/doc-audit`)が行い、対応が必要なものは bd チケットに落ちる。機能完成やセッション終了の節目に実行する。
