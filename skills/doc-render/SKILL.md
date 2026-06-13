---
name: doc-render
description: "Use when rendering Markdown to PDF for human review — レビュー資料・設計資料の Markdown(mermaid 図含む)を PDF にするとき。トリガー例: 「PDFにして」「レビュー用に出力して」「/doc-render <file.md>」。"
---

# doc-render

mermaid 図入りの Markdown を、日本語対応の A4 PDF にレンダリングする。

## 使い方

```bash
"$(find ~/.claude/skills/doc-render ~/.codex/skills/doc-render -name render.py 2>/dev/null | head -1)" <input.md> [output.pdf]
```

- 出力省略時は入力と同じ場所に `<name>.pdf`
- 初回実行時のみ mermaid.js を CDN から `~/.local/share/doc-render/` へ取得(以後オフライン)
- 壊れた mermaid 図はその位置に赤いエラーボックスで表示され、PDF 自体は生成される
- 要件: uv、Playwright Chromium(無ければ `uv run --with playwright playwright install chromium`)

## 複雑チケットのレビュー資料の書き方

複雑なチケット(epic、設計判断を含む作業)では、人間レビュー用の資料を書いてから変換する:

1. `docs/reports/YYYY-MM-DD-<topic>.md`(frontmatter `type: report`)に書く
2. 推奨構成: **背景 / 検討した選択肢と判断 / 構成図(mermaid)/ 影響範囲 / レビューで見てほしい点**
3. 変換して PDF パスを報告し、bd があるリポジトリでは `bd note <ticket-id> "レビュー資料: <path>"` で記録する
4. レビュー指摘は bd チケットに落とす(資料の修正は Markdown 側で行い、PDF は再生成する)
