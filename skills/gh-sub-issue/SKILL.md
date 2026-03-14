---
name: gh-sub-issue
description: GitHub で子イシューを作成し、親イシューの本文にチェックリストで関連付ける
user-invocable: true
allowed-tools: Bash
---

# GitHub サブイシュー作成スキル

GitHub API はサブイシュー（親子関係）の設定をサポートしていないため、以下の手順で代替する。

## 引数パース

`$ARGUMENTS` から以下を抽出:
- **--parent=N**: 親イシュー番号（必須）
- **--repo=owner/repo**: リポジトリ（省略時は現在のリポジトリ）
- それ以外の引数はサブイシューのタイトルと本文として使う

引数が不十分な場合はユーザーに確認する。

## 実行手順

### Step 1: 親イシューの確認

```
gh issue view <parent> --repo <repo>
```

内容を確認して、どのようなサブイシューを作るべきか把握する。

### Step 2: サブイシューの作成

```
gh issue create --repo <repo> --title "<title>" --body "<body>"
```

本文には必ず以下を含める:
```
親イシュー: #<parent>
```

### Step 3: 親イシューの本文を更新

親イシューの末尾に「## 関連イシュー」セクションがなければ追加し、
作成したサブイシューをチェックリスト形式で追記する:

```
## 関連イシュー

- [ ] #<new-issue> <title>
```

既に「## 関連イシュー」セクションがある場合は、そこに行を追記する。

手順:
1. `gh issue view <parent> --repo <repo> --json body -q .body` で現在の本文を取得
2. 末尾にチェックリスト行を追加した新しい本文を作成
3. `gh issue edit <parent> --repo <repo> --body "<new-body>"` で更新

### Step 4: 完了報告

作成したイシューの URL と、親イシューの更新内容を報告する。
