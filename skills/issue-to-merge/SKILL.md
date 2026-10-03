---
skill: issue-to-merge
description: GitHub Issueを読み、設計→実装→PR作成→独立レビュー→mergeまで人間の確認なしで自走する。設計判断もすべて委任したい時に使う。実装後にPRをレビューしてから自分でmergeしたい時は /issue-to-pr を使うこと。
user-invocable: true
---

# Issue to Merge - 全自動ワークフロー

GitHub Issueを入力に、設計→実装→PR作成→独立レビュー→mergeまで人間の確認なしで実行する**薄いオーケストレーター**。
中身は既存スキル（`/issue-to-pr` → merge-gate → `/lgtm`）の連結。

## 使い方
`/issue-to-merge <issue番号>`

## /issue-to-pr との違い（軸は「難易度」ではなく「レビュー要否」）

- `/issue-to-merge`: **設計判断もすべて委任**して merge まで自走。HITL は原則ゼロ。
- `/issue-to-pr`: 実装後に PR を**人間がレビュー**してから merge する経路。

Issue が複雑でも `/issue-to-merge` を使ってよい。複雑さは停止の理由にならない（設計を尽くす理由になるだけ）。
**唯一の例外**は「Issue を複数に分割すべき」と設計時に判断した場合のみ（後述）。

## 設計判断の扱い（最重要）

`/issue-to-pr` は Issue が低品質な場合（Phase 1）と設計に不明点がある場合（Phase 3.5）に AskUserQuestion を出す。
このスキルの配下では **`--autonomous` を付けて起動し、その2つの質問を人間に上げず自分（Opus）が判断して続行する。**
実装方式・影響範囲・既存パターンとの差異などは、すべて自分で調査して決める。

**人間にエスカレーションするのは次の2つだけ:**
1. `/issue-to-pr` が `SPLIT_NEEDED`（1 PR で完結できず Issue 分割が必要）と報告した場合
2. 要件が文字通り意味不明で着手不能な場合（稀）

それ以外で停止してよいのは、実装が技術的に行き詰まった時（テスト修正上限到達・コンフリクト解消不能）のみ。

AC が未達・前提が誤っていた場合は、人間に聞かず、新しいコンテキストの agent に実測結果を渡して AC を改訂させ、それに従って merge まで進める（実装者が自分で AC を緩めない）。

## Instructions for Claude:

### Phase 1: PR作成

`/issue-to-pr <issue番号> --autonomous` を Skill ツールで起動する。

- `SPLIT_NEEDED` の報告 → このスキルを中断し、分割案を人間に提示して指示を待つ
- PR作成成功 → PR番号を取得して Phase 2 へ

### Phase 2: 独立レビュー → マージ

merge してよいかは実装したこのセッションではなく `~/.claude/bin/merge-gate <PR番号>` が決める（repo の policy・verify と、文脈を持たない別の `claude -p` が diff を Issue と突き合わせる）。判定を覆さない。承認なしの `gh pr merge` は hook が止める。

- exit 0（APPROVE） → `/lgtm <PR番号>` を Skill ツールで起動する。rebase や push で head が変わったら merge-gate からやり直す
- exit 1（REJECT） → 指摘を直して push し、もう一度 merge-gate。2回目も REJECT なら exit 2 と同じ扱い
- exit 2（要人間） → merge しない。PR は残し、理由を Issue にコメントして同じ内容を質問として投げ、入力待ちで止まる

### Phase 3: 完了報告

merge済みcommit hashとIssue番号、所要フェーズのサマリをユーザーに報告。

## スコープ外

- 実装後に人間がレビューしてから merge したい → `/issue-to-pr` を使うこと
- 個別の動作確認のみ → `/test-pr` を直接呼ぶこと
