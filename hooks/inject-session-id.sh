#!/bin/bash
# ~/.claude/hooks/inject-session-id.sh
# PreToolUse hook: block gh issue create/comment without session ID footer

JSON_INPUT=$(cat)
TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

COMMAND=$(echo "$JSON_INPUT" | jq -r '.tool_input.command // empty')

# Only check 'gh issue create' or 'gh issue comment' commands (exact start match)
# Split on first space to get the actual command
FIRST_PART=$(echo "$COMMAND" | cut -d' ' -f1-3)
if ! [[ "$FIRST_PART" =~ ^gh\ issue\ (create|comment) ]]; then
    exit 0
fi

# Block if CLAUDE_SESSION_ID is not referenced in the command
if ! echo "$COMMAND" | grep -q 'CLAUDE_SESSION_ID'; then
    echo '{"decision":"block","reason":"gh issue create/comment must include session ID footer: \n---\n🤖 Claude Code session: `$CLAUDE_SESSION_ID`"}'
    exit 0
fi
