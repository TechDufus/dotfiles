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

The command detects if the first argument is a parent issue reference:
- If it's a number → treats it as parent issue in current repo
- If it's `org/repo#123` format → treats it as parent issue in another repo
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
# Parent in same repository
/gh-issue 5 "Implement login form"
/gh-issue 10 "Fix memory leak" high "bug,backend"
/gh-issue 23 "Add unit tests" medium "testing"

# Parent in different repository
/gh-issue TechDufus/dotfiles#42 "Implement related feature"
/gh-issue org/main-repo#100 "Add integration tests" high "testing"
```

## Parameters

- `parent`: Optional - Parent issue reference (formats: `123`, `#123`, or `org/repo#123`)
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
   - If first arg matches `org/repo#123` → Cross-repo parent reference
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
     [--parent "<parent-reference>"] \
     [--labels "<detected-labels>"] \
     [--priority <priority>]
   ```

   **Important:** Always quote parent references containing `#` to prevent shell interpretation as comments:
   - ✅ `--parent "org/repo#123"`
   - ❌ `--parent org/repo#123` (# will be treated as comment)

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