---
model: haiku
---

# LGTM

ユーザーが PR をレビューして OK と判断した。`~/.claude/bin/pr-land <PR番号>` で merge と worktree / branch の後片付けをする。

PR 番号が引数や発話に無ければ `gh pr list` で探し、一意に決まらなければユーザーに確認する。

- exit 0 → 出力（merge commit・削除した worktree / branch・warning）をそのまま報告
- exit 3（base とコンフリクト） → PR の worktree で `origin/<base>` に rebase して解消し、push してもう一度 pr-land。自動解消できない・設計判断が要るコンフリクトなら止めて報告
- exit 2 → merge せず理由を報告

`git reset --hard`・`git checkout -f`・`git stash`・`git clean` で同期問題を解消しない。
