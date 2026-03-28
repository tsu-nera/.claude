# sync-main

Merge latest changes from main branch to current branch

## Usage
Run this command when you want to merge the latest main branch changes into your current feature branch (works in worktrees too).

## Command
```bash
echo "Syncing main branch into current branch..."
git fetch origin
echo "Fetched latest changes from origin"
git merge origin/main
echo "Sync completed successfully"
git status
```

## Description
This command:
1. Fetches the latest changes from the remote repository
2. Merges the origin/main branch into the current branch
3. Shows the final status after merge
