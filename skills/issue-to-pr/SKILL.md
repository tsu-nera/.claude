---
skill: issue-to-pr
description: GitHub Issueを読み、設計→実装→PR作成まで一気通貫で実行する
user-invocable: true
---

# Issue to PR - オーケストレーター

GitHub Issueを入力に、planner→coder→PR作成を管理する薄いオーケストレーター。
**単一Issue専用。** 複数Issueを並列処理したい場合は複数セッションを開く。

## 使い方
`/issue-to-pr <issue番号>`

## Instructions for Claude:

**重要: EnterPlanMode / ExitPlanMode は使用禁止。** 人間への確認はPR作成時のみ。

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
    🤖 Claude Code session: \`$CLAUDE_SESSION_ID\`
    EOF
    )'

    ## 注意事項
    - `pnpm install` は実行しないこと（シンボリックリンクが壊れる）
    - `resources/` はコミットに含めないこと
    - 設計変更はしないこと。仕様に問題がある場合は中断して報告
    - ブランチ命名規則: ラベルから feature→feat/, fix→fix/, improve→refactor/
  "
)
```

**ファイルサイズhookにブロックされた場合**:
確認を求めずに、該当ファイルの分割リファクタリングを行ってから本来の変更を実装する。

---

### Phase 4: 結果確認

coderの結果を確認する。

- **PR作成成功**: PR URLをユーザーに報告。specファイルをクリーンアップ。
  ```bash
  rm -f /tmp/spec-<issue番号>-impl.md /tmp/spec-<issue番号>-test.md
  ```
- **品質チェック3回失敗**: ユーザーに報告し、方針を相談。
- **仕様の曖昧さで中断**: plannerの設計を見直し、必要ならユーザーに確認してcoderを再起動。
- **コンフリクト自動解消不可**: ユーザーに報告。

---

## エラー時の対応

- **planner中断（低品質Issue）**: ユーザーに方針確認 → plannerを再起動
- **coder中断（仕様の曖昧さ）**: impl-specを修正 → coderを再起動
- **品質チェック失敗**: coderが直接修正。3回失敗したらユーザーに報告
- **マージコンフリクト**: ユーザーに報告し方針確認
