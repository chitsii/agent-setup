---
type: spec
---

# 設計: doc-render スキル(Markdown→PDF、mermaid レンダリング)

日付: 2026-06-13
ステータス: 承認済み
対応チケット: agent-setup-8hl

## 目的

複雑なチケット対応時に、人間がレビューしやすい資料(Markdown、mermaid 図入り)を PDF として出力できるようにする。Markdown を正とし、PDF はレンダリング成果物。

## 方針(案1: 自前 HTML + Playwright Chromium 印刷)

既存部品(Playwright Chromium 導入済み、CJK フォントあり、uv)だけで構成し、新規の重い依存(pandoc/LaTeX/md-to-pdf)を持たない。doc-audit と同じ「uv スクリプト+スキル」パターン。

検討した代替案: md-to-pdf(npm)は mermaid 注入の設定を外部 DSL で書くことになり、puppeteer 用 Chromium も重複する。pandoc+LaTeX は日本語 PDF の導入コストが過剰。

## 成果物

| 成果物 | 役割 |
|---|---|
| `skills/doc-render/SKILL.md` | 使い方 + 複雑チケットのレビュー資料の書き方指示 |
| `skills/doc-render/scripts/render.py` | 変換器本体(uv PEP 723。依存: markdown-it-py, playwright) |

## render.py の仕様

- 入力: `render.py <input.md> [output.pdf]`。出力省略時は入力と同じ場所に `<name>.pdf`
- 処理:
  1. frontmatter(doc-conventions 形式)があれば剥がし、`title` 等をヘッダ表示に流用(無ければ最初の H1、それも無ければファイル名)
  2. markdown-it-py(GFM: テーブル・コードフェンス)で HTML 化。` ```mermaid ` フェンスは `<pre class="mermaid">` へ
  3. GitHub 風スタイル + CJK フォント(Noto Sans CJK JP 等のフォールバックチェーン)+ 印刷 CSS を内蔵した単一 HTML を生成
  4. Playwright Chromium でロード → mermaid.js がクライアントレンダリング → 全図の完了を待つ → `page.pdf()`(A4、ヘッダ: タイトル+日付、フッタ: ページ番号)
- mermaid.js: バージョン固定で初回実行時に CDN から `~/.local/share/doc-render/` へ取得・キャッシュ。リポジトリには同梱しない(置き場所はリポジトリ規約に従う)。HTML へはインライン埋め込みで参照し、レンダリングはオフラインで完結
- エラー処理:
  - mermaid 構文エラー: 該当図の位置にエラーメッセージを表示し、**PDF 自体は生成する**(1つの壊れた図で全体を失敗させない)
  - 初回かつネット不通で mermaid.js が無い: 取得方法を明示して exit 非ゼロ
  - Chromium 未導入: `uv run --with playwright playwright install chromium` を案内して exit 非ゼロ

## SKILL.md の内容

- 変換の使い方: `/doc-render <file.md>`、「この md を PDF にして」
- 複雑チケットのレビュー資料の書き方(doc-conventions と接続):
  - `docs/reports/YYYY-MM-DD-<topic>.md`(`type: report`)に書く
  - 推奨構成: 背景 / 検討した選択肢と判断 / 構成図(mermaid)/ 影響範囲 / レビューで見てほしい点
  - 変換後、PDF パスを `bd note <ticket-id>` でチケットに記録する(bd がある場合)
- 可搬性: スキルは user-scope 配布。対象リポジトリに設置物なし。bd 無し環境でも変換は動く

## 検証(実機検証してから完了とする)

1. 合成フィクスチャ: 日本語・表・コードブロック・mermaid 2種(flowchart/sequence)・**壊れた mermaid 1つ**を含む md → PDF が生成され、pdftotext で日本語が抽出でき、壊れた図はエラー表示・他の図は正常
2. 実物 E2E: `/home/tishi/prj/agent-setup/tmp.md`(38KB、mermaid 複数、`<br>` 入りラベル)を PDF 化し、ユーザーが目視確認
3. キャッシュ動作: `~/.local/share/doc-render/` に mermaid.js が保存され、2回目以降ネット無しで動く
