# beads チケット制タスク管理 導入実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** agent-setup リポジトリに beads(bd)によるチケット制タスク管理を導入し、CLAUDE.md の Markdown TODO を全件移行、運用規約を配布物 `prompts/beads-tickets.md` として整備する。

**Architecture:** beads 公式機能(`brew install beads` / `bd init` / `bd setup claude|codex`)に統合を全部任せ、自前実装はゼロ。agent-setup が持つのは運用規約テキスト(配布物)と導入手順ドキュメントのみ。フェーズ1としてこのリポジトリ完結で試験運用し、グローバル昇格はチケット化して後日判断する。

**Tech Stack:** beads v1.0系(Dolt embedded ストレージ)、Homebrew、git。

**Spec:** `docs/superpowers/specs/2026-06-13-beads-ticket-system-design.md`

**注意(全タスク共通):**
- beads は破壊的変更が速い CLI。コマンドのフラグが計画と食い違ったら `bd <subcommand> --help` で現行仕様を確認し、意図(タイトル・優先度・説明の登録)を保って読み替えること。
- `bd create` の発行する ID はハッシュベース(例: `bd-a1b2`)で実行時にしか分からない。各作成ステップで出力から ID を控え、後続の `bd dep add` 等で使うこと。以下では `<id:○○>` と表記する。

---

### Task 1: beads のインストールと動作確認

**Files:** なし(システムへのツール導入のみ)

- [ ] **Step 1: Homebrew でインストール**

Run: `brew install beads`
Expected: 正常終了。失敗した場合のフォールバック: `npm install -g @beads/bd`

- [ ] **Step 2: バージョン確認**

Run: `bd version`(動かなければ `bd --version`)
Expected: `1.0.x` 系の出力。0.x 系が入った場合は中断してインストール経路を見直す(spec の前提が v1.0 系新規導入のため)

- [ ] **Step 3: ヘルプでサブコマンド存在確認**

Run: `bd --help`
Expected: `init` / `create` / `ready` / `list` / `close` / `dep` / `setup` が列挙される

---

### Task 2: bd init とチケット実体のコミット

**Files:**
- Create: `.beads/`(bd init が生成。Dolt embedded 実体を含む)
- Modify: `.gitignore`(bd init が変更した場合のみ内容を確認)

- [ ] **Step 1: リポジトリが clean であることを確認**

Run: `git -C /home/tishi/prj/agent-setup status --porcelain`
Expected: 空出力

- [ ] **Step 2: 初期化**

Run: `cd /home/tishi/prj/agent-setup && bd init`
Expected: `.beads/` ディレクトリが作成される。origin 未設定の警告が出ても続行してよい(GitHub 公開前のため正常)

- [ ] **Step 3: 生成物の確認**

Run: `git status --porcelain && ls .beads/`
Expected: `.beads/` 配下(`embeddeddolt/` 等)が untracked または一部 .gitignore 済みで現れる。**確認事項:** bd init が .gitignore に何か追記した場合、その内容を読み、チケット実体(コミットすべきもの)まで ignore していないか確認する。beads のデフォルト設計は「`.beads/` をコミットして git で運ぶ」なので、実体が ignore されていたら beads のドキュメント(`bd init --help`)を確認して意図を把握する

- [ ] **Step 4: 動作スモークテスト(create→ready→close の一連)**

Run:
```bash
bd create "smoke: 動作確認用ダミー" -p 2
bd ready
bd close <id:smoke>
bd ready
```
Expected: create で ID が発行され、1回目の ready に表示され、close 後の ready から消える

- [ ] **Step 5: コミット**

```bash
git add .beads/ .gitignore
git commit -m "Init beads ticket tracking (.beads/)"
```

---

### Task 3: bd setup claude(プロジェクトレベル限定)

**Files:**
- Modify: `.claude/settings.json`(bd setup が生成・変更する想定)
- 監視対象: `~/.claude/settings.json`(グローバル。**変更されたら手動で巻き戻してプロジェクト側に移す**)

- [ ] **Step 1: 実行前スナップショット**

Run:
```bash
md5sum ~/.claude/settings.json 2>/dev/null; cp ~/.claude/settings.json /tmp/claude-settings.bak 2>/dev/null
ls -la /home/tishi/prj/agent-setup/.claude/
```
Expected: 現状の記録が取れる(ファイルが無ければ無いことを記録)

- [ ] **Step 2: セットアップ実行**

Run: `cd /home/tishi/prj/agent-setup && bd setup claude`
Expected: SessionStart / PreCompact フックが導入される

- [ ] **Step 3: 書き込み先の検証(spec の必須要件)**

Run:
```bash
md5sum ~/.claude/settings.json 2>/dev/null
git status --porcelain
cat .claude/settings.json 2>/dev/null
```
Expected: 変更がプロジェクト配下(`.claude/settings.json` 等)に閉じている。**グローバル `~/.claude/settings.json` が変更されていた場合:** 追加されたフック設定をプロジェクトの `.claude/settings.json` に移し、グローバルは `/tmp/claude-settings.bak` から復元する(フェーズ1はリポジトリ完結が要件)

- [ ] **Step 4: チェック**

Run: `bd setup claude --check`
Expected: セットアップ済みと報告される(Step 3 でファイルを移した場合、check がグローバル前提で失敗する可能性がある。その場合はフックが project settings に存在することを目視確認できていれば合格とし、挙動をチケットに記録する: `bd create "bd setup claude --check がプロジェクトレベル設定を認識するか確認" -p 2`)

- [ ] **Step 5: コミット**

```bash
git add .claude/ .beads/
git commit -m "Add beads Claude Code hooks (project-level)"
```

---

### Task 4: bd setup codex(リポジトリ完結で収まる場合のみ)

**Files:**
- 監視対象: `~/.codex/`(グローバル。変更が必要なら今回は見送る)

- [ ] **Step 1: 書き込み先の事前調査**

Run: `bd setup codex --help`
Expected: 何をどこにインストールするかの説明。プロジェクトレベルに限定するオプションの有無を確認

- [ ] **Step 2: 分岐判断**

**プロジェクト配下(AGENTS.md やリポジトリ内設定)に閉じる場合:** 実行して `bd setup codex --check` で確認し、変更をコミットする:
```bash
git add -A && git commit -m "Add beads Codex integration (project-level)"
```

**グローバル(`~/.codex/`)への書き込みが必須の場合:** 今回は実行せず、チケットに先送りする(フェーズ2のグローバル昇格と同時に実施):
```bash
bd create "bd setup codex の導入(グローバル書き込みが必要なためフェーズ2で実施)" -p 2
```
どちらに分岐したかを Task 8 の README 追記に反映すること。

---

### Task 5: 運用規約 prompts/beads-tickets.md の作成

**Files:**
- Create: `prompts/beads-tickets.md`

- [ ] **Step 1: ファイル作成**

以下の内容で作成する(CLAUDE.md に貼る断片。リポジトリ固有の記述を含めないこと):

```markdown
# beads チケット制タスク管理(CLAUDE.md 断片)

## タスク管理(beads)

`.beads/` のあるリポジトリでは、タスク管理に beads(`bd`)を使うこと。

### ルール

- **セッション開始時**: `bd ready` で着手可能タスク(ブロックされていないもの)を確認する。フックが文脈注入する場合はそれを優先し、`bd ready` は補助とする
- **開発中の登録**: 作業中に見つけたバグ・改善案・スコープ外の作業は、その場で対応せず `bd create "タイトル" -p <0-3>` で登録して本筋に戻る(スコープクリープ防止)
- **Markdown TODO の禁止**: CLAUDE.md や README に TODO リストを作らない・育てない。タスクはすべて bd へ
- **着手と完了**: 着手時は `bd update <id> --claim`、完了時は `bd close <id>`
- **依存関係**: 順序依存があるタスクは `bd dep add <child> <parent>` で表現する(`bd ready` が正しく機能するために重要)
- **アップグレード時**: `bd info --whats-new` を確認する(破壊的変更が速いツールのため)

### 未導入リポジトリでの振る舞い

`.beads/` が無いリポジトリでは無理に使わない。セッションをまたぐタスクリストが必要になったら `bd init` の実行をユーザーに提案する。
```

- [ ] **Step 2: 内容確認**

Run: `cat prompts/beads-tickets.md`
Expected: 上記内容と一致。リポジトリ固有の記述(agent-setup への言及)が無いこと

- [ ] **Step 3: コミット**

```bash
git add prompts/beads-tickets.md
git commit -m "Add beads ticket workflow rules as distributable prompt"
```

---

### Task 6: 既存 TODO の beads 移行と運用チケットの登録

**Files:**
- Modify: `.beads/`(bd 経由でのみ変更。手で触らない)

CLAUDE.md の未完了 TODO 6件を移行する。「GitHub 公開」は依存関係の例示のため2チケットに分割する(公開 → URL差し替え)。

- [ ] **Step 1: TODO 6件を登録**

Run(各行ごとに出力の ID を控える):
```bash
bd create "codex-delegate の herdr 閲覧ペインの使い勝手改善(完了後にペインが残る。自動クローズや完了表示を検討)" -p 2
bd create "herdr の pane read / wait output が無人ペインで空を返す問題の調査(判明済み: 人が見ているペインなら動く。要確認: ソース実装上の意図か不具合か。リポジトリ: https://github.com/ogulcancelik/herdr)" -p 2
bd create "Codex が ~/.codex/skills/ の symlink スキルを実際に認識するか実機検証" -p 1
bd create "prompts/fable-codex-collab.md(役割分担)をグローバル CLAUDE.md にも取り込むか検討" -p 2
bd create "GitHub 公開(リモート追加と push)" -p 1
bd create "README の <this-repo> を実URLへ差し替え" -p 2
```
Expected: 6件分の ID が発行される

- [ ] **Step 2: 運用・後続サブプロジェクトのチケットを登録**

Run:
```bash
bd create "beads 運用規約のグローバル CLAUDE.md への昇格(受け入れ条件: 数セッションの実運用で create→ready→close のループが回り不満点が解消されていること。実体は /mnt/c/Users/tishi/.claude/CLAUDE.md)" -p 1
bd create "サブプロジェクト2: ドキュメントの「書く型」規約の設計(種類・置き場所・frontmatter テンプレート)" -p 2
bd create "サブプロジェクト3: indexion による「腐らせない型」の設計(乖離検出・カバレッジ監査 → bd チケット化のループ。indexion は採用前提)" -p 2
bd create "macOS での install.sh 動作検証(pwd -P 化済みだが未検証)" -p 3
```
Expected: 4件分の ID が発行される(Task 4 で見送り分岐した場合はそのチケットも既に存在する)

- [ ] **Step 3: 依存関係を設定**

Run:
```bash
bd dep add <id:README差し替え> <id:GitHub公開>
bd dep add <id:サブプロジェクト3> <id:サブプロジェクト2>
```
Expected: エラーなし

- [ ] **Step 4: ready の検証(spec 検証項目4)**

Run: `bd ready` と `bd list`
Expected: list には全チケット(10〜11件)が表示され、ready には「README差し替え」「サブプロジェクト3」が**現れない**(ブロック中のため)。それ以外の open チケットは ready に現れる

- [ ] **Step 5: コミット**

```bash
git add .beads/
git commit -m "Migrate CLAUDE.md TODOs to beads tickets"
```

---

### Task 7: CLAUDE.md の TODO セクション置き換え

**Files:**
- Modify: `CLAUDE.md`(9〜20行目の `## TODO` セクション)

- [ ] **Step 1: TODO セクションを置き換え**

`## TODO` 見出しから末尾の「完了した項目は消すか `[x]` にして、肥大化したら整理する。」までを削除し、以下に置き換える:

```markdown
## タスク管理

タスクは beads(`bd`)で管理する。Markdown の TODO リストはもう作らない。運用規約は [prompts/beads-tickets.md](prompts/beads-tickets.md) を参照(本リポジトリで試験運用中。検証後にグローバル CLAUDE.md へ昇格予定)。セッション開始時は `bd ready`。
```

- [ ] **Step 2: 確認**

Run: `cat CLAUDE.md`
Expected: TODO リストが消え、上記セクションがある。冒頭の作業ルール3項目(個人データ禁止 / install.sh 再実行 / writing-skills 手順)は変更されていないこと

- [ ] **Step 3: コミット**

```bash
git add CLAUDE.md
git commit -m "Replace CLAUDE.md TODO list with beads ticket management"
```

---

### Task 8: README 更新(導入手順とプロンプト一覧)

**Files:**
- Modify: `README.md`(75行目付近「## プロンプト集(prompts/)」の表、および「## スキルを追加する」の直前)

- [ ] **Step 1: プロンプト一覧表に行を追加**

`codex-instruction-generator.md` の行の下に追加:

```markdown
| [beads-tickets.md](prompts/beads-tickets.md) | beads(bd)によるチケット制タスク管理の運用規約。CLAUDE.md に貼る断片 |
```

- [ ] **Step 2: タスク管理セクションを追加**

「## スキルを追加する」の直前に追加(Task 4 で Codex 統合を見送った場合は最後の一文を「Codex 統合はグローバル昇格時に導入予定。」に差し替える):

````markdown
## タスク管理(beads)

このリポジトリのタスクは [beads](https://github.com/steveyegge/beads)(`bd`)で管理している。チケットの実体は `.beads/` としてコミットされるので、clone すればタスクごと手に入る。

```bash
brew install beads        # または npm install -g @beads/bd
bd ready                  # 着手可能なタスク一覧
```

運用規約は [prompts/beads-tickets.md](prompts/beads-tickets.md) を参照。Claude Code / Codex との連携は `bd setup claude` / `bd setup codex` で導入できる。
````

- [ ] **Step 3: 確認**

Run: `cat README.md`
Expected: 表に3行目が増え、「## タスク管理(beads)」セクションが「## スキルを追加する」の直前にある。コードブロックの入れ子が壊れていないこと(セクション内の bash ブロックが正しく閉じているか目視確認)

- [ ] **Step 4: コミット**

```bash
git add README.md
git commit -m "Document beads ticket workflow in README"
```

---

### Task 9: 最終検証

**Files:** なし

- [ ] **Step 1: チケット一覧の健全性確認**

Run: `bd list && bd ready`
Expected: 全チケットが list に出る。ready にブロック中の2件(README差し替え、サブプロジェクト3)が出ない。smoke チケットは closed

- [ ] **Step 2: claim→close のループ確認(spec 検証項目1)**

Run:
```bash
bd create "verify: claim/close 動作確認" -p 3
bd update <id:verify> --claim
bd show <id:verify>
bd close <id:verify>
```
Expected: claim で in_progress + 自分にアサインされ、show で監査ログが見え、close できる

- [ ] **Step 3: git 状態の確認**

Run: `git status --porcelain && git log --oneline -8`
Expected: working tree clean。Task 2〜8 のコミットが揃っている

- [ ] **Step 4: ユーザーへの手動確認依頼(spec 検証項目2)**

新しい Claude Code セッションを開いたときに SessionStart フックが beads の文脈(ready タスク等)を注入するかは、**このセッション内では検証できない**。ユーザーに「次回セッション開始時に beads の文脈が見えるか」の確認を依頼し、結果待ちであることを最終報告に明記する。検証されるまで「グローバル昇格」チケットは着手しない

---

## 完了の定義

- spec の検証項目 1, 3, 4 がこのセッションで合格(項目2 = フック注入は次回セッションでユーザー確認)
- CLAUDE.md に TODO リストが存在しない
- `prompts/beads-tickets.md` が配布物として存在し、README から参照されている
- working tree が clean
