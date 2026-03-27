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

## 分割指針（AIエージェント最適化）

### タスク粒度の原則

サブIssueは**AIエージェントが35分以内で完了できるサイズ**に分割する。

| 粒度 | 目安 | 判定 |
|------|------|------|
| 小さすぎ | 単ファイル1箇所修正 | エージェント起動コストに見合わない → 他と統合 |
| **適切** | **1〜3ファイル変更、明確なAC** | **1 サブIssue = 1 PR として最適** |
| 大きすぎ | 4ファイル超、横断的設計変更 | さらに分割するか、依存関係を整理 |

### 分割の基準

1. **ファイル境界で分割**: 同一ファイルを複数サブIssueが変更しないようにする
2. **共有ファイル（型定義、config等）の変更は1つのサブIssueに集約**
3. **新規ファイル作成は独立サブIssueとして分離しやすい**
4. **依存関係がある場合**: 依存元を先に、依存先を後にする順序を明記

### 分割時のチェックリスト

- [ ] 各サブIssueが1〜3ファイルの変更に収まっているか
- [ ] サブIssue間でファイル変更が重複していないか
- [ ] 各サブIssueのACが具体的で検証可能か
- [ ] 依存関係の順序が明記されているか
- [ ] 親Issueのラベルが各サブIssueに引き継がれているか

## 実行手順

### Step 1: 親Issueの内容確認

```bash
gh issue view <N> --json title,body,labels,comments
```

内容を読み、タスクの全体像を把握する。

### Step 2: 分割案の提示

上記の分割指針に従ってサブIssueの一覧を作成し、ユーザーに提示する。
各サブIssueについて以下を決定:
- タイトル
- body（背景・AC・変更対象ファイル・依存関係）
- ラベル（親Issueから引き継ぐ）

### Step 3: 各サブIssueの作成

各サブIssueの本文に必ず含める:

```markdown
## 親Issue
#<N>

## 背景
（なぜこのタスクが必要か）

## 実装
（何をどう変更するか）

## 変更対象ファイル
- `path/to/file` — 変更内容の概要

## Acceptance Criteria
- [ ] （具体的な完了条件1）
- [ ] （具体的な完了条件2）
- [ ] 品質チェック（型チェック/lint/test）がパスする

## 依存関係
- なし / #xxx が先にマージされている必要あり
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
