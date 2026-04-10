---
skill: test-pr
description: PRの動作確認を実行する。PRのTest planに沿ってスクリプト実行やdry-runで検証し、失敗時はコード修正→再テストのループを回す。
user-invocable: true
---

# Test PR - PR動作確認ワークフロー

PRのTest planを抽出し、`@validator` エージェントに委任して動作確認を実行する。

## 使い方
`/test-pr <PR番号>`

## Instructions for Claude:

**薄いオーケストレーター。** PR情報の収集とブランチ準備を行い、テスト実行はvalidatorに委任する。

---

### Phase 1: PR情報の収集

```bash
gh pr view <PR番号> --json title,body,files,headRefName
```

PRのbodyから以下を抽出:
- **Test plan**: リスト項目を実行対象として取得

**Test planが空の場合**: PRコメントに「動作確認項目なし」と投稿して終了。

---

### Phase 2: ブランチ準備

1. PRのブランチ名を取得（headRefName）
2. 既存worktreeがそのブランチを使用しているか確認: `git worktree list`
3. 既存worktreeがあれば → そのworktreeディレクトリを作業ディレクトリとして使用
4. なければ → `gh pr checkout <PR番号>` で切り替え

worktreeの場合は `pnpm install` を実行（node_modulesが共有されないため）。

---

### Phase 3: Validator起動

`@validator` エージェントを起動し、以下を渡す:

```
@validator
PR番号: <PR番号>
テスト項目リスト:
<Phase 1で抽出したTest plan項目>
作業ディレクトリ: <worktreeパスまたはリポジトリルート>
headRefName: <headRefName>
```

---

### Phase 4: 修正ループ（最大3回）

validatorの結果を確認し、FAILがあれば修正ループに入る。

- **全パス** → Phase 5へ
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

修正後、**Phase 3に戻り validator を再起動**（全テスト項目を再実行）。

3回失敗したら修正ループを打ち切り、Phase 5へ。

---

### Phase 5: 結果報告

validatorの最終結果をユーザーに報告する。

- **全パス（修正なし）**: 「全テストパス。PRコメントに結果を投稿しました。」
- **全パス（修正あり）**: 「N回の修正後に全テストパス。修正コミットをプッシュ済み。」
- **失敗（上限到達）**: 失敗内容と修正試行の経緯を報告。人間の判断を求める。

---

## スコープ外

- **テスト項目の設計**: plannerの責務（将来的にplanner.mdが担当）
- **マージ判断**: 人間が行う
- **破壊的操作**: 送金、データ削除等は絶対に実行しない
