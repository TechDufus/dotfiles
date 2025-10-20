---
description: "Fix GitHub issue end-to-end: /gh-work <issue#> [branch-name]"
---

Complete GitHub issue workflow: view issue, create branch, implement fix, test, commit, and create PR.

## Usage

```
/gh-work <issue-number> [branch-name]
```

## Implementation

First, run the workflow script to setup the branch and fetch issue details:

!`~/.config/opencode/scripts/gh-work-issue.sh $ARGUMENTS`

After the script completes, I will:

1. **Analyze the issue**
   - Review requirements and acceptance criteria
   - Understand the problem/feature request
   - Check for related context

2. **Implement the solution**
   - Search codebase for relevant files
   - Make necessary code changes
   - Follow existing patterns and conventions

3. **Test and validate**
   - Run relevant tests
   - Verify the fix resolves the issue
   - Run linting and type checking

4. **Commit with proper message**
   - Use conventional commit format
   - Reference the issue: `fix: description (closes #N)`

5. **Create PR**
   - Push branch to remote
   - Create PR that closes the issue
   - Include summary and test plan

## Branch Naming

Auto-generated branch names follow:
- Bug fixes: `fix/issue-<num>-<description>`
- Features: `feat/issue-<num>-<description>`
- Docs: `docs/issue-<num>-<description>`
- Tests: `test/issue-<num>-<description>`
