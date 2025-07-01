---
description: "Create GitHub issue: /gh-issue <title> | /gh-issue <parent> <title>"
---

# /gh-issue

Create a GitHub issue, optionally linked to a parent.

## Usage

```
/gh-issue <title>                                    # Create standalone issue
/gh-issue <parent> <title> [priority] [labels]      # Create child issue
```

## Intelligent Parsing

The command detects if the first argument is a parent issue number:
- If it's a number → treats it as parent issue
- If it's not a number → treats entire input as the title

## Examples

### Standalone Issues
```
/gh-issue Implement user authentication
/gh-issue "Fix memory leak in API handler"
/gh-issue Add comprehensive test coverage
```

### Child Issues (with parent)
```
/gh-issue 5 "Implement login form"
/gh-issue 10 "Fix memory leak" high "bug,backend"
/gh-issue 23 "Add unit tests" medium "testing"
```

## Parameters

- `parent`: Optional - Parent issue number (if provided, creates child task)
- `title`: The issue title
- `priority`: Optional - critical|high|medium|low (defaults to medium)
- `labels`: Optional - comma-separated labels

## Features

- Smart detection of parent vs title
- Automatically detects current repository
- Creates parent/child relationship when parent provided
- Sets appropriate labels
- Assigns to current user by default

## Environment Variables

- `GITHUB_REPOSITORY`: Override auto-detected repository
- `GITHUB_ASSIGNEE`: Set custom assignee (defaults to @me)

## Implementation

The command intelligently routes to the appropriate action:

1. **Parse the input to determine intent**
   - If first arg is a number → Parent issue number
   - Otherwise → Description of what needs to be done

2. **Generate title and body based on context**
   - Analyze the current conversation/code context
   - Generate a concise, descriptive title (50 chars or less)
   - Create a detailed issue body with:
     - Summary of the problem/task
     - Context from the conversation
     - Acceptance criteria
     - Technical details
     - Any relevant code snippets or errors

3. **Execute with generated content:**
   ```bash
   ~/.claude/scripts/gh-create-issue.sh "<generated-title>" \
     --body "<generated-body>" \
     [--parent <parent-number>] \
     [--labels "<detected-labels>"] \
     [--priority <priority>]
   ```

### Body Generation Template

When generating the issue body, I'll include:

```markdown
## Summary
[Brief description based on context]

## Context
[Reference to conversation/code that prompted this issue]

## Problem/Objective
[What needs to be solved or implemented]

## Acceptance Criteria
- [ ] [Specific measurable outcomes]
- [ ] [Based on discussed requirements]

## Technical Details
[Any implementation notes, error messages, or code snippets]

## Related
[Links to related issues, PRs, or discussions]
```

## Claude's Context Analysis

When generating issues, I will:
- Review the current conversation for context
- Identify the problem being solved
- Extract relevant error messages or code
- Determine appropriate labels based on the work type
- Create clear acceptance criteria
- Include implementation hints if discussed