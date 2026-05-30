---
skill: direct-commit
description: PRを経由せず main ブランチへ直接 commit + push する。キャッシュ/週次ログ/memory/docs等の機械的変更に加え、src/・config/ の「簡単な修正」（typo/ログ文言/軽微な定数・バグfix等、型チェックが通りテスト/レビュー不要なもの）も対象。設計判断・依存変更・広範なロジック変更は使わず /pr-merge または /pr を使うこと。
user-invocable: true
---

# Direct Commit - mainブランチに直 commit + push

PRを経由せず main へ直接 commit + push する**薄いオーケストレーター**。
プロジェクト CLAUDE.md「main 直コミット運用」節で定められた変更が対象。

`src/` `config/` を含む場合は **`pnpm run check`（型チェック）必須**。
設計判断・依存変更・広範なロジック変更は使わず `/pr-merge` / `/pr` を使うこと。

## 使い方
`/direct-commit`

## いつ使うか

**使うべき**:
- `resources/`、`logs/weekly/`、`docs/`、`memory` 等の機械的・型無関係な変更
- `src/` `config/` の**簡単な修正**: typo、ログ文言、軽微な定数調整、
  型チェックが通りテスト/レビュー無しで自信を持てる小規模なバグ fix
- CIゲート（PR）を通す価値がないと自信を持てる変更

**使うべきでない**:
- 設計判断・複数アプローチの検討が必要 → `/pr` で人間判断を仰ぐ
- `package.json` `pnpm-lock.yaml` `tsconfig*` 等の依存・ビルド構成変更 → `/pr-merge`
- ロジックが広範囲に及ぶ／テストを伴うべき変更 → `/pr-merge`

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
  - 機械的・型無関係な変更のみ（`resources/` `logs/weekly/` `docs/` `memory` 等）
    → 型チェック不要、Phase 1 へ
  - `src/` `config/` を含むが**「簡単な修正」**（typo/ログ文言/軽微な定数・bug fix、
    テスト/レビュー無しで自信を持てる小規模変更）→ Phase 0.5（型チェック）必須
  - `package.json` `pnpm-lock.yaml` `tsconfig*` 等の依存・ビルド構成変更が含まれる
    → **停止**し `/pr-merge` の使用を提案
  - 設計判断・複数アプローチ検討・広範なロジック変更 → **停止**し `/pr-merge` / `/pr`
  - 「簡単な修正」か迷う → 停止してユーザーに確認

### Phase 0.5: 型チェック（`src/` `config/` を含む場合のみ）

```bash
pnpm run check
```

- 失敗 → 停止してユーザーに報告（直コミットは中止）
- 成功 → Phase 1 へ

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

- **Phase 0 で依存変更・広範なロジック変更混入**: 停止して `/pr-merge` を提案
- **Phase 0.5 で型チェック失敗**: 停止してユーザーに報告（直コミット中止）
- **Phase 1 で main 以外**: 停止してユーザーに確認
- **Phase 2 で push reject（fast-forward失敗等）**: `git pull --rebase` を提案、
  conflict 発生時は停止してユーザー判断を仰ぐ（強制 push は禁止）

## スコープ外

- テスト実行（直コミット対象はテスト不要と自信を持てるものに限るため。
  テストを伴うべき変更は `/pr-merge`）
- 型チェック以外の品質ゲート・PR レビュー → `/pr-merge` または `/pr`
- デプロイ → `/ship` または `server-operations` スキル
