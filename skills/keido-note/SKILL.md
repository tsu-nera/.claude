---
skill: keido-note
description: keido org-roamノートの検索・読み取り・作成・編集。別リポジトリからでも利用可能。
user-invocable: true
---

# keido-note - ナレッジベース操作

keido (~/repo/keido/notes/zk/) のorg-roamノートを任意のリポジトリから操作する。
コンテキスト保護のため、必ずAgent経由で実行する。

## 使い方

```
/keido-note <操作の説明>
```

例:
- `/keido-note DEXのAMM理論について調べて`
- `/keido-note Uniswap v3の集中流動性についてノートを作成`
- `/keido-note MEVに関するノートを更新して、Flashbots Protectの情報を追記`
- `/keido-note org-roamのリンク構造でDeFi関連ノートを一覧`

## Instructions for Claude:

### 実行方法

**必ずAgent toolで実行すること。** メインコンテキストでkeido配下のファイルを直接Grep/Readしてはならない。

Agent toolに以下のプロンプトテンプレートを使ってタスクを委譲する:

```
subagent_type: "general-purpose"
```

プロンプトには以下を含める:

1. ユーザーのリクエスト内容
2. 下記「ノート形式」セクションの全内容
3. 操作種別に応じた指示

### ノート形式

keido org-roamノートの仕様:

- **パス**: ~/repo/keido/notes/zk/
- **ファイル名**: タイムスタンプ形式 `YYYYMMDDHHmmss.org`（例: `20211111225741.org`）
- **構造**:
```org
:PROPERTIES:
:ID:       <uuidv4>
:END:
#+title: タイトル
#+filetags: :Tag1:Tag2:

本文（org-mode記法）
```
- **リンク**: `[[id:<uuid>][表示名]]` 形式でノート間を接続
- **タグ**: `#+filetags:` にコロン区切りで指定（例: `:DeFi:AMM:Crypto:`）
- **言語**: ノートは基本的に日本語。技術用語は英語のまま使用可

### 操作種別

#### search（検索）
- Grep/Globで ~/repo/keido/notes/zk/ 内を検索
- `#+title:` 行、`#+filetags:` 行、本文を横断的に検索
- 結果は「ファイル名、タイトル、関連部分の要約」を返す
- 大量ヒット時は最も関連性の高い5-10件に絞る

#### read（読み取り）
- 指定ノートの内容を読んで要約または全文を返す
- リンク先のノートも必要に応じて辿る

#### write（新規作成）
- `uuidgen` でUUIDを生成
- `date +%Y%m%d%H%M%S` でファイル名を決定
- 上記フォーマットに従ってノートを作成
- 関連する既存ノートがあればリンクを追加

#### update（既存ノート更新）
- 既存ノートを読み取り、指定された情報を追記・修正
- `:PROPERTIES:` ブロックと `#+title:` は変更しない（タグ追加は可）

#### link（リンク追加）
- 関連ノート間に双方向リンクを追加
- リンク元・リンク先の両方にリンクを挿入

### Agentへのプロンプト例

```
~/repo/keido/notes/zk/ 内のorg-roamノートを操作してください。

【リクエスト】
{ユーザーの指示内容}

【ノート仕様】
- ファイル名: YYYYMMDDHHmmss.org
- 構造: :PROPERTIES: + #+title: + #+filetags: + 本文
- リンク形式: [[id:uuid][表示名]]
- パス: ~/repo/keido/notes/zk/

【注意事項】
- 検索結果は要約して返すこと（全文を返さない）
- 新規作成時はuuidgenでID生成、date +%Y%m%d%H%M%Sでファイル名決定
- 既存ノートの:PROPERTIES:と#+title:は変更しない
```
