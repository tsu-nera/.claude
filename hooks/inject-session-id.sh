#!/bin/bash
# ~/.claude/hooks/inject-session-id.sh
# PreToolUse hook: block gh issue/pr create/comment without session ID footer

JSON_INPUT=$(cat)
TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

COMMAND=$(echo "$JSON_INPUT" | jq -r '.tool_input.command // empty')

# Only check 'gh issue/pr create/comment' and 'edit --body' commands
FIRST_PART=$(echo "$COMMAND" | cut -d' ' -f1-3)
if [[ "$FIRST_PART" =~ ^gh\ (issue|pr)\ edit ]]; then
    # edit commands only need session ID when --body is being changed
    if ! echo "$COMMAND" | grep -q '\-\-body'; then
        exit 0
    fi
elif ! [[ "$FIRST_PART" =~ ^gh\ (issue|pr)\ (create|comment) ]]; then
    exit 0
fi

# Block if actual session ID value is not in the command
# Check for either the literal variable reference OR the resolved UUID value
if [[ -n "$CLAUDE_SESSION_ID" ]]; then
    if ! echo "$COMMAND" | grep -q "$CLAUDE_SESSION_ID"; then
        echo '{"decision":"block","reason":"gh issue/pr create/comment must include the actual session ID value ('"$CLAUDE_SESSION_ID"'), not just the variable name. Use unquoted EOF heredoc or inline the value.\n---\n🤖 Claude Code session: `'"$CLAUDE_SESSION_ID"'`"}'
        exit 0
    fi
else
    # Fallback: at least check variable reference exists
    if ! echo "$COMMAND" | grep -q 'CLAUDE_SESSION_ID'; then
        echo '{"decision":"block","reason":"gh issue/pr create/comment must include session ID footer: \n---\n🤖 Claude Code session: `$CLAUDE_SESSION_ID`"}'
        exit 0
    fi
fi
