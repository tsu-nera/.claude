---
name: research
description: 指定トピックをWebSearchで調査し、要点を日本語でまとめる。「調査して」「調べて」で起動。--google で gemini-cli 使用。
user-invocable: true
allowed-tools: Agent, WebSearch, Bash(gemini*), WebFetch
---

# リサーチスキル

指定トピックについて調査し、要点を日本語でまとめる。

## 引数パース

`$ARGUMENTS` から以下を抽出:
- `--google`: gemini-cli（Google Search）を使用する。省略時は WebSearch を使用。
- それ以外のテキスト: トピック（調査対象）

## 実行手順

### Step 1: 調査観点の整理

トピックに応じて調査観点を2-3個に分割する。例:
- 概要・基本情報
- メリット・デメリット / 賛否
- 実践例・ベストプラクティス

### Step 2: 並列調査

Agentを使い、各観点ごとに並列で検索を実行する。

**モデル指定: `model: "haiku"`** — 検索+抜粋は軽量タスクのためHaikuで十分。

#### デフォルト（WebSearch）

各Agentへの指示:
- WebSearchで複数ソースを確認する
- 200語以内で要点を報告する
- 情報源のURLを含める

#### `--google` 指定時（gemini-cli）

各Agentへの指示:
- 以下のコマンドで検索する（キーワードは2-3個に絞る）:
  ```bash
  gemini --yolo -p 'google_web_search:キーワード'
  ```
- 検索結果から200語以内で要点を報告する
- 情報源のURLを含める

### Step 3: 結果の統合・報告（メインモデルが担当）

複数Agentの調査結果を統合・分析し、以下の形式で日本語で報告する:

```markdown
## 調査結果: {トピック}

### 要点
- ポイント1
- ポイント2
- ポイント3

### 詳細
（各観点ごとの調査結果）

### 情報源
- [タイトル](URL)
```

### Step 4: 検討への橋渡し

調査結果を踏まえ、ユーザーに次のアクション（検討・適用・深掘り）を提案する。
