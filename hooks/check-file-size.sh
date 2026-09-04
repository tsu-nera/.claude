#!/bin/bash
# ~/.claude/hooks/check-file-size.sh
# PostToolUse hook: Edit/Write後にファイル行数をチェック
#
# 行数ルールの本体は、対象 repo に scripts/ops/check-file-size.sh があれば
# それに委譲する（repo 側を single source of truth にし、Codex CLI の
# pre-commit hook と定義を共有するため）。無ければ従来の組み込み既定を使う。

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

# MEMORY.md（auto-load index）は行数でなくバイト数で見る。
# 24.4KB を超えると auto-load が途中で切られ、index の後半が読まれなくなる。
# 定期的に肥大化するので、20KB を超えた時点で圧縮を促す（block はしない＝書き込みは通す）。
if [[ "$FILE_PATH" =~ /memory/MEMORY\.md$ ]]; then
  BYTES=$(wc -c < "$FILE_PATH")
  if [[ "$BYTES" -gt 20480 ]]; then
    KB=$(( BYTES / 1024 ))
    jq -n --arg msg "MEMORY.md is ${KB}KB (auto-load limit 24.4KB). 圧縮すること: 話題単位の塊は memory/index-*.md のクラスタ索引へ、決着済み・単発は ARCHIVE.md へ退避する（topic ファイル本体は消さない）。" \
      '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$msg}}'
  fi
  exit 0
fi

# repo 側の共有スクリプトがあれば委譲（single source of truth）
REPO_ROOT=$(git -C "$(dirname "$FILE_PATH")" rev-parse --show-toplevel 2>/dev/null)
REPO_CHECK="${REPO_ROOT}/scripts/ops/check-file-size.sh"
if [[ -n "$REPO_ROOT" && -x "$REPO_CHECK" ]]; then
  REASON=$("$REPO_CHECK" "$FILE_PATH")
  if [[ $? -ne 0 && -n "$REASON" ]]; then
    jq -n --arg reason "$REASON" '{decision:"block", reason:$reason}'
  fi
  exit 0
fi

# --- 以下、repo 側スクリプトが無い場合の組み込み既定 ---

# src/ 配下のみ対象
if [[ ! "$FILE_PATH" =~ /src/ ]]; then
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
