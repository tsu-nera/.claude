#!/bin/bash
# ~/.claude/hooks/capture-session-id.sh
# SessionStart hook: capture session_id and export as CLAUDE_SESSION_ID

JSON_INPUT=$(cat)
SESSION_ID=$(echo "$JSON_INPUT" | jq -r '.session_id // empty')

if [[ -n "$SESSION_ID" && -n "$CLAUDE_ENV_FILE" ]]; then
    echo "CLAUDE_SESSION_ID=$SESSION_ID" >> "$CLAUDE_ENV_FILE"
fi
