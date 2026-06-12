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
