#!/bin/bash
# ~/.claude/hooks/keyword-notify.sh

# Check if the user's last message contained notification keywords
LAST_MESSAGE_FILE="/tmp/claude-last-message.txt"

# Keywords that trigger notification (case insensitive)
KEYWORDS=("notify me" "通知して" "notification" "alert me")

# Check if last message file exists and contains keywords
if [[ -f "$LAST_MESSAGE_FILE" ]]; then
    LAST_MESSAGE=$(cat "$LAST_MESSAGE_FILE" | tr '[:upper:]' '[:lower:]')
    
    for keyword in "${KEYWORDS[@]}"; do
        if [[ "$LAST_MESSAGE" == *"$keyword"* ]]; then
            MESSAGE="${1:-Task completed}"
            TITLE="${2:-Claude Code}"
            
            # Send toast notification
            powershell.exe -Command "Import-Module BurntToast; New-BurntToastNotification -Text '$TITLE', '$MESSAGE'"
            
            # Clean up the message file
            rm -f "$LAST_MESSAGE_FILE"
            exit 0
        fi
    done
    
    # Clean up if no keywords found
    rm -f "$LAST_MESSAGE_FILE"
fi