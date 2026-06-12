---
name: doc-audit
description: "Use when auditing document freshness — ドキュメントの鮮度切れ(stale)や code↔docs 乖離(drift)を検出して bd チケット化するとき。トリガー例: 「/doc-audit」「ドキュメント監査して」「docs が古くなってないか確認して」、機能完成・セッション終了の節目。"
---

# doc-audit

ドキュメント規約(doc-conventions)の「生きた文書」(frontmatter `type: runbook|readme`)を機械監査し、グレーゾーンだけ判定して bd チケットに落とす。文書の修正はしない(直すのはチケット消化時)。例外は `last_reviewed` の更新のみ。

## 手順

1. **決定論層を実行**(対象リポジトリのルートで):

   ```bash
   "$(find ~/.claude/skills/doc-audit ~/.codex/skills/doc-audit -name check.py 2>/dev/null | head -1)" .
   ```

   uv が必要(PEP 723 で PyYAML を自動解決)。出力は JSON 配列。

2. **status ごとに処理**:
   - `violation`(frontmatter 不備)/ `stale`(期限切れ): 機械判定で確定 → 手順4へ
   - `drift-candidate`: watched_changes の差分を読む
     (`git log --since=<last_reviewed> -p -- <path>`)。文書の記述と実態が
     ズレているか判定する。ズレが無ければ該当文書の `last_reviewed` を今日に
     更新して完了(これが唯一許される文書編集)

3. 期限切れ文書も、レビューして実態と合っていれば `last_reviewed` 更新だけで完了。

4. **チケット化**(対応が必要なものだけ):
   - 起票前に `bd search "<ファイル名>"` で重複確認
   - `bd create "docs: <file> <stale|乖離>の解消" --type chore -p 2 -d "<理由と watched_changes>"`
   - **bd が無いリポジトリでは起票せず、結果をユーザーに報告**する。継続的に
     必要そうなら `bd init` を提案する(勝手に実行しない)

5. 結果サマリ(検出数・起票数・last_reviewed 更新数)をユーザーに報告する。

## 出力の読み方

| status | 意味 | 扱い |
|---|---|---|
| violation | frontmatter 不備(owner/last_reviewed 欠落、YAML 壊れ) | 確定。修正チケット |
| stale | last_reviewed + review_cycle_days が今日より過去 | 確定。レビューか修正 |
| drift-candidate | watches のパスが last_reviewed 以降に変更 | 要判定(グレーゾーン) |
