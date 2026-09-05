---
skill: review-codex-pr
description: codex CLI が仕上げた PR/worktree をレビューし、問題なければ merge、軽微な修正が必要なら worktree を直接編集して commit してから merge するところまで自走する。codex の実装完了サマリ（PR URL・Branch・Commit・Worktree path）を貼り付けて「レビューして問題なければ lgtm、直すなら worktree で直して merge」系の依頼をされたら必ずこれを使う。
user-invocable: true
---

# Review Codex PR - codex 実装 PR のレビュー→修正→merge

codex CLI に実装を委譲した後の受け取り工程を自走する**薄いオーケストレーター**。
レビューは `reviewer` subagent、merge は `/lgtm` に委譲し、判断（merge するか／直すか／人間に返すか）だけをメインで持つ。

前提のワークフロー: Issue設計(Claude) → 実装〜PR作成(codex) → **レビュー〜merge(このスキル)**。
codex は stop condition（full validation failure の原因が短時間で切れない・live smoke / RPC / 外部API /
market data 調査が主作業化・product decision 化）に当たると **PR を作らず handoff** する。
handoff サマリは本スキルの対象外（下記「使うべきでない」）。
codex を使う動機はメイン context のトークン節約なので、PR全体を読む重い作業は subagent に逃がし、
メイン会話には diff 本文を載せない。

## 使い方

codex の完了サマリ（PR URL・Branch・Commit・Worktree path）を貼り付けて起動する。
worktree path か PR番号のどちらかが分かれば動く。

## いつ使うか

**使うべき**: codex が worktree にコミット済みの PR を受け取り、レビューして問題なければ merge、
軽微な指摘なら自分で直して merge まで一気に進めたいとき。

**使うべきでない**:
- 手元の（codex 由来でない）未コミット変更を PR にしたい → `/pr-merge`
- Issue 起点で設計から自走したい → `/issue-to-merge`
- 実装が大きく設計を伴う修正が必要と分かっている → レビューだけして人間に返す（下記 Phase 3 の停止条件）
- **codex が stop condition で止めた handoff サマリ**（PR 無し・Blocker / next decision あり）→
  レビュー〜merge フローに入らない。handoff の Branch / Worktree / Changed files / Implemented /
  Focused・Full validation / Blocker を引き継ぎ、Blocker の調査・実装をメイン Claude の通常作業として継続する
  （完了後の PR 化は `/pr-merge` 等）

## Instructions for Claude:

### Phase 0: 入力の確定

貼り付けられた codex サマリから抽出する:
- **Worktree path**（絶対パス）
- **PR番号 / URL**
- Branch, Commit（補助情報。無くてもよい）

**handoff 判定を先に行う**: サマリに PR が無く Blocker / next decision が書かれていれば handoff。
本スキルを適用せず、その旨を報告して worktree 引き継ぎ（通常作業）に切り替える（「使うべきでない」参照）。

不足時の補完:
- worktree path のみ → `git -C <worktree> rev-parse --abbrev-ref HEAD` で branch、`gh pr list --head <branch> --json number,url` で PR を引く
- PR番号のみ → `gh pr view <PR> --json headRefName` の branch を `git worktree list` で照合して worktree path を得る
- どちらも一意に決まらなければユーザーに確認する（推測で進めない）

### Phase 1: diff 基準の確定（phantom revert ガード）

worktree は作成後に origin/main が他PRのマージで前進していることがある。この状態で
`git diff origin/main` を取ると、**PR が触っていないファイル**が「revert/削除」として現れ、
reviewer が scope 違反と誤診する（phantom revert）。これを先に潰す。

```bash
git -C <worktree> fetch origin main --quiet
MB=$(git -C <worktree> merge-base HEAD origin/main)
ORIGIN=$(git -C <worktree> rev-parse origin/main)
```

- `MB` == `ORIGIN` → ベースは最新。レビューの diff 基準は `origin/main`。
- `MB` != `ORIGIN` → **diverged**。レビューの diff 基準は **merge-base (`$MB`)** にする
  （`git diff $MB` が PR 本来の変更だけになる）。この場合、後段の merge は GitHub 側で行うため
  ローカル rebase は必須ではない。ただし `gh pr view` の `mergeable` が conflict を示すなら
  merge できないので、worktree で `git rebase origin/main` → 型チェック（§2 で判定）→
  `git push --force-with-lease` してから進む（rebase で conflict が出たら停止して報告）。

コミットが実際に触るファイルの真実は `git -C <worktree> show --stat --format="" <commit>` で確認できる。

### Phase 2: レビュー（reviewer subagent）

`reviewer` subagent（project agent, sonnet）を起動する。**worktree の絶対パスと PR番号の両方**を渡す:
- worktree path = ファイル全体を PR ブランチ状態で Read させるため（無いと agent は main checkout で
  周辺コードを古い内容で読み、文脈がズレる）
- PR番号 = PR body の WHY・Test plan を文脈にするため
- Phase 1 で diverged なら「diff 基準は merge-base `<hash>`（`git diff <hash>`）。origin/main 基準だと
  phantom revert が出る」と明記して渡す

reviewer は規約違反・バグ・改善提案・別issue推奨を確信度つきで返す。コードは変更しない。

### Phase 3: 判定（オーケストレーター）

reviewer の結果を確信度「高」中心に判定する:

- **問題なし / nitpick のみ** → Phase 5（merge）へ
- **軽微な要修正**（その差分内で完結、既存ヘルパー差し替え数行程度） → Phase 4（自分で直す）へ
- **大規模 / 設計判断を伴う**（別issue推奨・複数ファイル横断・アプローチ再検討） →
  **停止**。reviewer の指摘を要約してユーザーに返し、merge しない。ここは委譲せず人間判断を仰ぐ。

判断に迷う（軽微か大規模か曖昧）ときは大規模側に倒して停止する。誤って壊れた実装を merge するより、
一度人間に返すほうが安い。

**full validation の unrelated / flaky 主張の検証**: codex は full validation failure を
unrelated / flaky と判断した場合 PR body に明記して PR 作成まで進める運用。この主張は鵜呑みにせず、
merge 前に merge-base（main 相当）で同じ failure が再現するか確認する。
再現すれば unrelated 確定で続行、再現しなければ diff 起因として Phase 4 / 停止側に倒す。

### Phase 4: 修正（メインの Claude が worktree を直接編集）

軽微な指摘に限り、worktree 内で自分で直す。codex に再委任しない（往復コストが指摘規模に見合わない）。

1. `<worktree>` 内のファイルを Edit で直接修正する
2. 型チェック（worktree では依存を再 install しない。コマンド判定は `~/.claude/docs/worktree-tooling.md` §1/§2 に従う。純粋関数を触ったらテストも回す）
3. 関連ファイルのみ明示 add してコミット（Conventional Commits。コミット除外対象は
   AGENTS.md「コミット除外対象」= `resources/` `logs/weekly/` `resources/goplus/` を混入させない）
4. `git push`（既存 PR ブランチへの追記）
5. 修正が指摘を確実に潰したか、**変更行だけ**軽く自己確認する（全 PR の再レビューは不要。
   修正が別の箇所を壊しうるなら reviewer を再度回す）

型チェックが通らず自力で直せない → 停止してユーザーに報告（merge しない）。

### Phase 5: merge

`/lgtm <PR番号>` を Skill ツールで起動する。CI fail 時の非merge・worktree/branch の後片付けは
すべて `/lgtm` のロジックに委譲する（このスキルで再実装しない）。

### Phase 6: 報告

- merge 済み PR番号・merge commit hash
- レビュー結果のサマリ（無指摘 / 自分で直した内容 / 別issue推奨があればその範囲）
- Phase 4 で修正した場合は追加コミット hash

## スコープ外・停止条件

- **設計判断を伴う修正**: 直さず reviewer 指摘を添えてユーザーに返す
- **CI fail / conflict**: `/lgtm` の判定に従い merge しない。PR は残す
- **破壊的操作**: `git reset --hard` 等での同期解消はしない（`/lgtm` 方針に準拠）
- **codex 実装サマリの検証**: diff が真実。サマリ文面は信用の根拠にしない

## 関連

- メモリ: codex-impl-subagent-review-workflow（渡し方の正典）、worktree-diverged-base-phantom-revert（Phase 1 の罠）
- 委譲先: `reviewer` agent、`/lgtm`
