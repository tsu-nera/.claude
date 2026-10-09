現在の作業をPRとして提出してください。以下の手順で進めてください。

## 手順

1. **現在の状態を確認**
   - `git status` で変更ファイルを確認
   - `git branch` で現在のブランチを確認
   - mainブランチにいる場合は、作業内容に応じたブランチ名を決めてから `git checkout -b feat/xxx` でブランチを切る

2. **型チェック**
   - プロジェクトに応じた型チェックを実行（例: `npm run check`, `mypy`, `cargo check` 等）
   - CLAUDE.mdやREADMEを参照してプロジェクトの型チェックコマンドを確認する
   - エラーがあれば修正してから次へ進む

3. **コミット**
   - 関連ファイルをステージング
   - Conventional Commits形式でコミット（`feat:`, `fix:`, `refactor:` 等）
   - 関連IssueがあればCommitメッセージに `Closes #xx` を含める

4. **Push & PR作成**
   - `git push -u origin <ブランチ名>`
   - `gh pr create` でPRを作成
   - PRの本文には以下を含める：
     - 変更内容（箇条書き）
     - 関連Issue（`Closes #xx`）

## 注意事項
- マージは人間が判断するため、PR作成までを行う
