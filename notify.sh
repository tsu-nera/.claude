#!/bin/bash
# ~/.claude/notify.sh

# WSL2でWindows通知を送信するスクリプト

MESSAGE="${1:-Claude Code タスクが完了しました}"
TITLE="${2:-Claude Code}"

# 方法1: PowerShellを使用したポップアップ
powershell.exe -Command "
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show('$MESSAGE', '$TITLE', 'OK', 'Information')
"

# 方法2: トースト通知（Windows 10/11）
powershell.exe -Command "
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText01)
    \$template.GetElementsByTagName('text')[0].AppendChild(\$template.CreateTextNode('$MESSAGE')) | Out-Null
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('$TITLE').Show(\$template)
"