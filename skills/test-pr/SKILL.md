---
skill: test-pr
description: PRの動作確認を実行する。PRのTest planに沿ってスクリプト実行やdry-runで検証し、結果をPRコメントに投稿する。
user-invocable: true
---

# Test PR - PR動作確認ワークフロー

PRのTest planに沿って動作確認を実行し、結果をPRコメントに投稿する。
Test planは `/issue-to-pr` のopusが設計済み。このスキルは**実行と記録に専念**する。

## 使い方
`/test-pr <PR番号>`

## Instructions for Claude:

**重要: このスキルは「テストエンジニア」の役割。コード修正はしない。Test planの実行と結果記録のみ。**

---

### Phase 1: PR情報の収集とブランチ切り替え

```bash
gh pr view <PR番号> --json title,body,files,headRefName
```

**ブランチ切り替え**:
1. PRのブランチ名を取得（headRefName）
2. 既存worktreeがそのブランチを使用しているか確認: `git worktree list`
3. 既存worktreeがあれば → そのworktreeディレクトリで実行
4. なければ → `gh pr checkout <PR番号>` で切り替え

**worktreeで実行する場合の準備**:
```bash
cd <worktreeパス>
pnpm install
```
worktreeは `node_modules` を共有しないため、テスト実行前に必ず `pnpm install` する。

PRのbodyから以下を抽出:
- **Test plan**: チェックリスト項目を実行対象として取得
- **Closes #xx**: 関連Issue番号（結果記録用）

Test planが空または曖昧な場合はユーザーに報告して中断する。

---

### Phase 2: テスト実行

PRのTest plan項目を**上から順に逐次実行**する。

**CI検証**（ローカルで実行）:
```bash
pnpm run check
pnpm run build
```

**スクリプト実行**:
- ローカルで実行可能なもの → そのまま実行
- サーバ接続が必要なもの → ユーザーに実行環境を確認してから実行
- 破壊的操作（データ変更、送金等）→ **絶対に実行しない。** dry-runオプションがあれば使う

**実行ルール**:
- スクリプトは**逐次実行**（並列実行禁止、API rate limit回避）
- タイムアウトは適切に設定（デフォルト120秒、長いものは明示的に延長）
- エラーが出た場合、原因を分析してテスト結果に含める
- 各項目の実行コマンドと出力を記録する

---

### Phase 3: 結果の記録

テスト結果をPRコメントとして投稿する。

```bash
gh pr comment <PR番号> --body "$(cat <<'EOF'
## 🧪 動作確認結果

### テスト環境
- 実行日時: YYYY-MM-DD HH:MM
- 実行環境: local / conoha1 / conoha2
- ブランチ: <headRefName>

### テスト項目と結果

| # | テスト項目 | 結果 | 備考 |
|---|----------|------|------|
| 1 | ... | ✅ PASS | |
| 2 | ... | ⚠️ 要確認 | 人間の判断が必要 |
| 3 | ... | ❌ FAIL | エラー内容 |

### 実行ログ
<details>
<summary>テスト1: ...</summary>

```
$ コマンド
出力
```
</details>

### 総合判定
✅ 全テストパス / ⚠️ 要確認あり / ❌ 失敗あり

🤖 Tested with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

### Phase 4: 報告

テスト結果のサマリをユーザーに報告する。

- **全パス**: 「全テストパス。PRコメントに結果を投稿しました。」
- **要確認**: 具体的に何を人間が確認すべきか明示
- **失敗**: 失敗内容と推定原因を報告

---

## スコープ外

- **コード修正**: 失敗を報告するだけ。修正はしない
- **テスト項目の設計**: `/issue-to-pr` が担当済み
- **マージ判断**: 人間が行う
- **破壊的操作**: 送金、データ削除等は絶対に実行しない
