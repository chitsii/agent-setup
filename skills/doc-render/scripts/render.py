#!/usr/bin/env -S uv run --script --quiet
# /// script
# requires-python = ">=3.10"
# dependencies = ["markdown-it-py[linkify]", "playwright"]
# ///
"""Markdown(mermaid フェンス対応)を A4 PDF にレンダリングする。

Usage: render.py <input.md> [output.pdf]

- frontmatter(doc-conventions 形式)は剥がし、title をヘッダに流用
- mermaid.js は初回に CDN から ~/.local/share/doc-render/ へ取得・キャッシュ
- 壊れた mermaid 図はその位置にエラー表示し、PDF 自体は生成する
"""
import datetime as dt
import html as html_mod
import re
import sys
import urllib.request
from pathlib import Path

MERMAID_VERSION = "11"  # メジャー固定(jsdelivr が 11.x 最新に解決)
CACHE_DIR = Path.home() / ".local/share/doc-render"
MERMAID_JS = CACHE_DIR / f"mermaid-v{MERMAID_VERSION}.min.js"
MERMAID_URL = f"https://cdn.jsdelivr.net/npm/mermaid@{MERMAID_VERSION}/dist/mermaid.min.js"

CSS = """
body { font-family: 'Noto Sans CJK JP','Noto Sans JP','Hiragino Sans','Yu Gothic',sans-serif;
       font-size: 10.5pt; line-height: 1.75; color: #1f2328; margin: 0; }
h1 { font-size: 1.7em; border-bottom: 1px solid #d1d9e0; padding-bottom: .3em; }
h2 { font-size: 1.35em; border-bottom: 1px solid #d1d9e0; padding-bottom: .25em;
     margin-top: 1.6em; break-after: avoid; }
h3 { font-size: 1.15em; margin-top: 1.4em; break-after: avoid; }
p { margin: .6em 0; }
code { font-family: 'Noto Sans Mono CJK JP','Cascadia Mono',monospace; font-size: .9em;
       background: #f0f1f3; padding: .15em .35em; border-radius: 4px; }
pre { background: #f6f8fa; padding: 12px; border-radius: 6px; overflow-x: hidden; }
pre code { background: none; padding: 0; white-space: pre-wrap; word-break: break-all; }
table { border-collapse: collapse; margin: .8em 0; width: 100%; }
th, td { border: 1px solid #d1d9e0; padding: 5px 10px; text-align: left; vertical-align: top; }
th { background: #f6f8fa; }
blockquote { border-left: 4px solid #d1d9e0; margin: .8em 0; padding: 0 1em; color: #59636e; }
.mermaid-figure { text-align: center; break-inside: avoid; margin: 1em 0; }
.mermaid-figure svg { max-width: 100%; height: auto; }
.mermaid-error { border: 2px solid #d1242f; background: #ffebe9; color: #d1242f;
                 padding: 10px; border-radius: 6px; font-size: .9em; white-space: pre-wrap; }
hr { border: 0; border-top: 1px solid #d1d9e0; margin: 1.5em 0; }
"""

RENDER_JS = """
mermaid.initialize({ startOnLoad: false, securityLevel: 'loose', theme: 'default' });
(async () => {
  const els = Array.from(document.querySelectorAll('pre.mermaid'));
  for (let i = 0; i < els.length; i++) {
    const el = els[i], id = 'mmd' + i;
    try {
      const { svg } = await mermaid.render(id, el.textContent);
      const fig = document.createElement('div');
      fig.className = 'mermaid-figure';
      fig.innerHTML = svg;
      el.replaceWith(fig);
    } catch (e) {
      const err = document.createElement('div');
      err.className = 'mermaid-error';
      err.textContent = '⚠ mermaid レンダリング失敗: ' + String((e && e.message) || e);
      el.replaceWith(err);
      const leftover = document.getElementById(id);
      if (leftover) leftover.remove();
    }
  }
  window.__render_done = true;
})();
"""


def ensure_mermaid_js() -> str:
    if not MERMAID_JS.exists():
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        print(f"mermaid.js を取得中: {MERMAID_URL}", file=sys.stderr)
        try:
            with urllib.request.urlopen(MERMAID_URL, timeout=60) as r:
                MERMAID_JS.write_bytes(r.read())
        except OSError as e:
            sys.exit(f"error: mermaid.js を取得できない({e})。ネット接続後に再実行するか、"
                     f"手動で {MERMAID_URL} を {MERMAID_JS} に保存してください")
    return MERMAID_JS.read_text(encoding="utf-8")


def split_frontmatter(text: str):
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            return text[4:end], text[end + 5:]
    return None, text


def extract_title(frontmatter, body: str, fallback: str) -> str:
    if frontmatter:
        m = re.search(r"^title:\s*(.+)$", frontmatter, re.M)
        if m:
            return m.group(1).strip().strip("\"'")
    m = re.search(r"^#\s+(.+)$", body, re.M)
    return m.group(1).strip() if m else fallback


def md_to_html(body: str) -> str:
    from markdown_it import MarkdownIt
    from markdown_it.renderer import RendererHTML

    md = MarkdownIt("gfm-like")
    default_fence = RendererHTML.fence

    def fence(self, tokens, idx, options, env):
        token = tokens[idx]
        if (token.info or "").strip().split(" ")[0] == "mermaid":
            return f'<pre class="mermaid">{html_mod.escape(token.content)}</pre>\n'
        return default_fence(self, tokens, idx, options, env)

    md.add_render_rule("fence", fence)
    return md.render(body)


def render_pdf(html_path: Path, pdf_path: Path, title: str):
    from playwright.sync_api import sync_playwright

    header = (f'<div style="font-size:8px; width:100%; padding:0 10mm; color:#59636e; '
              f'display:flex; justify-content:space-between;">'
              f'<span>{html_mod.escape(title)}</span>'
              f'<span>{dt.date.today().isoformat()}</span></div>')
    footer = ('<div style="font-size:8px; width:100%; text-align:center; color:#59636e;">'
              '<span class="pageNumber"></span> / <span class="totalPages"></span></div>')
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(html_path.as_uri())
            page.wait_for_function("window.__render_done === true", timeout=120_000)
            page.pdf(path=str(pdf_path), format="A4", print_background=True,
                     display_header_footer=True,
                     header_template=header, footer_template=footer,
                     margin={"top": "18mm", "bottom": "16mm", "left": "14mm", "right": "14mm"})
            browser.close()
    except Exception as e:
        if "Executable doesn't exist" in str(e):
            sys.exit("error: Chromium 未導入。`uv run --with playwright playwright install chromium` を実行してください")
        raise


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: render.py <input.md> [output.pdf]")
    src = Path(sys.argv[1]).resolve()
    if not src.is_file():
        sys.exit(f"error: 入力ファイルが無い: {src}")
    out = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else src.with_suffix(".pdf")

    text = src.read_text(encoding="utf-8")
    frontmatter, body = split_frontmatter(text)
    title = extract_title(frontmatter, body, src.stem)
    mermaid_js = ensure_mermaid_js()
    content = md_to_html(body)

    html = (f"<!doctype html><html><head><meta charset='utf-8'>"
            f"<title>{html_mod.escape(title)}</title><style>{CSS}</style></head>"
            f"<body>{content}"
            f"<script>{mermaid_js}</script><script>{RENDER_JS}</script></body></html>")
    html_path = out.with_suffix(".render.html")
    html_path.write_text(html, encoding="utf-8")
    try:
        render_pdf(html_path, out, title)
    finally:
        html_path.unlink(missing_ok=True)
    print(out)


if __name__ == "__main__":
    main()
