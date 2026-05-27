---
skill: direct-commit
description: PRを経由せず main ブランチへ直接 commit + push する。プロジェクト CLAUDE.md で「main 直コミット運用」と定められた変更（キャッシュ/週次ログ/memory/docs typo等、型チェック不要で機械的なもの）専用。src/ や config/ などロジック・型に影響する変更は使わず /pr-merge を使うこと。
user-invocable: true
---

# Direct Commit - mainブランチに直 commit + push

PRを経由せず main へ直接 commit + push する**薄いオーケストレーター**。
プロジェクト CLAUDE.md で「main 直コミット運用」と定められたパス
（キャッシュ/週次ログ/memory/docs等）の機械的な変更専用。

ロジック・型・config に影響する変更は使わず `/pr-merge` を使うこと。

## 使い方
`/direct-commit`

## いつ使うか

**使うべき**:
- プロジェクト CLAUDE.md で「main 直コミット」と明示されたパスの変更
  （例: `resources/`、`logs/weekly/`）
- 型チェック対象外の機械的変更（docs typo、memory、weekly log 等）
- 自信があり、CIゲートを通す価値がない変更

**使うべきでない**:
- `src/` `config/` `package.json` 等、ロジック・型に影響しうる変更 → `/pr-merge`
- 設計判断・複数アプローチの検討が必要 → `/pr` で人間判断を仰ぐ
- プロジェクト CLAUDE.md に直コミット対象として明記が無いパス → `/pr-merge`

## Instructions for Claude:

### Phase 0: 適性判定（ガード）

```bash
git status
git diff --stat
```

- 未コミット変更が無い → 「対象の変更がない」と報告して停止
- 変更ファイルを **プロジェクト CLAUDE.md の「main 直コミット運用」節**
  （無ければ `~/.claude/docs/worktree-tooling.md` §3）と照合
- **判定ロジック**:
  - すべての変更ファイルが「直コミット対象」に収まる → Phase 1 へ
  - `src/` `config/` `package.json` `pnpm-lock.yaml` `tsconfig*` 等が含まれる
    → **停止**し `/pr-merge` の使用を提案
  - 判断に迷う混在ケース → 停止してユーザーに切り分けを依頼
    （直コミット対象だけ stash → `/pr-merge` のような分割提案でもよい）

### Phase 1: ブランチ確認

```bash
git rev-parse --abbrev-ref HEAD
```

- main 以外にいる → 停止してユーザーに確認（直コミットは原則 main 上で行う）
- main 上にいる → Phase 2 へ

### Phase 2: commit + push

- `git add` は対象ファイルを**明示**（`git add -A` 禁止。除外対象の事故混入防止）
- commit メッセージは Conventional Commits 形式（プロジェクト規約に従う）
- `git push origin main` で直接 push

```bash
git add <対象ファイル>
git diff --cached --stat        # 直前確認
git commit -m "<message>"
git push origin main
```

### Phase 3: 完了報告

commit hash と push 先、対象ファイル一覧を簡潔に報告。

## エラー時の対応

- **Phase 0 でロジック変更混入**: 停止して `/pr-merge` を提案
- **Phase 1 で main 以外**: 停止してユーザーに確認
- **Phase 2 で push reject（fast-forward失敗等）**: `git pull --rebase` を提案、
  conflict 発生時は停止してユーザー判断を仰ぐ（強制 push は禁止）

## スコープ外

- 型チェック・テスト実行（直コミット対象は型チェック不要なものに限るため）
- PR 作成・レビュー → `/pr-merge` または `/pr`
- デプロイ → `/ship` または `server-operations` スキル
