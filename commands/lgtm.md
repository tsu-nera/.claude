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

4. **PRブランチのworktree事前チェック**
   - PRのブランチ名を取得: `gh pr view <PR番号> --json headRefName -q .headRefName`
   - `git worktree list` でそのブランチが別のworktreeで使用中か確認
   - 使用中の場合、マージ前にworktreeを削除する:
     ```bash
     git worktree remove <worktreeパス> --force
     ```

5. **マージ**
   - **通常のブランチ**: `gh pr merge <PR番号> --merge --delete-branch`
   - **worktree環境**: `gh pr merge <PR番号> --merge`（`--delete-branch` は内部でgit checkoutを試みて失敗するため使わない）

6. **ローカルのクリーンアップ**
   - **通常のブランチ**:
     - `git checkout main` でmainに戻る
     - `git pull` でmainを最新化
     - `git branch -d <ブランチ名>` でローカルブランチ削除
   - **worktree環境**（すでにメインリポジトリにいる）:
     - `git pull` でmainを最新化
     - `git worktree remove <worktreeパス>`（存在する場合）
     - `git branch -d <ブランチ名>` でローカルブランチ削除
     - `git push origin --delete <ブランチ名>` でリモートブランチ削除

7. **完了報告**
   - マージされたcommit hashとPR番号を報告する

## 注意事項
- CIがfailしている場合はマージしない
- PR番号が不明な場合は `gh pr list` で確認してユーザーに問い合わせる
