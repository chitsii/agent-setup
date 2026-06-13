---
type: report
---

# 調査報告: beads-ui の Epic 子一覧が「No issues found」になる問題

日付: 2026-06-13
対応チケット: agent-setup-78z(open、上流対応待ち)
ステータス: 原因特定済み。下記ドラフトを mantoni/beads-ui へ起票予定(ユーザーが後日実施)

## 経緯と結論(日本語サマリ)

- bd v1.0.5 で Epic(`--type epic` + `--parent`)を構成。CLI(`bd epic status` / `bd children`)は正常
- beads-ui v0.12.0 の Epics タブでは、Epic ヘッダと進捗(0/3)は表示されるが、子一覧が「No issues found」
- 原因: beads-ui は epic 展開時に `issue-detail` 購読 → サーバーが `bd show <id> --json` を実行し、その JSON の children を表示する。しかし **bd v1.0.5 の `bd show --json` には children フィールドが無い**(人間向け出力には CHILDREN セクションが出る)。ヘッダの 0/N は別経路(`bd epic status --json` の `total_children`)のため正しい
- 副症状: bd への書き込み後、`epics` 購読のリストが空になり、サーバー再起動まで Epics タブ自体が「No epics found.」になる
- 回避策(検証済みの否定形含む): `parent-child` 依存エッジを張っても解消しない。当面は CLI(`bd epic status` / `bd children <id>`)で進捗確認。Issues / Board ビューは正常
- 修正の鍵: `bd children <id> --json` は子の完全な情報(dependencies 含む)を返すことを実測確認済み。UI はこちらを使えば直る

## 上流 issue ドラフト(mantoni/beads-ui へ投稿用・英語)

Title: **Epics view shows "No issues found" for children with bd v1.0.x (`bd show --json` no longer includes children)**

---

**Environment**

- beads-ui: 0.12.0 (npm, global install)
- bd (beads): 1.0.5 (Homebrew), embedded Dolt workspace
- OS: Linux (WSL2), Node 24

**Steps to reproduce**

1. In a bd v1.0.5 workspace, create an epic and attach children:
   ```bash
   bd create "Epic: demo" --type epic --acceptance "done when..."
   bd create "child task" -p 2            # then:
   bd update <child-id> --parent <epic-id>
   ```
2. Verify CLI works: `bd children <epic-id>` and `bd epic status` both show the children / progress correctly.
3. `bdui start`, open the **Epics** tab, expand the epic.

**Expected**

Children table under the epic.

**Actual**

- Epic header renders with the correct progress counter (e.g. `0/3`, sourced from `bd epic status --json` → `total_children`), but the children area shows **"No issues found"**.
- Additionally, after any subsequent bd write, the `epics` list subscription returns an empty snapshot and the tab shows "No epics found." until the server is restarted (possibly a separate issue — happy to file it separately).

**Root cause analysis (from reading the installed package)**

- `server/list-adapters.js` maps the `epics` subscription to `bd epic status --json` — this works on bd 1.0.5.
- Expanding an epic subscribes `issue-detail` → the server runs `bd show <id> --json`. On **bd 1.0.5 this JSON contains no `children` (or `dependencies`) array** — only scalar fields and counts (`dependency_count`, `dependent_count`) — while the human-readable `bd show` output still prints a CHILDREN section. The frontend's children list is therefore always empty (`O.length === 0` → "No issues found" in the `epic-children` render path of `app/main.bundle.js`).

**Suggested fix**

`bd children <epic-id> --json` on bd 1.0.5 returns the full child issues (including their `dependencies`), so mapping an `epic-children` subscription (or the detail fetch) to that command appears to be a drop-in fix:

```bash
bd children <epic-id> --json   # works on bd 1.0.5, full child objects
```

Thanks for beads-ui — the Issues and Board views work great against bd 1.0.x; the Epics children pane seems to be the main gap after the bd 1.0 JSON output changes.

---

## 投稿時のメモ

- 既存 issue に重複なし(2026-06-13 時点で `is:issue epic` を確認。最も近いのは表示崩れの #57、unknown flag の #68)
- 投稿後、issue URL を agent-setup-78z に `bd note` で記録し、`--external-ref` を設定すること
