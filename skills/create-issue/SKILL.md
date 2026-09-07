---
name: create-issue
description: 会話の内容から GitHub Issue を作成する。「issue立てて」「issueにして」「とりあえずissue立てておいて」で起動。ready（実装者に渡す粒度）と draft（あとで詰める）の2モード。
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Issue作成スキル

**Issue 作成の唯一の入口。** 生 `gh issue create` は hook で deny される。

## Step 0: モード判定（最初にこれだけ決める）

ユーザーの語で決め打ちする。意味を推測しない。

- 「issue立てて」「issueにして」「起票して」 → **ready**
- 「とりあえず」「あとで」「忘れないうちに」「メモ」を含む → **draft**
- **迷ったら draft**（draft を後で ready に昇格させるのは安い。逆は無人実行で壊れる）

`--mode` が明示指定されていればそれに従う。

---

## draft モード

目的は「**後で自分が再現できること**」だけ。実装者に渡す前提が無いので、Acceptance Criteria も実装方針も書かない。
探索（Grep/Read）もしない。会話に出ていない情報を調べに行かない。

body:

```markdown
## 現象 / 気になったこと

（1-3行）

## 出典

- `src/xxx/foo.ts:123`（会話で見た具体的な箇所。無ければ issue 番号 / ログ / コマンド）

## なぜ気になったか

（1-2行。後で読む自分が「で、何が問題なんだっけ」にならないように）
```

作成:

```bash
~/.claude/bin/create-issue.sh --mode draft --repo <REPO> --title "<タイトル>" --body-file <path> --label inbox
```

`inbox`（未トリアージ・週次棚卸し）が必ず付く。type ラベルは付けない（まだ分類しない）。

---

## ready モード

**`references/ready.md` を読んでから書く。** ここで初めて doctrine（下流の `issue-to-pr` / codex が自走できる
粒度・format・stop condition 回避）と `autopilot` 判定が必要になる。

---

## 引数

`$ARGUMENTS` から抽出:
- `--repo=owner/repo`（省略時は `gh repo view --json nameWithOwner -q .nameWithOwner`）
- `--mode=ready|draft`（省略時は Step 0 で判定）
- `--label=<label>`（複数可）
- それ以外のテキスト: Issue 内容の補足
