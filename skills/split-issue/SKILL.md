---
name: split-issue
description: GitHub Issueを複数のサブIssueに分割する。エージェント開発向けに各サブIssueにAcceptance Criteriaを含める。「#NNNをサブイシューに分割」「split issue #NNN」で起動。
user-invocable: true
allowed-tools: Bash
---

# Issue分割スキル

既存のGitHub IssueをAcceptance Criteria付きのサブIssueに分割し、親子関係を設定する。

## 引数パース

`$ARGUMENTS` から以下を抽出:
- Issue番号（`#NNN` または `NNN`）: 必須
- `--repo=owner/repo`: リポジトリ（省略時は現在のリポジトリ）

## 実行手順

### Step 1: 親Issueの内容確認

```bash
gh issue view <N> --json title,body,labels,comments
```

内容を読み、タスクの全体像を把握する。

### Step 2: 分割案の提示

以下の観点でサブIssueに分割する:

- **独立性**: 各サブIssueが他に依存せず単独でエージェントが実装できる
- **単一責任**: 1つのサブIssueは1つの変更ポイント（ファイル群）に集中
- **適切な粒度**: 1セッション（1-2時間）で完了できる規模
- **依存関係**: 依存がある場合は明記する

分割案をユーザーに提示し、確認を得てから作成する。

### Step 3: 各サブIssueの作成

各サブIssueの本文に必ず含める:

```markdown
## 親Issue
#<N>

## 背景
（なぜこのタスクが必要か）

## 実装
（何をどう変更するか）

## Acceptance Criteria
- [ ] （具体的な完了条件1）
- [ ] （具体的な完了条件2）
- [ ] `pnpm run check` が通る

## 依存
（依存するIssueがあれば記載、なければ「独立」）

## 注意
- `resources/` をコミットに含めない
- `src/`, `config/` のみをgit addする
```

```bash
gh issue create --title "<title>" --label "<label>" --body "<body>"
```

### Step 4: 親子関係の一括設定

```bash
PARENT_ID=$(gh issue view <parent> --json id -q .id)

for child_num in <child1> <child2> ...; do
  CHILD_ID=$(gh issue view $child_num --json id -q .id)
  gh api graphql -f query='
    mutation AddSubIssue($parentId: ID!, $childId: ID!) {
      addSubIssue(input: {issueId: $parentId, subIssueId: $childId}) {
        issue { number }
        subIssue { number }
      }
    }
  ' -f parentId="$PARENT_ID" -f childId="$CHILD_ID" \
    --jq '.data.addSubIssue | "#\(.issue.number) <- #\(.subIssue.number)"'
done
```

### Step 5: 完了報告

作成したサブIssueの一覧と推奨着手順序を表示する。

| Issue | 内容 | 独立性 |
|-------|------|--------|
| #NNN | タイトル | 独立 / #XXX完了後 |
