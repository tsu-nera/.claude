---
model: haiku
---

# LGTM - PRをマージしてブランチを削除する

ユーザーがPRをレビューしてOKと判断したため、マージしてブランチを削除する。

## 手順

1. **現在のPRを確認**
   - `gh pr list` で現在のPRを確認
   - 対象のPR番号を特定する（引数で指定された場合はそれを使う）

2. **worktree判定と事前準備**
   - 以下の1コマンドで必要な情報をすべて収集する:
     ```bash
     GIT_DIR=$(git rev-parse --git-dir); BRANCH=$(git rev-parse --abbrev-ref HEAD); WORKTREE_PATH=$(pwd); echo "git_dir=$GIT_DIR branch=$BRANCH worktree=$WORKTREE_PATH"
     ```
   - `GIT_DIR` に `worktrees` が含まれればworktree環境
   - worktree環境の場合、**以降すべてのgitコマンドの前に**メインリポジトリへ移動する:
     ```bash
     cd $(git -C $(git rev-parse --git-common-dir)/.. rev-parse --show-toplevel)
     ```
     （worktree削除後にCWDが消えて操作不能になるのを防ぐ）

4. **PRブランチのworktree事前チェックと削除**
   - PRのブランチ名を取得: `gh pr view <PR番号> --json headRefName -q .headRefName`
   - `git worktree list` でそのブランチがworktreeで使用中か確認
   - 使用中の場合、**マージ前に**worktreeを削除する:
     ```bash
     git worktree remove <worktreeパス> --force
     ```

5. **マージ**
   - 常に `gh pr merge <PR番号> --merge` を使う（`--delete-branch` は付けない）
   - 理由: `--delete-branch` はローカルブランチ削除時にworktree残存等で失敗しやすく、マージ自体も巻き添えで失敗する。ブランチ削除は次のステップで明示的に行う

6. **ローカルのクリーンアップ**
   - worktree環境の場合はすでにメインリポジトリにいるはず。そうでなければ `git checkout main`
   - main を最新化する。**必ず fast-forward 限定で行う**:
     ```bash
     git fetch origin && git merge --ff-only origin/main
     ```
   - **🚫 絶対禁止**: `git reset --hard` / `git checkout -f` / `git stash` / `git clean` で
     divergent や "would be overwritten" を解消しないこと。メインの作業ツリーには
     **未コミットの生成データ（`data/*.csv` 等）が存在しうる**。これらは追跡ファイルなので
     hard reset 等で**復元不能に消失**する（過去に実害発生済み）。
   - `git merge --ff-only` が **fast-forward 不可で失敗**した場合:
     → そこで**停止し、人間に報告する**。自動で破壊的同期を試みない。
       （ローカル main に未push commitがある／乖離している兆候。手動判断が必要）
   - `git branch -d <ブランチ名>` でローカルブランチ削除（残っている場合）
   - `git push origin --delete <ブランチ名>` でリモートブランチ削除（残っている場合）

7. **完了報告**
   - マージされたcommit hashとPR番号を報告する

## 注意事項
- CIがfailしている場合はマージしない
- PR番号が不明な場合は `gh pr list` で確認してユーザーに問い合わせる
