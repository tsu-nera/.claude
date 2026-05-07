---
skill: issue-to-merge
description: GitHub Issueを読み、設計→実装→PR作成→動作確認→mergeまでhuman-in-the-loopなしで一気通貫で実行する。簡単で自信のあるIssue向け。曖昧・複雑な場合は使わず /issue-to-pr を使うこと。
user-invocable: true
---

# Issue to Merge - 全自動ワークフロー

GitHub Issueを入力に、PR作成→動作確認→mergeまで人間の確認なしで実行する**薄いオーケストレーター**。
中身は既存スキル（`/issue-to-pr` → `/test-pr` → `/lgtm`）の連結。

## 使い方
`/issue-to-merge <issue番号>`

## いつ使うか

**使うべき**:
- AC明確・変更ファイル特定済みの高品質Issue
- 1-2ファイルの小規模変更
- 既存パターンを踏襲する単純な修正

**使うべきでない（→ `/issue-to-pr` を使う）**:
- 設計判断が必要
- 複数アプローチがあり方針未確定
- 影響範囲が広い・型変更が他モジュールに波及

## Instructions for Claude:

### Phase 0: 適性判定

```bash
gh issue view <番号>
```

Issue品質を判定し、**低品質または複雑と判断したらここで停止**してユーザーに `/issue-to-pr` の使用を提案する。
判定基準は `/issue-to-pr` Phase 1 と同じ。迷ったら停止する（このスキルは「迷いなく進める時だけ使う」前提）。

### Phase 1: PR作成

`/issue-to-pr <issue番号>` を Skill ツールで起動する。

- Phase 3.5（設計レビュー）で AskUserQuestion が発火した場合 → このスキルを中断し、`/issue-to-pr` 単体に切り替えるようユーザーに通知
- PR作成成功 → PR番号を取得して Phase 2 へ

### Phase 2: 動作確認

`/test-pr <PR番号>` を Skill ツールで起動する。

- 全パス → Phase 3 へ
- 失敗（修正上限到達） → 中断してユーザーに報告。merge はしない

### Phase 3: マージ

`/lgtm <PR番号>` を Skill ツールで起動する。

### Phase 4: 完了報告

merge済みcommit hashとIssue番号、所要フェーズのサマリをユーザーに報告。

## エラー時の対応

- **Phase 0で複雑と判定**: `/issue-to-pr` 使用を提案して終了
- **Phase 1で設計確認が必要**: 中断、`/issue-to-pr` に切り替え
- **Phase 2でテスト失敗**: 中断、PR は残したままユーザー判断を待つ
- **Phase 3でCI失敗等**: lgtm の指示に従い中断

## スコープ外

- 設計判断・人間レビュー → `/issue-to-pr` を使うこと
- 個別の動作確認のみ → `/test-pr` を直接呼ぶこと
