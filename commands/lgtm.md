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
   - マージ直後に **merge commit oid を取得** する:
     ```bash
     MERGE_OID=$(gh pr view <PR番号> --json mergeCommit -q .mergeCommit.oid)
     echo "merge_oid=$MERGE_OID"
     ```
     取得できない場合は2秒待ってリトライ（GitHub 側の反映ラグ対策、最大3回）。

6. **ローカルのクリーンアップ**
   - worktree環境の場合はすでにメインリポジトリにいるはず。そうでなければ `git checkout main`
   - main を最新化する。**fetch 後に merge commit が origin/main に含まれるまでポーリング** してから ff-only マージ:
     ```bash
     for i in 1 2 3 4 5 6 7 8; do
       git fetch origin main --quiet
       if git merge-base --is-ancestor "$MERGE_OID" origin/main 2>/dev/null; then
         break
       fi
       sleep 2
     done
     # 最終確認: origin/main に MERGE_OID が含まれていなければ停止して人間に報告
     git merge-base --is-ancestor "$MERGE_OID" origin/main || { echo "ERROR: $MERGE_OID not in origin/main after 16s"; exit 1; }
     git merge --ff-only origin/main
     ```
   - **理由**: `gh pr merge` 直後は GitHub 側 main 反映に遅延があり、即 `git fetch` すると merge 前の origin/main を取って FF 成功しても merge commit を取りこぼす（stale local main）。後続 `/ship` が古い HEAD でビルドして本番に未反映 PR が混入する事故が発生したため、merge commit を明示的に待つ。
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
