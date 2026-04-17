---
skill: issue-to-lgtm-agents
description: GitHub Issueを読み、設計→実装→テスト→マージまで一気通貫で実行する（planner/coder/validatorエージェント使用版）
user-invocable: true
---

# Issue to LGTM - 一気通貫オーケストレーター

GitHub Issueを入力に、planner→coder→validator→マージを管理する薄いオーケストレーター。
**単一Issue専用。** 複数Issueを並列処理したい場合は複数セッションを開く。

## 使い方
`/issue-to-lgtm <issue番号>`

## Instructions for Claude:

**重要: EnterPlanMode / ExitPlanMode は使用禁止。** 人間への確認はマージ判断時のみ。

---

### Phase 1: Planner起動（設計）

plannerエージェントを起動し、Issue分析→impl-spec/test-spec設計を委譲する。

```
Agent(
  subagent_type: "planner",
  model: "opus",
  prompt: "
    Issue #<番号> の設計を行ってください。

    リポジトリ: <owner/repo>
    作業ディレクトリ: <絶対パス>

    出力先:
    - impl-spec: /tmp/spec-<issue番号>-impl.md
    - test-spec: /tmp/spec-<issue番号>-test.md
  "
)
```

**plannerが「低品質」と判定して中断した場合**:
AskUserQuestion でユーザーに方針を確認し、その回答を含めてplannerを再起動する。

**plannerが「設計上の判断ポイント」を報告した場合**:
内容を確認し、不明点がある場合は AskUserQuestion でユーザーに確認する。
確認不要と判断した場合はそのまま Phase 2 へ進む。

---

### Phase 2: 設計レビュー

plannerの出力（`/tmp/spec-<issue番号>-impl.md`, `/tmp/spec-<issue番号>-test.md`）を読む。

**以下のいずれかに該当する場合、AskUserQuestion でユーザーに確認してから Phase 3 へ進む:**
- 複数の実装アプローチがあり、Issueで方針が決まっていない
- 既存コードのパターンと異なる設計を採用しようとしている
- Issueの記述と実際のコードベースの状態に齟齬がある
- 影響範囲が想定より広く、スコープの確認が必要

**確認メッセージのフォーマット:**
```
## 設計確認（#<issue番号>）

### 実装方針
<impl-specの概要を箇条書き>

### 確認したいポイント
- <不明点1>

これで進めてよいですか？
```

**不明点がない場合**: 確認なしでそのまま Phase 3 へ。

---

### Phase 3: Coder起動（実装）

coderエージェントを `isolation: "worktree"` で起動し、実装を委譲する。

impl-specとtest-specの内容を読み込み、coderへのプロンプトに含める。

```
Agent(
  subagent_type: "coder",
  model: "sonnet",
  isolation: "worktree",
  mode: "auto",
  prompt: "
    Issue #<番号> を実装してください。

    ## 実装仕様
    <impl-specの全文をここに貼る>

    ## テスト仕様
    <test-specの全文をここに貼る>

    ## 実装後の手順

    ### 品質チェック
    1. `pnpm run check && pnpm run test`（失敗時は直接修正。3回失敗したら報告）
    2. テスト仕様から1つコマンドを選んでスモークテスト実行
    3. `git diff main` で差分確認。`resources/` が混入していないか確認
    4. mainとのコンフリクトチェック:
       git fetch origin main
       if git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main | grep -q '<<<<<<'; then
         git merge origin/main
       fi

    ### コミット・PR作成
    git add <変更ファイル>  # resources/ を含めない
    git commit -m '$(cat <<EOF
    <type>: <概要>

    Closes #<issue番号>

    Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
    EOF
    )'

    PRのタイトル・本文は日本語で記述:
    gh pr create --title '<日本語タイトル>' --body '$(cat <<EOF
    ## 概要
    <変更内容の箇条書き>

    Closes #<issue番号>

    ## テスト計画
    <test-specのテスト項目をチェックリスト形式で記載>

    ---
    🤖 Claude Code session: \`<親セッションの$CLAUDE_SESSION_ID値をここに埋め込む>\`
    EOF
    )'

    ## 注意事項
    - `pnpm install` は実行しないこと。代わりに `ln -s <main-repo>/node_modules <worktree>/node_modules` でシンボリックリンクを作成
    - `resources/` はコミットに含めないこと
    - 設計変更はしないこと。仕様に問題がある場合は中断して報告
    - ブランチ命名規則: ラベルから feature→feat/, fix→fix/, improve→refactor/
  "
)
```

**ファイルサイズhookにブロックされた場合**:
確認を求めずに、該当ファイルの分割リファクタリングを行ってから本来の変更を実装する。

---

### Phase 4: Validator起動（テスト）

coderがPR作成に成功したら、test-specを使ってvalidatorを起動する。

1. PR番号を取得（coderの結果から）
2. test-specファイル（`/tmp/spec-<issue番号>-test.md`）を読む
3. PRのブランチ名を取得: `gh pr view <PR番号> --json headRefName -q .headRefName`
4. worktree準備:
   - `git worktree list` で既存worktreeを確認
   - worktreeがあればそのパスを使用、なければ `gh pr checkout <PR番号>` で切り替え
5. validatorを起動:

```
Agent(
  subagent_type: "validator",
  model: "sonnet",
  prompt: "
    PR #<PR番号> の動作確認を行ってください。

    テスト項目リスト:
    <test-specのテスト項目をここに貼る>

    作業ディレクトリ: <worktreeパスまたはリポジトリルート>
    headRefName: <ブランチ名>
  "
)
```

---

### Phase 5: 修正ループ（最大3回）

validatorの結果を確認し、FAILがあれば修正ループに入る。

- **全パス** → Phase 6へ
- **FAILあり** → sonnetサブエージェント（coder）を起動して修正

```
Agent(
  model: "sonnet",
  prompt: "以下のテスト失敗を修正せよ。
    失敗したテスト項目: <項目>
    エラーログ: <validatorの出力>
    対象ファイル: <PRの変更ファイル一覧>
    作業ディレクトリ: <パス>

    修正後:
    1. pnpm run check で型チェックを通す
    2. git add <変更ファイル> && git commit で修正をコミット
    3. git push"
)
```

修正後、**Phase 4に戻り validator を再起動**（全テスト項目を再実行）。

3回失敗したら修正ループを打ち切り、Phase 6へ。

---

### Phase 6: 結果報告とマージ判断

#### 全テストパスの場合

AskUserQuestion でユーザーにマージ確認を求める:

```
## 動作確認完了（#<issue番号>）

PR: <PR URL>

### テスト結果
- 全 N 項目パス
- 修正ループ: M 回

マージしてよいですか？
```

**ユーザーが承認した場合**: マージを実行する。

1. worktree環境の判定と事前準備:
   ```bash
   GIT_DIR=$(git rev-parse --git-dir); BRANCH=$(git rev-parse --abbrev-ref HEAD); echo "git_dir=$GIT_DIR branch=$BRANCH"
   ```
   - `GIT_DIR` に `worktrees` が含まれればworktree環境
   - worktree環境の場合、メインリポジトリへ移動:
     ```bash
     cd $(git -C $(git rev-parse --git-common-dir)/.. rev-parse --show-toplevel)
     ```

2. PRブランチのworktree削除（使用中の場合）:
   ```bash
   git worktree remove <worktreeパス> --force
   ```

3. マージ（`--delete-branch` は付けない）:
   ```bash
   gh pr merge <PR番号> --merge
   ```

4. クリーンアップ:
   ```bash
   git checkout main
   git pull
   git branch -d <ブランチ名>
   git push origin --delete <ブランチ名>
   rm -f /tmp/spec-<issue番号>-impl.md /tmp/spec-<issue番号>-test.md
   ```

#### テスト失敗（修正上限到達）の場合

マージせず、失敗内容と修正試行の経緯をユーザーに報告する。specファイルは残す。

---

## エラー時の対応

- **planner中断（低品質Issue）**: ユーザーに方針確認 → plannerを再起動
- **coder中断（仕様の曖昧さ）**: impl-specを修正 → coderを再起動
- **品質チェック失敗**: coderが直接修正。3回失敗したらユーザーに報告
- **テスト失敗**: 修正ループ（最大3回）。上限到達でユーザーに報告
- **マージコンフリクト**: ユーザーに報告し方針確認
- **CI失敗**: マージしない。ユーザーに報告
