#!/bin/bash
# ~/.claude/hooks/notify.sh

# WSL2 Windows toast notification script for Claude Code

MESSAGE="${1:-Task completed}"
TITLE="${2:-Claude Code}"

# BurntToast toast notification
powershell.exe -Command "Import-Module BurntToast; New-BurntToastNotification -Text '$TITLE', '$MESSAGE'"