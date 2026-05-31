## General Tips
- システムコンテキストの日付から曜日を判断しない。`date +%A` で確認すること
- SSH接続が失敗した場合は、数秒待ってからリトライすること（一時的なネットワーク障害の可能性がある）

## Development Tips
- `gh issue create` / `gh issue comment` / `gh pr create` の本文末尾には必ずセッションIDフッターを付与すること:
  ```
  ---
  🤖 Claude Code session: `$CLAUDE_SESSION_ID`
  ```

## Communication Strategy
- 英語で思考、日本語で応答
- 表はmarkdownテーブル形式（`| col | col |`）で出力する。罫線文字（┌─┬─┐等）は使わない
- memory の保守作業（関連Issue/PRのクロスリンク追記、既存memoryの更新、新規ケースの記録先判断など）はユーザーに聞かず自律的に判断・実行する。「~に追記しますか?」は禁止。実行後に簡潔に報告

## Memory管理
- memory（永続メモリ）の保守は**自律実行・ユーザー確認不要**。「メモに残しますか?」「memory更新しますか?」と聞かない
- 記録先判断（新規ファイル or 既存追記）・クロスリンク・事実誤認の修正・MEMORY.md index 同期は自分で判断して実行し、事後に1-2文で報告
- 何を残すかの取捨選択も自分で行う（定着した運用知見・判断の前提を残し、一過性の状態は残さない）

- リファクタリングで不要なコードはコメントアウトやdeprecatedではなく完全に削除
- コーディング規約: `~/.claude/docs/coding-guidelines.md`