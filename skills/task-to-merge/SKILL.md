---
skill: task-to-merge
description: Issue不要。チャットで渡したタスク記述を起点に、worktree隔離で 設計→実装→型チェック→PR作成→merge まで人間の確認なしで自走する。issue-to-merge の非Issue版。「issueを立てずに実装からmergeまでやって」「このタスクを隔離環境で実装してmergeまで」のように、Issueは無いが設計判断ごと委任してmergeまで一気に進めたい時に使う。手元に実装済みの未コミット変更がある場合は /pr-merge を使うこと。
user-invocable: true
---

# Task to Merge - Issueなし・worktree隔離で実装からmergeまで自走

チャットで渡されたタスク記述（= Issueの代わり）を起点に、worktree内で
設計→実装→型チェック→commit→push→PR作成→merge まで人間の確認なしで実行する
**薄いオーケストレーター**。

## 兄弟スキルとの使い分け

- `/task-to-merge`: **Issueなし** + 設計判断も委任 + **worktree隔離** で merge まで自走（このスキル）
- `/issue-to-merge`: 上記の **Issue起点**版（GitHub Issueを入力にする）
- `/pr-merge`: 手元に**既に実装済み**の未コミット変更があり、それをPR経由でmergeするだけ（worktree隔離なし）

つまり「実装をこれからやる」かつ「Issueは立てない」かつ「他の作業を妨害したくない（隔離したい）」が
このスキルの担当領域。実装が既に終わっているなら `/pr-merge`、Issue起点なら `/issue-to-merge`。

このスキルは **動作確認（test-pr）を挟まない**。dry-run やスクリプト実行で検証したいなら、
merge 前に手動で `/test-pr <PR番号>` を呼ぶか、`/issue-to-merge` 経路を使う。

## 使い方
`/task-to-merge <タスクの説明>`

## 設計判断の扱い

Issueが無いぶん要件はチャット文脈にある。**設計の不明点は人間に上げず、自分（Opus）が
調査して決めて続行する**（実装方式・影響範囲・既存パターンとの差異など）。

**人間にエスカレーションするのは次の2つだけ:**
1. 1つのPRで完結できず**タスク分割が必要**と設計時に判断した場合（分割案を提示して指示を待つ）
2. 要件が文字通り意味不明で着手不能な場合

それ以外で停止してよいのは、実装が技術的に行き詰まった時（型チェック修正上限到達・コンフリクト解消不能）のみ。
複雑さは停止の理由にならない（設計を尽くす理由になるだけ）。

## Instructions for Claude:

### Phase 0: 適性判定

- タスク記述が無い → タスク内容を尋ねて停止
- このリポジトリの責務外・複数PRに割るべき規模 → 分割案を提示して指示を待つ

### Phase 1: 実装（worktree隔離エージェントにハンドオフ）

実装は **`isolation: "worktree"` のエージェント**にハンドオフする。**例外なし**（メインの作業ツリーを
汚さない・複数セッション競合を避けるのが目的。行数ではなく隔離の必要性で判断する）。
worktree起動が失敗しても直接ブランチ作業に fallback せず、worktree をリトライする。

エージェントの prompt に必ず含める:
- タスクの要件（チャット文脈から抽出した実装すべき内容）と、自分が下した設計方針の全文
- 変更対象ファイルの見当（あれば）と既存実装の要点
- ブランチ命名規則（新機能→`feat/`, バグ修正→`fix/`, リファクタ→`refactor/`）
- 「worktree の依存セットアップ・品質チェックは `~/.claude/docs/worktree-tooling.md` §1-2 に従うこと」
  （`pnpm install` 禁止・`node_modules` は main の symlink を使う等）
- 「コミット除外対象は `~/.claude/docs/worktree-tooling.md` §3 に従い、`git add` は関連ファイルを明示すること」
- 「実装後 `pnpm run check`（プロジェクト正典コマンドがあれば §2 で判定）を通してから commit すること。
  通らなければ自力修正（最大3回）、不能なら commit せず正確に報告して停止すること」
- 「commit メッセージは Conventional Commits、PR タイトル・本文は日本語、本文に Test plan を含めること」
- 「PR本文末尾のセッションIDフッターには `$CLAUDE_SESSION_ID` ではなく、この値をそのまま使うこと:
  `<親セッションの $CLAUDE_SESSION_ID 値>`」（子エージェントのenvは別物になり得るため値を直接渡す）

エージェントには **PR番号・ブランチ名・変更ファイル一覧・型チェック結果・worktreeパス** を
構造化して返させる。型チェック不能で停止した報告が返ったら、このスキルも中断して人間に報告（mergeしない）。

### Phase 2: マージ

`/lgtm <PR番号>` を Skill ツールで起動する。worktree環境の後処理（メインへの移動・
worktree削除・main の ff-only 同期・ブランチ削除）は lgtm のロジックに委譲する。

### Phase 3: 完了報告

merge済み commit hash・PR番号・実施フェーズのサマリを報告する。
デプロイは明示指示があるまで行わない。

## エラー時の対応

- **Phase 0で分割が必要と判定**: 分割案を提示して終了（自動で複数PR化しない）
- **Phase 1で型チェック失敗・修正不能**: 中断して人間に報告。PRは作らない
- **Phase 2でCI失敗等**: lgtm の指示に従い中断。PRは残したまま人間判断を待つ

## スコープ外

- 動作確認（dry-run・スクリプト検証）を挟みたい → merge前に `/test-pr` を手動で呼ぶ、または `/issue-to-merge`
- 手元に実装済みの変更がある → `/pr-merge`
- Issue起点で進めたい → `/issue-to-merge`
- main 直コミット運用対象（キャッシュ・週次ログ・docs・memory 等）→ `/direct-commit`
