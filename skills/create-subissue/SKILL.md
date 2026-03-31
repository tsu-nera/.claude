---
name: create-subissue
description: 親子関係のあるGitHub Issueを新規作成する。「サブイシューを作って」「親イシューと子イシューを作成」で起動。
user-invocable: true
allowed-tools: Bash
---

# サブイシュー作成スキル

親Issueと子Issue（サブIssue）を新規作成し、GitHub Sub-Issue APIで親子関係を設定する。

## 引数パース

`$ARGUMENTS` から以下を抽出:
- `--repo=owner/repo`: リポジトリ（省略時は現在のリポジトリ）
- それ以外のテキスト: 作成するIssueの内容（自然言語）

リポジトリが省略された場合:
```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

## 実行手順

### Step 1: Issue構造の設計

ユーザーの要望から、以下を整理して提示する:

- 親Issueのタイトルとbody
- 各子Issueのタイトルとbody
- ラベル（あれば）

**確認**: 作成前にユーザーに構造を提示し、承認を得る。

### Step 2: 親Issueの作成

```bash
gh issue create --repo <REPO> --title "<親タイトル>" --body "<親body>" --label "<label>"
```

親Issue番号を控える。

### Step 3: 子Issueの作成

```bash
gh issue create --repo <REPO> --title "<子タイトル>" --body "<子body>" --label "<label>"
```

### Step 4: 親子関係の設定

マークダウンリンクではなく、GitHub Sub-Issue APIを使う:

```bash
PARENT_ID=$(gh issue view <親番号> --repo <REPO> --json id -q .id)

for child_num in <子1> <子2> ...; do
  CHILD_ID=$(gh issue view $child_num --repo <REPO> --json id -q .id)
  gh api graphql -f query='
    mutation($parentId: ID!, $childId: ID!) {
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

作成したIssueの一覧を表示する。

| Issue | タイトル | 関係 |
|-------|---------|------|
| #NNN | 親タイトル | 親 |
| #NNN | 子タイトル1 | 子 |
| #NNN | 子タイトル2 | 子 |
