# LGTM - PRをマージしてブランチを削除する

ユーザーがPRをレビューしてOKと判断したため、マージしてブランチを削除する。

## 手順

1. **現在のPRを確認**
   - `gh pr list` で現在のPRを確認
   - 対象のPR番号を特定する（引数で指定された場合はそれを使う）

2. **CIの状態を確認**
   - `gh pr checks <PR番号>` でCIがpassしているか確認
   - failしている場合はユーザーに報告して中断する

3. **worktree判定と事前準備**
   - `git rev-parse --git-dir` の出力に `worktrees` が含まれればworktree環境
   - worktree環境の場合、**以降すべてのgitコマンドの前に**メインリポジトリへ移動する:
     - メインリポジトリパスの取得: `git -C $(git rev-parse --git-common-dir)/.. rev-parse --show-toplevel`
     - `cd <メインリポジトリパス>` で移動（worktree削除後にCWDが消えて操作不能になるのを防ぐ）
   - 現在のブランチ名とworktreeパスを変数に保存しておく

4. **マージ**
   - **通常のブランチ**: `gh pr merge <PR番号> --merge --delete-branch`
   - **worktree環境**: `gh pr merge <PR番号> --merge`（`--delete-branch` は内部でgit checkoutを試みて失敗するため使わない）

5. **ローカルのクリーンアップ**
   - **通常のブランチ**:
     - `git checkout main` でmainに戻る
     - `git pull` でmainを最新化
     - `git branch -d <ブランチ名>` でローカルブランチ削除
   - **worktree環境**（すでにメインリポジトリにいる）:
     - `git pull` でmainを最新化
     - `git worktree remove <worktreeパス>`（存在する場合）
     - `git branch -d <ブランチ名>` でローカルブランチ削除
     - `git push origin --delete <ブランチ名>` でリモートブランチ削除

6. **完了報告**
   - マージされたcommit hashとPR番号を報告する

## 注意事項
- CIがfailしている場合はマージしない
- PR番号が不明な場合は `gh pr list` で確認してユーザーに問い合わせる
