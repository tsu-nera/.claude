---
name: gh-sub-issue
description: GitHub で子イシューを作成し、親イシューにネイティブのサブイシューとして関連付ける
user-invocable: true
allowed-tools: Bash
---

# GitHub サブイシュー作成スキル

GitHub GraphQL API の `addSubIssue` mutation でネイティブのサブイシュー（親子関係）を設定する。

## 引数パース

`$ARGUMENTS` から以下を抽出:
- **--parent=N**: 親イシュー番号（必須）
- **--repo=owner/repo**: リポジトリ（省略時は現在のリポジトリ）
- それ以外の引数はサブイシューのタイトルと本文として使う

引数が不十分な場合はユーザーに確認する。

## 実行手順

### Step 1: 親イシューの確認

```bash
gh issue view <parent> --repo <repo>
```

内容を確認して、どのようなサブイシューを作るべきか把握する。

### Step 2: サブイシューの作成

```bash
gh issue create --repo <repo> --title "<title>" --body "<body>"
```

作成後、新しいイシューの番号を取得する。

### Step 3: 親子関係の設定（GraphQL API）

両イシューの node ID を取得して `addSubIssue` mutation を実行する:

```bash
# 親イシューの node ID 取得
PARENT_ID=$(gh issue view <parent> --repo <repo> --json id -q .id)

# 子イシューの node ID 取得
CHILD_ID=$(gh issue view <child> --repo <repo> --json id -q .id)

# サブイシューとして関連付け
gh api graphql -f query='
  mutation AddSubIssue($parentId: ID!, $childId: ID!) {
    addSubIssue(input: {issueId: $parentId, subIssueId: $childId}) {
      issue { number title }
      subIssue { number title }
    }
  }
' -f parentId="$PARENT_ID" -f childId="$CHILD_ID"
```

### Step 4: 完了報告

作成したイシューの URL と、親子関係が設定されたことを報告する。
