---
model: haiku
---

# Task Complete Command

Automatically commit changes and push to remote repository when a task is completed.

## What this command does:

1. Check git status and show current changes
2. Show diff stats and changed files  
3. Add all changes to staging
4. Create a commit with standardized format
5. Push to remote repository

## Usage:

- Use this command when you have completed a development task
- Provide a descriptive commit message that summarizes the work done
- The command will automatically add Claude Code signature and co-author tags

## Instructions for Claude:

When the user says a task is complete or asks to commit and push changes:

1. Run `git status` and `git diff --stat` to show current changes
2. Run `git log --oneline -3` to see recent commit history for context
3. Add all relevant changed files using `git add [files]`
4. Create a commit with this format:
   ```
   [type]: [description]
   
   - [bullet point of change 1]
   - [bullet point of change 2] 
   - [bullet point of change 3]
   
   🤖 Generated with [Claude Code](https://claude.ai/code)
   
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
5. Push the commit using `git push`
6. Confirm completion with commit hash and branch info

## Example commit types:
- `feat`: New feature implementation
- `fix`: Bug fixes
- `refactor`: Code refactoring without functional changes
- `docs`: Documentation updates
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

## Notes:
- Always check that we're in a git repository first
- Only commit files that are relevant to the completed task
- Provide clear, descriptive commit messages in Japanese when appropriate