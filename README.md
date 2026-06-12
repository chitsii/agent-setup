# agent-setup

Claude Code / Codex で使う自作スキルを、別のPCやプロジェクトにそのまま持ち込むための素材リポジトリ。

`git clone` して `./install.sh` を流すと、`~/.claude/skills/` と `~/.codex/skills/` に symlink が張られ、どのプロジェクトで作業していても同じスキルが使える状態になる。スキルの実体はこのリポジトリ1箇所だけなので、`git pull` すれば全マシンに更新が行き渡る。

## 構成

```
skills/            # スキルの実体（SKILL.md + シェルスクリプト。エージェント非依存）
  x-bookmarks/     #   自分のXブックマークをローカル同期・検索
prompts/           # コピペで使うプロンプト集（CLAUDE.md断片など）
.claude/skills     # -> ../skills へのsymlink（このリポジトリ内で作業する時用）
install.sh         # ユーザースコープへの配線スクリプト
```

設計上のルール:

- 個人データと認証情報はリポジトリに置かない。アーカイブは `~/.local/share/<skill>/`、認証は `~/.config/<skill>/` に逃がす。リポジトリに入るのはコードとドキュメントだけ。
- スキルは Claude Code と Codex の両方から同じ実体を参照する（一段 symlink）。
- 環境依存の機能（herdr、codex CLI など）はスキル側で実行時に検出し、無ければフォールバックする。

## 動作環境

- Linux / WSL2（macOS でも動くはずだが未検証）
- bash, git, jq
- Claude Code と Codex CLI はどちらか片方だけでもいい

## インストール

```bash
git clone <this-repo> ~/prj/agent-setup
cd ~/prj/agent-setup
./install.sh
```

これで配線は終わり。オプションは3つ。

```bash
./install.sh --dry-run        # 何が起きるか先に見る
./install.sh --claude-only    # Claude Code にだけ配線
./install.sh --codex-only     # Codex にだけ配線
```

install.sh は何度実行しても安全。壊れたリンクは張り直し、リンク先が本当にこのリポジトリに解決されるかまで検証する。配線先に同名の実ディレクトリがあった場合は消さずに `*.bak.<日時>` に退避する。

リポジトリを別の場所に移動したら `./install.sh` をもう一度実行すればいい。

### スキルごとの初期設定

配線しただけでは動かないスキルもある。必要なCLIツールや認証の手順は各スキルの SKILL.md に書いてあるので、使うものだけ済ませる。

| スキル | 用途 | 必要なもの |
|--------|------|-----------|
| [x-bookmarks](skills/x-bookmarks/SKILL.md) | 自分のXブックマークを同期してローカル検索 | `uv tool install twitter-cli`、jq、XのCookie認証 |
| [codex-delegate](skills/codex-delegate/SKILL.md) | Codexへの実装委譲とコミット前セルフレビュー（ファイルベース・ポーリング不要） | codex CLI（herdrは任意） |
| [doc-audit](skills/doc-audit/SKILL.md) | ドキュメントの鮮度切れ・コード乖離を検出して bd チケット化 | uv、git（bd は任意） |

例えば x-bookmarks なら、twitter-cli を入れて `~/.config/x-bookmarks/auth.env` に Cookie を置き、初回同期を流すところまでやって初めて検索が動く。詳細は [SKILL.md](skills/x-bookmarks/SKILL.md) の Auth Setup を参照。

## 使い方

インストール後は、エージェントとの会話の中で自然に発動する。

```
あなた: ブックマークから Claude Code の便利な使い方を探して
Claude: （x-bookmarks スキルが発動し、ローカルアーカイブを検索して結果を返す）
```

スキルを名指しで呼んでもいい（Claude Code なら `/x-bookmarks`）。スクリプトを直接叩く使い方も普通にできる:

```bash
bash skills/x-bookmarks/scripts/sync.sh        # 差分同期
```

## プロンプト集（prompts/）

スキルにするほどでもない「方針」や「定型プロンプト」は `prompts/` に置いてある。install.sh の配線対象ではなく、必要な箇所に手でコピペして使う。

| ファイル | 中身 |
|----------|------|
| [fable-codex-collab.md](prompts/fable-codex-collab.md) | Fable=設計/レビュー、Codex=実装の役割分担。CLAUDE.md に貼る断片 |
| [codex-instruction-generator.md](prompts/codex-instruction-generator.md) | コードベースを読ませて Codex 向け実装指示書を作らせるプロンプト |
| [beads-tickets.md](prompts/beads-tickets.md) | beads（bd）によるチケット制タスク管理の運用規約。グローバル CLAUDE.md に貼る断片 |
| [doc-conventions.md](prompts/doc-conventions.md) | ドキュメントの種類・置き場所・鮮度管理（frontmatter）の規約。CLAUDE.md に貼る断片 |

## タスク管理（beads）

このリポジトリのタスクは [beads](https://github.com/steveyegge/beads)（`bd`）で管理している。ステルス運用にしており、`.beads/` は丸ごと git 管理外（`.git/info/exclude` で除外）。チケットの実体はローカルの Dolt DB にあり、マシン間同期はリモート追加後の `bd dolt push / pull`、別マシンでの初期化は `bd init` で行う。

```bash
brew install beads        # または npm install -g @beads/bd
bd ready                  # 着手可能なタスク一覧

npm install -g beads-ui   # 人間向けWeb UI
bdui start --open         # localhost:3000 にカンバン(Dolt直結・ライブ更新)
```

運用規約は [prompts/beads-tickets.md](prompts/beads-tickets.md) を参照。Claude Code / Codex 向けのフックや指示ファイルは `bd init` が自動でプロジェクト配下に導入する。

## スキルを追加する

1. `skills/<name>/SKILL.md` を作る（frontmatter に `name` と `description` が必須）
2. `./install.sh` を再実行

これだけ。スクリプトを持つスキルは、個人データの置き場所を `~/.local/share/<name>/` にする規約だけ守ること。

## アンインストール

```bash
rm ~/.claude/skills/<name> ~/.codex/skills/<name>   # symlinkを消すだけ
```

実体とアーカイブ（`~/.local/share/<skill>/`）は残るので、消したければ別途。

## 注意

x-bookmarks は X の非公式API（Cookie認証）を使う。自分のデータの読み取りに限定し、短時間の連続実行は避けること。規約上はグレーなので、その点は理解した上で使ってほしい。
