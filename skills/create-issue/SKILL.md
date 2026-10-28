---
name: create-issue
description: 会話の内容から、やることが明確な GitHub Issue（変更対象と Acceptance Criteria つき）を作成する。「issue立てて」「issueにして」「起票して」で起動。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Issue作成スキル

**Issue 作成の唯一の入口。** 生 `gh issue create` は hook で deny される。

Issue は「やること」を管理する場所。気づき・感想・「あとで考える」は Issue にしない。

## Step 0: 起票してよいか

変更対象と Acceptance Criteria を書き切れるものだけ起票する。書き切れないなら起票しない:

- 調べれば書けるなら、その場で調べて書き切る
- 判断の前提・知見なら memory、経緯なら journal に残す
- やる価値が見合わないなら、却下と理由をユーザーに返す

「とりあえず」「メモ」と言われても同じ。書き切れない時は Issue にせず、どこに残したかを報告する。

## Step 1: 本文を書いて作成

**`references/ready.md` を読んでから書く。** 下流の `issue-to-pr` / codex が自走できる粒度・format・`autopilot` 判定はそこにある。

## 引数

`$ARGUMENTS` から抽出:
- `--repo=owner/repo`（省略時は `gh repo view --json nameWithOwner -q .nameWithOwner`）
- `--label=<label>`（複数可）
- それ以外のテキスト: Issue 内容の補足
