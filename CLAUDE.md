# agent-setup 作業ルール

Claude Code / Codex 共用のスキルとプロンプト集を配布するための素材リポジトリ。全体像は README.md を読むこと。

- 個人データ・認証情報は絶対にコミットしない。アーカイブは `~/.local/share/<skill>/`、認証は `~/.config/<skill>/` に逃がす
- `skills/` を追加・改名したら `./install.sh` を再実行し、README.md のスキル一覧表も更新する
- スキルを新規作成・編集するときは superpowers:writing-skills の手順（実機検証してから書く）に従う

## TODO

- [x] codex-delegate スキルの実装（ファイルベース設計: 完了検知=プロセス終了通知、回収=ログRead、herdrは閲覧ペインのみ）
- [ ] codex-delegate の herdr 閲覧ペインの使い勝手改善（完了後にペインが残る。自動クローズや完了表示を検討）
- [ ] herdr の `pane read` / `wait output` が無人ペインで空を返す問題の調査（別セッションで実施予定。判明済み: 人が見ているペインなら動く。要確認: ソース実装上の意図か不具合か。リポジトリ: https://github.com/ogulcancelik/herdr ）
- [ ] Codex が `~/.codex/skills/` の symlink スキルを実際に認識するか実機検証
- [x] グローバル `~/.claude/CLAUDE.md` の Codex Review ルールを codex-delegate スキル方式に差し替え（2026-06-13。実体は `/mnt/c/Users/tishi/.claude/CLAUDE.md`、WSL2/Windows共有）
- [ ] prompts/fable-codex-collab.md（役割分担）をグローバル CLAUDE.md にも取り込むか検討
- [ ] GitHub 公開（リモート追加、README の `<this-repo>` を実URLへ差し替え）
- [ ] macOS での install.sh 動作検証（`pwd -P` 化済みだが未検証）

完了した項目は消すか `[x]` にして、肥大化したら整理する。
