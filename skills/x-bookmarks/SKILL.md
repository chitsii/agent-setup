---
name: x-bookmarks
description: Use when the user asks to fetch, sync, or search their own X (Twitter) bookmarks — e.g. "ブックマークを検索して", "Xのブックマークから〇〇を探して", "ブックマークを同期/取得して". Not for general X/Twitter keyword search of public posts.
---

# X Bookmarks — 自分のブックマークのローカル検索

## Overview

`twitter-cli`（Cookie認証・非公式）で自分のXブックマークをローカルのJSONLアーカイブに同期し、検索はアーカイブに対して行う。XのブックマークはAPI無料枠・公式エクスポートが存在しないため、「同期してローカル検索」が基本方針。

## Quick Reference

| 操作 | コマンド |
|------|---------|
| 認証確認 | `set -a; . ~/.config/x-bookmarks/auth.env; set +a; twitter status`（`ok: true` なら認証済み） |
| 同期（差分取得） | `bash scripts/sync.sh`（デフォルト100件取得→マージ） |
| 初回同期（全量） | `bash scripts/sync.sh 800` |
| 検索 | `jq -c 'select(.text \| test("KEYWORD"; "i"))' "$BM"` |
| 個別ツイート詳細 | `twitter tweet <id> --yaml` または `https://x.com/i/web/status/<id>` |

`scripts/` はこのスキルのディレクトリ基準。アーカイブはリポジトリ外に置く（個人データを配布物に含めないため）:

```bash
BM="${X_BOOKMARKS_FILE:-${XDG_DATA_HOME:-$HOME/.local/share}/x-bookmarks/bookmarks.jsonl}"
```

検索の前にこの `BM` を定義してから下記コマンドを使う。

## Workflow

1. **認証確認**: 上記 Quick Reference の認証確認コマンド（auth.env を source してから `twitter status`）。`not_authenticated` なら下記 Auth Setup をユーザーに案内（Cookie値はユーザーしか取得できない）。
2. **同期**: `bash scripts/sync.sh [件数]`。ID重複は自動排除されるので何度実行してもよい。
3. **検索**: `"$BM"` は1行=1ツイートのJSON。主なフィールド: `id`, `text`, `author.screenName`, `author.name`, `createdAtISO`, `urls`, `media`, `metrics.likes`。
   - キーワード: `jq -c 'select(.text | test("rust|cargo"; "i"))' "$BM"`
   - 投稿者: `jq -c 'select(.author.screenName == "USER")' "$BM"`
   - 期間: `jq -c 'select(.createdAtISO >= "2026-01")' "$BM"`
   - 曖昧な依頼なら全件の `text` を読んで意味的に選んでもよい（数百件程度なら直接読める）。
4. **結果提示**: 各ヒットに `https://x.com/<screenName>/status/<id>` 形式のリンクを付ける。

## Auth Setup（初回のみ・ユーザー作業）

WSL2ではブラウザCookieの自動抽出が**必ず失敗する**（ブラウザはWindows側のため）。手動設定が必要:

1. Windowsのブラウザで x.com にログイン → DevTools → Application → Cookies → `auth_token` と `ct0` の値をコピー
2. 認証ファイルを作成:
   ```bash
   mkdir -p ~/.config/x-bookmarks
   cat > ~/.config/x-bookmarks/auth.env <<'EOF'
   TWITTER_AUTH_TOKEN=<auth_tokenの値>
   TWITTER_CT0=<ct0の値>
   EOF
   chmod 600 ~/.config/x-bookmarks/auth.env
   ```
3. 認証を確認（`twitter status` 単体では env を読まないので、source してから実行する）:
   ```bash
   set -a; . ~/.config/x-bookmarks/auth.env; set +a
   twitter status   # ok: true なら成功
   ```

`sync.sh` はこのファイルを自動で読み込むので、同期時の source は不要。

## Common Mistakes

| 症状 | 原因と対処 |
|------|-----------|
| `No Twitter cookies found` | WSL2のCookie自動抽出失敗。auth.env を設定する（上記） |
| 403 / 認証エラーが再発 | `ct0` はローテーションする。ブラウザから再取得して auth.env を更新 |
| 同期が遅い・レート制限 | 初回以降は件数を小さく（`sync.sh 50` 程度）。短時間の連続実行を避ける |
| 検索ヒットなし | まず同期したか確認。アーカイブは同期時点のスナップショット |

## 注意

- 非公式アクセス（Cookie認証）はX利用規約上グレー。自分のデータの読み取りのみに使い、高頻度実行を避ける。
- アーカイブと認証情報はリポジトリ外（`~/.local/share/x-bookmarks/`, `~/.config/x-bookmarks/`）。このスキルは配布素材であり、個人データを一切含めない。
- Codexから使う場合も同じ構成で動く（`scripts/sync.sh` + jq はエージェント非依存）。
