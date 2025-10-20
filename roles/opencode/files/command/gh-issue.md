---
description: "Create GitHub issue: /gh-issue [parent] <description>"
---

Create a GitHub issue based on the current conversation context, optionally linked to a parent issue.

## Usage

```
/gh-issue <description>              # Standalone issue
/gh-issue <parent> <description>     # Child issue linked to parent
```

## Implementation

I will analyze the current conversation and generate:

1. **Concise title** (50 characters or less)
2. **Detailed body** including:
   - Summary of the problem/task
   - Context from conversation
   - Acceptance criteria as checkboxes
   - Technical details
   - Relevant code snippets or errors

Then execute:

!`~/.config/opencode/scripts/gh-create-issue.sh "<generated-title>" --body "<generated-body>" $ARGUMENTS`

## Parent Detection

The command intelligently detects parent references:
- If first argument is a number → parent issue in current repo
- If first argument is `org/repo#123` → parent in different repo
- Otherwise → entire input is the description

## Examples

```
/gh-issue Implement user authentication system
/gh-issue 5 Add login form component
/gh-issue org/repo#42 Add related integration tests
```
