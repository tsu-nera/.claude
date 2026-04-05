---
skill: adr
description: Architecture Decision Record (ADR) を docs/adr/ に作成する
user-invocable: true
---

# ADR 作成スキル

設計判断を ADR として記録する。フォーマットは Michael Nygard 形式（Title / Status / Context / Decision / Consequences）に準拠。

## 使い方
`/adr <判断の概要>`

例: `/adr Redisをキャッシュに採用する`

## 手順

1. `docs/adr/` 内の既存ファイルを確認し、次の連番を決定する
   - ファイル名: `NNN-<slug>.md`（例: `003-use-redis-for-cache.md`）
   - slug は英語のケバブケース、簡潔に
2. ユーザーの入力と現在のコードベースから Context を理解する
3. 以下のテンプレートで ADR を作成する

## テンプレート

```markdown
# ADR-NNN: <タイトル（日本語）>

## Status

Accepted (YYYY-MM-DD)

## Context

<なぜこの判断が必要になったのか。背景・課題・制約を記述>

## Decision

**<判断内容を1行で太字>**

<理由を箇条書きまたは段落で補足>

## Consequences

<この判断による影響。良い点・注意点を分けて記述>
```

## ルール

- 本文は日本語で書く
- 日付は今日の日付を使う
- `docs/adr/` ディレクトリが存在しない場合は作成する
- 作成後、ファイルパスと概要をユーザーに報告する
