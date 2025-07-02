---
description: "Review GitHub PRs: /gh-review <pr-reference> [options]"
---

# /gh-review

Review GitHub pull requests with detailed diff viewing and interactive review actions.

## Usage

```
/gh-review <pr-reference> [options]
```

## PR Reference Formats

- `123` - PR in current repository
- `#123` - PR in current repository  
- `org/repo#123` - PR in specific repository
- `https://github.com/org/repo/pull/123` - Full PR URL

## Options

- `--diff-only` - Show diff only, skip review prompt
- `--approve` - Auto-approve without prompting
- `--comment <text>` - Add comment without prompting

## Examples

### Interactive Review
```
/gh-review 42
/gh-review TechDufus/dotfiles#100
/gh-review https://github.com/org/repo/pull/123
```

### Quick Actions
```
/gh-review 42 --approve
/gh-review 42 --comment "Nice work on the refactoring!"
/gh-review 42 --diff-only
```

## Features

- **Smart PR detection**: Supports multiple reference formats
- **Comprehensive PR info**: Shows title, author, files changed, merge status
- **Syntax-highlighted diff**: Full PR diff with color highlighting
- **Interactive review flow**: Choose to approve, comment, request changes, or skip
- **Cross-repository support**: Review PRs in any accessible repository
- **Quick actions**: Approve or comment without interactive prompts

## Interactive Review Actions

When reviewing interactively, you'll be prompted to:
- **[a] Approve**: Approve the PR with optional comment
- **[c] Comment**: Add a review comment
- **[r] Request changes**: Request changes with explanation
- **[s] Skip**: View without taking action

## Environment Variables

- `GITHUB_REPOSITORY`: Override auto-detected repository (format: owner/repo)

## Implementation

Execute the following command with the provided arguments:

```bash
~/.claude/scripts/gh-review-pr.sh "<pr-reference>" [options]
```

**Important:** Always quote PR references containing `#` to prevent shell interpretation as comments:
- ✅ `~/.claude/scripts/gh-review-pr.sh "org/repo#123"`
- ❌ `~/.claude/scripts/gh-review-pr.sh org/repo#123` (# will be treated as comment)

### Script Location
`~/.claude/scripts/gh-review-pr.sh`

### What the script does
1. Parses PR reference (number, #number, org/repo#number, or URL)
2. Fetches PR metadata (title, author, state, files, etc.)
3. Displays PR summary in a formatted box
4. Shows list of changed files with additions/deletions
5. Displays full diff with syntax highlighting
6. Prompts for review action (unless using quick options)
7. Executes chosen action via GitHub API

### PR Information Displayed
- Title and PR number
- Author
- State (open/closed/merged) and draft status
- Source and target branches
- Mergeable status
- Number of files changed
- PR description
- File-by-file changes with line counts

### Error Handling
- Validates PR exists before attempting review
- Handles large PRs that might timeout
- Provides clear error messages for invalid references
- Gracefully handles missing PR descriptions