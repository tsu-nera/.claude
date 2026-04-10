---
name: update-issue
description: GitHub Issueのbodyを更新する。「イシューを更新して」「issue bodyを書き直して」で起動。--titleオプションでタイトルも更新。
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash(gh *)
---

# Issue更新スキル

会話コンテキストからGitHub Issueのbodyを更新する。

## 引数パース

`$ARGUMENTS` から以下を抽出:
- `#<number>` または `<number>`: Issue番号（**必須**）
- `--repo=owner/repo`: リポジトリ（省略時は現在のリポジトリ）
- `--title`: タイトルも更新する（このフラグがない場合はbodyのみ更新）
- それ以外のテキスト: 更新内容に関する補足指示

リポジトリが省略された場合:
```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

## 実行手順

### Step 1: 現在のIssue内容を取得

```bash
gh issue view <NUMBER> --repo <REPO> --json title,body
```

### Step 2: 更新内容の生成

会話の流れと補足指示をもとに、**body**を再生成する。

- 既存bodyの構造をベースに、会話で議論した内容を反映する
- `--title` フラグがある場合はタイトルも新たに生成する

bodyのフォーマット（既存の構造を尊重しつつ）:
```markdown
## 背景

（更新された背景・動機）

## やること

- [ ] タスク1
- [ ] タスク2
```

### Step 3: Issue更新

`--title` フラグがある場合:
```bash
gh issue edit <NUMBER> --repo <REPO> --title "<新タイトル>" --body "<新body>"
```

`--title` フラグがない場合:
```bash
gh issue edit <NUMBER> --repo <REPO> --body "<新body>"
```

### Step 4: 完了報告

更新したIssueのURLを報告する。
