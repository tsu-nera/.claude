---
skill: issue-to-merge
description: GitHub Issueを読み、設計→実装→PR作成→動作確認→mergeまで人間の確認なしで自走する。設計判断もすべて委任したい時に使う。実装後にPRをレビューしてから自分でmergeしたい時は /issue-to-pr を使うこと。
user-invocable: true
---

# Issue to Merge - 全自動ワークフロー

GitHub Issueを入力に、設計→実装→PR作成→動作確認→mergeまで人間の確認なしで実行する**薄いオーケストレーター**。
中身は既存スキル（`/issue-to-pr` → `/test-pr` → `/lgtm`）の連結。

## 使い方
`/issue-to-merge <issue番号>`

## /issue-to-pr との違い（軸は「難易度」ではなく「レビュー要否」）

- `/issue-to-merge`: **設計判断もすべて委任**して merge まで自走。HITL は原則ゼロ。
- `/issue-to-pr`: 実装後に PR を**人間がレビュー**してから merge する経路。

Issue が複雑でも `/issue-to-merge` を使ってよい。複雑さは停止の理由にならない（設計を尽くす理由になるだけ）。
**唯一の例外**は「Issue を複数に分割すべき」と設計時に判断した場合のみ（後述）。

## 設計判断の扱い（最重要）

`/issue-to-pr` は設計に不明点があると AskUserQuestion で人間に聞こうとする。
このスキルの配下では、**その設計質問を人間に上げず、自分（Opus）が設計判断を下して続行する。**
実装方式・影響範囲・既存パターンとの差異などは、すべて自分で調査して決める。

**人間にエスカレーションするのは次の2つだけ:**
1. `/issue-to-pr` が `SPLIT_NEEDED`（1 PR で完結できず Issue 分割が必要）と報告した場合
2. 要件が文字通り意味不明で着手不能な場合（稀）

それ以外で停止してよいのは、実装が技術的に行き詰まった時（テスト修正上限到達・コンフリクト解消不能）のみ。

## Instructions for Claude:

### Phase 1: PR作成

`/issue-to-pr <issue番号>` を Skill ツールで起動する。

- 設計判断を問う AskUserQuestion が出そうになったら → **発火させず自分で決めて続行**
- `SPLIT_NEEDED` の報告 → このスキルを中断し、分割案を人間に提示して指示を待つ
- PR作成成功 → PR番号を取得して Phase 2 へ

### Phase 2: 動作確認

`/test-pr <PR番号>` を Skill ツールで起動する。

- 全パス → Phase 3 へ
- 失敗（修正上限到達） → 中断してユーザーに報告。merge はしない

### Phase 3: マージ

`/lgtm <PR番号>` を Skill ツールで起動する。

### Phase 4: 完了報告

merge済みcommit hashとIssue番号、所要フェーズのサマリをユーザーに報告。

## スコープ外

- 実装後に人間がレビューしてから merge したい → `/issue-to-pr` を使うこと
- 個別の動作確認のみ → `/test-pr` を直接呼ぶこと
