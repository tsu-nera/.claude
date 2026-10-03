# LGTM

ユーザーが PR をレビューして OK と判断した後に、GitHub PR を merge し、local worktree / local branch / remote branch を安全に片付けるための共通手順。

## 共通方針

- CI が fail している PR は merge しない。
- PR 番号が不明な場合は `gh pr list` で候補を確認し、対象が一意に決まらなければユーザーに確認する。
- worktree 削除後に CWD が消える事故を避けるため、PR branch の worktree を削除する前に main repository path を確定する。
- `gh pr merge --delete-branch` は使わない。merge と branch 削除を分ける。
- `git reset --hard`、`git checkout -f`、`git stash`、`git clean` で同期問題を解消しない。
- local main の未コミット変更や未push commit を勝手に解消しない。

## 共通手順

1. 対象 PR を特定する。
   - 引数やユーザー発話に PR 番号があればそれを使う。
   - なければ `gh pr list` で現在の repository の open PR を確認する。
   - 対象が一意に決まらなければユーザーに確認する。
2. PR 状態を確認する。
   - `gh pr view <PR番号> --json number,title,state,isDraft,mergeable,headRefName,baseRefName,statusCheckRollup,url`
   - `state` が `OPEN` でない、`isDraft` が true、または required checks が失敗している場合は merge しない。
   - `mergeable` が conflict を示す場合は停止せず、`origin/main` への rebase でコンフリクト解消を試みる。並列開発ではコンフリクトは想定内。自動解消できない／設計判断が要るコンフリクトのみ停止してユーザーに報告する。
3. main repository path を確定する。
   - `git rev-parse --git-dir`
   - `git rev-parse --git-common-dir`
   - `git rev-parse --show-toplevel`
4. PR branch の worktree を確認し、必要なら merge 前に削除する。
   - head branch: `gh pr view <PR番号> --json headRefName -q .headRefName`
   - `git worktree list --porcelain` で、その branch を使っている worktree path を探す。
   - 削除対象 path が main repository path と同じ場合は停止してユーザーに報告する。
5. PR を merge する。
   - `gh pr merge <PR番号> --merge`
   - `--delete-branch` は付けない。
6. merge commit oid を取得する。
   - `gh pr view <PR番号> --json mergeCommit -q .mergeCommit.oid`
   - 取得できない場合は 2 秒待って最大 3 回 retry する。
7. local main を安全に最新化する。
   - main branch にいない場合は `git switch main` を使う。
   - `git fetch origin main --quiet`
   - merge commit が `origin/main` に含まれるまで最大 16 秒程度 polling する。
   - `git merge-base --is-ancestor "$MERGE_OID" origin/main` が最後まで失敗する場合は停止して報告する。
   - 確認後に `git merge --ff-only origin/main` を実行する。
   - `git merge --ff-only` が失敗した場合は停止して報告する。破壊的同期を試みない。
8. branch を削除する。
   - local branch が残っていれば `git branch -d <headRefName>` を実行する。
   - remote branch が残っていれば `git push origin --delete <headRefName>` を実行する。
   - branch が存在しない場合のエラーは、既に削除済みとして扱ってよい。
9. 完了報告をする。
   - PR 番号
   - merge commit hash
   - 削除した worktree path
   - 削除した local / remote branch
   - 実行できなかった cleanup があれば理由

## Codex セクション

Codex の tool call は、session 全体の CWD が自動で安全な場所に移るわけではない。worktree を削除した後に古い worktree path を `workdir` にすると command が失敗する。

- 最初に main repository path を取得する。
- worktree を削除する可能性がある操作の前に、以後の `exec_command` の `workdir` を main repository path に固定する。
- PR branch の worktree を削除する場合は、main repository path を `workdir` にして `git worktree remove <worktree-path> --force` を実行する。
- `apply_patch` は使わない。この手順は merge/cleanup 操作用であり、ファイル編集をしない。
- worktree path を削除した後、その path を `workdir` にして command を実行しない。

## Claude Code セクション

Claude Code では shell 内で `cd` できるため、worktree 環境の場合は merge/cleanup 前に main repository へ移動する。

```bash
GIT_DIR=$(git rev-parse --git-dir)
BRANCH=$(git rev-parse --abbrev-ref HEAD)
WORKTREE_PATH=$(pwd)
echo "git_dir=$GIT_DIR branch=$BRANCH worktree=$WORKTREE_PATH"
```

`GIT_DIR` に `worktrees` が含まれる場合は、以降すべての git command の前に main repository へ移動する。

```bash
cd $(git -C $(git rev-parse --git-common-dir)/.. rev-parse --show-toplevel)
```

PR branch の worktree が残っている場合は、merge 前に削除する。

```bash
git worktree remove <worktree-path> --force
```
