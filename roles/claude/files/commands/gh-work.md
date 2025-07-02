---
description: "Fix GitHub issue end-to-end: /gh-work <issue#> [branch-name]"
---

# /gh-work

Complete GitHub issue workflow: view, fix, test, commit, push, and create PR.

## Usage

```
/gh-work <issue-number> [branch-name]
```

## Parameters

- `issue-number`: The GitHub issue number to work on (required)
- `branch-name`: Optional custom branch name (auto-generated if not provided)

## Examples

```
/gh-work 42                        # Creates branch like fix/issue-42-login-bug
/gh-work 15 feature/auth-system    # Uses custom branch name
```

## Workflow

When you run this command, I will:

1. **Fetch and analyze the issue**
   - View issue details, description, and comments
   - Understand the problem/task requirements
   - Check for related issues or context

2. **Create an appropriate branch**
   - Generate branch name from issue title (if not provided)
   - Use prefixes: fix/, feat/, docs/, test/, refactor/
   - Checkout the new branch from main/master

3. **Implement the fix**
   - Update todo list with issue tasks
   - Search for and fix the root cause
   - Make all necessary code changes

4. **Test and validate**
   - Run relevant tests
   - Verify the fix resolves the issue
   - Run linting and type checking

5. **Commit with proper message**
   - Create commit message that follows conventions
   - Reference the issue being fixed
   - Use format: `fix: description (closes #N)`

6. **Push and create PR**
   - Push branch to remote
   - Create PR that closes the issue
   - Include test plan and summary

## Implementation

I'll execute these steps:

```bash
# 1. View the issue
gh issue view <issue-number>

# 2. Create and checkout branch
git checkout -b <branch-name>

# 3. Implement the fix
# (Search, analyze, and fix the issue)

# 4. Test the changes
# (Run tests, linting, type checking)

# 5. Commit with issue reference
git add -A
git commit -m "fix: <description> (closes #<issue-number>)"

# 6. Push and create PR
git push -u origin <branch-name>
gh pr create --title "Fix: <description>" --body "Closes #<issue-number>

## Summary
- <what was fixed>

## Test Plan
- <how it was tested>"
```

## Branch Naming Convention

Auto-generated names follow this pattern:
- Bug fixes: `fix/issue-<num>-<short-description>`
- Features: `feat/issue-<num>-<short-description>`
- Documentation: `docs/issue-<num>-<short-description>`
- Tests: `test/issue-<num>-<short-description>`
- Refactoring: `refactor/issue-<num>-<short-description>`

## Features

- Automatically detects issue type and creates appropriate branch prefix
- Implements complete fix with testing
- Creates properly formatted commits that close the issue
- Pushes branch and creates PR automatically
- Links PR to close the original issue
- Validates code quality before committing

## Environment Variables

- `GITHUB_REPOSITORY`: Override auto-detected repository
- `GH_WORK_BASE_BRANCH`: Base branch to create from (defaults to main/master)