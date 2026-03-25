---
name: post-plan-to-issue
description: plan mode で生成された設計プランを GitHub Issue にコメントとして投稿する
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# Plan → Issue 投稿スキル

plan mode で生成された `~/.claude/plans/*.md` の設計プランを、指定した GitHub Issue にコメントとして投稿する。

## 引数パース

`$ARGUMENTS` から以下を抽出:
- **Issue番号**（必須）: `#127` や `127` の形式
- **--plan=ファイル名**: plan ファイル指定（省略時は最新の plan ファイルを使用）
- **--repo=owner/repo**: リポジトリ（省略時は現在のリポジトリ）

引数が不十分な場合はユーザーに確認する。

## 実行手順

### Step 1: plan ファイルの特定

`--plan` が指定されている場合はそのファイルを使用。
未指定の場合は最新の plan ファイルを取得:

```bash
ls -t ~/.claude/plans/*.md | head -1
```

plan ファイルの内容を Read ツールで読み、ユーザーに確認する:
- ファイル名
- プランのタイトル（1行目）
- 投稿先 Issue 番号

### Step 2: Issue の現在の内容を確認

```bash
gh issue view <issue-number> --repo <repo>
```

Issue のタイトルと本文を表示して、投稿先が正しいか確認する。

### Step 3: タスク規模の判定と追加情報の収集

plan ファイルの変更ファイル数・モジュール数から規模を判定する:

| 規模 | 目安 | plan だけ | 追加情報 |
|------|------|----------|---------|
| 小 | 1-2ファイル、単一モジュール | 十分 | 不要 |
| 中 | 3-5ファイル、複数モジュール | やや不足 | 判断基準を追記 |
| 大 | 6+ファイル、アーキテクチャ変更 | 不足 | 却下案・制約・指針が必須 |

**中〜大規模の場合**、plan ファイルには最終案しか残っていない。plan mode の会話中に議論された以下の情報が欠落している可能性がある。ユーザーに「plan mode で却下した案や制約はあるか？」と確認し、あれば追加情報セクションに含める:

- **却下した代替案とその理由**: なぜ他のアプローチを選ばなかったか（実装セッションで同じ案を再検討するのを防ぐ）
- **既存コードの制約**: plan mode で気づいた注意点（例: 「この関数は副作用がある」「この型は変更不可」）
- **判断基準**: 実装中に迷ったときの指針（例: 「パフォーマンスより可読性を優先」「既存パターンに合わせる」）

### Step 4: コメントの整形

plan ファイルの内容を以下の形式でコメント用に整形する:

**小規模タスク:**
```markdown
## 設計メモ（from plan mode）

### 実装プラン

（plan ファイルの Context セクション以降の内容）

### 変更ファイル一覧

（plan ファイルにあればそのまま転記）

### 検証

（plan ファイルにあればそのまま転記）
```

**中〜大規模タスク:**
```markdown
## 設計メモ（from plan mode）

### 実装プラン

（plan ファイルの Context セクション以降の内容）

### 変更ファイル一覧

（plan ファイルにあればそのまま転記）

### 設計判断の補足

#### 却下した代替案
- **案A**: 〇〇 → 却下理由: △△

#### 既存コードの制約
- `src/xxx.ts`: 〇〇に注意

#### 実装時の判断基準
- 迷ったら〇〇を優先する

### 検証

（plan ファイルにあればそのまま転記）
```

注意:
- plan ファイルのタイトル行（`# Plan: ...`）はコメントには含めない（Issue タイトルと重複するため）
- コードブロック内のコードは省略せずそのまま含める
- 冗長な説明は簡潔にまとめる

### Step 5: コメントの投稿

コメントの末尾に Claude Code セッションID を付与する。`$CLAUDE_SESSION_ID` が設定されている場合はそれを使用し、未設定の場合はセクションを省略する。

```bash
gh issue comment <issue-number> --repo <repo> --body "<整形したコメント>"
```

コメントのフッターに以下を追加（`$CLAUDE_SESSION_ID` が設定されている場合のみ）:

```markdown
---
🤖 Claude Code session: `<CLAUDE_SESSION_ID>`
```

### Step 6: `claude-planned` ラベルの付与

Issue に `claude-planned` ラベルを付与して「設計済み・実装待ち」であることを示す。

ラベルが存在しない場合は先に作成する:

```bash
gh label create claude-planned --description "Plan mode で設計済み・実装待ち" --color "C2E0C6" --repo <repo> 2>/dev/null || true
gh issue edit <issue-number> --add-label "claude-planned" --repo <repo>
```

### Step 7: 完了報告

投稿したコメントの URL を報告する。

## 使用例

```
/post-plan-to-issue 127
/post-plan-to-issue #127 --plan=vivid-stirring-blum.md
/post-plan-to-issue 127 --repo=tsu-nera/xchain-arb
```
