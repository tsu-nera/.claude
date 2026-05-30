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

- リファクタリングで不要なコードはコメントアウトやdeprecatedではなく完全に削除
- コーディング規約: `~/.claude/docs/coding-guidelines.md`