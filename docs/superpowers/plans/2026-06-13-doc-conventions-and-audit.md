---
type: plan
---

# doc-conventions + doc-audit 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ドキュメントの書く型規約(配布物)と、鮮度切れ・乖離を検出して bd チケット化する doc-audit スキルを実装し、agent-setup 自身に適用する。

**Architecture:** 規約はテキスト(`prompts/doc-conventions.md`)、検出は user-scope 配布のスキル(`skills/doc-audit/`)。決定論層(Python チェッカー、JSON 出力)とエージェント判定層(SKILL.md 手順)を分離。判定の真実は frontmatter のみで、対象リポジトリに必須の設置物はない。

**Tech Stack:** Python 3.10+(uv PEP 723 インライン依存で PyYAML)、git、bash。

**Spec:** `docs/superpowers/specs/2026-06-13-doc-conventions-and-audit-design.md`
**対応チケット:** agent-setup-js2(書く型)、agent-setup-9yb(doc-audit)

---

### Task 1: 書く型規約 prompts/doc-conventions.md

**Files:**
- Create: `prompts/doc-conventions.md`

- [ ] **Step 1: ファイル作成**

以下の内容で作成(この文書自体が生きた文書なので frontmatter を持つ):

````markdown
---
type: runbook
owner: chitsii
last_reviewed: 2026-06-13
review_cycle_days: 180
watches:
  - skills/doc-audit/**
---

# ドキュメント規約(CLAUDE.md 断片)

グローバル CLAUDE.md または各リポジトリの CLAUDE.md に貼って使う。検出の実行系は doc-audit スキル(agent-setup リポジトリ)が担う。

## 原則: 腐る対象を減らす

網羅的な説明やコードの要約は書かない(エージェントが都度コードから生成できる)。書くのは**コードから復元できないもの** — 意図、却下した代替案、決定の経緯、運用手順。

## 文書の種類(frontmatter の `type:` で宣言)

| type | 性質 | 既定の置き場所 | 鮮度管理 |
|---|---|---|---|
| `spec` | 記録 | `docs/specs/YYYY-MM-DD-<topic>.md` | 不要 |
| `plan` | 記録 | `docs/plans/YYYY-MM-DD-<topic>.md` | 不要 |
| `decision` | 記録 | `docs/decisions/NNNN-<topic>.md`(MADR v4 準拠) | 不要 |
| `handoff` | 記録 | 使用するハンドオフツールの既定に従う | 不要 |
| `runbook` | 生きた文書 | `docs/runbooks/<topic>.md` | **必須** |
| `readme` | 生きた文書 | リポジトリ直下・各ディレクトリ | **必須**(直下 README.md のみ frontmatter 省略可) |

- 置き場所は迷わないための既定。リポジトリや既存ツール(superpowers の `docs/superpowers/specs/` 等)に確立済みの場所があればそちらを優先してよい。**判定は type のみで行われ、場所は問わない**
- CLAUDE.md 断片・運用規約のような配布断片は `runbook` 扱い
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
````

- [ ] **Step 2: 確認とコミット**

Run: `head -10 prompts/doc-conventions.md`
Expected: frontmatter(type: runbook、watches に skills/doc-audit/**)

```bash
git add prompts/doc-conventions.md
git commit -m "Add doc conventions as distributable prompt"
```

---

### Task 2: チェッカー skills/doc-audit/scripts/check.py

**Files:**
- Create: `skills/doc-audit/scripts/check.py`(実行可能)

- [ ] **Step 1: スクリプト作成**

```python
#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyyaml"]
# ///
"""doc-audit の決定論層: 生きた文書の鮮度・乖離候補を機械判定する。

*.md の frontmatter を走査し、type が runbook/readme の文書について
violation(メタデータ不備)/ stale(レビュー期限切れ)/
drift-candidate(watches のパスが last_reviewed 以降に変更)を検出。
結果を JSON 配列で stdout に出力する。常に exit 0(走査自体の失敗時のみ非ゼロ)。
git リポジトリ外では drift 判定をスキップして動く。

Usage: check.py [target-dir]
"""
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path

import yaml

LIVING_TYPES = {"runbook", "readme"}
DEFAULT_CYCLE_DAYS = {"runbook": 90, "readme": 180}
SKIP_DIRS = {".git", ".beads", "node_modules", ".venv", "vendor"}


def parse_frontmatter(path: Path):
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return None
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end == -1:
        return None
    try:
        data = yaml.safe_load(text[4:end])
    except yaml.YAMLError:
        return {"_parse_error": True}
    return data if isinstance(data, dict) else None


def git(repo: Path, *args: str):
    try:
        res = subprocess.run(
            ["git", "-C", str(repo), *args],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return res.stdout.strip() if res.returncode == 0 else None


def last_commit_ts(repo: Path, pathspec: str):
    out = git(repo, "log", "-1", "--format=%ct", "--", f":(glob){pathspec}")
    return int(out) if out else None


def changed_files_since(repo: Path, since: str, pathspec: str):
    out = git(repo, "log", f"--since={since}", "--name-only", "--format=",
              "--", f":(glob){pathspec}")
    if not out:
        return []
    return sorted({line for line in out.splitlines() if line.strip()})


def to_date(value):
    if isinstance(value, dt.datetime):
        return value.date()
    if isinstance(value, dt.date):
        return value
    if isinstance(value, str):
        try:
            return dt.date.fromisoformat(value.strip())
        except ValueError:
            return None
    return None


def main():
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
    today = dt.date.today()
    use_git = git(root, "rev-parse", "--is-inside-work-tree") == "true"
    findings = []

    for path in sorted(root.rglob("*.md")):
        if any(part in SKIP_DIRS for part in path.relative_to(root).parts):
            continue
        rel = str(path.relative_to(root))
        fm = parse_frontmatter(path)
        if fm is None:
            continue  # frontmatter なし(記録や直下 README 特例)は対象外
        if fm.get("_parse_error"):
            findings.append({"file": rel, "status": "violation",
                             "reason": "frontmatter が YAML としてパースできない",
                             "watched_changes": []})
            continue
        if fm.get("type") not in LIVING_TYPES:
            continue  # 記録 type は鮮度管理対象外

        missing = [k for k in ("owner", "last_reviewed") if not fm.get(k)]
        if missing:
            findings.append({"file": rel, "status": "violation",
                             "reason": f"必須フィールド欠落: {', '.join(missing)}",
                             "watched_changes": []})
            continue

        reviewed = to_date(fm["last_reviewed"])
        if reviewed is None:
            findings.append({"file": rel, "status": "violation",
                             "reason": f"last_reviewed が日付として読めない: {fm['last_reviewed']!r}",
                             "watched_changes": []})
            continue

        cycle = int(fm.get("review_cycle_days") or DEFAULT_CYCLE_DAYS[fm["type"]])
        if reviewed + dt.timedelta(days=cycle) < today:
            findings.append({"file": rel, "status": "stale",
                             "reason": f"レビュー期限切れ: last_reviewed={reviewed} + {cycle}日 < {today}",
                             "watched_changes": []})

        watches = fm.get("watches") or []
        if watches and use_git:
            since = f"{reviewed.isoformat()}T23:59:59"
            changed = set()
            for pattern in watches:
                ts = last_commit_ts(root, str(pattern))
                if ts is not None and dt.datetime.fromtimestamp(ts).date() > reviewed:
                    changed.update(changed_files_since(root, since, str(pattern)))
            if changed:
                findings.append({"file": rel, "status": "drift-candidate",
                                 "reason": f"watches のパスが last_reviewed({reviewed}) 以降に変更されている",
                                 "watched_changes": sorted(changed)})

    json.dump(findings, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 実行権限付与と素振り**

Run: `chmod +x skills/doc-audit/scripts/check.py && ./skills/doc-audit/scripts/check.py . | head -20`
Expected: JSON 配列が出る(この時点では Task 1 の doc-conventions.md が対象。watches した skills/doc-audit/** は未コミットなので drift は出ない、または check.py 追加コミット後なら drift-candidate が1件出る — どちらも正常)

---

### Task 3: チェッカーのフィクスチャ検証

**Files:** なし(/tmp に使い捨てフィクスチャ)

- [ ] **Step 1: フィクスチャリポジトリ作成(4ケース)**

```bash
F=/tmp/doc-audit-fixture && rm -rf $F && mkdir -p $F/docs && cd $F && git init -q
# ケース1: 正常(期限内・watches 変更なし)
printf -- '---\ntype: runbook\nowner: test\nlast_reviewed: 2099-01-01\n---\nok\n' > docs/ok.md
# ケース2: violation(owner 欠落)
printf -- '---\ntype: runbook\nlast_reviewed: 2026-01-01\n---\nx\n' > docs/no-owner.md
# ケース3: stale(期限切れ)
printf -- '---\ntype: readme\nowner: test\nlast_reviewed: 2020-01-01\n---\nold\n' > docs/stale.md
# ケース4: drift(watches のコードが last_reviewed より後に変更)
printf -- '---\ntype: runbook\nowner: test\nlast_reviewed: 2020-01-01\nreview_cycle_days: 99999\nwatches:\n  - src/**\n---\nd\n' > docs/drift.md
mkdir src && echo 'v2' > src/app.sh
git add -A && git commit -qm fixture
```

- [ ] **Step 2: 実行して4ケースを確認**

Run: `cd $F && ~/prj/agent-setup/skills/doc-audit/scripts/check.py . | jq -r '.[] | "\(.file) \(.status)"' | sort`
Expected(ok.md は出ない):
```
docs/drift.md drift-candidate
docs/no-owner.md violation
docs/stale.md stale
```
さらに `jq '.[] | select(.status=="drift-candidate") | .watched_changes'` が `["src/app.sh"]` を含むこと。

- [ ] **Step 3: 可搬性ケース(非 git・docs なし)**

```bash
P=/tmp/doc-audit-empty && rm -rf $P && mkdir $P
~/prj/agent-setup/skills/doc-audit/scripts/check.py $P; echo "exit=$?"
```
Expected: `[]` と `exit=0`(クラッシュしない)

- [ ] **Step 4: フィクスチャ削除**

Run: `rm -rf /tmp/doc-audit-fixture /tmp/doc-audit-empty`

---

### Task 4: SKILL.md と配線

**Files:**
- Create: `skills/doc-audit/SKILL.md`

- [ ] **Step 1: SKILL.md 作成**

````markdown
---
name: doc-audit
description: Use when auditing document freshness — ドキュメントの鮮度切れ(stale)や code↔docs 乖離(drift)を検出して bd チケット化するとき。トリガー例: 「/doc-audit」「ドキュメント監査して」「docs が古くなってないか確認して」、機能完成・セッション終了の節目。
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
````

- [ ] **Step 2: install.sh 再実行と確認**

Run: `./install.sh && ls -la ~/.claude/skills/doc-audit ~/.codex/skills/doc-audit`
Expected: 両方に symlink が張られ、リポジトリ内実体に解決される

- [ ] **Step 3: コミット**

```bash
git add skills/doc-audit/
git commit -m "Add doc-audit skill (deterministic checker + agent runbook)"
```

---

### Task 5: 既存ドキュメントへの frontmatter 付与

**Files:**
- Modify: `prompts/beads-tickets.md`, `prompts/fable-codex-collab.md`, `prompts/codex-instruction-generator.md`(先頭に frontmatter 追加)
- Modify: `docs/superpowers/specs/2026-06-13-beads-ticket-system-design.md`, `docs/superpowers/specs/2026-06-13-doc-conventions-and-audit-design.md`(`type: spec`)
- Modify: `docs/superpowers/plans/2026-06-13-beads-ticket-system.md`, `docs/superpowers/plans/2026-06-13-doc-conventions-and-audit.md`(`type: plan`)

- [ ] **Step 1: prompts 3件に生きた文書の frontmatter を先頭追加**

各ファイル先頭に(内容は共通、watches は beads-tickets.md のみ設定):

```yaml
---
type: runbook
owner: chitsii
last_reviewed: 2026-06-13
review_cycle_days: 180
---
```

beads-tickets.md のみ `watches:` を追加: `- .claude/settings.json`、`- .codex/hooks.json`(bd のフック構成が変わったら規約を見直す合図)

- [ ] **Step 2: specs 2件・plans 2件に記録の frontmatter を先頭追加**

specs: `---\ntype: spec\n---`、plans: `---\ntype: plan\n---`(記録なので type のみ)

- [ ] **Step 3: チェッカーで自己検証**

Run: `./skills/doc-audit/scripts/check.py . | jq -r '.[] | "\(.file) \(.status)"'`
Expected: violation / stale ゼロ。drift-candidate は出ない(全ファイル last_reviewed=今日)

- [ ] **Step 4: コミット**

```bash
git add prompts/ docs/
git commit -m "Apply doc-conventions frontmatter to existing docs"
```

---

### Task 6: README と CLAUDE.md の更新

**Files:**
- Modify: `README.md`(スキル一覧表 56行目付近、プロンプト一覧表 83行目付近)
- Modify: `CLAUDE.md`(タスク管理セクションの後)

- [ ] **Step 1: README スキル一覧表に行を追加**(codex-delegate 行の下)

```markdown
| [doc-audit](skills/doc-audit/SKILL.md) | ドキュメントの鮮度切れ・コード乖離を検出して bd チケット化 | uv、git(bd は任意) |
```

- [ ] **Step 2: README プロンプト一覧表に行を追加**(beads-tickets.md 行の下)

```markdown
| [doc-conventions.md](prompts/doc-conventions.md) | ドキュメントの種類・置き場所・鮮度管理(frontmatter)の規約。CLAUDE.md に貼る断片 |
```

- [ ] **Step 3: CLAUDE.md の「## タスク管理」セクションの直後に追加**

```markdown
## ドキュメント規約

ドキュメントの種類・frontmatter・鮮度管理は [prompts/doc-conventions.md](prompts/doc-conventions.md) を試験運用中(検証後にグローバル昇格予定)。監査は doc-audit スキルで行い、結果は bd に起票する。
```

- [ ] **Step 4: コミット**

```bash
git add README.md CLAUDE.md
git commit -m "Document doc-conventions and doc-audit in README and CLAUDE.md"
```

---

### Task 7: Codex セルフレビュー

コードを含む機能完成なので、グローバル CLAUDE.md の規約に従い Codex レビューを実施。

- [ ] **Step 1: レビュー実行(バックグラウンド)**

Run: `~/.claude/skills/codex-delegate/scripts/delegate.sh review /home/tishi/prj/agent-setup`(バックグラウンド実行し、完了通知後に STATE_DIR の codex.log を Read)
注意: 直近コミット済みのため、レビュー対象が「uncommitted」前提なら直近コミット群(doc-conventions 実装一式)を範囲指定するか、`codex review` の挙動に合わせて読み替える。

- [ ] **Step 2: 指摘の対応**

重大な指摘があれば修正してコミット。軽微なら bd に起票して先送り可。

---

### Task 8: E2E 検証とチケットクローズ

**Files:** なし(一時的な編集はすべて元に戻す)

- [ ] **Step 1: 人工 stale を作って監査の一連を実走**

```bash
# prompts/fable-codex-collab.md の last_reviewed を 2020-01-01 に一時変更
sed -i 's/^last_reviewed: .*/last_reviewed: 2020-01-01/' prompts/fable-codex-collab.md
./skills/doc-audit/scripts/check.py . | jq -r '.[] | "\(.file) \(.status)"'
```
Expected: `prompts/fable-codex-collab.md stale` が出る

- [ ] **Step 2: SKILL.md の手順通りに処理**

stale を確認 → 文書をレビュー(実態と合っている)→ `last_reviewed` を今日に戻す → check.py 再実行で findings ゼロ。bd 起票フロー確認のため、ダミーで `bd create "docs: E2E検証用ダミー" --type chore -p 3` → `bd close <id> --reason "E2E検証完了"` まで流す

- [ ] **Step 3: working tree を確認してコミット(残差があれば)**

Run: `git status --porcelain`
Expected: clean(Step 1-2 の変更は相殺)

- [ ] **Step 4: チケットクローズ**

```bash
bd close agent-setup-js2 --reason "prompts/doc-conventions.md として実装。frontmatter 付与・README/CLAUDE.md 反映済み"
bd close agent-setup-9yb --reason "skills/doc-audit として実装(check.py + SKILL.md)。フィクスチャ4ケース+可搬性+E2E 検証済み"
bd create "GitHub 公開後: doc-audit を claude-code-action の週次 cron に載せる" --type task -p 3 -q
bd dep add <新チケット> agent-setup-7oo
```

- [ ] **Step 5: 完了確認**

Run: `bd ready && git log --oneline -8 && git status --porcelain`
Expected: js2/9yb がクローズ済み、コミット群が揃い、working tree clean

---

## 完了の定義

- スペック検証項目: フィクスチャ4ケース(Task 3)、可搬性(Task 3 Step 3)、E2E(Task 8)がすべて合格
- `/doc-audit` がこのリポジトリで findings ゼロを返す
- agent-setup-js2 / agent-setup-9yb クローズ、後続(CI 化)チケット起票済み
