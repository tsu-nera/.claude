---
name: create-issue
description: 会話で決めた内容からGitHub Issueを作成する。「イシューをあげて」「issueにして」で起動。
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash(gh *)
---

# Issue作成スキル

会話コンテキストからGitHub Issueを作成する。

## 引数パース

`$ARGUMENTS` から以下を抽出:
- `--repo=owner/repo`: リポジトリ（省略時は現在のリポジトリ）
- `--label=<label>`: ラベル（省略時はなし、複数指定可）
- それ以外のテキスト: Issueの内容に関する補足

リポジトリが省略された場合:
```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

## コンテキスト

- 変更ファイル: !`git diff --name-only`
- 最近のコミット: !`git log --oneline -5`

## 実行手順

### Step 1: Issue内容の生成

会話の流れから以下を自動生成する:

- **タイトル**: 簡潔に要点をまとめる
- **body**: 背景・目的・やることを整理する

bodyのフォーマット:
```markdown
## 背景

（会話で議論した背景・動機）

## やること

- [ ] タスク1
- [ ] タスク2

---
🤖 Generated with [Claude Code](https://claude.ai/code)
```

### Step 2: Issue作成

```bash
gh issue create --repo <REPO> --title "<タイトル>" --body "<body>" [--label "<label>"]
```

### Step 3: 完了報告

作成したIssueのURLを報告する。
