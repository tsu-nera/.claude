#!/bin/bash
# ~/.claude/hooks/inject-session-id.sh
# PreToolUse hook: block gh issue/pr create/comment without session ID footer

JSON_INPUT=$(cat)
TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

COMMAND=$(echo "$JSON_INPUT" | jq -r '.tool_input.command // empty')

# Only check 'gh issue create', 'gh issue comment', 'gh pr create' commands
FIRST_PART=$(echo "$COMMAND" | cut -d' ' -f1-3)
if ! [[ "$FIRST_PART" =~ ^gh\ (issue|pr)\ (create|comment) ]]; then
    exit 0
fi

# Block if CLAUDE_SESSION_ID is not referenced in the command
if ! echo "$COMMAND" | grep -q 'CLAUDE_SESSION_ID'; then
    echo '{"decision":"block","reason":"gh issue/pr create/comment must include session ID footer: \n---\n🤖 Claude Code session: `$CLAUDE_SESSION_ID`"}'
    exit 0
fi
