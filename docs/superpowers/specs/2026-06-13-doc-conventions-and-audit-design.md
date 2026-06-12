---
type: spec
---

# 設計: ドキュメントの書く型と腐らせない仕組み(doc-conventions + doc-audit)

日付: 2026-06-13
ステータス: 承認待ち
スコープ: サブプロジェクト2(agent-setup-js2「書く型」)+ サブプロジェクト3(agent-setup-9yb「腐らせない仕組み」)

## 背景と決定の経緯

「ドキュメントは蓄積した後、読まれず・メンテされなければ死蔵する」問題を、(a) 書く時の型(種類・置き場所・メタデータ)と (b) 腐らせない仕組み(鮮度切れと code↔docs 乖離の検出 → bd チケット化)で解消する。

当初は indexion(trkbt10/indexion)の採用を前提としたが、実機検証と代替調査(2026-06-13、3系統の並列調査)の結果、以下を確認して**薄い自前実装に方針転換**した:

- indexion のシンボル系機能(reconcile・カバレッジ・検索)は shell+Markdown リポジトリでは機能しない(shell.kgf が `set -euo pipefail` でパースエラー、`document_symbol_kinds` 宣言は7言語のみ)。ツールは設計優秀だがバス係数1・v0.x
- **code↔docs の意味的乖離を検出する成熟した汎用 OSS は存在しない**(調査で反証を尽くした結論。皮肉なことに indexion 自体が ★134 でこのニッチの OSS 最上位)
- 鮮度管理の業界の現実解は「frontmatter 規約 + 小さい自作チェック + 期限切れの Issue 起票」(Google g3doc、GOV.UK、GitLab、Giant Swarm が同型)
- 「AI 自動 wiki の単体製品」は墓場(Mutable.ai、CodeSee、Sourcegraph Notebooks 等が死亡・撤退)。生き残りは決定論的ジェネレータ・プラットフォーム付帯機能・エージェント向けコンテキスト層のみ。**wiki 機能は見送り**(ユーザー決定)
- LLM による drift 監査は「決定論チェックで足切りし、グレーゾーンだけ LLM が判定する門番方式」が定石として確立(Dosu レシピ、Claude Code Routines の公式「Docs drift」パターン)

indexion は「コードのあるプロジェクトで reconcile を再評価する」spike(agent-setup-042)に格下げ。

## 設計原則

1. **腐る対象を減らす**: 網羅的な説明・コードの要約は書かない(エージェントが都度コードから生成できる)。書くのはコードから復元できないもの — 意図、却下した代替案、決定の経緯、運用手順
2. **記録と生きた文書は腐り方が違う**: 日付付きの記録(spec/plan/decision/handoff)は不変であり鮮度管理不要。生きた文書(runbook/readme/規約)だけが鮮度管理の対象
3. **可搬性**: 判定の真実は置き場所(パス)ではなく frontmatter に置く。スキルは user-scope 配布でどのリポジトリでも動き、対象リポジトリ側に必須の設置物はない。bd が無い環境では報告のみに段階的劣化する

## 成果物

| 成果物 | 役割 | 配布経路 |
|---|---|---|
| `prompts/doc-conventions.md` | 書く型の規約本文(CLAUDE.md 断片)。グローバル昇格候補 | 手でコピペ |
| `skills/doc-audit/` | 監査スキル(SKILL.md + チェッカースクリプト) | install.sh(user-scope symlink) |
| bd(beads) | 検出結果の受け皿 | 導入済み |

## 1. 書く型(prompts/doc-conventions.md)

### 種類語彙(6つ)と既定の置き場所

frontmatter の `type:` で宣言する。**チェッカーは type だけを見て判定し、置き場所は問わない**(可搬性原則)。置き場所は迷わないための既定であり、リポジトリや既存ツール(superpowers 等)に確立済みの場所があればそちらを優先する。

| type | 性質 | 既定の置き場所 | 鮮度管理 |
|---|---|---|---|
| `spec` | 記録 | `docs/specs/YYYY-MM-DD-<topic>.md`(superpowers 導入済みなら `docs/superpowers/specs/`) | 不要 |
| `plan` | 記録 | `docs/plans/`(同上) | 不要 |
| `decision` | 記録 | `docs/decisions/NNNN-<topic>.md`(MADR v4 準拠) | 不要 |
| `handoff` | 記録 | 使用するハンドオフツールの既定に従う | 不要 |
| `runbook` | 生きた文書 | `docs/runbooks/<topic>.md` | 必須 |
| `readme` | 生きた文書 | リポジトリ直下・各ディレクトリ | 必須(直下 README.md のみ frontmatter 省略可の特例) |

CLAUDE.md 断片や運用規約(prompts/ 配下のような配布断片)は `runbook` 扱い(生きた文書)。

記録 type は不変。間違い・実態との乖離は本文を書き換えず「追記(実施記録・訂正)」で正す。

### 生きた文書の frontmatter

```yaml
---
type: runbook
owner: <git config user.name の値が既定>
last_reviewed: 2026-06-13
review_cycle_days: 90        # 既定: runbook 90日 / readme・規約 180日
watches:                     # この文書が依存するコードパス(glob、任意)
  - install.sh
  - skills/*/scripts/*.sh
---
```

- `owner`: レビュー責任の明示(byline が文化定着に効くという Google g3doc の知見)。値は検証しない(存在のみチェック)
- `watches`: doc→依存パスのマップを中央ファイルでなく各文書に持たせる。文書と一緒に更新されるためマップ自体が腐りにくい
- レビューして問題なければ `last_reviewed` を更新するだけでよい(本文変更不要)

## 2. 腐らせない仕組み(skills/doc-audit)

### 決定論層: scripts/check.py

Python スクリプト(uv の PEP 723 インライン依存で PyYAML を使用。追加依存は許容する=ユーザー決定)。LLM 不要の機械判定のみ:

1. リポジトリ内の `*.md` を走査し frontmatter をパース(`.git` 等は除外)
2. 生きた文書(`type: runbook|readme`)について:
   - `owner` / `last_reviewed` 欠落 → **violation**
   - `last_reviewed + review_cycle_days < 今日` → **stale**
   - `watches` の各パスの git 最終コミット日時 > `last_reviewed` → **drift-candidate**(変更したパスの一覧付き)
3. リポジトリ直下 README.md の特例は「frontmatter 義務の免除」のみ。frontmatter が無い README は決定論層の判定対象外(機械監査したい README には frontmatter を付ける)。リポジトリ全体の活動と比較する案は、README に無関係なコミットすべてで誤検知するため不採用
4. 結果を JSON で出力(`{file, status, reason, watched_changes[]}`)。違反ゼロなら空配列で exit 0。docs が無いリポジトリでも正常終了

### 判定層: SKILL.md(エージェントの手順)

1. check.py を実行し JSON を読む
2. **violation / stale** はそのまま扱う(機械判定で確定)
3. **drift-candidate** だけ、watched パスの diff を読んで「文書の記述に実害があるか」を判定(LLM は門番方式: グレーゾーンのみ)
4. 実害あり → bd があれば `bd create --type chore`(起票前に `bd search` で重複確認)。bd が無ければ結果をユーザーに報告し、必要なら `bd init` を提案
5. 文書が現実と合っていれば `last_reviewed` を今日に更新して完了

起動タイミング: ユーザーの `/doc-audit` 手動実行、または機能完成・セッション終了の節目。GitHub 公開後は claude-code-action の週次 cron を追加する(GitHub 公開チケット agent-setup-7oo の後続として起票)。

## 3. agent-setup への適用(ドッグフーディング)

- `prompts/*.md`(beads-tickets / fable-codex-collab / codex-instruction-generator / doc-conventions 自身)に frontmatter を付与して生きた文書化
- 既存の specs/plans に `type: spec` / `type: plan` を追記(記録としての宣言のみ。任意だが揃える)
- README のスキル一覧表に doc-audit、プロンプト一覧に doc-conventions.md を追記し、`./install.sh` を再実行
- CLAUDE.md に「ドキュメント規約は prompts/doc-conventions.md を試験運用中」の一文を追記

## 4. 可搬性の保証(検査済みの結合点と対処)

- ~~superpowers 既定パスを正とする~~ → type→既定パスは汎用定義とし、既存ツールの場所を優先と明記。判定は frontmatter のみ
- ~~owner 例の個人名固定~~ → `git config user.name` を既定と規定
- ~~bd 前提~~ → チェッカーは bd を知らない(JSON を吐くだけ)。起票はスキル手順側で、bd 不在時は報告に劣化
- チェッカーの依存(uv + PyYAML)は許容(ユーザー決定)。uv は本リポジトリ群の既存前提ツール

## 5. 検証(実機検証してから完了とする)

1. check.py 単体: 正常 / frontmatter 欠落 / 期限切れ / watches 乖離の4ケースをこのリポジトリ上で再現し、JSON 出力を確認
2. スキル経由の一連: 人工的に期限切れを作り、`/doc-audit` → 判定 → bd 起票までを実走
3. 可搬性: docs/ も .beads/ も無い一時ディレクトリで check.py が正常終了することを確認
4. bd 不在の劣化動作は SKILL.md の手順として記述し、3 の環境でスキルの振る舞いを確認

## 実装チケット

実装は agent-setup-js2(書く型=規約+frontmatter 付与)と agent-setup-9yb(doc-audit スキル)に対応。js2 → 9yb の依存設定済み。
