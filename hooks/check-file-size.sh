#!/bin/bash
# ~/.claude/hooks/check-file-size.sh
# PostToolUse hook: Edit/Write後にファイル行数をチェック

MAX_LINES=500

JSON_INPUT=$(cat)
TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // empty')

# Edit/Write以外は無視
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // empty')

# ファイルパスがない or ファイルが存在しない場合はスキップ
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# ソースコードのみ対象
if [[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|py)$ ]]; then
  exit 0
fi

# テストファイルは除外
if [[ "$FILE_PATH" =~ \.(test|spec)\.(ts|tsx|js|jsx)$ || "$FILE_PATH" =~ (test_|_test)\.(py)$ ]]; then
  exit 0
fi

LINE_COUNT=$(wc -l < "$FILE_PATH")

if [[ "$LINE_COUNT" -gt "$MAX_LINES" ]]; then
  echo '{"decision":"block","reason":"'"$FILE_PATH"' is '"$LINE_COUNT"' lines (limit: '"$MAX_LINES"'). Consider splitting this file into smaller modules."}'
else
  exit 0
fi
