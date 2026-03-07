#!/bin/bash
# ~/.claude/hooks/capture-message.sh

# Capture the user's message for keyword checking
# This script receives JSON input via stdin

# Read JSON from stdin
JSON_INPUT=$(cat)

# Extract the prompt from JSON using simple parsing
# The JSON format is: {"prompt": "user message here"}
MESSAGE=$(echo "$JSON_INPUT" | grep -o '"prompt":"[^"]*"' | sed 's/"prompt":"\([^"]*\)"/\1/')

if [[ -n "$MESSAGE" ]]; then
    echo "$MESSAGE" > /tmp/claude-last-message.txt
fi

# Pass through the input unchanged
echo "$JSON_INPUT"