---
skill: issue-to-pr
description: GitHub Issueを読み、設計→実装→PR作成まで一気通貫で実行する
user-invocable: true
---

# Issue to PR - 自動実装ワークフロー

GitHub Issueを入力に、調査→設計→実装→品質チェック→PR作成まで自動実行する。
**単一Issue専用。** 複数Issueを並列処理したい場合は複数セッションを開く。

## 使い方
`/issue-to-pr <issue番号>`

複数セッションで同時実行しても安全（デフォルトでworktreeを使用するため）。

## Instructions for Claude:

**重要: EnterPlanMode / ExitPlanMode は使用禁止。** 人間への確認はPR作成時のみ。

**モデル割り当て:**
- Phase 1-3（探索・設計）: 親エージェント（起動モデル）が実行
- Phase 4-6（実装・PR）: `model: "sonnet"`, `isolation: "worktree"` のエージェントにハンドオフ

`/model opus` で起動すればopusで設計 → sonnetで実装、となる。

---

### Phase 1: Issue読み込みと品質判定

```bash
gh issue view <番号>
gh issue view <番号> --comments
```

Issueの品質を判定する:

**高品質（一気通貫で進む）**:
- 修正箇所・変更ファイルが具体的に列挙されている
- Acceptance Criteria / やるべきことが明確
- 設計方針が記述されている

**低品質（人間に確認を求める）**:
- 「パフォーマンス改善」のような曖昧な記述
- 複数のアプローチがあり、Issueで方針が決まっていない
- 影響範囲が不明確

→ 低品質の場合: AskUserQuestion で方針を確認してから続行。
→ 高品質の場合: そのまま Phase 2 へ。

---

### Phase 2: コード調査

`subagent_type: "Explore"`, `model: "sonnet"` でエージェントを起動してコードベースを調査する。

- 変更対象ファイルの現在の実装を把握
- 既存パターン・ユーティリティの確認
- 依存関係・影響範囲の特定

```
Agent(
  subagent_type: "Explore",
  model: "sonnet",
  prompt: "..."
)
```

**並列Exploreの目安**:
- 変更箇所が1モジュール内 → 1エージェント
- 複数モジュールにまたがる → 2-3エージェント（最大3）
- 小規模な変更（1-2ファイル） → Explore不要、直接Readで確認

---

### Phase 3: 設計

調査結果に基づき、実装方針を決める。（**親エージェント＝起動モデル**が担当）

**小規模（1-2ファイル）**: 設計をスキップし、Phase 4へ直行。

**中規模以上（3ファイル超）**:
1. 変更対象ファイルと修正内容を整理
2. タスク分割が必要な場合、ファイル境界で分割
3. 依存順序の確認

**Test planの設計**（小規模含む全ケース）:
IssueのACと変更内容から、PRのTest planに含めるテスト項目を設計する。
`/test-pr` で機械的に実行されるため、以下を守ること:
- 実行可能な具体的コマンドを記載（`npm run transfers -- --source api` 等）
- 期待結果を明記（「一覧が表示される」「エラーなく完了する」等）
- 回帰確認（変更の影響を受けうる既存機能の確認コマンド）を含める
- 曖昧な項目（「正しく動作する」）は禁止

---

### Phase 4: 実装

実装は **`model: "sonnet"`, `isolation: "worktree"` のエージェントにハンドオフ**する。
worktreeにより、複数セッションが同時実行されても競合しない。

```
Agent(
  model: "sonnet",
  isolation: "worktree",
  mode: "auto",
  prompt: "..."
)
```

**Agentへのpromptに含めるべき情報**:
- Issue番号と実装すべき内容（Issueのテキストそのまま）
- Phase 3で決定した設計方針の全文
- 変更対象ファイルのパスと現在の実装の要点
- 具体的な修正内容（コード例があれば含める）
- 型定義の変更がある場合、その詳細
- ブランチ命名規則（ラベルから: feature→feat/, fix→fix/, improve→refactor/）
- 「完了後に `pnpm run check` を実行し型チェックを通すこと」
- 「`resources/` はコミットに含めないこと」
- 「Phase 5-6の手順に従ってコミット・PRを作成すること」

**Agentへのpromptに含めてはいけない情報**:
- 曖昧な指示（「適切に修正して」）

**worktree内で複数ファイルを並列実装する場合（3ファイル超かつ独立分割可能）**:
worktreeエージェント内でさらに複数のsonnet worktreeサブエージェントを起動してよい。

---

### Phase 5: 品質チェック（worktree内で実行）

1. **品質チェック実行**: `pnpm run check`
2. **失敗時**: 直接修正。3回失敗したら人間に報告。
3. **差分確認**: `git diff main` で全変更を確認。`resources/` が混入していないか確認。

---

### Phase 6: コミット・PR作成（worktree内で実行）

**ここで初めて人間に報告する。**

変更内容のサマリを表示し、PR作成の承認を求める。

#### コミット
```bash
git add <変更ファイル>  # resources/ を含めない
git commit -m "$(cat <<'EOF'
<type>: <概要>

Closes #<issue番号>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

#### PR作成
```bash
gh pr create --title "<タイトル>" --body "$(cat <<'EOF'
## Summary
<変更内容の箇条書き>

Closes #<issue番号>

## Test plan
- [ ] `pnpm run check` パス
- [ ] <具体的な実行コマンドと期待結果>
- [ ] <回帰確認: 既存機能への影響がないこと>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

PR作成後:
```bash
gh pr checks <PR番号> --watch
```

---

## エラー時の対応

- **品質チェック失敗**: worktreeエージェントが直接修正。3回失敗したら人間に報告。
- **マージコンフリクト**: 人間に報告し、方針を確認。
